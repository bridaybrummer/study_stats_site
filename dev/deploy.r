# Set the working directory to your project folder.
setwd("/Users/briday/Desktop/study_stats_site")
cat("Current working directory:", getwd(), "\n")

# List files in the directory.
cat("Directory listing:\n")
system("ls")

# Initialize the Git repository if it hasn't been initialized.
if (!dir.exists(".git")) {
  system("git init")
  cat("Initialized new Git repository.\n")
} else {
  cat("Git repository already exists.\n")
}

# Add the remote "origin" if it does not exist.
remotes <- system("git remote", intern = TRUE)
if (!("origin" %in% remotes)) {
  system("git remote add origin https://github.com/bridaybrummer/study_stats_site.git")
  cat("Added remote 'origin'.\n")
} else {
  cat("Remote 'origin' already exists.\n")
}

# Render your Quarto site.
cat("Rendering Quarto site...\n")
system("quarto render")

# Add all files to Git.
system("git add .")
cat("Added all files to staging.\n")

# Increase the postBuffer size (if needed for large pushes).
system("git config --global http.postBuffer 524288000")

# Ensure the current branch is named 'main'.
system("git branch -M main")
cat("Renamed branch to 'main'.\n")

# Pull remote changes to ensure your local branch is up-to-date.
cat("Pulling latest changes from remote 'main' branch...\n")
system("git pull origin main --rebase")

# Check if there are staged changes that need to be committed.
status <- system("git diff --cached --quiet")
if (status != 0) {
  # If there are changes, commit them.
  system("git commit -m 'Update site after Quarto render'")
  cat("Committed changes.\n")
} else {
  cat("No changes to commit.\n")
}

# Push changes to the remote repository.
cat("Pushing changes to remote 'main' branch...\n")
system("git push -u origin main")

# Final status check.
cat("Git status:\n")
system("git status")


# go to gh-pages branch and add the _site folder

# 1. Change to your project directory where your source and rendered files reside.
setwd("/Users/briday/Desktop/study_stats_site")

# 2. Initialize Git (if not already) and add the remote.
if (!dir.exists(".git")) {
  system("git init")
}

# Add the remote "origin" if it’s not already present.
remotes <- system("git remote", intern = TRUE)
if (!"origin" %in% remotes) {
  system("git remote add origin https://github.com/bridaybrummer/study_stats_site.git")
}

# 3. Render your Quarto site (this will output your HTML to the _site folder).
system("quarto render")

# 4. Remove any existing local 'gh-pages' branch.
local_branches <- system("git branch", intern = TRUE)
if (any(grepl("gh-pages", local_branches))) {
  system("git branch -D gh-pages")
}

# 5. Delete the remote 'gh-pages' branch if it exists.
#    (This command may output an error if the branch doesn't exist—but that's okay.)
system("git push origin --delete gh-pages", ignore.stderr = TRUE)

# 6. Create a subtree split from the _site folder into a temporary branch named 'gh-pages'.
system("git subtree split --prefix _site -b gh-pages")

# 7. Force push the new 'gh-pages' branch to GitHub.
system("git push origin gh-pages --force")

# 8. Clean up by deleting the temporary local 'gh-pages' branch.
system("git branch -D gh-pages")
