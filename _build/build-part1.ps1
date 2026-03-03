#!/usr/bin/env pwsh
# _build/build-part1.ps1
# Creates: scripts/setup/ (3) + scripts/operations/ (2) + scripts/utilities/ (1)
#          scripts/deployment/ (1) + scripts/testing/ (1) = 8 scripts

$root = "C:\IT-Stack\it-stack-dev\repos\meta\it-stack-installer"

function Write-Script { param($path, $content)
  $dir = Split-Path $path
  if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  [System.IO.File]::WriteAllText($path, $content, [System.Text.UTF8Encoding]::new($false))
}

# ══════════════════════════════════════════════════════════════
# scripts/setup/install-tools.ps1
# ══════════════════════════════════════════════════════════════
Write-Script "$root\scripts\setup\install-tools.ps1" @'
#!/usr/bin/env pwsh
# scripts/setup/install-tools.ps1
# Install all tools required for IT-Stack development on Windows.
#
# Tools installed:
#   Git, GitHub CLI (gh), Docker Desktop, kubectl, Helm,
#   Ansible (via WSL/pip), Terraform, Python 3, jq, make
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts/setup/install-tools.ps1
#   powershell -ExecutionPolicy Bypass -File scripts/setup/install-tools.ps1 -Verbose

[CmdletBinding()]
param(
  [switch]$SkipWinget,
  [switch]$CheckOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step  { param($msg) Write-Host "`n[STEP] $msg" -ForegroundColor Cyan }
function Write-OK    { param($msg) Write-Host "  [OK] $msg"   -ForegroundColor Green }
function Write-Skip  { param($msg) Write-Host "  [--] $msg"   -ForegroundColor DarkGray }
function Write-Warn  { param($msg) Write-Host "  [!!] $msg"   -ForegroundColor Yellow }
function Write-Fail  { param($msg) Write-Host " [ERR] $msg"   -ForegroundColor Red }

function Test-CommandExists { param($cmd) return [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }

function Install-ViaWinget { param($id, $name)
  if ($CheckOnly) { Write-Skip "$name (check-only mode)"; return }
  Write-Host "  Installing $name via winget..." -ForegroundColor DarkGray
  winget install --id $id --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
  if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq -1978335189) {
    Write-OK "$name installed"
  } else {
    Write-Warn "$name install returned $LASTEXITCODE — may already be installed"
  }
}

$tools = @(
  @{ cmd = "git";      name = "Git";           id = "Git.Git" },
  @{ cmd = "gh";       name = "GitHub CLI";    id = "GitHub.cli" },
  @{ cmd = "docker";   name = "Docker Desktop"; id = "Docker.DockerDesktop" },
  @{ cmd = "kubectl";  name = "kubectl";        id = "Kubernetes.kubectl" },
  @{ cmd = "helm";     name = "Helm";           id = "Helm.Helm" },
  @{ cmd = "terraform"; name = "Terraform";     id = "Hashicorp.Terraform" },
  @{ cmd = "python";   name = "Python 3";       id = "Python.Python.3.12" },
  @{ cmd = "jq";       name = "jq";             id = "jqlang.jq" }
)

Write-Step "Checking installed tools"
$missing = @()
foreach ($tool in $tools) {
  if (Test-CommandExists $tool.cmd) {
    $ver = try { & $tool.cmd --version 2>&1 | Select-Object -First 1 } catch { "unknown" }
    Write-OK "$($tool.name): $ver"
  } else {
    Write-Warn "$($tool.name): NOT FOUND"
    $missing += $tool
  }
}

if ($CheckOnly) {
  Write-Host "`nCheck-only mode. $($missing.Count) tool(s) missing." -ForegroundColor Yellow
  exit ($missing.Count -gt 0 ? 1 : 0)
}

if ($missing.Count -eq 0) {
  Write-Host "`nAll tools already installed." -ForegroundColor Green
  exit 0
}

if ($SkipWinget) {
  Write-Warn "Skipping winget installs (-SkipWinget set)"
  exit 1
}

Write-Step "Installing $($missing.Count) missing tool(s) via winget"
if (!(Test-CommandExists "winget")) {
  Write-Fail "winget not found. Install App Installer from Microsoft Store, then re-run."
  exit 1
}

foreach ($tool in $missing) {
  Install-ViaWinget -id $tool.id -name $tool.name
}

Write-Step "Installing Ansible (via pip in WSL)"
if (Test-CommandExists "wsl") {
  $ansibleCheck = wsl -- which ansible 2>&1
  if ($ansibleCheck -match "ansible") {
    Write-OK "Ansible already installed in WSL"
  } else {
    Write-Host "  Installing Ansible in WSL..." -ForegroundColor DarkGray
    wsl -- sudo apt-get update -qq 2>&1 | Out-Null
    wsl -- sudo apt-get install -y ansible 2>&1 | Out-Null
    Write-OK "Ansible installed in WSL"
  }
} else {
  Write-Warn "WSL not available — Ansible must be installed manually"
  Write-Warn "  Ubuntu: sudo apt install ansible"
  Write-Warn "  macOS:  brew install ansible"
}

Write-Step "Verifying all tools after install"
$failed = @()
foreach ($tool in $tools) {
  if (Test-CommandExists $tool.cmd) {
    $ver = try { & $tool.cmd --version 2>&1 | Select-Object -First 1 } catch { "installed" }
    Write-OK "$($tool.name): $ver"
  } else {
    Write-Fail "$($tool.name): still not found"
    $failed += $tool.name
  }
}

if ($failed.Count -gt 0) {
  Write-Warn "Some tools may require a terminal restart to be recognized:"
  $failed | ForEach-Object { Write-Warn "  $_" }
  Write-Host "`nRestart your terminal and re-run with -CheckOnly to verify." -ForegroundColor Yellow
} else {
  Write-Host "`nAll tools installed successfully!" -ForegroundColor Green
}
'@

# ══════════════════════════════════════════════════════════════
# scripts/setup/setup-directory-structure.ps1
# ══════════════════════════════════════════════════════════════
Write-Script "$root\scripts\setup\setup-directory-structure.ps1" @'
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
'@

# ══════════════════════════════════════════════════════════════
# scripts/setup/setup-github.ps1
# ══════════════════════════════════════════════════════════════
Write-Script "$root\scripts\setup\setup-github.ps1" @'
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

# ── Check gh is installed ─────────────────────────────────────
Write-Step "Checking GitHub CLI"
if (!(Get-Command gh -ErrorAction SilentlyContinue)) {
  Write-Fail "gh not found. Run scripts/setup/install-tools.ps1 first."
  exit 1
}
Write-OK "gh $(gh --version | Select-Object -First 1)"

# ── Authenticate ──────────────────────────────────────────────
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

# ── Verify org access ─────────────────────────────────────────
Write-Step "Verifying org access: $Org"
try {
  $orgInfo = gh api "orgs/$Org" --jq '.login,.name' 2>&1
  Write-OK "Org accessible: $orgInfo"
} catch {
  Write-Fail "Cannot access org $Org. Check token scopes (need: repo, read:org, project)"
  exit 1
}

# ── Set git config ────────────────────────────────────────────
Write-Step "Configuring git defaults"
$gitUser  = gh api user --jq '.login' 2>&1
$gitEmail = gh api user/emails --jq '.[0].email' 2>&1
git config --global user.name  $gitUser
git config --global user.email $gitEmail
git config --global core.autocrlf false
git config --global init.defaultBranch main
Write-OK "git user: $gitUser <$gitEmail>"

# ── Configure gh defaults ────────────────────────────────────
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
'@

Write-Host "setup scripts done"

# ══════════════════════════════════════════════════════════════
# scripts/operations/clone-all-repos.ps1
# ══════════════════════════════════════════════════════════════
Write-Script "$root\scripts\operations\clone-all-repos.ps1" @'
#!/usr/bin/env pwsh
# scripts/operations/clone-all-repos.ps1
# Clone all 26 it-stack-dev repositories into the correct local directories.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts/operations/clone-all-repos.ps1
#   powershell -ExecutionPolicy Bypass -File scripts/operations/clone-all-repos.ps1 -Root "D:\mypath"
#   powershell -ExecutionPolicy Bypass -File scripts/operations/clone-all-repos.ps1 -Phase 1

[CmdletBinding()]
param(
  [string]$Root  = "C:\IT-Stack\it-stack-dev",
  [string]$Org   = "it-stack-dev",
  [int]$Phase    = 0    # 0 = all, 1-4 = specific phase + meta
)

Set-StrictMode -Version Latest

$repos = @(
  # Meta repos
  @{ name = "it-stack-docs";      dir = "repos\meta";               phase = 0 },
  @{ name = "it-stack-installer"; dir = "repos\meta";               phase = 0 },
  @{ name = "it-stack-testing";   dir = "repos\meta";               phase = 0 },
  @{ name = "it-stack-ansible";   dir = "repos\meta";               phase = 0 },
  @{ name = "it-stack-terraform"; dir = "repos\meta";               phase = 0 },
  @{ name = "it-stack-helm";      dir = "repos\meta";               phase = 0 },
  # Phase 1 — Foundation
  @{ name = "it-stack-freeipa";       dir = "repos\01-identity";       phase = 1 },
  @{ name = "it-stack-keycloak";      dir = "repos\01-identity";       phase = 1 },
  @{ name = "it-stack-postgresql";    dir = "repos\02-database";       phase = 1 },
  @{ name = "it-stack-redis";         dir = "repos\02-database";       phase = 1 },
  @{ name = "it-stack-traefik";       dir = "repos\07-infrastructure"; phase = 1 },
  # Phase 2 — Collaboration
  @{ name = "it-stack-nextcloud";     dir = "repos\03-collaboration";  phase = 2 },
  @{ name = "it-stack-mattermost";    dir = "repos\03-collaboration";  phase = 2 },
  @{ name = "it-stack-jitsi";         dir = "repos\03-collaboration";  phase = 2 },
  @{ name = "it-stack-iredmail";      dir = "repos\04-communications"; phase = 2 },
  @{ name = "it-stack-zammad";        dir = "repos\04-communications"; phase = 2 },
  # Phase 3 — Back Office
  @{ name = "it-stack-freepbx";       dir = "repos\04-communications"; phase = 3 },
  @{ name = "it-stack-suitecrm";      dir = "repos\05-business";       phase = 3 },
  @{ name = "it-stack-odoo";          dir = "repos\05-business";       phase = 3 },
  @{ name = "it-stack-openkm";        dir = "repos\05-business";       phase = 3 },
  # Phase 4 — IT Management
  @{ name = "it-stack-taiga";         dir = "repos\06-it-management";  phase = 4 },
  @{ name = "it-stack-snipeit";       dir = "repos\06-it-management";  phase = 4 },
  @{ name = "it-stack-glpi";          dir = "repos\06-it-management";  phase = 4 },
  @{ name = "it-stack-elasticsearch"; dir = "repos\02-database";       phase = 4 },
  @{ name = "it-stack-zabbix";        dir = "repos\07-infrastructure"; phase = 4 },
  @{ name = "it-stack-graylog";       dir = "repos\07-infrastructure"; phase = 4 }
)

$cloned  = 0
$skipped = 0
$failed  = 0

foreach ($repo in $repos) {
  # Filter by phase if specified
  if ($Phase -gt 0 -and $repo.phase -ne 0 -and $repo.phase -ne $Phase) { continue }

  $targetDir  = Join-Path $Root $repo.dir
  $repoPath   = Join-Path $targetDir $repo.name
  $cloneUrl   = "https://github.com/$Org/$($repo.name).git"

  if (!(Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
  }

  if (Test-Path "$repoPath\.git") {
    Write-Host "  [--] $($repo.name) already cloned" -ForegroundColor DarkGray
    $skipped++
  } else {
    Write-Host "  [+]  Cloning $($repo.name)..." -ForegroundColor Cyan
    git clone $cloneUrl $repoPath 2>&1
    if ($LASTEXITCODE -eq 0) {
      Write-Host "       -> $repoPath" -ForegroundColor DarkGray
      $cloned++
    } else {
      Write-Host " [ERR] Failed to clone $($repo.name)" -ForegroundColor Red
      $failed++
    }
  }
}

Write-Host ""
Write-Host "Clone complete:" -ForegroundColor Cyan
Write-Host "  Cloned:  $cloned" -ForegroundColor Green
Write-Host "  Skipped: $skipped" -ForegroundColor DarkGray
if ($failed -gt 0) {
  Write-Host "  Failed:  $failed" -ForegroundColor Red
}
'@

# ══════════════════════════════════════════════════════════════
# scripts/operations/update-all-repos.ps1
# ══════════════════════════════════════════════════════════════
Write-Script "$root\scripts\operations\update-all-repos.ps1" @'
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
          Write-Host "  [M]  $repoName ($branch) — uncommitted changes" -ForegroundColor Yellow
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
  Write-Host "Update complete — Updated: $updated  |  Issues: $failed" -ForegroundColor Cyan
}
'@

Write-Host "operations scripts done"

# ══════════════════════════════════════════════════════════════
# scripts/utilities/create-repo-template.ps1
# ══════════════════════════════════════════════════════════════
Write-Script "$root\scripts\utilities\create-repo-template.ps1" @'
#!/usr/bin/env pwsh
# scripts/utilities/create-repo-template.ps1
# Scaffold a new IT-Stack module repository with the complete standard structure.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts/utilities/create-repo-template.ps1 `
#     -ModuleName "freeipa" -ModuleNumber "01" -Category "01-identity" -Phase 1
#
#   Creates: C:\IT-Stack\it-stack-dev\repos\01-identity\it-stack-freeipa\

[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$ModuleName,    # e.g. "freeipa"
  [Parameter(Mandatory)][string]$ModuleNumber,  # e.g. "01"
  [Parameter(Mandatory)][string]$Category,      # e.g. "01-identity"
  [Parameter(Mandatory)][int]$Phase,            # 1-4
  [string]$Root = "C:\IT-Stack\it-stack-dev",
  [string]$Org  = "it-stack-dev",
  [switch]$CreateGitHubRepo
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoName  = "it-stack-$ModuleName"
$repoPath  = Join-Path $Root "repos\$Category\$repoName"

if (Test-Path $repoPath) {
  Write-Host "Directory already exists: $repoPath" -ForegroundColor Yellow
  $overwrite = Read-Host "Continue and add missing files? (y/N)"
  if ($overwrite -ne 'y') { exit 0 }
}

function New-Dir  { param($p) New-Item -ItemType Directory -Path $p -Force | Out-Null }
function New-File { param($p, $c = "")
  New-Dir (Split-Path $p)
  [System.IO.File]::WriteAllText($p, $c, [System.Text.UTF8Encoding]::new($false))
}

Write-Host "Creating $repoName..." -ForegroundColor Cyan

# ── Directories ───────────────────────────────────────────────
@(
  "src", "tests\unit", "tests\integration", "tests\e2e",
  "tests\labs",
  "docker", "kubernetes\base", "kubernetes\overlays\dev",
  "kubernetes\overlays\staging", "kubernetes\overlays\production",
  "helm\templates", "ansible\roles\$ModuleName\tasks",
  "ansible\roles\$ModuleName\templates",
  "docs\labs",
  ".github\workflows"
) | ForEach-Object { New-Dir (Join-Path $repoPath $_) }

# ── Module manifest ───────────────────────────────────────────
New-File (Join-Path $repoPath "$repoName.yml") @"
# $repoName module manifest
name: $ModuleName
repo: $repoName
module_number: "$ModuleNumber"
phase: $Phase
category: $(($Category -split '-',2)[1])
org: $Org

labs:
  - id: "$ModuleNumber-01"
    name: "Standalone"
    compose: docker/docker-compose.standalone.yml
    test:    tests/labs/test-lab-$ModuleNumber-01.sh
  - id: "$ModuleNumber-02"
    name: "External Dependencies"
    compose: docker/docker-compose.lan.yml
    test:    tests/labs/test-lab-$ModuleNumber-02.sh
  - id: "$ModuleNumber-03"
    name: "Advanced Features"
    compose: docker/docker-compose.advanced.yml
    test:    tests/labs/test-lab-$ModuleNumber-03.sh
  - id: "$ModuleNumber-04"
    name: "SSO Integration"
    compose: docker/docker-compose.sso.yml
    test:    tests/labs/test-lab-$ModuleNumber-04.sh
  - id: "$ModuleNumber-05"
    name: "Advanced Integration"
    compose: docker/docker-compose.integration.yml
    test:    tests/labs/test-lab-$ModuleNumber-05.sh
  - id: "$ModuleNumber-06"
    name: "Production Deployment"
    compose: docker/docker-compose.production.yml
    test:    tests/labs/test-lab-$ModuleNumber-06.sh
"@

# ── Dockerfile stub ───────────────────────────────────────────
New-File (Join-Path $repoPath "Dockerfile") @"
# $repoName Dockerfile
# TODO: Add service-specific base image and configuration
FROM ubuntu:24.04
LABEL maintainer="it-stack-dev"
HEALTHCHECK --interval=30s --timeout=10s --retries=3 CMD echo "TODO: add healthcheck"
"@

# ── Makefile ──────────────────────────────────────────────────
New-File (Join-Path $repoPath "Makefile") @"
.DEFAULT_GOAL := help
COMPOSE_STANDALONE := docker/docker-compose.standalone.yml
COMPOSE_PROD       := docker/docker-compose.production.yml

.PHONY: help install test build deploy clean lab-01 lab-02 lab-03 lab-04 lab-05 lab-06

help:
	@grep -E '^## ' Makefile | sed 's/## /  /'

## install   Install dependencies
install:
	@echo "TODO: add install steps"

## test       Run unit tests
test:
	@echo "TODO: add test steps"

## build      Build Docker image
build:
	docker build -t ghcr.io/it-stack-dev/$repoName:latest .

## lab-01     Run Lab $ModuleNumber-01 (standalone)
lab-01:
	docker compose -f `$(COMPOSE_STANDALONE) up -d
	bash tests/labs/test-lab-$ModuleNumber-01.sh
	docker compose -f `$(COMPOSE_STANDALONE) down -v

## lab-06     Run Lab $ModuleNumber-06 (production)
lab-06:
	docker compose -f `$(COMPOSE_PROD) up -d
	bash tests/labs/test-lab-$ModuleNumber-06.sh
	docker compose -f `$(COMPOSE_PROD) down -v

## clean      Remove all containers and volumes
clean:
	docker compose -f `$(COMPOSE_STANDALONE) down -v --remove-orphans 2>/dev/null || true
	docker compose -f `$(COMPOSE_PROD) down -v --remove-orphans 2>/dev/null || true
"@

# ── Docker Compose stubs (6 files) ───────────────────────────
$composeFiles = @(
  @{ file = "docker-compose.standalone.yml";  comment = "Lab $ModuleNumber-01: Standalone — no external dependencies" },
  @{ file = "docker-compose.lan.yml";         comment = "Lab $ModuleNumber-02: External Dependencies — PostgreSQL/Redis on LAN" },
  @{ file = "docker-compose.advanced.yml";    comment = "Lab $ModuleNumber-03: Advanced Features — tuning, resource limits" },
  @{ file = "docker-compose.sso.yml";         comment = "Lab $ModuleNumber-04: SSO Integration — Keycloak OIDC/SAML" },
  @{ file = "docker-compose.integration.yml"; comment = "Lab $ModuleNumber-05: Advanced Integration — multi-service ecosystem" },
  @{ file = "docker-compose.production.yml";  comment = "Lab $ModuleNumber-06: Production — HA, monitoring, DR" }
)

foreach ($cf in $composeFiles) {
  New-File (Join-Path $repoPath "docker\$($cf.file)") @"
# $($cf.comment)
services:
  $ModuleName:
    image: TODO
    # TODO: Add service configuration
"@
}

# ── Lab test script stubs (6 files) ──────────────────────────
for ($i = 1; $i -le 6; $i++) {
  $labNum  = $i.ToString("D2")
  $labPad  = "$ModuleNumber-$labNum"
  New-File (Join-Path $repoPath "tests\labs\test-lab-$labPad.sh") @"
#!/usr/bin/env bash
# Lab $labPad — TODO: Add lab description
set -euo pipefail
SCRIPT_DIR="`$(cd "`$(dirname "`${BASH_SOURCE[0]}")" && pwd)"
PASS=0; FAIL=0
pass() { echo "  PASS: `$1"; ((PASS++)); }
fail() { echo "  FAIL: `$1"; ((FAIL++)); }

echo "=== Lab $labPad ==="
# TODO: Add test steps

echo ""
echo "Results: `${PASS} passed, `${FAIL} failed"
[ `$FAIL -eq 0 ]
"@
}

# ── GitHub Actions workflows ──────────────────────────────────
New-File (Join-Path $repoPath ".github\workflows\ci.yml") @"
name: CI
on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]
jobs:
  shellcheck:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: find tests/labs -name '*.sh' | xargs shellcheck
  compose-validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: docker compose -f docker/docker-compose.standalone.yml config --quiet
"@

# ── Standard markdown files ───────────────────────────────────
New-File (Join-Path $repoPath "README.md")        "# $repoName`n`nTODO: Add description."
New-File (Join-Path $repoPath "CHANGELOG.md")     "# Changelog`n`n## [Unreleased]`n"
New-File (Join-Path $repoPath "CONTRIBUTING.md")  "# Contributing`n`nSee [it-stack-dev/.github](https://github.com/it-stack-dev/.github/blob/main/CONTRIBUTING.md)."
New-File (Join-Path $repoPath "CODE_OF_CONDUCT.md") "# Code of Conduct`n`nSee [it-stack-dev](https://github.com/it-stack-dev/.github/blob/main/CODE_OF_CONDUCT.md)."
New-File (Join-Path $repoPath "SECURITY.md")      "# Security`n`nSee [it-stack-dev](https://github.com/it-stack-dev/.github/blob/main/SECURITY.md)."
New-File (Join-Path $repoPath "SUPPORT.md")       "# Support`n`nOpen an issue or see the [docs](https://it-stack-dev.github.io/it-stack-docs/)."
New-File (Join-Path $repoPath "LICENSE")          "Apache License, Version 2.0`nSee https://www.apache.org/licenses/LICENSE-2.0"

New-File (Join-Path $repoPath ".gitignore") @"
# Secrets
*.key
*.pem
*.crt
.env
.vault_pass
secrets/

# Docker
docker/volumes/

# OS
.DS_Store
Thumbs.db

# Editor
.vscode/
*.swp
"@

Write-Host ""
Write-Host "Scaffolded: $repoPath" -ForegroundColor Green
Write-Host "  Files created: $((Get-ChildItem $repoPath -Recurse -File).Count)" -ForegroundColor DarkGray

if ($CreateGitHubRepo) {
  Write-Host ""
  Write-Host "Creating GitHub repo..." -ForegroundColor Cyan
  Push-Location $repoPath
  git init
  git add -A
  git commit -m "chore: initial scaffold"
  gh repo create "$Org/$repoName" --public --source . --push `
    --description "IT-Stack: $ModuleName module — labs, Docker Compose, Ansible, Helm" `
    --remote origin
  Pop-Location
  Write-Host "Created: https://github.com/$Org/$repoName" -ForegroundColor Green
}
'@

Write-Host "utilities scripts done"

# ══════════════════════════════════════════════════════════════
# scripts/deployment/deploy-stack.sh
# ══════════════════════════════════════════════════════════════
Write-Script "$root\scripts\deployment\deploy-stack.sh" @'
#!/usr/bin/env bash
# scripts/deployment/deploy-stack.sh
# Run the full IT-Stack Ansible deployment.
#
# Usage:
#   bash scripts/deployment/deploy-stack.sh
#   bash scripts/deployment/deploy-stack.sh --phase 1
#   bash scripts/deployment/deploy-stack.sh --module nextcloud
#   bash scripts/deployment/deploy-stack.sh --check   (dry-run)
#
# Prerequisites:
#   - Ansible installed (ansible --version)
#   - vault/secrets.yml created from it-stack-ansible/vault/secrets.yml.example
#   - .vault_pass file in it-stack-ansible/ (chmod 600)
#   - SSH keys deployed to all 8 servers

set -euo pipefail

ANSIBLE_DIR="${ANSIBLE_DIR:-/opt/it-stack-dev/repos/meta/it-stack-ansible}"
VAULT_PASS="${ANSIBLE_DIR}/.vault_pass"
INVENTORY="${ANSIBLE_DIR}/inventory/hosts.ini"
PLAYBOOKS_DIR="${ANSIBLE_DIR}/playbooks"

PHASE=""
MODULE=""
CHECK_MODE=false
VERBOSE=false

# ── Parse args ────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --phase)   PHASE="$2";   shift 2 ;;
    --module)  MODULE="$2";  shift 2 ;;
    --check)   CHECK_MODE=true; shift ;;
    --verbose) VERBOSE=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ── Validate prerequisites ────────────────────────────────────
