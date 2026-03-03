#!/usr/bin/env pwsh
# _build/build-part2.ps1
# Creates all scripts/github/ scripts (11 files):
#   apply-labels, create-milestones, create-github-projects,
#   create-phase1-modules, create-phase2-modules,
#   create-phase3-modules, create-phase4-modules,
#   add-phase1-issues, add-phase2-issues,
#   add-phase3-issues, add-phase4-issues

$root = "C:\IT-Stack\it-stack-dev\repos\meta\it-stack-installer"
$gh   = "$root\scripts\github"

function Write-Script { param($path, $content)
  $dir = Split-Path $path
  if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  [System.IO.File]::WriteAllText($path, $content, [System.Text.UTF8Encoding]::new($false))
}

# ══════════════════════════════════════════════════════════════
# apply-labels.ps1
# ══════════════════════════════════════════════════════════════
Write-Script "$gh\apply-labels.ps1" @'
#!/usr/bin/env pwsh
# scripts/github/apply-labels.ps1
# Create all 39 IT-Stack labels across every module + meta repo.
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
  @{ name = "module-01";  color = "e4e669"; desc = "FreeIPA" },
  @{ name = "module-02";  color = "e4e669"; desc = "Keycloak" },
  @{ name = "module-03";  color = "e4e669"; desc = "PostgreSQL" },
  @{ name = "module-04";  color = "e4e669"; desc = "Redis" },
  @{ name = "module-05";  color = "e4e669"; desc = "Elasticsearch" },
  @{ name = "module-06";  color = "e4e669"; desc = "Nextcloud" },
  @{ name = "module-07";  color = "e4e669"; desc = "Mattermost" },
  @{ name = "module-08";  color = "e4e669"; desc = "Jitsi" },
  @{ name = "module-09";  color = "e4e669"; desc = "iRedMail" },
  @{ name = "module-10";  color = "e4e669"; desc = "FreePBX" },
  @{ name = "module-11";  color = "e4e669"; desc = "Zammad" },
  @{ name = "module-12";  color = "e4e669"; desc = "SuiteCRM" },
  @{ name = "module-13";  color = "e4e669"; desc = "Odoo" },
  @{ name = "module-14";  color = "e4e669"; desc = "OpenKM" },
  @{ name = "module-15";  color = "e4e669"; desc = "Taiga" },
  @{ name = "module-16";  color = "e4e669"; desc = "Snipe-IT" },
  @{ name = "module-17";  color = "e4e669"; desc = "GLPI" },
  @{ name = "module-18";  color = "e4e669"; desc = "Traefik" },
  @{ name = "module-19";  color = "e4e669"; desc = "Zabbix" },
  @{ name = "module-20";  color = "e4e669"; desc = "Graylog" },
  # Phases
  @{ name = "phase-1";    color = "0052cc"; desc = "Foundation" },
  @{ name = "phase-2";    color = "0052cc"; desc = "Collaboration" },
  @{ name = "phase-3";    color = "0052cc"; desc = "Back Office" },
  @{ name = "phase-4";    color = "0052cc"; desc = "IT Management" },
  # Categories
  @{ name = "identity";       color = "d93f0b"; desc = "Identity & SSO" },
  @{ name = "database";       color = "d93f0b"; desc = "Database & Cache" },
  @{ name = "collaboration";  color = "d93f0b"; desc = "Collaboration tools" },
  @{ name = "communications"; color = "d93f0b"; desc = "Communications" },
  @{ name = "business";       color = "d93f0b"; desc = "Business systems" },
  @{ name = "it-management";  color = "d93f0b"; desc = "IT & Project Management" },
  @{ name = "infrastructure"; color = "d93f0b"; desc = "Infrastructure" },
  # Priority
  @{ name = "priority-high";  color = "b60205"; desc = "High priority" },
  @{ name = "priority-med";   color = "fbca04"; desc = "Medium priority" },
  @{ name = "priority-low";   color = "0e8a16"; desc = "Low priority" },
  # Status
  @{ name = "status-todo";        color = "cccccc"; desc = "Not started" },
  @{ name = "status-in-progress"; color = "1d76db"; desc = "In progress" },
  @{ name = "status-done";        color = "0e8a16"; desc = "Completed" },
  @{ name = "status-blocked";     color = "b60205"; desc = "Blocked" }
)

