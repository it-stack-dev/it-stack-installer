#!/usr/bin/env pwsh
# scripts/setup/setup-directory-structure.ps1
# Creates the full C:\IT-Stack\it-stack-dev\ directory tree.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts/setup/setup-directory-structure.ps1
#   powershell -ExecutionPolicy Bypass -File scripts/setup/setup-directory-structure.ps1 -Root "D:\mypath"

[CmdletBinding()]
param(
  [string]$Root = "C:\IT-Stack\it-stack-dev"
)

Set-StrictMode -Version Latest

$dirs = @(
  # Repo category directories
  "repos\meta",
  "repos\01-identity",
  "repos\02-database",
  "repos\03-collaboration",
  "repos\04-communications",
  "repos\05-business",
  "repos\06-it-management",
  "repos\07-infrastructure",
  # Work directories
  "workspaces\sprint-current",
  "workspaces\sprint-archive",
  "deployments\local",
  "deployments\dev",
  "deployments\staging",
  "deployments\production",
  # Lab environments
  "lab-environments\tier-1-lab",
  "lab-environments\tier-1-school",
  "lab-environments\tier-2-department",
  "lab-environments\tier-3-enterprise",
  # Configuration
  "configs\global",
  "configs\modules",
  "configs\environments",
  "configs\secrets",
  # Scripts (this repo will be cloned here)
  "scripts\setup",
  "scripts\github",
  "scripts\operations",
  "scripts\utilities",
  "scripts\deployment",
  "scripts\testing",
  # Logs
  "logs\ansible",
  "logs\deployments",
  "logs\labs"
)

$created = 0
$existed = 0

foreach ($dir in $dirs) {
  $fullPath = Join-Path $Root $dir
  if (Test-Path $fullPath) {
    $existed++
  } else {
    New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
    Write-Host "  [+] $dir" -ForegroundColor Green
    $created++
  }
}

# Create placeholder .gitkeep files in empty leaf directories
$emptyDirs = @("configs\secrets", "logs\ansible", "logs\deployments", "logs\labs")
foreach ($dir in $emptyDirs) {
  $keepFile = Join-Path $Root "$dir\.gitkeep"
  if (!(Test-Path $keepFile)) {
    New-Item -ItemType File -Path $keepFile -Force | Out-Null
  }
}

# Create configs/secrets/.gitignore to ensure secrets never leak
$secretsGitignore = Join-Path $Root "configs\secrets\.gitignore"
if (!(Test-Path $secretsGitignore)) {
  Set-Content -Path $secretsGitignore -Value "*`n!.gitignore"
}

Write-Host ""
Write-Host "Directory structure ready at: $Root" -ForegroundColor Cyan
Write-Host "  Created: $created directories" -ForegroundColor Green
Write-Host "  Already existed: $existed directories" -ForegroundColor DarkGray
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Run scripts/setup/setup-github.ps1"
Write-Host "  2. Run scripts/operations/clone-all-repos.ps1"