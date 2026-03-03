#!/usr/bin/env pwsh
# scripts/github/create-phase4-modules.ps1
# Create the 6 Phase 4 (IT Management) GitHub repositories.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts/github/create-phase4-modules.ps1

[CmdletBinding()]
param([string]$Org = "it-stack-dev")

Set-StrictMode -Version Latest

$modules = @(
  @{ name = "taiga";         num = "15"; desc = "IT-Stack: Taiga Project Management -- Scrum, Kanban, sprints (module 15)" },
  @{ name = "snipeit";       num = "16"; desc = "IT-Stack: Snipe-IT Asset Management -- hardware, licenses, CMDB (module 16)" },
  @{ name = "glpi";          num = "17"; desc = "IT-Stack: GLPI ITSM -- tickets, CMDB, change management (module 17)" },
  @{ name = "elasticsearch"; num = "05"; desc = "IT-Stack: Elasticsearch Search Engine -- full-text search, log indexing (module 05)" },
  @{ name = "zabbix";        num = "19"; desc = "IT-Stack: Zabbix Infrastructure Monitoring -- metrics, alerts, dashboards (module 19)" },
  @{ name = "graylog";       num = "20"; desc = "IT-Stack: Graylog Log Management -- centralized logging, GELF, Syslog (module 20)" }
)

Write-Host "Creating Phase 4 repos in org: $Org" -ForegroundColor Cyan
Write-Host ""

$created = 0; $failed = 0

foreach ($m in $modules) {
  $repoName = "it-stack-$($m.name)"
  Write-Host "  Creating $repoName..." -ForegroundColor DarkGray
  gh repo create "$Org/$repoName" `
    --public `
    --description $m.desc `
    --add-readme 2>&1 | Out-Null
  if ($LASTEXITCODE -eq 0) {
    Write-Host "  [+] https://github.com/$Org/$repoName" -ForegroundColor Green
    $created++
  } else {
    Write-Host "  [!] $repoName -- already exists or permission error" -ForegroundColor Yellow
    $failed++
  }
  Start-Sleep -Milliseconds 500
}

Write-Host ""
Write-Host "Phase 4 repos -- Created: $created  |  Errors: $failed" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Run: scripts\github\apply-labels.ps1 -Repo it-stack-<name>"
Write-Host "  2. Run: scripts\github\create-milestones.ps1 -Repo it-stack-<name>"
Write-Host "  3. Run: scripts\github\add-phase4-issues.ps1"
