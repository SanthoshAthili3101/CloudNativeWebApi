# commit-and-push.ps1
# Stage, commit, and push changes to an existing Git repository with user-provided commit message and branch name

param (
    [Parameter(Mandatory=$true)]
    [string]$CommitMessage,
    [Parameter(Mandatory=$true)]
    [string]$BranchName
)

# Ensure the script stops on errors
$ErrorActionPreference = "Stop"

# Check if git is installed
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error "Git is not installed or not found in PATH. Please install Git."
    exit 1
}

# Check if the current directory is a Git repository
if (-not (Test-Path .git)) {
    Write-Error "This directory is not a Git repository. Please run this script in a Git repository."
    exit 1
}

# Check if the branch exists locally, create it if it doesn't
$branchExists = git rev-parse --verify $BranchName 2>$null
if (-not $branchExists) {
    Write-Host "Creating and switching to branch $BranchName..."
    git checkout -b $BranchName
} else {
    Write-Host "Switching to branch $BranchName..."
    git checkout $BranchName
}

# Check if there are changes to commit
$status = git status --porcelain
if (-not $status) {
    Write-Host "No changes to commit."
    exit 0
}

# Stage all changes (modified, new, or deleted files)
Write-Host "Staging all changes..."
git add .

# Commit changes
Write-Host "Committing changes with message: $CommitMessage..."
git commit -m $CommitMessage

# Push to the remote repository
Write-Host "Pushing to $BranchName..."
git push origin $BranchName

Write-Host "Changes committed and pushed successfully!"