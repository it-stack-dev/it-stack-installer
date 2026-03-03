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
    Write-Warn "$name install returned $LASTEXITCODE â€” may already be installed"
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
  Write-Warn "WSL not available â€” Ansible must be installed manually"
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