if ! command -v ansible-playbook &>/dev/null; then
  echo "ERROR: ansible-playbook not found. Install Ansible first."
  exit 1
fi

if [[ ! -f "$VAULT_PASS" ]]; then
  echo "ERROR: .vault_pass not found at $VAULT_PASS"
  echo "       Create it: echo 'your-vault-password' > $VAULT_PASS && chmod 600 $VAULT_PASS"
  exit 1
fi

if [[ ! -f "${ANSIBLE_DIR}/vault/secrets.yml" ]]; then
  echo "ERROR: vault/secrets.yml not found."
  echo "       Copy vault/secrets.yml.example, fill all values, encrypt:"
  echo "       ansible-vault encrypt vault/secrets.yml --vault-password-file .vault_pass"
  exit 1
fi

ANSIBLE_ARGS="-i $INVENTORY --vault-password-file $VAULT_PASS"
[[ "$CHECK_MODE" == "true" ]] && ANSIBLE_ARGS="$ANSIBLE_ARGS --check --diff"
[[ "$VERBOSE"    == "true" ]] && ANSIBLE_ARGS="$ANSIBLE_ARGS -v"

# ── Run playbook ──────────────────────────────────────────────
cd "$ANSIBLE_DIR"

if [[ -n "$MODULE" ]]; then
  PLAYBOOK="$PLAYBOOKS_DIR/deploy-${MODULE}.yml"
  if [[ ! -f "$PLAYBOOK" ]]; then
    echo "ERROR: Playbook not found: $PLAYBOOK"
    echo "Available modules:"
    ls "$PLAYBOOKS_DIR"/deploy-*.yml | xargs -n1 basename | sed 's/deploy-//;s/\.yml//' | sort
    exit 1
  fi
  echo "==> Deploying module: $MODULE"
  ansible-playbook $ANSIBLE_ARGS "$PLAYBOOK"

