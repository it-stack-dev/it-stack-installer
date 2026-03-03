#!/usr/bin/env pwsh
# scripts/github/add-phase1-issues.ps1
# Create 30 lab issues (6 labs x 5 modules) for Phase 1 repos.
#
# Prerequisites:
#   - gh auth login completed
#   - Phase 1 repos exist (run create-phase1-modules.ps1 first)
#   - Labels applied  (run apply-labels.ps1 first)
#   - Milestones set  (run create-milestones.ps1 first)
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts/github/add-phase1-issues.ps1
#   powershell -ExecutionPolicy Bypass -File scripts/github/add-phase1-issues.ps1 -Module freeipa

[CmdletBinding()]
param(
  [string]$Org    = "it-stack-dev",
  [string]$Module = ""   # leave blank for all Phase 1 modules
)

Set-StrictMode -Version Latest

$modules = @(
  @{ name = "freeipa";    num = "01"; cat = "identity";      phase = "1"; milestone = "Phase 1: Foundation" },
  @{ name = "keycloak";   num = "02"; cat = "identity";      phase = "1"; milestone = "Phase 1: Foundation" },
  @{ name = "postgresql"; num = "03"; cat = "database";      phase = "1"; milestone = "Phase 1: Foundation" },
  @{ name = "redis";      num = "04"; cat = "database";      phase = "1"; milestone = "Phase 1: Foundation" },
  @{ name = "traefik";    num = "18"; cat = "infrastructure"; phase = "1"; milestone = "Phase 1: Foundation" }
)

$labDefs = @(
  @{ num = "01"; name = "Standalone";            compose = "standalone";    guide = "01-standalone" },
  @{ num = "02"; name = "External Dependencies"; compose = "lan";           guide = "02-external-dependencies" },
  @{ num = "03"; name = "Advanced Features";     compose = "advanced";      guide = "03-advanced-features" },
  @{ num = "04"; name = "SSO Integration";       compose = "sso";           guide = "04-sso-integration" },
  @{ num = "05"; name = "Advanced Integration";  compose = "integration";   guide = "05-advanced-integration" },
  @{ num = "06"; name = "Production Deployment"; compose = "production";    guide = "06-production-deployment" }
)

$labDesc = @{
  "01" = "Basic service validation in complete isolation. No external dependencies."
  "02" = "Network integration with external PostgreSQL, Redis, and LAN services."
  "03" = "Production feature set: resource limits, performance tuning, scaling."
  "04" = "Keycloak OIDC/SAML single sign-on authentication integration."
  "05" = "Deep multi-module ecosystem integration with dependent IT-Stack services."
  "06" = "HA cluster deployment, monitoring hooks, disaster recovery, load testing."
}

$targetModules = if ($Module -ne "") {
  $modules | Where-Object { $_.name -eq $Module }
} else { $modules }

$created = 0; $failed = 0

foreach ($m in $targetModules) {
  $repoName = "it-stack-$($m.name)"
  Write-Host "`n[$repoName]" -ForegroundColor Cyan

  foreach ($lab in $labDefs) {
    $labId    = "$($m.num)-$($lab.num)"
    $title    = "Lab ${labId}: $($lab.name)"
    $labels   = "lab,module-$($m.num),phase-$($m.phase),$($m.cat),priority-high,status-todo"

    $body = @"
## Lab $labId: $($lab.name)

**Module:** $($m.name) (module $($m.num))
**Phase:** $($m.phase) -- $($m.milestone)
**Objective:** $($labDesc[$lab.num])

### Docker Compose File
``docker/docker-compose.$($lab.compose).yml``

### Test Script
``tests/labs/test-lab-${labId}.sh``

### Acceptance Criteria
- [ ] ``docker compose -f docker/docker-compose.$($lab.compose).yml up -d`` completes successfully
- [ ] All assertions in ``tests/labs/test-lab-${labId}.sh`` pass
- [ ] Service health endpoint returns HTTP 200 OK
- [ ] No ERROR-level messages in container logs
- [ ] ``make test LAB=$($lab.num)`` exits 0

### References
- Lab Guide: ``docs/labs/$($lab.guide).md``
- Architecture: ``docs/ARCHITECTURE.md``
- Module Manifest: ``it-stack-$($m.name).yml``
"@

    $result = gh issue create `
      --repo "$Org/$repoName" `
      --title  $title `
      --body   $body `
      --label  $labels `
      --milestone $m.milestone 2>&1

    if ($LASTEXITCODE -eq 0) {
      Write-Host "  [+] $title" -ForegroundColor DarkGray
      $created++
    } else {
      Write-Host "  [!] $title" -ForegroundColor Yellow
      Write-Host "      $result" -ForegroundColor DarkGray
      $failed++
    }
    Start-Sleep -Milliseconds 300
  }
}

Write-Host ""
Write-Host "Phase 1 issues -- Created: $created  |  Errors: $failed" -ForegroundColor Cyan
