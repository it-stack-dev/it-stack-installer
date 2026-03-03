#!/usr/bin/env pwsh
# scripts/setup/setup-github.ps1
# Authenticate GitHub CLI and configure defaults for the it-stack-dev org.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts/setup/setup-github.ps1
#   powershell -ExecutionPolicy Bypass -File scripts/setup/setup-github.ps1 -Token "ghp_xxx"

[CmdletBinding()]
param(
  [string]$Token = "",
  [string]$Org   = "it-stack-dev"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step { param($msg) Write-Host "`n[STEP] $msg" -ForegroundColor Cyan }
function Write-OK   { param($msg) Write-Host "  [OK] $msg"   -ForegroundColor Green }
function Write-Fail { param($msg) Write-Host " [ERR] $msg"   -ForegroundColor Red }

# â”€â”€ Check gh is installed â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
Write-Step "Checking GitHub CLI"
if (!(Get-Command gh -ErrorAction SilentlyContinue)) {
  Write-Fail "gh not found. Run scripts/setup/install-tools.ps1 first."
  exit 1
}
Write-OK "gh $(gh --version | Select-Object -First 1)"

# â”€â”€ Authenticate â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
Write-Step "Authenticating with GitHub"
$authStatus = gh auth status 2>&1
if ($authStatus -match "Logged in") {
  Write-OK "Already authenticated"
  $authStatus | Select-Object -First 3 | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
} elseif ($Token -ne "") {
  Write-Host "  Logging in with provided token..." -ForegroundColor DarkGray
  $Token | gh auth login --with-token
  Write-OK "Authenticated via token"
} else {
  Write-Host "  Launching interactive login..." -ForegroundColor DarkGray
  gh auth login --hostname github.com --git-protocol https --web
}

# â”€â”€ Verify org access â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
Write-Step "Verifying org access: $Org"
try {
  $orgInfo = gh api "orgs/$Org" --jq '.login,.name' 2>&1
  Write-OK "Org accessible: $orgInfo"
} catch {
  Write-Fail "Cannot access org $Org. Check token scopes (need: repo, read:org, project)"
  exit 1
}

# â”€â”€ Set git config â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
Write-Step "Configuring git defaults"
$gitUser  = gh api user --jq '.login' 2>&1
$gitEmail = gh api user/emails --jq '.[0].email' 2>&1
git config --global user.name  $gitUser
git config --global user.email $gitEmail
git config --global core.autocrlf false
git config --global init.defaultBranch main
Write-OK "git user: $gitUser <$gitEmail>"

# â”€â”€ Configure gh defaults â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
Write-Step "Setting gh defaults"
gh config set git_protocol https
gh config set prompt enabled
Write-OK "gh defaults set"

Write-Host ""
Write-Host "GitHub CLI configured for org: $Org" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Run scripts/operations/clone-all-repos.ps1"
Write-Host "  2. Or run scripts/github/create-phase1-modules.ps1 to create repos"