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

print_status "Starting StudyStats Site Deployment v2..."
print_status "Project directory: $PROJECT_DIR"

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

# Optional: Deploy to GitHub Pages if using gh-pages
if git show-ref --verify --quiet refs/heads/gh-pages; then
    read -p "Deploy to GitHub Pages? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Deploying to GitHub Pages..."
        
        # Copy _site contents to gh-pages branch
        git checkout gh-pages
        
        # Remove old files (keep .git)
        find . -maxdepth 1 ! -name '.git' ! -name '.' ! -name '..' -exec rm -rf {} +
        
        # Copy new site files
        git checkout "$CURRENT_BRANCH" -- _site/
        mv _site/* .
        rmdir _site
        
        # Commit and push gh-pages
        git add .
        git commit -m "Deploy site: $(date '+%Y-%m-%d %H:%M:%S')" || true
        git push origin gh-pages
        
        # Switch back to main branch
        git checkout "$CURRENT_BRANCH"
        
        print_success "Deployed to GitHub Pages"
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
