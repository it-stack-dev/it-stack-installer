# it-stack-installer
# it-stack-installer

Automated bootstrap scripts and tools for the [IT-Stack](https://github.com/it-stack-dev) open-source enterprise IT platform.

## Overview

This repository contains 19 PowerShell and Bash scripts organized into five categories:

| Category | Scripts | Purpose |
|----------|---------|---------|
| `scripts/setup/` | 3 | Initial developer workstation setup |
| `scripts/github/` | 11 | GitHub org bootstrap (repos, labels, milestones, issues, projects) |
| `scripts/operations/` | 2 | Day-to-day repository management |
| `scripts/utilities/` | 1 | Module scaffolding |
| `scripts/deployment/` | 1 | Ansible deployment wrapper |
| `scripts/testing/` | 1 | Lab test runner |

## Prerequisites

- Windows 10/11 with PowerShell 7+
- [winget](https://learn.microsoft.com/en-us/windows/package-manager/winget/) (for install-tools.ps1)
- [GitHub CLI](https://cli.github.com/) (`gh`) authenticated to `it-stack-dev` org
- WSL2 with Ubuntu (for Ansible-based scripts)

## Quick Start

```powershell
# 1. Install all required tools
powershell -ExecutionPolicy Bypass -File scripts\setup\install-tools.ps1

# 2. Create the local directory structure
powershell -ExecutionPolicy Bypass -File scripts\setup\setup-directory-structure.ps1

# 3. Authenticate GitHub CLI and configure git
powershell -ExecutionPolicy Bypass -File scripts\setup\setup-github.ps1

# 4. Clone all 26 repos into the correct category directories
powershell -ExecutionPolicy Bypass -File scripts\operations\clone-all-repos.ps1
```

## Script Reference

### Setup Scripts

#### `scripts/setup/install-tools.ps1`
Installs all required developer tools via winget and WSL.

**Installs:** Git, GitHub CLI, Docker Desktop, kubectl, Helm, Terraform, Python 3.12, jq, Ansible (WSL)

```powershell
# Install everything
.\scripts\setup\install-tools.ps1

# Check what's installed without installing
.\scripts\setup\install-tools.ps1 -CheckOnly

# Skip winget (manual installs already done)
.\scripts\setup\install-tools.ps1 -SkipWinget
```

#### `scripts/setup/setup-directory-structure.ps1`
Creates the full `C:\IT-Stack\it-stack-dev\` workspace layout.

```powershell
.\scripts\setup\setup-directory-structure.ps1

# Use a custom root path
.\scripts\setup\setup-directory-structure.ps1 -Root "D:\MyWorkspace"
```

**Creates:** `repos/`, `workspaces/`, `deployments/`, `lab-environments/`, `configs/`, `scripts/`, `logs/`

#### `scripts/setup/setup-github.ps1`
Authenticates GitHub CLI and configures git defaults.

```powershell
.\scripts\setup\setup-github.ps1

# Use a pre-existing PAT
.\scripts\setup\setup-github.ps1 -Token "ghp_..."
```

---

### GitHub Bootstrap Scripts

Run these in order when setting up the GitHub organization for the first time.

#### `scripts/github/apply-labels.ps1`
Creates all 39 IT-Stack labels across every repo. Safe to re-run (`--force` updates existing).

```powershell
# Apply to all 26 repos
.\scripts\github\apply-labels.ps1

# Apply to a single repo
.\scripts\github\apply-labels.ps1 -Repo it-stack-freeipa
```

**Labels:** `lab`, `module-01..20`, `phase-1..4`, category labels, priority labels, status labels

#### `scripts/github/create-milestones.ps1`
Creates four deployment phase milestones in every module repo.

```powershell
.\scripts\github\create-milestones.ps1
.\scripts\github\create-milestones.ps1 -Repo it-stack-nextcloud
```

**Milestones:** Phase 1: Foundation, Phase 2: Collaboration, Phase 3: Back Office, Phase 4: IT Management

#### `scripts/github/create-github-projects.ps1`
Creates five GitHub Projects (v2) in the org.

```powershell
.\scripts\github\create-github-projects.ps1
```

**Projects:** Phase 1-4 boards + Master Dashboard

#### `scripts/github/create-phase{1-4}-modules.ps1`
Creates the GitHub repositories for each deployment phase.

```powershell
.\scripts\github\create-phase1-modules.ps1   # freeipa, keycloak, postgresql, redis, traefik
.\scripts\github\create-phase2-modules.ps1   # nextcloud, mattermost, jitsi, iredmail, zammad
.\scripts\github\create-phase3-modules.ps1   # freepbx, suitecrm, odoo, openkm
.\scripts\github\create-phase4-modules.ps1   # taiga, snipeit, glpi, elasticsearch, zabbix, graylog
```

#### `scripts/github/add-phase{1-4}-issues.ps1`
Creates six lab issues per module repo (120 total across all phases).

```powershell
.\scripts\github\add-phase1-issues.ps1          # 30 issues across 5 repos
.\scripts\github\add-phase1-issues.ps1 -Module freeipa   # 6 issues for freeipa only

.\scripts\github\add-phase2-issues.ps1          # 30 issues
.\scripts\github\add-phase3-issues.ps1          # 24 issues
.\scripts\github\add-phase4-issues.ps1          # 36 issues
```

**Issue format:** `Lab XX-YY: <Lab Name>` with acceptance criteria checklist, compose file reference, and test script path.

#### `scripts/github/create-integration-issues.ps1`
Creates 23 GitHub Issues for all cross-service integration milestones (8 SSO + 15 business workflow integrations).

```powershell
# All 23 integration issues
.\scripts\github\create-integration-issues.ps1

# SSO integrations only (8 issues)
.\scripts\github\create-integration-issues.ps1 -Category sso

# Business workflow integrations only (15 issues)
.\scripts\github\create-integration-issues.ps1 -Category business

# Single integration by ID
.\scripts\github\create-integration-issues.ps1 -Id INT-09
```

**Issue format:** `Integration: Service-A <-> Service-B (description)` with overview, step-by-step implementation checklist, and acceptance criteria per integration.

**Integrations covered:**

| ID | Integration | Protocol | Repo |
|----|-------------|----------|------|
| INT-01 | FreeIPA <-> Keycloak | LDAP federation | `it-stack-keycloak` |
| INT-02 | Nextcloud <-> Keycloak | OIDC | `it-stack-nextcloud` |
| INT-03 | Mattermost <-> Keycloak | OIDC | `it-stack-mattermost` |
| INT-04 | SuiteCRM <-> Keycloak | SAML 2.0 | `it-stack-suitecrm` |
| INT-05 | Odoo <-> Keycloak | OIDC | `it-stack-odoo` |
| INT-06 | Zammad <-> Keycloak | OIDC | `it-stack-zammad` |
| INT-07 | GLPI <-> Keycloak | SAML 2.0 | `it-stack-glpi` |
| INT-08 | Taiga <-> Keycloak | OIDC | `it-stack-taiga` |
| INT-08b | Snipe-IT <-> Keycloak | SAML 2.0 | `it-stack-snipeit` |
| INT-09 | FreePBX <-> SuiteCRM | CTI / REST API | `it-stack-freepbx` |
| INT-10 | FreePBX <-> Zammad | AMI webhook | `it-stack-freepbx` |
| INT-11 | FreePBX <-> FreeIPA | LDAP extension provisioning | `it-stack-freepbx` |
| INT-12 | SuiteCRM <-> Odoo | REST API bidirectional sync | `it-stack-suitecrm` |
| INT-13 | SuiteCRM <-> Nextcloud | CalDAV calendar sync | `it-stack-suitecrm` |
| INT-14 | SuiteCRM <-> OpenKM | REST API document linking | `it-stack-suitecrm` |
| INT-15 | Odoo <-> FreeIPA | LDAP employee sync | `it-stack-odoo` |
| INT-16 | Odoo <-> Taiga | Timesheet export | `it-stack-odoo` |
| INT-17 | Odoo <-> Snipe-IT | Procurement -> asset | `it-stack-odoo` |
| INT-18 | Taiga <-> Mattermost | Webhook notifications | `it-stack-taiga` |
| INT-19 | Snipe-IT <-> GLPI | Asset -> CMDB sync | `it-stack-snipeit` |
| INT-20 | GLPI <-> Zammad | Ticket escalation | `it-stack-glpi` |
| INT-21 | OpenKM <-> Nextcloud | Document storage bridge | `it-stack-openkm` |
| INT-22 | Zabbix <-> Mattermost | Infrastructure alert webhooks | `it-stack-zabbix` |
| INT-23 | Graylog <-> Zabbix | Log-based alert triggers | `it-stack-graylog` |

> **Note:** Requires `integration` label — run `apply-labels.ps1` first (label added in v1.25.0).

---

### Operations Scripts

#### `scripts/operations/clone-all-repos.ps1`
Clones all 26 IT-Stack repos into the correct category subdirectories.

```powershell
# Clone everything
.\scripts\operations\clone-all-repos.ps1

# Clone only Phase 1 repos + meta
.\scripts\operations\clone-all-repos.ps1 -Phase 1

# Use a custom root and org
.\scripts\operations\clone-all-repos.ps1 -Root "D:\Work" -Org "my-fork-org"
```

#### `scripts/operations/update-all-repos.ps1`
Pulls latest changes in all cloned repos.

```powershell
# Pull all repos
.\scripts\operations\update-all-repos.ps1

# Show dirty/clean status without pulling
.\scripts\operations\update-all-repos.ps1 -Status

# Pull a specific branch
.\scripts\operations\update-all-repos.ps1 -Branch develop
```

---

### Utility Scripts

#### `scripts/utilities/create-repo-template.ps1`
Scaffolds a new module repo with the full IT-Stack standard structure.

```powershell
.\scripts\utilities\create-repo-template.ps1 `
  -ModuleName "freeipa" `
  -ModuleNumber "01" `
  -Category "01-identity" `
  -Phase "1"

# Also create and push to GitHub
.\scripts\utilities\create-repo-template.ps1 `
  -ModuleName "freeipa" -ModuleNumber "01" -Category "01-identity" -Phase "1" `
  -CreateGitHubRepo
```

**Creates:** Manifest YAML, Dockerfile, Makefile, 6 Docker Compose files, 6 lab test scripts, GitHub Actions workflows, standard docs.

---

### Deployment Scripts

#### `scripts/deployment/deploy-stack.sh`
Ansible deployment wrapper for all IT-Stack services.

```bash
# Deploy full stack
./scripts/deployment/deploy-stack.sh

# Deploy a single module
./scripts/deployment/deploy-stack.sh --module freeipa

# Deploy a phase (dry-run)
./scripts/deployment/deploy-stack.sh --phase 1 --check

# Verbose output
./scripts/deployment/deploy-stack.sh --module keycloak --verbose
```

---

### Testing Scripts

#### `scripts/testing/run-all-labs.sh`
Runs all 120 lab test scripts with filtering options.

```bash
# Run all 120 labs
./scripts/testing/run-all-labs.sh

# Run only Phase 1 labs
./scripts/testing/run-all-labs.sh --phase 1

# Run all labs for a single module
./scripts/testing/run-all-labs.sh --module postgresql

# Run a specific lab number across all modules
./scripts/testing/run-all-labs.sh --lab 4
```

---

## GitHub Bootstrap Order

When setting up the org from scratch, run scripts in this order:

```powershell
# Step 1: Create repos for each phase
.\scripts\github\create-phase1-modules.ps1
.\scripts\github\create-phase2-modules.ps1
.\scripts\github\create-phase3-modules.ps1
.\scripts\github\create-phase4-modules.ps1

# Step 2: Apply labels to all repos
.\scripts\github\apply-labels.ps1

# Step 3: Create milestones in all repos
.\scripts\github\create-milestones.ps1

# Step 4: Create the 5 GitHub Projects
.\scripts\github\create-github-projects.ps1

# Step 5: Create the 120 lab issues
.\scripts\github\add-phase1-issues.ps1
.\scripts\github\add-phase2-issues.ps1
.\scripts\github\add-phase3-issues.ps1
.\scripts\github\add-phase4-issues.ps1

# Step 6: Create the 23 integration milestone issues
.\scripts\github\create-integration-issues.ps1
```

## License

Apache 2.0 — see [LICENSE](../LICENSE)

