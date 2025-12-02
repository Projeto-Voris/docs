# Git & Submodule Cheat Sheet

## 1\. Setup & Configuration

*Run these once when setting up a new environment.*

```bash
# Set your identity (Essential for commits)
git config --global user.name "Your Name"
git config --global user.email "you@example.com"

# View current configuration
git config --list

# Initialize a new repo in current folder
git init

# Clone a repository (Standard)
git clone https://github.com/user/repo.git
```

## 2\. The Daily Workflow

*The loop you will repeat most often.*

```bash
# Check status (Modified files, untracked files) - USE OFTEN
git status

# Stage files (Prepare them for commit)
git add filename.py       # Add specific file
git add .                 # Add EVERYTHING (use carefully)

# Commit staged changes
git commit -m "Description of changes"

# Send to remote server
git push origin main

# Get latest changes from server
git pull origin main
```

## 3\. Submodules: The Essentials

*Managing repositories inside repositories.*

```bash
# 1. Add a new submodule
# Syntax: git submodule add <url> <path>
git submodule add https://github.com/org/repo.git src/my_submodule

# 2. Clone a NEW repo including its submodules
git clone --recursive https://github.com/user/main-repo.git

# 3. The "Silver Bullet" (Revive empty folders)
# Run this if you pulled a repo and submodule folders are empty
git submodule update --init --recursive

# 4. Update submodules to latest remote version
# Ignores the "locked" commit and fetches latest from branch
git submodule update --remote --merge
```

## 4\. Submodules: Advanced & Troubleshooting

*Fixing URLs, changing protocols, and cleaning messes.*

```bash
# CHANGE SUBMODULE URL (e.g., SSH to HTTPS)
# Step 1: Set the new URL
git submodule set-url path/to/module https://new-url.com/repo.git
# Step 2: Sync (CRITICAL - updates local .git/config)
git submodule sync
# Step 3: Update to test connection
git submodule update --init --recursive

# FIX "GHOST COMMIT" (Submodule points to commit not found on server)
# Go inside the submodule, checkout main, pull, then commit the fix in parent
cd path/to/submodule
git checkout main
git pull origin main
cd ..
git add path/to/submodule
git commit -m "Fixed submodule pointer"

# REMOVE A BROKEN SUBMODULE (The "Clean Slate" method)
# 1. Untrack the path
git rm --cached path/to/broken_module
# 2. Remove config entry
git config --remove-section submodule.path/to/broken_module
# 3. Delete internal git storage
rm -rf .git/modules/path/to/broken_module
# 4. Delete the physical folder
rm -rf path/to/broken_module
```

## 5\. Branching & Merging

*Working on features without breaking the main code.*

```bash
# List all branches
git branch

# Create a new branch and switch to it
git checkout -b feature-name

# Switch back to main
git checkout main

# Merge feature into main
git merge feature-name
```

## 6\. Undo & Emergency

*Fixing mistakes before (or after) they happen.*

```bash
# UNSTAGE files (Fix "Changes to be committed" mistake)
git restore --staged .

# DISCARD local changes to a file (Revert to last commit)
git restore file.txt

# SHOW modifications (What did I just type?)
git diff

# VIEW History
git log --oneline
```
