#!/usr/bin/env pwsh
# scripts/github/create-phase3-modules.ps1
# Create the 4 Phase 3 (Back Office) GitHub repositories.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts/github/create-phase3-modules.ps1

[CmdletBinding()]
param([string]$Org = "it-stack-dev")

Set-StrictMode -Version Latest

$modules = @(
  @{ name = "freepbx";  num = "10"; desc = "IT-Stack: FreePBX VoIP PBX -- Asterisk, SIP, IVR, voicemail (module 10)" },
  @{ name = "suitecrm"; num = "12"; desc = "IT-Stack: SuiteCRM CRM -- contacts, campaigns, sales pipelines (module 12)" },
  @{ name = "odoo";     num = "13"; desc = "IT-Stack: Odoo ERP -- accounting, HR, inventory, projects (module 13)" },
  @{ name = "openkm";   num = "14"; desc = "IT-Stack: OpenKM Document Management -- versioning, workflows, DMS (module 14)" }
)

Write-Host "Creating Phase 3 repos in org: $Org" -ForegroundColor Cyan
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
Write-Host "Phase 3 repos -- Created: $created  |  Errors: $failed" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Run: scripts\github\apply-labels.ps1 -Repo it-stack-<name>"
Write-Host "  2. Run: scripts\github\create-milestones.ps1 -Repo it-stack-<name>"
Write-Host "  3. Run: scripts\github\add-phase3-issues.ps1"