elif [[ -n "$PHASE" ]]; then
  case $PHASE in
    1) TAGS="phase1,common,freeipa,postgresql,redis,keycloak,traefik" ;;
    2) TAGS="phase2,nextcloud,mattermost,jitsi,iredmail,zammad,elasticsearch" ;;
    3) TAGS="phase3,freepbx,suitecrm,odoo,openkm" ;;
    4) TAGS="phase4,taiga,snipeit,glpi,zabbix,graylog" ;;
    *) echo "ERROR: Invalid phase $PHASE (use 1-4)"; exit 1 ;;
  esac
  echo "==> Deploying Phase $PHASE (tags: $TAGS)"
  ansible-playbook $ANSIBLE_ARGS --tags "$TAGS" "$PLAYBOOKS_DIR/site.yml"

else
  echo "==> Deploying full IT-Stack (all phases)"
  echo "    This will configure all 8 servers."
  read -rp "    Continue? [y/N] " confirm
  [[ "$confirm" == "y" || "$confirm" == "Y" ]] || { echo "Aborted."; exit 0; }
  ansible-playbook $ANSIBLE_ARGS "$PLAYBOOKS_DIR/site.yml"
fi

echo ""
echo "Deployment complete."
'@

# ══════════════════════════════════════════════════════════════
# scripts/testing/run-all-labs.sh
# ══════════════════════════════════════════════════════════════
Write-Script "$root\scripts\testing\run-all-labs.sh" @'
#!/usr/bin/env bash
# scripts/testing/run-all-labs.sh
# Run lab tests across all 20 IT-Stack module repositories.
#
# Usage:
#   bash scripts/testing/run-all-labs.sh
#   bash scripts/testing/run-all-labs.sh --phase 1
#   bash scripts/testing/run-all-labs.sh --module freeipa
#   bash scripts/testing/run-all-labs.sh --lab 01
#   bash scripts/testing/run-all-labs.sh --phase 2 --lab 04
#
# Prerequisites:
#   - All repos cloned under $REPOS_DIR (run clone-all-repos.ps1)
#   - Docker running
#   - Each repo's Compose files functional