$allRepos = @(
  ".github",
  "it-stack-docs","it-stack-installer","it-stack-testing","it-stack-ansible","it-stack-terraform","it-stack-helm",
  "it-stack-freeipa","it-stack-keycloak","it-stack-postgresql","it-stack-redis","it-stack-traefik",
  "it-stack-nextcloud","it-stack-mattermost","it-stack-jitsi","it-stack-iredmail","it-stack-zammad",
  "it-stack-freepbx","it-stack-suitecrm","it-stack-odoo","it-stack-openkm",
  "it-stack-taiga","it-stack-snipeit","it-stack-glpi","it-stack-elasticsearch","it-stack-zabbix","it-stack-graylog"
)

$targetRepos = if ($Repo -ne "") { @($Repo) } else { $allRepos }

$created = 0; $existed = 0; $failed = 0

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
Write-Host "Labels applied — Created/Updated: $created  |  Errors: $failed" -ForegroundColor Cyan
'@

# ══════════════════════════════════════════════════════════════
# create-milestones.ps1
# ══════════════════════════════════════════════════════════════
Write-Script "$gh\create-milestones.ps1" @'
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
  @{ title = "Phase 1: Foundation";      desc = "FreeIPA, Keycloak, PostgreSQL, Redis, Traefik — Labs 01-06"; due = "2026-04-18" },
  @{ title = "Phase 2: Collaboration";   desc = "Nextcloud, Mattermost, Jitsi, iRedMail, Zammad — Labs 01-06"; due = "2026-05-30" },
  @{ title = "Phase 3: Back Office";     desc = "FreePBX, SuiteCRM, Odoo, OpenKM — Labs 01-06"; due = "2026-07-31" },
  @{ title = "Phase 4: IT Management";   desc = "Taiga, Snipe-IT, GLPI, Elasticsearch, Zabbix, Graylog — Labs 01-06"; due = "2026-10-15" }
)

$moduleRepos = @(
  "it-stack-freeipa","it-stack-keycloak","it-stack-postgresql","it-stack-redis","it-stack-traefik",
  "it-stack-nextcloud","it-stack-mattermost","it-stack-jitsi","it-stack-iredmail","it-stack-zammad",
  "it-stack-freepbx","it-stack-suitecrm","it-stack-odoo","it-stack-openkm",
  "it-stack-taiga","it-stack-snipeit","it-stack-glpi","it-stack-elasticsearch","it-stack-zabbix","it-stack-graylog"
)

$targetRepos = if ($Repo -ne "") { @($Repo) } else { $moduleRepos }
$created = 0; $failed = 0

foreach ($r in $targetRepos) {
  Write-Host "`n[$r]" -ForegroundColor Cyan
  foreach ($ms in $milestones) {
    $body = @{ title = $ms.title; description = $ms.desc; due_on = "$($ms.due)T23:59:59Z"; state = "open" } | ConvertTo-Json
    $result = $body | gh api -X POST "repos/$Org/$r/milestones" --input - 2>&1
    if ($LASTEXITCODE -eq 0) {
      Write-Host "  [+] $($ms.title)" -ForegroundColor DarkGray
      $created++
    } else {
      # 422 = already exists
      if ($result -match "already exists" -or $result -match "422") {
        Write-Host "  [=] $($ms.title) (already exists)" -ForegroundColor DarkGray
      } else {
        Write-Host "  [!] $($ms.title): $result" -ForegroundColor Yellow
        $failed++
      }
    }
  }
}

