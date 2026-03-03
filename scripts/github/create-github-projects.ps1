#!/usr/bin/env pwsh
# scripts/github/create-github-projects.ps1
# Create the 5 GitHub Projects (v2 Projects) in the it-stack-dev org.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts/github/create-github-projects.ps1

[CmdletBinding()]
param([string]$Org = "it-stack-dev")

Set-StrictMode -Version Latest

$projects = @(
  @{ title = "Phase 1: Foundation";    desc = "FreeIPA - Keycloak - PostgreSQL - Redis - Traefik -- 30 labs" },
  @{ title = "Phase 2: Collaboration"; desc = "Nextcloud - Mattermost - Jitsi - iRedMail - Zammad -- 30 labs" },
  @{ title = "Phase 3: Back Office";   desc = "FreePBX - SuiteCRM - Odoo - OpenKM -- 24 labs" },
  @{ title = "Phase 4: IT Management"; desc = "Taiga - Snipe-IT - GLPI - Elasticsearch - Zabbix - Graylog -- 36 labs" },
  @{ title = "Master Dashboard";       desc = "All 20 IT-Stack modules -- 120 labs total" }
)

Write-Host "Creating GitHub Projects in org: $Org" -ForegroundColor Cyan
Write-Host ""

foreach ($p in $projects) {
  Write-Host "  Creating: $($p.title)..." -ForegroundColor DarkGray
  $result = gh project create `
    --owner $Org `
    --title $p.title `
    --format json 2>&1

  if ($LASTEXITCODE -eq 0) {
    $projectData = $result | ConvertFrom-Json
    Write-Host "  [+] Project #$($projectData.number): $($p.title)" -ForegroundColor Green
    Write-Host "      URL: $($projectData.url)" -ForegroundColor DarkGray
  } else {
    Write-Host "  [!] $($p.title): $result" -ForegroundColor Yellow
  }
  Start-Sleep -Milliseconds 500
}

Write-Host ""
Write-Host "Projects created. Add issues to a project with:" -ForegroundColor Yellow
Write-Host "  gh project item-add <number> --owner $Org --url <issue-url>"