set -uo pipefail

REPOS_DIR="${REPOS_DIR:-C:/IT-Stack/it-stack-dev/repos}"
FILTER_PHASE=""
FILTER_MODULE=""
FILTER_LAB=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --phase)  FILTER_PHASE="$2";  shift 2 ;;
    --module) FILTER_MODULE="$2"; shift 2 ;;
    --lab)    FILTER_LAB="$2";    shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Module list: "number name category_dir phase"
declare -a MODULES=(
  "01 freeipa       01-identity       1"
  "02 keycloak      01-identity       1"
  "03 postgresql    02-database       1"
  "04 redis         02-database       1"
  "18 traefik       07-infrastructure 1"
  "06 nextcloud     03-collaboration  2"
  "07 mattermost    03-collaboration  2"
  "08 jitsi         03-collaboration  2"
  "09 iredmail      04-communications 2"
  "11 zammad        04-communications 2"
  "10 freepbx       04-communications 3"
  "12 suitecrm      05-business       3"
  "13 odoo          05-business       3"
  "14 openkm        05-business       3"
  "15 taiga         06-it-management  4"
  "16 snipeit       06-it-management  4"
  "17 glpi          06-it-management  4"
  "05 elasticsearch 02-database       4"
  "19 zabbix        07-infrastructure 4"
  "20 graylog       07-infrastructure 4"
)

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
declare -a FAILURES=()

