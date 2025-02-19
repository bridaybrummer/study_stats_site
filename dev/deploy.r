
system("cd /Users/briday/Desktop/study_stats_site") # change to the directory where the html is stored
system("ls /Users/briday/Desktop/study_stats_site") # list the files in the directory
system("pwd")   # print the working directory
system("git init") # initialize the git repository
system( "git remote add origin https://github.com/bridaybrummer/study_stats_site.git")

system("quarto render")
system("git add _site") # add all the files to the repository


system("git add .") # add all the files to the repository
system( "git commit -m 'removal'") # commit the changes
system("git config --global http.postBuffer 524288000")
system("git branch -M main")
system("git push -u origin main") # create a new branch

# check if push is in progress
system( "git status") # check the status of the repository

# there is a naming error potentially, so rename the file to index.html
system(" git mv nmc_dashboard.html index.html")
system( "git commit -m \"Rename nmc_dashboard.html to index.html\"")
system("git push")



# remove all files from the repo 
system("git rm -r --cached .")

system("rm -rf .git") # remove the git repository
system("git init") # initialize the git repository

system( "git config pull.rebase false") # set the pull.rebase to false
system("git pull origin main") # pull the repository from the main branch

system( "ls | grep -v //^site$")

system( "ls .")

# remove all files from repo 
system(" git rm -r --cached .")


# * branch            main       -> FETCH_HEAD
# fatal: refusing to merge unrelated histories

# there is an error with the pull, so we need to force the pull

system("git pull origin main --allow-unrelated-histories") # pull the repository from the main branch






################

# 1. Change to your project directory where your source and rendered files reside.
system("cd /Users/briday/Desktop/study_stats_site")

# 2. Initialize Git (if not already initialized) and add the remote.
system("git init")
system("git remote add origin https://github.com/bridaybrummer/study_stats_site.git")

# 3. Render your Quarto site (this will output your HTML to your configured folder, e.g., _site).
system("quarto render")

# 4. (Optional) Commit your source files on the main branch.
system("git add .")
system("git commit -m 'Update source and rendered HTML'")
system("git branch -M main")
system("git push -u origin main")

# 5. Create an orphan branch for GitHub Pages called gh-pages.
#    This branch will have no history and will contain only your rendered HTML.
system("git checkout --orphan gh-pages")

# 6. Remove all files from the gh-pages branch.
system("git rm -rf .")

# 7. Copy your rendered HTML files into the root of the gh-pages branch.
#    Here we assume your rendered site is in a folder called _site.
system("cp -r _site/* .")

# 8. If needed, rename the main HTML file to index.html.
#    For example, if your main file is named nmc_dashboard.html:
system("git mv nmc_dashboard.html index.html")

# 9. Add, commit, and push the gh-pages branch.
system("git add .")
system("git commit -m 'Deploy rendered HTML for GitHub Pages'")
system("git push -u origin gh-pages --force")

# 10. (Optional) Check the status to ensure everything is committed.
system("git status")
