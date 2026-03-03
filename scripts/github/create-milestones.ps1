#!/usr/bin/env pwsh
# scripts/github/create-milestones.ps1
# Create the 4 IT-Stack deployment milestones in every module repo.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts/github/create-milestones.ps1
#   powershell -ExecutionPolicy Bypass -File scripts/github/create-milestones.ps1 -Repo it-stack-freeipa

[CmdletBinding()]
param(
  [string]$Org  = "it-stack-dev",
  [string]$Repo = ""
)

Set-StrictMode -Version Latest

$milestones = @(
  @{ title = "Phase 1: Foundation";    desc = "FreeIPA, Keycloak, PostgreSQL, Redis, Traefik -- Labs 01-06"; due = "2026-04-18" },
  @{ title = "Phase 2: Collaboration"; desc = "Nextcloud, Mattermost, Jitsi, iRedMail, Zammad -- Labs 01-06"; due = "2026-05-30" },
  @{ title = "Phase 3: Back Office";   desc = "FreePBX, SuiteCRM, Odoo, OpenKM -- Labs 01-06"; due = "2026-07-31" },
  @{ title = "Phase 4: IT Management"; desc = "Taiga, Snipe-IT, GLPI, Elasticsearch, Zabbix, Graylog -- Labs 01-06"; due = "2026-10-15" }
)

$moduleRepos = @(
  "it-stack-freeipa", "it-stack-keycloak", "it-stack-postgresql",
  "it-stack-redis", "it-stack-traefik",
  "it-stack-nextcloud", "it-stack-mattermost", "it-stack-jitsi",
  "it-stack-iredmail", "it-stack-zammad",
  "it-stack-freepbx", "it-stack-suitecrm", "it-stack-odoo", "it-stack-openkm",
  "it-stack-taiga", "it-stack-snipeit", "it-stack-glpi",
  "it-stack-elasticsearch", "it-stack-zabbix", "it-stack-graylog"
)

$targetRepos = if ($Repo -ne "") { @($Repo) } else { $moduleRepos }
$created = 0; $failed = 0

foreach ($r in $targetRepos) {
  Write-Host "`n[$r]" -ForegroundColor Cyan
  foreach ($ms in $milestones) {
    $body = @{
      title       = $ms.title
      description = $ms.desc
      due_on      = "$($ms.due)T23:59:59Z"
      state       = "open"
    } | ConvertTo-Json

    $result = $body | gh api -X POST "repos/$Org/$r/milestones" --input - 2>&1
    if ($LASTEXITCODE -eq 0) {
      Write-Host "  [+] $($ms.title)" -ForegroundColor DarkGray
      $created++
    } else {
      # 422 = already exists
      if ($result -match "already_exists" -or $result -match "422") {
        Write-Host "  [=] $($ms.title) (already exists)" -ForegroundColor DarkGray
      } else {
        Write-Host "  [!] $($ms.title): $result" -ForegroundColor Yellow
        $failed++
      }
    }
  }
}

Write-Host ""
Write-Host "Milestones complete -- Created: $created  |  Errors: $failed" -ForegroundColor Cyan
