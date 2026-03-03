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
  # Phase 1 â€” Foundation
  @{ name = "it-stack-freeipa";       dir = "repos\01-identity";       phase = 1 },
  @{ name = "it-stack-keycloak";      dir = "repos\01-identity";       phase = 1 },
  @{ name = "it-stack-postgresql";    dir = "repos\02-database";       phase = 1 },
  @{ name = "it-stack-redis";         dir = "repos\02-database";       phase = 1 },
  @{ name = "it-stack-traefik";       dir = "repos\07-infrastructure"; phase = 1 },
  # Phase 2 â€” Collaboration
  @{ name = "it-stack-nextcloud";     dir = "repos\03-collaboration";  phase = 2 },
  @{ name = "it-stack-mattermost";    dir = "repos\03-collaboration";  phase = 2 },
  @{ name = "it-stack-jitsi";         dir = "repos\03-collaboration";  phase = 2 },
  @{ name = "it-stack-iredmail";      dir = "repos\04-communications"; phase = 2 },
  @{ name = "it-stack-zammad";        dir = "repos\04-communications"; phase = 2 },
  # Phase 3 â€” Back Office
  @{ name = "it-stack-freepbx";       dir = "repos\04-communications"; phase = 3 },
  @{ name = "it-stack-suitecrm";      dir = "repos\05-business";       phase = 3 },
  @{ name = "it-stack-odoo";          dir = "repos\05-business";       phase = 3 },
  @{ name = "it-stack-openkm";        dir = "repos\05-business";       phase = 3 },
  # Phase 4 â€” IT Management
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