Write-Host ""
Write-Host "Milestones — Created: $created  |  Errors: $failed" -ForegroundColor Cyan
'@

# ══════════════════════════════════════════════════════════════
# create-github-projects.ps1
# ══════════════════════════════════════════════════════════════
Write-Script "$gh\create-github-projects.ps1" @'
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
  @{ title = "Phase 1: Foundation";      desc = "FreeIPA · Keycloak · PostgreSQL · Redis · Traefik — 30 labs" },
  @{ title = "Phase 2: Collaboration";   desc = "Nextcloud · Mattermost · Jitsi · iRedMail · Zammad — 30 labs" },
  @{ title = "Phase 3: Back Office";     desc = "FreePBX · SuiteCRM · Odoo · OpenKM — 24 labs" },
  @{ title = "Phase 4: IT Management";   desc = "Taiga · Snipe-IT · GLPI · Elasticsearch · Zabbix · Graylog — 36 labs" },
  @{ title = "Master Dashboard";         desc = "All 20 IT-Stack modules — 120 labs total" }
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
    Write-Host "  [+] Created Project #$($projectData.number): $($p.title)" -ForegroundColor Green
    Write-Host "      URL: $($projectData.url)" -ForegroundColor DarkGray
  } else {
    Write-Host "  [!] $($p.title): $result" -ForegroundColor Yellow
  }
}

Write-Host ""
Write-Host "Projects created. Add issues to projects using:" -ForegroundColor Yellow
Write-Host "  gh project item-add <number> --owner $Org --url <issue-url>"
'@

# ══════════════════════════════════════════════════════════════
# Helper function for create-phase scripts and add-issues scripts
# ══════════════════════════════════════════════════════════════

# ── create-phase1-modules.ps1 ─────────────────────────────────
Write-Script "$gh\create-phase1-modules.ps1" @'
#!/usr/bin/env pwsh
# scripts/github/create-phase1-modules.ps1
# Create the 5 Phase 1 (Foundation) GitHub repositories.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts/github/create-phase1-modules.ps1

[CmdletBinding()]
param([string]$Org = "it-stack-dev")

$modules = @(
  @{ name = "freeipa";    num = "01"; desc = "IT-Stack: FreeIPA Identity & DNS — LDAP, Kerberos, DNS (module 01)" },
  @{ name = "keycloak";   num = "02"; desc = "IT-Stack: Keycloak SSO Broker — OAuth2, OIDC, SAML (module 02)" },
  @{ name = "postgresql"; num = "03"; desc = "IT-Stack: PostgreSQL Database — primary DB for all 10+ services (module 03)" },
  @{ name = "redis";      num = "04"; desc = "IT-Stack: Redis Cache & Sessions — cache, queues, pub/sub (module 04)" },
  @{ name = "traefik";    num = "18"; desc = "IT-Stack: Traefik Reverse Proxy — TLS termination, routing, Let's Encrypt (module 18)" }
)

