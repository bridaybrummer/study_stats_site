# StudyStats Site Deployment Script v2 (R Version)
# This script cleans up git files and deploys the newly rendered site
# Usage: source("dev/deploy_v2.r") or Rscript dev/deploy_v2.r "commit message"

# Function to print colored messages
print_status <- function(msg, type = "info") {
  timestamp <- format(Sys.time(), "%H:%M:%S")
  
  colors <- list(
    info = "\033[0;34m[INFO]\033[0m",
    success = "\033[0;32m[SUCCESS]\033[0m", 
    warning = "\033[1;33m[WARNING]\033[0m",
    error = "\033[0;31m[ERROR]\033[0m"
  )
  
  cat(sprintf("%s [%s] %s\n", colors[[type]], timestamp, msg))
}

# Function to run system commands with error handling
run_cmd <- function(cmd, error_msg = NULL) {
  result <- system(cmd, intern = TRUE, ignore.stderr = FALSE)
  exit_code <- attr(result, "status")
  
  if (!is.null(exit_code) && exit_code != 0) {
    if (!is.null(error_msg)) {
      print_status(error_msg, "error")
    }
    print_status(paste("Command failed:", cmd), "error")
    stop("Deployment failed")
  }
  
  return(result)
}

# Main deployment function
deploy_site <- function(commit_msg = NULL) {
  
  print_status("Starting StudyStats Site Deployment v2...")
  
  # Get project directory
  if (basename(getwd()) == "dev") {
    setwd("..")
  }
  
  project_dir <- getwd()
  print_status(paste("Project directory:", project_dir))
  
  # Check if we're in a git repository
  if (!dir.exists(".git")) {
    print_status("Not a git repository. Please initialize git first.", "error")
    stop("Not a git repository")
  }
  
  # Clean up old git backups
  print_status("Cleaning up old git backups...")
  backup_files <- list.files(pattern = "^\\.git\\.bak_", all.files = TRUE, full.names = TRUE)
  
  if (length(backup_files) > 0) {
    unlink(backup_files, recursive = TRUE)
    print_status("Removed old git backup files", "success")
  } else {
    print_status("No git backup files found")
  }
  
  # Check git status
  git_status <- run_cmd("git status --porcelain=v1")
  
  # Check if we're in detached HEAD state
  status_output <- run_cmd("git status")
  if (any(grepl("HEAD detached", status_output))) {
    print_status("Currently in detached HEAD state", "warning")
    
    # Try to switch to main branch
    branches <- run_cmd("git branch -a")
    
    if (any(grepl("main", branches))) {
      print_status("Switching to main branch...")
      run_cmd("git checkout main")
    } else if (any(grepl("master", branches))) {
      print_status("Switching to master branch...")
      run_cmd("git checkout master")
    } else {
      print_status("No main/master branch found. Creating main branch...", "warning")
      run_cmd("git checkout -b main")
    }
  }
  
  # Get current branch
  current_branch <- trimws(run_cmd("git branch --show-current"))
  print_status(paste("Current branch:", current_branch))
  
  # Check if quarto is available
  quarto_available <- tryCatch({
    system("quarto --version", ignore.stdout = TRUE, ignore.stderr = TRUE) == 0
  }, error = function(e) FALSE)
  
  if (quarto_available) {
    print_status("Rendering Quarto site...")
    run_cmd("quarto render", "Failed to render Quarto site")
    print_status("Quarto site rendered successfully", "success")
  } else {
    print_status("Quarto not found. Checking for alternative rendering methods...", "warning")
    
    # Try using rmarkdown if available
    if (requireNamespace("rmarkdown", quietly = TRUE)) {
      print_status("Using rmarkdown to render site...")
      try({
        rmarkdown::render_site()
        print_status("Site rendered using rmarkdown", "success")
      })
    } else {
      print_status("Neither Quarto nor rmarkdown available for rendering", "error")
      stop("No rendering method available")
    }
  }
  
  # Add all changes to git
  print_status("Adding changes to git...")
  run_cmd("git add .")
  
  # Check if there are changes to commit
  staged_changes <- run_cmd("git diff --staged --name-only")
  
  if (length(staged_changes) == 0 || all(staged_changes == "")) {
    print_status("No changes to commit", "warning")
  } else {
    # Generate commit message if not provided
    if (is.null(commit_msg)) {
      args <- commandArgs(trailingOnly = TRUE)
      if (length(args) > 0) {
        commit_msg <- args[1]
      } else {
        commit_msg <- paste("Auto-deploy: Update site content", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
      }
    }
    
    print_status(paste("Committing changes with message:", commit_msg))
    run_cmd(paste0("git commit -m \"", commit_msg, "\""))
    print_status("Changes committed successfully", "success")
  }
  
  # Check for remote repository
  remotes <- run_cmd("git remote")
  
  if (length(remotes) > 0 && any(grepl("origin", remotes))) {
    print_status("Pushing to remote repository...")
    
    # Check if upstream is set
    upstream_check <- tryCatch({
      run_cmd("git rev-parse --abbrev-ref --symbolic-full-name @{u}")
      TRUE
    }, error = function(e) FALSE)
    
    if (!upstream_check) {
      print_status("Setting upstream branch...")
      run_cmd(paste("git push --set-upstream origin", current_branch))
    } else {
      run_cmd("git push")
    }
    
    print_status("Pushed to remote repository", "success")
  } else {
    print_status("No remote repository configured", "warning")
  }
  
  # Check for GitHub Pages deployment
  branches <- run_cmd("git branch -a")
  if (any(grepl("gh-pages", branches))) {
    response <- readline(prompt = "Deploy to GitHub Pages? (y/N): ")
    
    if (tolower(trimws(response)) %in% c("y", "yes")) {
      print_status("Deploying to GitHub Pages...")
      
      tryCatch({
        # Switch to gh-pages branch
        run_cmd("git checkout gh-pages")
        
        # Remove old files (except .git)
        files_to_remove <- list.files(all.files = FALSE, full.names = TRUE)
        files_to_remove <- files_to_remove[!grepl("^\\.git", basename(files_to_remove))]
        unlink(files_to_remove, recursive = TRUE)
        
        # Copy new site files
        run_cmd(paste("git checkout", current_branch, "-- _site/"))
        
        # Move _site contents to root
        if (dir.exists("_site")) {
          site_files <- list.files("_site", all.files = TRUE, full.names = TRUE)
          site_files <- site_files[!basename(site_files) %in% c(".", "..")]
          
          for (file in site_files) {
            file.copy(file, ".", recursive = TRUE, overwrite = TRUE)
          }
          unlink("_site", recursive = TRUE)
        }
        
        # Commit and push gh-pages
        run_cmd("git add .")
        
        tryCatch({
          run_cmd(paste("git commit -m \"Deploy site:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\""))
        }, error = function(e) {
          print_status("No changes to commit in gh-pages", "warning")
        })
        
        run_cmd("git push origin gh-pages")
        
        # Switch back to main branch
        run_cmd(paste("git checkout", current_branch))
        
        print_status("Deployed to GitHub Pages", "success")
        
      }, error = function(e) {
        print_status(paste("GitHub Pages deployment failed:", e$message), "error")
        # Try to switch back to main branch
        tryCatch(run_cmd(paste("git checkout", current_branch)), error = function(e2) {})
      })
    }
  }
  
  # Summary
  print_status("Deployment completed successfully!", "success")
  print_status(paste("Site files are in:", file.path(project_dir, "_site")))
  print_status("Git repository is clean and up to date")
  
  # Optional: Open site in browser
  if (file.exists("_site/index.html")) {
    if (.Platform$OS.type == "unix" && Sys.info()["sysname"] == "Darwin") {
      response <- readline(prompt = "Open site in browser? (y/N): ")
      if (tolower(trimws(response)) %in% c("y", "yes")) {
        system("open _site/index.html")
      }
    }
  }
  
  print_status("Done! 🚀", "success")
  
  return(invisible(TRUE))
}

# If script is run directly (not sourced), execute deployment
if (!interactive()) {
  args <- commandArgs(trailingOnly = TRUE)
  commit_msg <- if (length(args) > 0) args[1] else NULL
  deploy_site(commit_msg)
} else {
  cat("Deployment functions loaded. Run deploy_site() to start deployment.\n")
  cat("Usage: deploy_site('your commit message')\n")
}
