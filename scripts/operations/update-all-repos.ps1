#!/usr/bin/env pwsh
# scripts/operations/update-all-repos.ps1
# Pull latest changes for all cloned it-stack repositories.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts/operations/update-all-repos.ps1
#   powershell -ExecutionPolicy Bypass -File scripts/operations/update-all-repos.ps1 -Branch develop

[CmdletBinding()]
param(
  [string]$Root   = "C:\IT-Stack\it-stack-dev",
  [string]$Branch = "main",
  [switch]$Status  # Show git status instead of pulling
)

Set-StrictMode -Version Latest

$searchDirs = @(
  "repos\meta",
  "repos\01-identity",
  "repos\02-database",
  "repos\03-collaboration",
  "repos\04-communications",
  "repos\05-business",
  "repos\06-it-management",
  "repos\07-infrastructure"
)

$updated  = 0
$failed   = 0
$notFound = 0

foreach ($dir in $searchDirs) {
  $fullDir = Join-Path $Root $dir
  if (!(Test-Path $fullDir)) { continue }

  Get-ChildItem -Path $fullDir -Directory | Where-Object { Test-Path "$($_.FullName)\.git" } | ForEach-Object {
    $repoPath = $_.FullName
    $repoName = $_.Name

    Push-Location $repoPath
    try {
      if ($Status) {
        $dirty = git status --porcelain 2>&1
        $branch = git branch --show-current 2>&1
        if ($dirty) {
          Write-Host "  [M]  $repoName ($branch) â€” uncommitted changes" -ForegroundColor Yellow
        } else {
          Write-Host "  [OK] $repoName ($branch)" -ForegroundColor DarkGray
        }
      } else {
        $currentBranch = git branch --show-current 2>&1
        Write-Host "  [>>] $repoName ($currentBranch)" -ForegroundColor Cyan
        git fetch --quiet 2>&1 | Out-Null
        git pull --ff-only --quiet origin $Branch 2>&1
        if ($LASTEXITCODE -eq 0) {
          $updated++
        } else {
          Write-Host "       Warning: pull failed (may not have branch '$Branch')" -ForegroundColor Yellow
          $failed++
        }
      }
    } finally {
      Pop-Location
    }
  }
}

if (!$Status) {
  Write-Host ""
  Write-Host "Update complete â€” Updated: $updated  |  Issues: $failed" -ForegroundColor Cyan
}