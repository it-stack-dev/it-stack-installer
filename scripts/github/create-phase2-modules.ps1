#!/usr/bin/env pwsh
# scripts/github/create-phase2-modules.ps1
# Create the 5 Phase 2 (Collaboration) GitHub repositories.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts/github/create-phase2-modules.ps1

[CmdletBinding()]
param([string]$Org = "it-stack-dev")

Set-StrictMode -Version Latest

$modules = @(
  @{ name = "nextcloud";  num = "06"; desc = "IT-Stack: Nextcloud Files and Collaboration -- WebDAV, CalDAV, office suite (module 06)" },
  @{ name = "mattermost"; num = "07"; desc = "IT-Stack: Mattermost Team Messaging -- channels, bots, webhooks (module 07)" },
  @{ name = "jitsi";      num = "08"; desc = "IT-Stack: Jitsi Meet Video Conferencing -- WebRTC, TURN, JWT auth (module 08)" },
  @{ name = "iredmail";   num = "09"; desc = "IT-Stack: iRedMail Email Server -- Postfix, Dovecot, webmail (module 09)" },
  @{ name = "zammad";     num = "11"; desc = "IT-Stack: Zammad Help Desk -- tickets, LDAP, Elasticsearch (module 11)" }
)

Write-Host "Creating Phase 2 repos in org: $Org" -ForegroundColor Cyan
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
Write-Host "Phase 2 repos -- Created: $created  |  Errors: $failed" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Run: scripts\github\apply-labels.ps1 -Repo it-stack-<name>"
Write-Host "  2. Run: scripts\github\create-milestones.ps1 -Repo it-stack-<name>"
Write-Host "  3. Run: scripts\github\add-phase2-issues.ps1"
