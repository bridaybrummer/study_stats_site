#!/bin/bash

# StudyStats Site Deployment Script v2
# This script cleans up git files and deploys the newly rendered site
# Usage: ./deploy_v2.sh [commit_message]

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Change to project directory
cd "$PROJECT_DIR"

# Activate project Python venv if present (Quarto needs jupyter+pyyaml
# for some pages; the venv lives in .venv/).
if [ -f ".venv/bin/activate" ]; then
    # shellcheck disable=SC1091
    source .venv/bin/activate
fi

print_status "Starting StudyStats Site Deployment v2..."
print_status "Project directory: $PROJECT_DIR"

# Purge iCloud / Finder sync-conflict duplicates (e.g. "foo 2.qmd")
# These break Quarto render with `os error 60` (TimedOut) when iCloud
# leaves them as offline-only stubs. Safe: only matches "<name> <digits>"
# suffixes, excludes .git/.venv/_site/etc by default.
if [ -x "$SCRIPT_DIR/clean_icloud_dupes.sh" ]; then
    print_status "Purging iCloud sync-conflict duplicates..."
    "$SCRIPT_DIR/clean_icloud_dupes.sh" --apply | tail -3 || true
fi

# Check if we're in a git repository
if [ ! -d ".git" ]; then
    print_error "Not a git repository. Please initialize git first."
    exit 1
fi

# Clean up old git backups
print_status "Cleaning up old git backups..."
if ls .git.bak_* 1> /dev/null 2>&1; then
    rm -rf .git.bak_*
    print_success "Removed old git backup files"
else
    print_status "No git backup files found"
fi

# Check if we're in a detached HEAD state
GIT_STATUS=$(git status --porcelain=v1 2>/dev/null || echo "error")
if git status | grep -q "HEAD detached"; then
    print_warning "Currently in detached HEAD state"
    
    # Try to switch back to main branch
    if git show-ref --verify --quiet refs/heads/main; then
        print_status "Switching to main branch..."
        git checkout main
    elif git show-ref --verify --quiet refs/heads/master; then
        print_status "Switching to master branch..."
        git checkout master
    else
        print_warning "No main/master branch found. Creating main branch..."
        git checkout -b main
    fi
fi

# Get current branch
CURRENT_BRANCH=$(git branch --show-current)
print_status "Current branch: $CURRENT_BRANCH"

# Render the Quarto site
print_status "Rendering Quarto site..."
if command -v quarto &> /dev/null; then
    quarto render
    print_success "Quarto site rendered successfully"
else
    print_error "Quarto not found. Please install Quarto CLI."
    exit 1
fi

# Add all changes to git
print_status "Adding changes to git..."
git add .

# Check if there are any changes to commit
if git diff --staged --quiet; then
    print_warning "No changes to commit"
else
    # Get commit message
    if [ -n "$1" ]; then
        COMMIT_MSG="$1"
    else
        COMMIT_MSG="Auto-deploy: Update site content $(date '+%Y-%m-%d %H:%M:%S')"
    fi
    
    print_status "Committing changes with message: $COMMIT_MSG"
    git commit -m "$COMMIT_MSG"
    print_success "Changes committed successfully"
fi

# Push to remote if it exists
if git remote | grep -q origin; then
    print_status "Pushing to remote repository..."
    
    # Set upstream if it doesn't exist
    if ! git rev-parse --abbrev-ref --symbolic-full-name @{u} &>/dev/null; then
        print_status "Setting upstream branch..."
        git push --set-upstream origin "$CURRENT_BRANCH"
    else
        git push
    fi
    
    print_success "Pushed to remote repository"
else
    print_warning "No remote repository configured"
fi

# Deploy to GitHub Pages via the gh-pages branch.
# IMPORTANT: _site is gitignored on the source branch, so it cannot be
# 'git checkout'-ed across branches. We stage it to a temp dir on the
# filesystem before switching branches, then sync into gh-pages.
if git show-ref --verify --quiet refs/heads/gh-pages || \
   git ls-remote --exit-code --heads origin gh-pages &>/dev/null; then

    read -p "Deploy to GitHub Pages? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        print_status "Deploying to GitHub Pages..."

        if [ ! -d "_site" ]; then
            print_error "_site/ does not exist. Run 'quarto render' first."
            exit 1
        fi

        # Stage rendered site to a temp dir outside the working tree.
        STAGE_DIR="$(mktemp -d -t studystats_site_XXXX)"
        print_status "Staging site to $STAGE_DIR"
        # rsync preserves dotfiles (.nojekyll, CNAME if dotted) and is
        # safer than mv; trailing /. copies contents only.
        rsync -a --delete _site/ "$STAGE_DIR/"

        # Ensure GitHub Pages does NOT run Jekyll on Quarto's _-prefixed dirs.
        touch "$STAGE_DIR/.nojekyll"

        # Ensure custom domain CNAME is present.
        if [ -f CNAME ] && [ ! -f "$STAGE_DIR/CNAME" ]; then
            cp CNAME "$STAGE_DIR/CNAME"
        fi

        # Switch to gh-pages (create tracking branch from origin if local missing).
        if git show-ref --verify --quiet refs/heads/gh-pages; then
            git checkout gh-pages
        else
            git fetch origin gh-pages
            git checkout -b gh-pages origin/gh-pages
        fi

        # Remove only TRACKED files; leaves local untracked dirs (.venv,
        # _site, .quarto, etc.) intact.
        git rm -rf . >/dev/null 2>&1 || true

        # Copy the staged site over the now-empty tree (incl. dotfiles).
        rsync -a "$STAGE_DIR/" ./

        # Write a .gitignore so 'git add -A' does NOT pick up local-only
        # source-tree dirs that may still be sitting in the working tree
        # (.venv/, .quarto/ cache, _site/, macOS noise). Without this,
        # git add -A races with Quarto rewriting .quarto/idx/*.json.
        cat > .gitignore <<'GITIGNORE'
.venv/
.quarto/
_site/
.DS_Store
**/.DS_Store
*~
GITIGNORE

        git add -A
        if git diff --staged --quiet; then
            print_warning "gh-pages: no changes to deploy"
        else
            git commit -m "Deploy site: $(date '+%Y-%m-%d %H:%M:%S')"
            git push origin gh-pages
            print_success "Deployed to GitHub Pages"
        fi

        # Return to source branch and clean up.
        git checkout "$CURRENT_BRANCH"
        rm -rf "$STAGE_DIR"
    fi
fi

# Summary
print_success "Deployment completed successfully!"
print_status "Site files are in: $PROJECT_DIR/_site/"
print_status "Git repository is clean and up to date"

# Optional: Open the site in browser
if command -v open &> /dev/null && [ -f "_site/index.html" ]; then
    read -p "Open site in browser? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        open "_site/index.html"
    fi
fi

print_success "Done! 🚀"
