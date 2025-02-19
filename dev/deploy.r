
system("cd /Users/briday/Desktop/study_stats_site") # change to the directory where the html is stored
system("ls /Users/briday/Desktop/study_stats_site") # list the files in the directory
system("pwd")   # print the working directory
system("git init") # initialize the git repository
system( "git remote add origin https://github.com/bridaybrummer/study_stats_site.git")

system("quarto render")

system("git add .") # add all the files to the repository

system("git config --global http.postBuffer 524288000")
system("git branch -M main")
system("git pull origin main --rebase")
system("git commit -m 'first commit'") # commit the changes
system("git push -u origin main") # create a new branch

# check if push is in progress
system( "git status") # check the status of the repository



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
