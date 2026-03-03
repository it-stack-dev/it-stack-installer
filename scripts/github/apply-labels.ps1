#!/usr/bin/env pwsh
# scripts/github/apply-labels.ps1
# Create all 39 IT-Stack labels across every module and meta repo.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts/github/apply-labels.ps1
#   powershell -ExecutionPolicy Bypass -File scripts/github/apply-labels.ps1 -Repo it-stack-freeipa

[CmdletBinding()]
param(
  [string]$Org  = "it-stack-dev",
  [string]$Repo = ""   # leave blank to apply to ALL repos
)

Set-StrictMode -Version Latest

# All 39 labels: name, color, description
$labels = @(
  # Core
  @{ name = "lab";              color = "0075ca"; desc = "Lab test issue" },
  # Module numbers
  @{ name = "module-01"; color = "e4e669"; desc = "FreeIPA" },
  @{ name = "module-02"; color = "e4e669"; desc = "Keycloak" },
  @{ name = "module-03"; color = "e4e669"; desc = "PostgreSQL" },
  @{ name = "module-04"; color = "e4e669"; desc = "Redis" },
  @{ name = "module-05"; color = "e4e669"; desc = "Elasticsearch" },
  @{ name = "module-06"; color = "e4e669"; desc = "Nextcloud" },
  @{ name = "module-07"; color = "e4e669"; desc = "Mattermost" },
  @{ name = "module-08"; color = "e4e669"; desc = "Jitsi" },
  @{ name = "module-09"; color = "e4e669"; desc = "iRedMail" },
  @{ name = "module-10"; color = "e4e669"; desc = "FreePBX" },
  @{ name = "module-11"; color = "e4e669"; desc = "Zammad" },
  @{ name = "module-12"; color = "e4e669"; desc = "SuiteCRM" },
  @{ name = "module-13"; color = "e4e669"; desc = "Odoo" },
  @{ name = "module-14"; color = "e4e669"; desc = "OpenKM" },
  @{ name = "module-15"; color = "e4e669"; desc = "Taiga" },
  @{ name = "module-16"; color = "e4e669"; desc = "Snipe-IT" },
  @{ name = "module-17"; color = "e4e669"; desc = "GLPI" },
  @{ name = "module-18"; color = "e4e669"; desc = "Traefik" },
  @{ name = "module-19"; color = "e4e669"; desc = "Zabbix" },
  @{ name = "module-20"; color = "e4e669"; desc = "Graylog" },
  # Phases
  @{ name = "phase-1"; color = "0052cc"; desc = "Foundation" },
  @{ name = "phase-2"; color = "0052cc"; desc = "Collaboration" },
  @{ name = "phase-3"; color = "0052cc"; desc = "Back Office" },
  @{ name = "phase-4"; color = "0052cc"; desc = "IT Management" },
  # Categories
  @{ name = "identity";       color = "d93f0b"; desc = "Identity and SSO" },
  @{ name = "database";       color = "d93f0b"; desc = "Database and Cache" },
  @{ name = "collaboration";  color = "d93f0b"; desc = "Collaboration tools" },
  @{ name = "communications"; color = "d93f0b"; desc = "Communications" },
  @{ name = "business";       color = "d93f0b"; desc = "Business systems" },
  @{ name = "it-management";  color = "d93f0b"; desc = "IT and Project Management" },
  @{ name = "infrastructure"; color = "d93f0b"; desc = "Infrastructure" },
  # Type
  @{ name = "integration"; color = "5319e7"; desc = "Cross-service integration milestone" },
  # Priority
  @{ name = "priority-high"; color = "b60205"; desc = "High priority" },
  @{ name = "priority-med";  color = "fbca04"; desc = "Medium priority" },
  @{ name = "priority-low";  color = "0e8a16"; desc = "Low priority" },
  # Status
  @{ name = "status-todo";        color = "cccccc"; desc = "Not started" },
  @{ name = "status-in-progress"; color = "1d76db"; desc = "In progress" },
  @{ name = "status-done";        color = "0e8a16"; desc = "Completed" },
  @{ name = "status-blocked";     color = "b60205"; desc = "Blocked" }
)

$allRepos = @(
  ".github",
  "it-stack-docs", "it-stack-installer", "it-stack-testing",
  "it-stack-ansible", "it-stack-terraform", "it-stack-helm",
  "it-stack-freeipa", "it-stack-keycloak", "it-stack-postgresql",
  "it-stack-redis", "it-stack-traefik",
  "it-stack-nextcloud", "it-stack-mattermost", "it-stack-jitsi",
  "it-stack-iredmail", "it-stack-zammad",
  "it-stack-freepbx", "it-stack-suitecrm", "it-stack-odoo", "it-stack-openkm",
  "it-stack-taiga", "it-stack-snipeit", "it-stack-glpi",
  "it-stack-elasticsearch", "it-stack-zabbix", "it-stack-graylog"
)

$targetRepos = if ($Repo -ne "") { @($Repo) } else { $allRepos }
$created = 0; $failed = 0

foreach ($r in $targetRepos) {
  Write-Host "`n[$r]" -ForegroundColor Cyan
  foreach ($label in $labels) {
    $result = gh label create $label.name `
      --repo "$Org/$r" `
      --color $label.color `
      --description $label.desc `
      --force 2>&1
    if ($LASTEXITCODE -eq 0) {
      Write-Host "  [+] $($label.name)" -ForegroundColor DarkGray
      $created++
    } else {
      Write-Host "  [!] $($label.name): $result" -ForegroundColor Yellow
      $failed++
    }
  }
}

Write-Host ""
Write-Host "Labels complete -- Created/Updated: $created  |  Errors: $failed" -ForegroundColor Cyan