run_lab() {
  local num="$1" mod="$2" cat="$3" phase="$4" lab="$5"
  local repo_path="$REPOS_DIR/$cat/it-stack-$mod"
  local test_script="$repo_path/tests/labs/test-lab-$num-$(printf '%02d' $lab).sh"

  # Apply filters
  [[ -n "$FILTER_PHASE"  && "$phase" != "$FILTER_PHASE"  ]] && return
  [[ -n "$FILTER_MODULE" && "$mod"   != "$FILTER_MODULE" ]] && return
  [[ -n "$FILTER_LAB"    && "$lab"   != "$FILTER_LAB"    ]] && return

  local label="Lab $num-$(printf '%02d' $lab) [$mod]"

  if [[ ! -f "$test_script" ]]; then
    echo "  SKIP: $label (test script not found)"
    ((SKIP_COUNT++))
    return
  fi

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Running: $label"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  if bash "$test_script"; then
    echo "  RESULT: PASS — $label"
    ((PASS_COUNT++))
  else
    echo "  RESULT: FAIL — $label"
    ((FAIL_COUNT++))
    FAILURES+=("$label")
  fi
}

echo "IT-Stack Lab Test Runner"
echo "Repos dir: $REPOS_DIR"
echo "Filters: phase=${FILTER_PHASE:-all} module=${FILTER_MODULE:-all} lab=${FILTER_LAB:-all}"
echo ""

for entry in "${MODULES[@]}"; do
  read -r num mod cat phase <<< "$entry"
  for lab in 1 2 3 4 5 6; do
    run_lab "$num" "$mod" "$cat" "$phase" "$lab"
  done
done

echo ""
echo "════════════════════════════════════════"
echo "IT-Stack Lab Results"
echo "════════════════════════════════════════"
echo "  PASS: $PASS_COUNT"
echo "  FAIL: $FAIL_COUNT"
echo "  SKIP: $SKIP_COUNT"

if [[ ${#FAILURES[@]} -gt 0 ]]; then
  echo ""
  echo "Failed labs:"
  for f in "${FAILURES[@]}"; do
    echo "  - $f"
  done
  exit 1
fi

echo ""
echo "All labs passed!"
'@

Write-Host "deployment + testing scripts done"
Write-Host ""
Write-Host "ALL PART 1 SCRIPTS DONE (8 scripts)"