foreach ($m in $modules) {
  $repoName = "it-stack-$($m.name)"
  Write-Host "Creating $repoName..." -ForegroundColor Cyan
  gh repo create "$Org/$repoName" `
    --public `
    --description $m.desc `
    --add-readme 2>&1
  if ($LASTEXITCODE -eq 0) {
    Write-Host "  [+] https://github.com/$Org/$repoName" -ForegroundColor Green
    Start-Sleep -Milliseconds 500
  } else {
    Write-Host "  [!] Already exists or error" -ForegroundColor Yellow
  }
}

Write-Host ""
Write-Host "Phase 1 repos ready. Next: run add-phase1-issues.ps1"
'@

# ── create-phase2-modules.ps1 ─────────────────────────────────
Write-Script "$gh\create-phase2-modules.ps1" @'
#!/usr/bin/env pwsh
# scripts/github/create-phase2-modules.ps1
# Create the 5 Phase 2 (Collaboration) GitHub repositories.

[CmdletBinding()]
param([string]$Org = "it-stack-dev")

$modules = @(
  @{ name = "nextcloud";  num = "06"; desc = "IT-Stack: Nextcloud Files & Collaboration — WebDAV, CalDAV, office (module 06)" },
  @{ name = "mattermost"; num = "07"; desc = "IT-Stack: Mattermost Team Messaging — channels, bots, webhooks (module 07)" },
  @{ name = "jitsi";      num = "08"; desc = "IT-Stack: Jitsi Meet Video Conferencing — WebRTC, TURN, JWT auth (module 08)" },
  @{ name = "iredmail";   num = "09"; desc = "IT-Stack: iRedMail Email Server — Postfix, Dovecot, webmail (module 09)" },
  @{ name = "zammad";     num = "11"; desc = "IT-Stack: Zammad Help Desk — tickets, LDAP, Elasticsearch (module 11)" }
)

foreach ($m in $modules) {
  $repoName = "it-stack-$($m.name)"
  Write-Host "Creating $repoName..." -ForegroundColor Cyan
  gh repo create "$Org/$repoName" --public --description $m.desc --add-readme 2>&1
  if ($LASTEXITCODE -eq 0) {
    Write-Host "  [+] https://github.com/$Org/$repoName" -ForegroundColor Green
    Start-Sleep -Milliseconds 500
  } else { Write-Host "  [!] Already exists or error" -ForegroundColor Yellow }
}
Write-Host "`nPhase 2 repos ready. Next: run add-phase2-issues.ps1"
'@

# ── create-phase3-modules.ps1 ─────────────────────────────────
Write-Script "$gh\create-phase3-modules.ps1" @'
#!/usr/bin/env pwsh
# scripts/github/create-phase3-modules.ps1
# Create the 4 Phase 3 (Back Office) GitHub repositories.

[CmdletBinding()]
param([string]$Org = "it-stack-dev")

$modules = @(
  @{ name = "freepbx";  num = "10"; desc = "IT-Stack: FreePBX VoIP PBX — Asterisk, SIP, IVR, voicemail (module 10)" },
  @{ name = "suitecrm"; num = "12"; desc = "IT-Stack: SuiteCRM CRM — contacts, campaigns, pipelines (module 12)" },
  @{ name = "odoo";     num = "13"; desc = "IT-Stack: Odoo ERP — accounting, HR, inventory, projects (module 13)" },
  @{ name = "openkm";   num = "14"; desc = "IT-Stack: OpenKM Document Management — versioning, workflows (module 14)" }
)

foreach ($m in $modules) {
  $repoName = "it-stack-$($m.name)"
  Write-Host "Creating $repoName..." -ForegroundColor Cyan
  gh repo create "$Org/$repoName" --public --description $m.desc --add-readme 2>&1
  if ($LASTEXITCODE -eq 0) {
    Write-Host "  [+] https://github.com/$Org/$repoName" -ForegroundColor Green
    Start-Sleep -Milliseconds 500
  } else { Write-Host "  [!] Already exists or error" -ForegroundColor Yellow }
}
Write-Host "`nPhase 3 repos ready. Next: run add-phase3-issues.ps1"
'@

# ── create-phase4-modules.ps1 ─────────────────────────────────
Write-Script "$gh\create-phase4-modules.ps1" @'
#!/usr/bin/env pwsh
# scripts/github/create-phase4-modules.ps1
# Create the 6 Phase 4 (IT Management) GitHub repositories.

[CmdletBinding()]
param([string]$Org = "it-stack-dev")

$modules = @(
  @{ name = "taiga";         num = "15"; desc = "IT-Stack: Taiga Project Management — Scrum, Kanban, sprints (module 15)" },
  @{ name = "snipeit";       num = "16"; desc = "IT-Stack: Snipe-IT Asset Management — hardware, licenses, CMDB (module 16)" },
  @{ name = "glpi";          num = "17"; desc = "IT-Stack: GLPI ITSM — tickets, CMDB, change management (module 17)" },
  @{ name = "elasticsearch"; num = "05"; desc = "IT-Stack: Elasticsearch Search Engine — full-text search, log indexing (module 05)" },
  @{ name = "zabbix";        num = "19"; desc = "IT-Stack: Zabbix Infrastructure Monitoring — metrics, alerts, dashboards (module 19)" },
  @{ name = "graylog";       num = "20"; desc = "IT-Stack: Graylog Log Management — centralized logging, GELF, Syslog (module 20)" }
)

foreach ($m in $modules) {
  $repoName = "it-stack-$($m.name)"
  Write-Host "Creating $repoName..." -ForegroundColor Cyan
  gh repo create "$Org/$repoName" --public --description $m.desc --add-readme 2>&1
  if ($LASTEXITCODE -eq 0) {
    Write-Host "  [+] https://github.com/$Org/$repoName" -ForegroundColor Green
    Start-Sleep -Milliseconds 500
  } else { Write-Host "  [!] Already exists or error" -ForegroundColor Yellow }
}
Write-Host "`nPhase 4 repos ready. Next: run add-phase4-issues.ps1"
'@

Write-Host "create-module scripts done"

# ══════════════════════════════════════════════════════════════
# Lab issue definitions helper function (reused across all 4 scripts)
# ══════════════════════════════════════════════════════════════

$labTitles = @{
  "01" = "Standalone — basic service validation in full isolation"
  "02" = "External Dependencies — PostgreSQL, Redis, and LAN integration"
  "03" = "Advanced Features — production settings, resource limits, performance"
  "04" = "SSO Integration — Keycloak OIDC/SAML authentication"
  "05" = "Advanced Integration — multi-service ecosystem integration"
  "06" = "Production Deployment — HA cluster, monitoring, disaster recovery"
}

# ── add-phase1-issues.ps1 ─────────────────────────────────────
$phase1Modules = @(
  @{ name = "freeipa";    num = "01"; cat = "identity";   phase = "1" },
  @{ name = "keycloak";   num = "02"; cat = "identity";   phase = "1" },
  @{ name = "postgresql"; num = "03"; cat = "database";   phase = "1" },
  @{ name = "redis";      num = "04"; cat = "database";   phase = "1" },
  @{ name = "traefik";    num = "18"; cat = "infrastructure"; phase = "1" }
)

$addIssuesScript = @"
#!/usr/bin/env pwsh
# scripts/github/add-phase1-issues.ps1
# Create the 30 lab issues (6 labs x 5 modules) for Phase 1 repos.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts/github/add-phase1-issues.ps1

[CmdletBinding()]
param([string]`$Org = "it-stack-dev")

`$modules = @(
  @{ name = "freeipa";    num = "01"; cat = "identity";      phase = "1" },
  @{ name = "keycloak";   num = "02"; cat = "identity";      phase = "1" },
  @{ name = "postgresql"; num = "03"; cat = "database";      phase = "1" },
  @{ name = "redis";      num = "04"; cat = "database";      phase = "1" },
  @{ name = "traefik";    num = "18"; cat = "infrastructure"; phase = "1" }
)

`$labTitles = @{
  "01" = "Standalone — basic service validation in full isolation"
  "02" = "External Dependencies — PostgreSQL, Redis, and LAN integration"
  "03" = "Advanced Features — production settings, resource limits, performance"
  "04" = "SSO Integration — Keycloak OIDC/SAML authentication"
  "05" = "Advanced Integration — multi-service ecosystem integration"
  "06" = "Production Deployment — HA cluster, monitoring, disaster recovery"
}

`$created = 0; `$failed = 0

foreach (`$m in `$modules) {
  `$repoName = "it-stack-`$(`$m.name)"
  Write-Host "`n[`$repoName]" -ForegroundColor Cyan
  for (`$lab = 1; `$lab -le 6; `$lab++) {
    `$labNum = `$lab.ToString("D2")
    `$labId  = "`$(`$m.num)-`$labNum"
    `$title  = "Lab `$labId`: `$(`$labTitles[`$labNum])"
    `$body   = @"
## Lab `$labId

**Module:** `$(`$m.name) (module `$(`$m.num))
**Phase:** `$(`$m.phase)
**Objective:** `$(`$labTitles[`$labNum])

### Acceptance Criteria
- [ ] All test assertions in ``tests/labs/test-lab-`$labId.sh`` pass
- [ ] ``docker compose -f docker/docker-compose.$(
      switch (`$labNum) {
        "01" { "standalone" } "02" { "lan" } "03" { "advanced" }
        "04" { "sso" }        "05" { "integration" } "06" { "production" }
      }
    ).yml up -d`` completes successfully
- [ ] Service health endpoint returns OK
- [ ] No errors in Docker container logs

### References
- [Lab Guide](docs/labs/$(
      switch (`$labNum) {
        "01" { "01-standalone" } "02" { "02-external-dependencies" } "03" { "03-advanced-features" }
        "04" { "04-sso-integration" } "05" { "05-advanced-integration" } "06" { "06-production-deployment" }
      }
    ).md)
