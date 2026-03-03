#!/usr/bin/env pwsh
# scripts/github/create-phase1-modules.ps1
# Create the 5 Phase 1 (Foundation) GitHub repositories.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts/github/create-phase1-modules.ps1

[CmdletBinding()]
param([string]$Org = "it-stack-dev")

Set-StrictMode -Version Latest

$modules = @(
  @{ name = "freeipa";    num = "01"; desc = "IT-Stack: FreeIPA Identity and DNS -- LDAP, Kerberos, DNS (module 01)" },
  @{ name = "keycloak";   num = "02"; desc = "IT-Stack: Keycloak SSO Broker -- OAuth2, OIDC, SAML (module 02)" },
  @{ name = "postgresql"; num = "03"; desc = "IT-Stack: PostgreSQL Database -- primary DB for all 10+ services (module 03)" },
  @{ name = "redis";      num = "04"; desc = "IT-Stack: Redis Cache and Sessions -- cache, queues, pub/sub (module 04)" },
  @{ name = "traefik";    num = "18"; desc = "IT-Stack: Traefik Reverse Proxy -- TLS termination, routing, Let's Encrypt (module 18)" }
)

Write-Host "Creating Phase 1 repos in org: $Org" -ForegroundColor Cyan
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
Write-Host "Phase 1 repos -- Created: $created  |  Errors: $failed" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Run: scripts\github\apply-labels.ps1"
Write-Host "  2. Run: scripts\github\create-milestones.ps1"
Write-Host "  3. Run: scripts\github\add-phase1-issues.ps1"
