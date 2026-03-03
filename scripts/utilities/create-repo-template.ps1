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

# â”€â”€ Directories â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

# â”€â”€ Module manifest â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

# â”€â”€ Dockerfile stub â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
New-File (Join-Path $repoPath "Dockerfile") @"
# $repoName Dockerfile
# TODO: Add service-specific base image and configuration
FROM ubuntu:24.04
LABEL maintainer="it-stack-dev"
HEALTHCHECK --interval=30s --timeout=10s --retries=3 CMD echo "TODO: add healthcheck"
"@

# â”€â”€ Makefile â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

# â”€â”€ Docker Compose stubs (6 files) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
$composeFiles = @(
  @{ file = "docker-compose.standalone.yml";  comment = "Lab $ModuleNumber-01: Standalone â€” no external dependencies" },
  @{ file = "docker-compose.lan.yml";         comment = "Lab $ModuleNumber-02: External Dependencies â€” PostgreSQL/Redis on LAN" },
  @{ file = "docker-compose.advanced.yml";    comment = "Lab $ModuleNumber-03: Advanced Features â€” tuning, resource limits" },
  @{ file = "docker-compose.sso.yml";         comment = "Lab $ModuleNumber-04: SSO Integration â€” Keycloak OIDC/SAML" },
  @{ file = "docker-compose.integration.yml"; comment = "Lab $ModuleNumber-05: Advanced Integration â€” multi-service ecosystem" },
  @{ file = "docker-compose.production.yml";  comment = "Lab $ModuleNumber-06: Production â€” HA, monitoring, DR" }
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

# â”€â”€ Lab test script stubs (6 files) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
for ($i = 1; $i -le 6; $i++) {
  $labNum  = $i.ToString("D2")
  $labPad  = "$ModuleNumber-$labNum"
  New-File (Join-Path $repoPath "tests\labs\test-lab-$labPad.sh") @"
#!/usr/bin/env bash
# Lab $labPad â€” TODO: Add lab description
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

# â”€â”€ GitHub Actions workflows â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

# â”€â”€ Standard markdown files â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
    --description "IT-Stack: $ModuleName module â€” labs, Docker Compose, Ansible, Helm" `
    --remote origin
  Pop-Location
  Write-Host "Created: https://github.com/$Org/$repoName" -ForegroundColor Green
}