- [Architecture Docs](docs/ARCHITECTURE.md)
"@
    `$labels = "lab,module-`$(`$m.num),phase-`$(`$m.phase),`$(`$m.cat),priority-high,status-todo"
    `$result = gh issue create ``
      --repo "`$Org/`$repoName" ``
      --title "`$title" ``
      --body "`$body" ``
      --label "`$labels" ``
      --milestone "Phase `$(`$m.phase): Foundation" 2>&1
    if (`$LASTEXITCODE -eq 0) {
      Write-Host "  [+] `$title" -ForegroundColor DarkGray
      `$created++
    } else {
      Write-Host "  [!] `$title: `$result" -ForegroundColor Yellow
      `$failed++
    }
    Start-Sleep -Milliseconds 300
  }
}

Write-Host ""
Write-Host "Phase 1 issues — Created: `$created  |  Errors: `$failed" -ForegroundColor Cyan
"@
Write-Script "$gh\add-phase1-issues.ps1" $addIssuesScript

# ── add-phase2-issues.ps1 ─────────────────────────────────────
$addPhase2Script = @"
#!/usr/bin/env pwsh
# scripts/github/add-phase2-issues.ps1
# Create the 30 lab issues (6 labs x 5 modules) for Phase 2 repos.

[CmdletBinding()]
param([string]`$Org = "it-stack-dev")

`$modules = @(
  @{ name = "nextcloud";  num = "06"; cat = "collaboration";  phase = "2" },
  @{ name = "mattermost"; num = "07"; cat = "collaboration";  phase = "2" },
  @{ name = "jitsi";      num = "08"; cat = "collaboration";  phase = "2" },
  @{ name = "iredmail";   num = "09"; cat = "communications"; phase = "2" },
  @{ name = "zammad";     num = "11"; cat = "communications"; phase = "2" }
)

`$labTitles = @{
  "01" = "Standalone — basic service validation in full isolation"
  "02" = "External Dependencies — PostgreSQL, Redis, and LAN integration"
  "03" = "Advanced Features — production settings, resource limits, performance"
  "04" = "SSO Integration — Keycloak OIDC/SAML authentication"
  "05" = "Advanced Integration — multi-service ecosystem integration"
  "06" = "Production Deployment — HA cluster, monitoring, disaster recovery"
}

`$created = 0; `$failed = 0

foreach (`$m in `$modules) {
  `$repoName = "it-stack-`$(`$m.name)"
  Write-Host "`n[`$repoName]" -ForegroundColor Cyan
  for (`$lab = 1; `$lab -le 6; `$lab++) {
    `$labNum = `$lab.ToString("D2")
    `$labId  = "`$(`$m.num)-`$labNum"
    `$title  = "Lab `$labId`: `$(`$labTitles[`$labNum])"
    `$labels = "lab,module-`$(`$m.num),phase-`$(`$m.phase),`$(`$m.cat),priority-high,status-todo"
    `$result = gh issue create ``
      --repo "`$Org/`$repoName" ``
      --title "`$title" ``
      --body "## Lab ``$labId``\n\n**Module:** ``$(`$m.name)``\n**Phase:** `$(`$m.phase)\n**Objective:** `$(`$labTitles[`$labNum])\n\n### Acceptance Criteria\n- [ ] All test assertions in ``tests/labs/test-lab-`$labId.sh`` pass\n- [ ] Service health endpoint returns OK" ``
      --label "`$labels" ``
      --milestone "Phase `$(`$m.phase): Collaboration" 2>&1
    if (`$LASTEXITCODE -eq 0) {
      Write-Host "  [+] `$title" -ForegroundColor DarkGray; `$created++
    } else {
      Write-Host "  [!] `$title" -ForegroundColor Yellow; `$failed++
    }
    Start-Sleep -Milliseconds 300
  }
}

Write-Host ""
Write-Host "Phase 2 issues — Created: `$created  |  Errors: `$failed" -ForegroundColor Cyan
"@
Write-Script "$gh\add-phase2-issues.ps1" $addPhase2Script

# ── add-phase3-issues.ps1 ─────────────────────────────────────
$addPhase3Script = @"
#!/usr/bin/env pwsh
# scripts/github/add-phase3-issues.ps1
# Create the 24 lab issues (6 labs x 4 modules) for Phase 3 repos.

[CmdletBinding()]
param([string]`$Org = "it-stack-dev")

`$modules = @(
  @{ name = "freepbx";  num = "10"; cat = "communications"; phase = "3" },
  @{ name = "suitecrm"; num = "12"; cat = "business";       phase = "3" },
  @{ name = "odoo";     num = "13"; cat = "business";       phase = "3" },
  @{ name = "openkm";   num = "14"; cat = "business";       phase = "3" }
)

`$labTitles = @{
  "01" = "Standalone — basic service validation in full isolation"
  "02" = "External Dependencies — PostgreSQL, Redis, and LAN integration"
  "03" = "Advanced Features — production settings, resource limits, performance"
  "04" = "SSO Integration — Keycloak OIDC/SAML authentication"
  "05" = "Advanced Integration — multi-service ecosystem integration"
  "06" = "Production Deployment — HA cluster, monitoring, disaster recovery"
}

`$created = 0; `$failed = 0

foreach (`$m in `$modules) {
  `$repoName = "it-stack-`$(`$m.name)"
  Write-Host "`n[`$repoName]" -ForegroundColor Cyan
  for (`$lab = 1; `$lab -le 6; `$lab++) {
    `$labNum = `$lab.ToString("D2")
    `$labId  = "`$(`$m.num)-`$labNum"
    `$title  = "Lab `$labId`: `$(`$labTitles[`$labNum])"
    `$labels = "lab,module-`$(`$m.num),phase-`$(`$m.phase),`$(`$m.cat),priority-high,status-todo"
    `$result = gh issue create ``
      --repo "`$Org/`$repoName" ``
      --title "`$title" ``
      --body "## Lab ``$labId``\n\n**Module:** ``$(`$m.name)``\n**Phase:** `$(`$m.phase)\n**Objective:** `$(`$labTitles[`$labNum])\n\n### Acceptance Criteria\n- [ ] All test assertions in ``tests/labs/test-lab-`$labId.sh`` pass\n- [ ] Service health endpoint returns OK" ``
      --label "`$labels" ``
      --milestone "Phase `$(`$m.phase): Back Office" 2>&1
    if (`$LASTEXITCODE -eq 0) {
      Write-Host "  [+] `$title" -ForegroundColor DarkGray; `$created++
    } else {
      Write-Host "  [!] `$title" -ForegroundColor Yellow; `$failed++
    }
    Start-Sleep -Milliseconds 300
  }
}

Write-Host ""
Write-Host "Phase 3 issues — Created: `$created  |  Errors: `$failed" -ForegroundColor Cyan
"@
Write-Script "$gh\add-phase3-issues.ps1" $addPhase3Script

# ── add-phase4-issues.ps1 ─────────────────────────────────────
$addPhase4Script = @"
#!/usr/bin/env pwsh
# scripts/github/add-phase4-issues.ps1
# Create the 36 lab issues (6 labs x 6 modules) for Phase 4 repos.

[CmdletBinding()]
param([string]`$Org = "it-stack-dev")

`$modules = @(
  @{ name = "taiga";         num = "15"; cat = "it-management";  phase = "4" },
  @{ name = "snipeit";       num = "16"; cat = "it-management";  phase = "4" },
  @{ name = "glpi";          num = "17"; cat = "it-management";  phase = "4" },
  @{ name = "elasticsearch"; num = "05"; cat = "database";       phase = "4" },
  @{ name = "zabbix";        num = "19"; cat = "infrastructure"; phase = "4" },
  @{ name = "graylog";       num = "20"; cat = "infrastructure"; phase = "4" }
)

`$labTitles = @{
  "01" = "Standalone — basic service validation in full isolation"
  "02" = "External Dependencies — PostgreSQL, Redis, and LAN integration"
  "03" = "Advanced Features — production settings, resource limits, performance"
  "04" = "SSO Integration — Keycloak OIDC/SAML authentication"
  "05" = "Advanced Integration — multi-service ecosystem integration"
  "06" = "Production Deployment — HA cluster, monitoring, disaster recovery"
}

`$created = 0; `$failed = 0

foreach (`$m in `$modules) {
  `$repoName = "it-stack-`$(`$m.name)"
  Write-Host "`n[`$repoName]" -ForegroundColor Cyan
  for (`$lab = 1; `$lab -le 6; `$lab++) {
    `$labNum = `$lab.ToString("D2")
    `$labId  = "`$(`$m.num)-`$labNum"
    `$title  = "Lab `$labId`: `$(`$labTitles[`$labNum])"
    `$labels = "lab,module-`$(`$m.num),phase-`$(`$m.phase),`$(`$m.cat),priority-high,status-todo"
    `$result = gh issue create ``
      --repo "`$Org/`$repoName" ``
      --title "`$title" ``
      --body "## Lab ``$labId``\n\n**Module:** ``$(`$m.name)``\n**Phase:** `$(`$m.phase)\n**Objective:** `$(`$labTitles[`$labNum])\n\n### Acceptance Criteria\n- [ ] All test assertions in ``tests/labs/test-lab-`$labId.sh`` pass\n- [ ] Service health endpoint returns OK" ``
      --label "`$labels" ``
      --milestone "Phase `$(`$m.phase): IT Management" 2>&1
    if (`$LASTEXITCODE -eq 0) {
      Write-Host "  [+] `$title" -ForegroundColor DarkGray; `$created++
    } else {
      Write-Host "  [!] `$title" -ForegroundColor Yellow; `$failed++
    }
    Start-Sleep -Milliseconds 300
  }
}

Write-Host ""
Write-Host "Phase 4 issues — Created: `$created  |  Errors: `$failed" -ForegroundColor Cyan
"@
Write-Script "$gh\add-phase4-issues.ps1" $addPhase4Script

Write-Host "add-issues scripts done"
Write-Host ""
Write-Host "ALL PART 2 SCRIPTS DONE (11 github scripts)"
