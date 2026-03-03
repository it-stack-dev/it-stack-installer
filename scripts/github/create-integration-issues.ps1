#!/usr/bin/env pwsh
# scripts/github/create-integration-issues.ps1
# Create GitHub Issues for all 23 cross-service integration milestones.
#
# Covers:
#   - 8  SSO integrations      (all web apps → Keycloak OIDC/SAML)
#   - 15 business integrations (CalDAV, CTI, webhook chains, REST API sync)
#
# Prerequisites:
#   - gh auth login completed
#   - All 26 repos exist (run create-phase1-4-modules.ps1 first)
#   - Labels applied including 'integration' (run apply-labels.ps1 first)
#   - Milestones set (run create-milestones.ps1 first)
#
# Usage:
#   pwsh -File scripts/github/create-integration-issues.ps1
#   pwsh -File scripts/github/create-integration-issues.ps1 -Category sso
#   pwsh -File scripts/github/create-integration-issues.ps1 -Category business
#   pwsh -File scripts/github/create-integration-issues.ps1 -Id INT-09

[CmdletBinding()]
param(
  [string]$Org      = "it-stack-dev",
  [string]$Category = "",   # blank = all | "sso" | "business"
  [string]$Id       = ""    # blank = all | e.g. "INT-01"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

# ─── Integration Definitions ──────────────────────────────────────────────────
# Each entry maps to one GitHub Issue in the primary service's repo.
# 'labels' uses comma-separated GitHub label names (no spaces around commas).

$integrations = @(

  # ════════════════════════════════════════════════════════════════════════════
  # SSO INTEGRATIONS — All web apps authenticate through Keycloak
  # ════════════════════════════════════════════════════════════════════════════

  @{
    id        = "INT-01"
    category  = "sso"
    title     = "Integration: FreeIPA <-> Keycloak LDAP Federation"
    repo      = "it-stack-keycloak"
    labels    = "integration,module-01,module-02,phase-1,identity,priority-high,status-todo"
    milestone = "Phase 1: Foundation"
    body      = @"
## INT-01: FreeIPA <-> Keycloak LDAP Federation

**Type:** Identity federation
**Services:** FreeIPA (``lab-id1:389/636``) -> Keycloak (``lab-id1:8443``)
**Protocol:** LDAP read-only user store federation
**Phase:** 1 -- Foundation (prerequisite for ALL other SSO integrations)

### Overview

Configure Keycloak to federate user identities from FreeIPA LDAP. FreeIPA is the
single authoritative source for users and groups. Keycloak reads from it every
5 minutes and acts as the OIDC/SAML broker for every web service in IT-Stack.

No user accounts should exist in Keycloak's own database -- all authenticate
via FreeIPA through this federation.

### Implementation Steps

- [ ] Create FreeIPA service account: ``uid=keycloak-svc,cn=sysaccounts,cn=etc,dc=it-stack,dc=lab``
- [ ] Grant read-only LDAP permissions to the service account
- [ ] Keycloak Admin: **Realm** -> **User Federation** -> **Add provider** -> LDAP
- [ ] Set Connection URL: ``ldaps://lab-id1:636`` (use LDAPS in production)
- [ ] Bind DN: ``uid=keycloak-svc,cn=sysaccounts,cn=etc,dc=it-stack,dc=lab``
- [ ] Users DN: ``cn=users,cn=accounts,dc=it-stack,dc=lab``
- [ ] Username LDAP attribute: ``uid``
- [ ] UUID LDAP attribute: ``ipaUniqueID``
- [ ] Full name attribute: ``cn``
- [ ] Enable **Kerberos integration**: Realm -> Authentication -> Kerberos
- [ ] Add **Group mapper**: ``cn=groups,cn=accounts,dc=it-stack,dc=lab``
- [ ] Map FreeIPA ``admins`` group -> Keycloak ``realm-admin`` role
- [ ] Set periodic sync: 300 seconds (5 min)
- [ ] Add Ansible task: ``roles/keycloak/tasks/ldap-federation.yml`` using Keycloak REST API
- [ ] Store bind password in Ansible Vault: ``vault_keycloak_ldap_bind_password``

### Acceptance Criteria

- [ ] ``Full Sync`` in Keycloak UI completes with 0 errors
- [ ] FreeIPA users appear in Keycloak Users list
- [ ] FreeIPA groups appear in Keycloak Groups list
- [ ] FreeIPA admin user can log into Keycloak Admin Console via SSO
- [ ] Password change in FreeIPA reflected in subsequent Keycloak login
- [ ] ``test-lab-01-04.sh`` LDAP bind assertion exits 0
- [ ] Ansible role is idempotent (run twice, no changes on second run)

### References

- [ADR-001: Identity Stack](../../docs/07-architecture/adr-001-identity-stack.md)
- [Keycloak: LDAP/AD integration](https://www.keycloak.org/docs/latest/server_admin/#_ldap)
- [FreeIPA LDAP schema](https://www.freeipa.org/page/Directory_Server)
"@
  }

  @{
    id        = "INT-02"
    category  = "sso"
    title     = "Integration: Nextcloud <-> Keycloak OIDC"
    repo      = "it-stack-nextcloud"
    labels    = "integration,module-02,module-06,phase-2,collaboration,priority-high,status-todo"
    milestone = "Phase 2: Collaboration"
    body      = @"
## INT-02: Nextcloud <-> Keycloak OIDC

**Type:** SSO
**Services:** Nextcloud (``lab-app1``) <- Keycloak (``lab-id1``)
**Protocol:** OpenID Connect (OIDC)
**Phase:** 2 -- Collaboration
**Depends on:** INT-01 (FreeIPA <-> Keycloak federation must be working)

### Overview

Users log into Nextcloud using their IT-Stack credentials via Keycloak OIDC.
New users are auto-provisioned on first login; group membership determines
Nextcloud admin vs. standard user role.

### Implementation Steps

- [ ] In Keycloak: create client ``nextcloud`` (Client Protocol: openid-connect, Access Type: confidential)
- [ ] Set Valid Redirect URI: ``https://cloud.it-stack.lab/apps/user_oidc/code``
- [ ] Set Web Origins: ``https://cloud.it-stack.lab``
- [ ] Add Client Scope: ``profile``, ``email``, ``groups``
- [ ] Add groups mapper: token claim name ``groups``, full group path ``false``
- [ ] In Nextcloud: enable app ``user_oidc`` (``occ app:enable user_oidc``)
- [ ] Configure OIDC provider: Discovery URL ``https://sso.it-stack.lab/realms/it-stack/.well-known/openid-configuration``
- [ ] Map claim ``groups`` / value ``nextcloud-admin`` -> Nextcloud admin group
- [ ] Set display name claim: ``preferred_username``
- [ ] Store client secret in Ansible Vault: ``vault_keycloak_nextcloud_secret``
- [ ] Add Ansible task: ``roles/nextcloud/tasks/oidc.yml``
- [ ] Optional: disable Nextcloud local login after SSO confirmed working

### Acceptance Criteria

- [ ] "Login with IT-Stack SSO" button appears on Nextcloud login page
- [ ] Successful Keycloak authentication creates/updates Nextcloud user
- [ ] Admin group membership provisioned correctly (admin can access Settings)
- [ ] Token refresh transparent to user (no unexpected session drops)
- [ ] ``test-lab-06-04.sh`` SSO assertion exits 0

### References

- [Nextcloud user_oidc app](https://github.com/nextcloud/user_oidc)
- [ADR-001: Identity Stack](../../docs/07-architecture/adr-001-identity-stack.md)
"@
  }

  @{
    id        = "INT-03"
    category  = "sso"
    title     = "Integration: Mattermost <-> Keycloak OIDC"
    repo      = "it-stack-mattermost"
    labels    = "integration,module-02,module-07,phase-2,collaboration,priority-high,status-todo"
    milestone = "Phase 2: Collaboration"
    body      = @"
## INT-03: Mattermost <-> Keycloak OIDC

**Type:** SSO
**Services:** Mattermost (``lab-app1:8065``) <- Keycloak (``lab-id1``)
**Protocol:** OpenID Connect (OIDC) -- Mattermost native GitLab/OpenID provider
**Phase:** 2 -- Collaboration
**Depends on:** INT-01

### Overview

Use Mattermost's built-in OpenID Connect provider support (configured as
"GitLab" or generic OIDC) to authenticate via Keycloak. Users are provisioned
on first login; FreeIPA group ``mattermost-admin`` maps to System Admin role.

### Implementation Steps

- [ ] Keycloak: create client ``mattermost`` (confidential, OIDC)
- [ ] Redirect URI: ``https://chat.it-stack.lab/signup/gitlab/complete``
- [ ] Add groups claim mapper
- [ ] Mattermost System Console -> Authentication -> OpenID Connect: enable
- [ ] Set Discovery Endpoint URL to Keycloak realm well-known URL
- [ ] Set Client ID / Client Secret (from Keycloak client credentials)
- [ ] Map groups claim to System Admin role for ``mattermost-admin`` group
- [ ] Enable guest accounts: disabled (all users via SSO only)
- [ ] Add Ansible task: ``roles/mattermost/tasks/oidc.yml`` (Mattermost mmctl config)
- [ ] Store client secret in Ansible Vault

### Acceptance Criteria

- [ ] Login page shows "Sign in with OpenID Connect"
- [ ] FreeIPA user can authenticate and lands in Mattermost
- [ ] Admin group member has System Admin permissions
- [ ] Username matches FreeIPA uid (not email)
- [ ] ``test-lab-07-04.sh`` SSO assertion exits 0
"@
  }

  @{
    id        = "INT-04"
    category  = "sso"
    title     = "Integration: SuiteCRM <-> Keycloak SAML 2.0"
    repo      = "it-stack-suitecrm"
    labels    = "integration,module-02,module-12,phase-3,business,priority-high,status-todo"
    milestone = "Phase 3: Back Office"
    body      = @"
## INT-04: SuiteCRM <-> Keycloak SAML 2.0

**Type:** SSO
**Services:** SuiteCRM (``lab-biz1``) <- Keycloak (``lab-id1``)
**Protocol:** SAML 2.0 (Keycloak as IdP, SuiteCRM as SP)
**Phase:** 3 -- Back Office
**Depends on:** INT-01

### Overview

SuiteCRM does not support OIDC natively; use SAML 2.0. Keycloak acts as the
SAML Identity Provider. SuiteCRM is the Service Provider configured via the
built-in SAML authentication module.

### Implementation Steps

- [ ] Keycloak: create client ``suitecrm`` (SAML client type)
- [ ] Set ACS URL: ``https://crm.it-stack.lab/index.php?module=Users&action=Authenticate``
- [ ] Set Entity ID (SP): ``https://crm.it-stack.lab``
- [ ] Add attribute mappers: ``email``, ``firstName``, ``lastName``, ``username``
- [ ] Download Keycloak realm certificate (for SuiteCRM SP config)
- [ ] SuiteCRM Admin -> Password Management -> SAML: enable SAML authentication
- [ ] Set IdP Entity ID: ``https://sso.it-stack.lab/realms/it-stack``
- [ ] Set IdP SSO URL, Certificate from Keycloak
- [ ] Map SAML attribute ``username`` -> SuiteCRM user name
- [ ] Auto-provision users on first login
- [ ] Add Ansible task: ``roles/suitecrm/tasks/saml.yml``

### Acceptance Criteria

- [ ] SuiteCRM login page redirects to Keycloak for authentication
- [ ] Successful SAML assertion creates/updates SuiteCRM user
- [ ] First name, last name, email populated from SAML attributes
- [ ] Admin role assigned to ``suitecrm-admin`` group members
- [ ] ``test-lab-12-04.sh`` SSO assertion exits 0
"@
  }

  @{
    id        = "INT-05"
    category  = "sso"
    title     = "Integration: Odoo <-> Keycloak OIDC"
    repo      = "it-stack-odoo"
    labels    = "integration,module-02,module-13,phase-3,business,priority-high,status-todo"
    milestone = "Phase 3: Back Office"
    body      = @"
## INT-05: Odoo <-> Keycloak OIDC

**Type:** SSO
**Services:** Odoo (``lab-biz1:8069``) <- Keycloak (``lab-id1``)
**Protocol:** OpenID Connect (OIDC) via ``auth_oidc`` OCA module
**Phase:** 3 -- Back Office
**Depends on:** INT-01

### Overview

Odoo does not ship with OIDC support; install the OCA ``auth_oidc`` module.
Users log in via Keycloak; their Odoo portal/internal user account is
auto-provisioned from the OIDC token claims.

### Implementation Steps

- [ ] Install OCA module: ``pip install odoo-addon-auth-oidc`` or install from Apps
- [ ] Keycloak: create client ``odoo`` (confidential, OIDC)
- [ ] Redirect URI: ``https://erp.it-stack.lab/auth_oidc/signin``
- [ ] Add groups mapper with claim name ``groups``
- [ ] Odoo Settings -> Auth Providers: add Keycloak OIDC provider
- [ ] Set Client ID / Client Secret / Discovery URL
- [ ] Map ``groups`` claim: ``odoo-admin`` group -> Internal User + Administration
- [ ] Map ``groups`` claim: ``odoo-portal`` group -> Portal user
- [ ] Disable default password login (optional)
- [ ] Add Ansible task: ``roles/odoo/tasks/oidc.yml``

### Acceptance Criteria

- [ ] Odoo login page shows "Log in with Keycloak" button
- [ ] New user auto-provisioned with correct access level on first login
- [ ] Employee record linked to user account
- [ ] ``test-lab-13-04.sh`` SSO assertion exits 0
"@
  }

  @{
    id        = "INT-06"
    category  = "sso"
    title     = "Integration: Zammad <-> Keycloak OIDC"
    repo      = "it-stack-zammad"
    labels    = "integration,module-02,module-11,phase-2,communications,priority-high,status-todo"
    milestone = "Phase 2: Collaboration"
    body      = @"
## INT-06: Zammad <-> Keycloak OIDC

**Type:** SSO
**Services:** Zammad (``lab-comm1:3000``) <- Keycloak (``lab-id1``)
**Protocol:** OpenID Connect (OIDC) -- Zammad native OAuth2/OIDC
**Phase:** 2 -- Collaboration
**Depends on:** INT-01

### Overview

Zammad ships with built-in OIDC/OAuth2 support. Staff (agents) and customers
authenticate via Keycloak. Group membership determines agent vs. admin role.

### Implementation Steps

- [ ] Keycloak: create client ``zammad`` (confidential, OIDC)
- [ ] Redirect URI: ``https://desk.it-stack.lab/auth/keycloak/callback``
- [ ] Add groups and email scopes/mappers
- [ ] Zammad Admin -> Security -> Third-Party Applications -> Enable OAuth2
- [ ] Configure Keycloak provider with App ID, App Secret, Authorize/Token/Info URLs
- [ ] Map ``zammad-admin`` group -> Admin role; ``zammad-agent`` group -> Agent
- [ ] Enable auto-creation of users from OIDC token
- [ ] Add Ansible task: ``roles/zammad/tasks/oidc.yml`` (Zammad REST API config)

### Acceptance Criteria

- [ ] Zammad login page shows "Login with Keycloak"
- [ ] Agent/admin role assigned by group membership
- [ ] User profile (name, email, language) populated from OIDC claims
- [ ] ``test-lab-11-04.sh`` SSO assertion exits 0
"@
  }

  @{
    id        = "INT-07"
    category  = "sso"
    title     = "Integration: GLPI <-> Keycloak SAML 2.0"
    repo      = "it-stack-glpi"
    labels    = "integration,module-02,module-17,phase-4,it-management,priority-high,status-todo"
    milestone = "Phase 4: IT Management"
    body      = @"
## INT-07: GLPI <-> Keycloak SAML 2.0

**Type:** SSO
**Services:** GLPI (``lab-mgmt1``) <- Keycloak (``lab-id1``)
**Protocol:** SAML 2.0 via GLPI ``saml`` plugin
**Phase:** 4 -- IT Management
**Depends on:** INT-01

### Overview

GLPI uses the ``saml`` plugin (formerly ``itsmf/glpi-saml``) for SSO.
Keycloak acts as SAML 2.0 IdP; permissions mapped by group.

### Implementation Steps

- [ ] Install GLPI SAML plugin: ``php bin/console plugin:install saml``
- [ ] Keycloak: create SAML client ``glpi``
- [ ] ACS URL: ``https://itsm.it-stack.lab/index.php?plugin=saml&action=acs``
- [ ] Entity ID: ``https://itsm.it-stack.lab``
- [ ] Map attributes: ``email``, ``first_name``, ``last_name``, ``groups``
- [ ] GLPI Admin -> Setup -> Authentication -> SAML: configure IdP metadata
- [ ] Import Keycloak IdP metadata XML
- [ ] Map ``glpi-admin`` group -> Super-Admin profile; ``glpi-tech`` -> Technician
- [ ] Enable JIT (just-in-time) user provisioning
- [ ] Add Ansible task: ``roles/glpi/tasks/saml.yml``

### Acceptance Criteria

- [ ] GLPI redirects to Keycloak on login
- [ ] JIT provisioning creates user with correct profile
- [ ] Technician group members can manage tickets; admins have full access
- [ ] ``test-lab-17-04.sh`` SSO assertion exits 0
"@
  }

  @{
    id        = "INT-08"
    category  = "sso"
    title     = "Integration: Taiga <-> Keycloak OIDC"
    repo      = "it-stack-taiga"
    labels    = "integration,module-02,module-15,phase-4,it-management,priority-high,status-todo"
    milestone = "Phase 4: IT Management"
    body      = @"
## INT-08: Taiga <-> Keycloak OIDC

**Type:** SSO
**Services:** Taiga (``lab-mgmt1``) <- Keycloak (``lab-id1``)
**Protocol:** OpenID Connect (OIDC) -- Taiga ``taiga-contrib-keycloak-auth`` plugin
**Phase:** 4 -- IT Management
**Depends on:** INT-01

### Overview

Taiga has a community contrib plugin for Keycloak OIDC. Users log in via
Keycloak; project membership and admin access managed inside Taiga per-project.

### Implementation Steps

- [ ] Install: ``pip install taiga-contrib-keycloak-auth`` in Taiga backend venv
- [ ] Keycloak: create client ``taiga`` (confidential, OIDC)
- [ ] Redirect URI: ``https://pm.it-stack.lab/api/v1/auth/keycloak``
- [ ] Add mapper for ``preferred_username``, ``email``, ``full_name``
- [ ] Set ``INSTALLED_APPS`` in Taiga backend settings to include ``taiga_contrib_keycloak_auth``
- [ ] Configure ``KEYCLOAK_URL``, ``KEYCLOAK_REALM``, ``KEYCLOAK_CLIENT_ID/SECRET`` in settings
- [ ] Frontend: enable ``keycloakAuthUrl`` in ``conf.json``
- [ ] Add Ansible task: ``roles/taiga/tasks/oidc.yml``

### Acceptance Criteria

- [ ] Taiga login page has "Login with Keycloak" button
- [ ] New users auto-provisioned from OIDC claims
- [ ] Existing Taiga user merged by email if present
- [ ] ``test-lab-15-04.sh`` SSO assertion exits 0
"@
  }

  @{
    id        = "INT-08b"
    category  = "sso"
    title     = "Integration: Snipe-IT <-> Keycloak SAML 2.0"
    repo      = "it-stack-snipeit"
    labels    = "integration,module-02,module-16,phase-4,it-management,priority-med,status-todo"
    milestone = "Phase 4: IT Management"
    body      = @"
## INT-08b: Snipe-IT <-> Keycloak SAML 2.0

**Type:** SSO
**Services:** Snipe-IT (``lab-mgmt1``) <- Keycloak (``lab-id1``)
**Protocol:** SAML 2.0 -- Snipe-IT native SAML support
**Phase:** 4 -- IT Management
**Depends on:** INT-01

### Overview

Snipe-IT has native SAML 2.0 support via Laravel's ``aacotroneo/laravel-saml2``
package. Keycloak acts as IdP; Snipe-IT auto-provisions users with appropriate
roles based on SAML attribute.

### Implementation Steps

- [ ] Keycloak: create SAML client ``snipeit``
- [ ] SP Entity ID: ``https://assets.it-stack.lab/saml2/snipeit/metadata``
- [ ] ACS URL: ``https://assets.it-stack.lab/saml2/snipeit/acs``
- [ ] Attribute mappers: ``email``, ``username``, ``firstName``, ``lastName``, ``role``
- [ ] Snipe-IT Admin -> Settings -> SAML: enable and configure IdP metadata
- [ ] Map role attribute value ``admin`` -> Snipe-IT Super Admin
- [ ] Map role attribute value ``user`` -> Read-only or IT user
- [ ] Add Ansible task: ``roles/snipeit/tasks/saml.yml``

### Acceptance Criteria

- [ ] Login via SAML redirects to Keycloak correctly
- [ ] User provisioned with correct role on first login
- [ ] ``test-lab-16-04.sh`` SSO assertion exits 0
"@
  }

  # ════════════════════════════════════════════════════════════════════════════
  # BUSINESS WORKFLOW INTEGRATIONS
  # ════════════════════════════════════════════════════════════════════════════

  @{
    id        = "INT-09"
    category  = "business"
    title     = "Integration: FreePBX <-> SuiteCRM (CTI click-to-call, call logging)"
    repo      = "it-stack-freepbx"
    labels    = "integration,module-10,module-12,phase-3,communications,priority-high,status-todo"
    milestone = "Phase 3: Back Office"
    body      = @"
## INT-09: FreePBX <-> SuiteCRM (CTI / Click-to-Call)

**Type:** CTI (Computer Telephony Integration)
**Services:** FreePBX (``lab-pbx1``) <-> SuiteCRM (``lab-biz1``)
**Protocol:** FreePBX REST API + SuiteCRM REST API v8 + AMI events
**Phase:** 3 -- Back Office

### Overview

When a call arrives or is placed from FreePBX, SuiteCRM is notified via AMI
(Asterisk Manager Interface) events. The system:
- Pops a SuiteCRM contact/lead record on inbound calls (screen pop)
- Allows click-to-call directly from SuiteCRM contact records
- Logs all calls with duration, recording link, and disposition

### Implementation Steps

**FreePBX side:**
- [ ] Enable Asterisk REST Interface (ARI) and AMI on FreePBX
- [ ] Create AMI user: ``suitecrm-ami`` with read/call events permission
- [ ] Install FreePBX module: ``asterisk-cti`` or configure custom AGI script
- [ ] Configure AGI script to POST call events to SuiteCRM REST API

**SuiteCRM side:**
- [ ] Enable SuiteCRM REST API v8 (OAuth2 client: ``freepbx``)
- [ ] Install or enable ``AOS_Calls`` and ``AOS_CallHistory`` modules
- [ ] Configure Asterisk Telephony Settings in SuiteCRM admin:
  - AMI host: ``lab-pbx1``
  - AMI user: ``suitecrm-ami``
  - AMI password (Ansible Vault: ``vault_ami_suitecrm_password``)
- [ ] Map inbound CallerID -> SuiteCRM Contacts/Leads phone field lookup
- [ ] Click-to-call: SuiteCRM sends REST call to FreePBX ARI to originate call
- [ ] Store call recording URL in call log record

**Automation:**
- [ ] Ansible task: ``roles/freepbx/tasks/suitecrm-cti.yml``
- [ ] Ansible task: ``roles/suitecrm/tasks/asterisk-cti.yml``

### Acceptance Criteria

- [ ] Inbound call to extension triggers SuiteCRM contact lookup popup (screen pop)
- [ ] Click-to-call from SuiteCRM contact dials extension correctly
- [ ] Completed call logged in SuiteCRM with: caller ID, duration, direction, recording URL
- [ ] Unknown callers create new Lead record automatically
- [ ] ``test-lab-10-05.sh`` CTI assertion exits 0
"@
  }

  @{
    id        = "INT-10"
    category  = "business"
    title     = "Integration: FreePBX <-> Zammad (automatic phone tickets)"
    repo      = "it-stack-freepbx"
    labels    = "integration,module-10,module-11,phase-3,communications,priority-high,status-todo"
    milestone = "Phase 3: Back Office"
    body      = @"
## INT-10: FreePBX <-> Zammad (Automatic Phone Tickets)

**Type:** Webhook / AMI event -> ticket creation
**Services:** FreePBX (``lab-pbx1``) -> Zammad (``lab-comm1``)
**Protocol:** Asterisk AMI event -> AGI/webhook -> Zammad REST API
**Phase:** 3 -- Back Office

### Overview

Every inbound phone call that is missed, dropped, or completes creates a
Zammad ticket automatically. The ticket contains caller ID, extension called,
call duration, recording URL, and wait time. This ensures no support calls
are lost even if not answered.

### Implementation Steps

- [ ] Create Zammad API token for FreePBX system user (``freepbx-bot``)
- [ ] Write AGI script (``/var/lib/asterisk/agi-bin/create-zammad-ticket.py``):
  - Triggered on ``h`` (hangup) extension in Asterisk dialplan
  - Posts to Zammad API: ``POST /api/v1/tickets``
  - Sets: title (caller number), group (``Phone Support``), customer email/phone, tags (``phone``, ``auto-created``)
  - Attaches call recording if available
- [ ] Add ``h`` extension to relevant inbound contexts in FreePBX dialplan
- [ ] Configure: only create ticket if call duration < threshold (missed call) OR always
- [ ] Zammad: create Group ``Phone Support``, assign to relevant agents
- [ ] Ansible task: ``roles/freepbx/tasks/zammad-webhook.yml``
- [ ] Store Zammad API token in Ansible Vault: ``vault_zammad_freepbx_token``

### Acceptance Criteria

- [ ] Missed inbound call creates Zammad ticket within 30 seconds
- [ ] Ticket contains: caller ID, dialed number, timestamp, call duration
- [ ] Agent can see and respond to the ticket
- [ ] Call recording (if enabled) attached to ticket as article attachment
- [ ] ``test-lab-10-05.sh`` phone-ticket assertion exits 0
"@
  }

  @{
    id        = "INT-11"
    category  = "business"
    title     = "Integration: FreePBX <-> FreeIPA (extension provisioning from LDAP)"
    repo      = "it-stack-freepbx"
    labels    = "integration,module-01,module-10,phase-3,communications,priority-med,status-todo"
    milestone = "Phase 3: Back Office"
    body      = @"
## INT-11: FreePBX <-> FreeIPA (Extension Provisioning from LDAP)

**Type:** Directory integration
**Services:** FreePBX (``lab-pbx1``) <- FreeIPA (``lab-id1``)
**Protocol:** LDAP read for user/extension provisioning
**Phase:** 3 -- Back Office

### Overview

FreePBX reads FreeIPA LDAP to automatically provision SIP extensions for
every staff user. When a new employee is added to FreeIPA, their extension
is provisioned automatically (via scheduled LDAP sync or on-demand script).

This also enables voicemail-to-email using FreeIPA email addresses.

### Implementation Steps

- [ ] Install FreePBX module: ``userman`` (User Manager) -- already present in FreePBX 16+
- [ ] Configure User Manager LDAP source:
  - LDAP host: ``lab-id1``
  - Bind DN: ``uid=freepbx-svc,cn=sysaccounts,cn=etc,dc=it-stack,dc=lab``
  - Users DN: ``cn=users,cn=accounts,dc=it-stack,dc=lab``
  - Username attr: ``uid``; email attr: ``mail``; name attr: ``cn``
- [ ] Write sync script ``/usr/local/bin/freepbx-ldap-sync.sh``:
  - Queries FreeIPA for users in ``voip-users`` group
  - Creates FreePBX extension 1NNNN (UID-based numbering) if not exists
  - Updates voicemail address from LDAP ``mail`` attribute
  - Runs via cron every 15 minutes
- [ ] Add FreeIPA group: ``voip-users`` (members get SIP extensions)
- [ ] Ansible task: ``roles/freepbx/tasks/ldap-provisioning.yml``
- [ ] Store LDAP bind password in Ansible Vault

### Acceptance Criteria

- [ ] New user added to FreeIPA ``voip-users`` group gets extension within 15 min
- [ ] Extension registers correctly with Asterisk (SIP REGISTER succeeds)
- [ ] Voicemail-to-email delivers to FreeIPA mail address
- [ ] Removing user from FreeIPA disables extension on next sync
- [ ] ``test-lab-10-05.sh`` LDAP provisioning assertion exits 0
"@
  }

  @{
    id        = "INT-12"
    category  = "business"
    title     = "Integration: SuiteCRM <-> Odoo (customer/contact data sync)"
    repo      = "it-stack-suitecrm"
    labels    = "integration,module-12,module-13,phase-3,business,priority-high,status-todo"
    milestone = "Phase 3: Back Office"
    body      = @"
## INT-12: SuiteCRM <-> Odoo (Customer / Contact Data Sync)

**Type:** Bidirectional data sync
**Services:** SuiteCRM (``lab-biz1``) <-> Odoo (``lab-biz1``)
**Protocol:** REST API (SuiteCRM v8 + Odoo XML-RPC / JSON-RPC)
**Phase:** 3 -- Back Office

### Overview

SuiteCRM (CRM) and Odoo (ERP) need a shared view of customers and contacts.
- SuiteCRM is the master for Accounts and Contacts (sales pipeline)
- Odoo is the master for invoicing and accounting
- When a SuiteCRM Account becomes a customer (deal won), it syncs to Odoo as a Partner
- Invoice status syncs back from Odoo to SuiteCRM opportunity

### Implementation Steps

- [ ] Design sync schema: SuiteCRM Account <-> Odoo res.partner (type: company)
- [ ] Design sync schema: SuiteCRM Contact <-> Odoo res.partner (type: person)
- [ ] Write sync script ``/opt/it-stack/integrations/suitecrm-odoo-sync.py``:
  - Uses SuiteCRM REST API v8 (OAuth2 bearer token)
  - Uses Odoo XML-RPC ``execute_kw`` (api key auth)
  - Sync direction: SuiteCRM -> Odoo on deal stage = Closed Won
  - Sync direction: Odoo -> SuiteCRM on invoice state change
  - Store sync map (SuiteCRM ID <-> Odoo ID) in PostgreSQL ``integrations`` schema
- [ ] Schedule via systemd timer: every 10 minutes
- [ ] Handle conflicts: SuiteCRM wins for contact fields; Odoo wins for financial fields
- [ ] Ansible task: ``roles/suitecrm/tasks/odoo-sync.yml``
- [ ] Store API credentials in Ansible Vault

### Acceptance Criteria

- [ ] New Account/Contact in SuiteCRM appears in Odoo Partners within 10 min
- [ ] Invoice created in Odoo for synced customer visible in SuiteCRM
- [ ] Sync script is idempotent (re-run creates no duplicates)
- [ ] Sync errors logged to Graylog (stream: ``integrations``)
- [ ] ``test-lab-12-05.sh`` sync assertion exits 0
"@
  }

  @{
    id        = "INT-13"
    category  = "business"
    title     = "Integration: SuiteCRM <-> Nextcloud (CalDAV calendar sync)"
    repo      = "it-stack-suitecrm"
    labels    = "integration,module-06,module-12,phase-3,business,priority-med,status-todo"
    milestone = "Phase 3: Back Office"
    body      = @"
## INT-13: SuiteCRM <-> Nextcloud (CalDAV Calendar Sync)

**Type:** Calendar sync
**Services:** SuiteCRM (``lab-biz1``) <-> Nextcloud (``lab-app1``)
**Protocol:** CalDAV (RFC 4791)
**Phase:** 3 -- Back Office

### Overview

SuiteCRM meetings and calls sync bidirectionally with Nextcloud Calendar via
CalDAV. Sales reps see their CRM activities in their personal calendar, and
calendar events they create in Nextcloud can flow back as SuiteCRM activities.

### Implementation Steps

- [ ] In Nextcloud: create calendar ``SuiteCRM`` per user (or shared team calendar)
- [ ] Get Nextcloud CalDAV endpoint: ``https://cloud.it-stack.lab/remote.php/dav/calendars/{uid}/suitecrm/``
- [ ] Generate Nextcloud app password per user (or service account token)
- [ ] Install SuiteCRM CalDAV sync module (``calDavSync`` or ``FP_Event`` integration):
  - If no native module: write Python sync script using ``caldav`` library
  - Script maps SuiteCRM ``Meetings`` and ``Calls`` -> CalDAV VEVENT
  - Script maps CalDAV VEVENT -> SuiteCRM ``Meetings`` (optional, one-way first)
- [ ] Configure per-user authentication (Nextcloud URL + app password) in SuiteCRM profile settings
- [ ] Schedule sync: cron every 5 minutes
- [ ] Ansible task: ``roles/suitecrm/tasks/nextcloud-caldav.yml``

### Acceptance Criteria

- [ ] SuiteCRM meeting created by a user appears in their Nextcloud calendar within 5 min
- [ ] Meeting updates (title, time, invitees) sync within one sync cycle
- [ ] Deleted meeting removed from calendar
- [ ] ``test-lab-12-05.sh`` CalDAV sync assertion exits 0
"@
  }

  @{
    id        = "INT-14"
    category  = "business"
    title     = "Integration: SuiteCRM <-> OpenKM (document linking)"
    repo      = "it-stack-suitecrm"
    labels    = "integration,module-12,module-14,phase-3,business,priority-med,status-todo"
    milestone = "Phase 3: Back Office"
    body      = @"
## INT-14: SuiteCRM <-> OpenKM (Document Linking)

**Type:** Document management integration
**Services:** SuiteCRM (``lab-biz1``) <-> OpenKM (``lab-biz1:8080``)
**Protocol:** OpenKM REST API
**Phase:** 3 -- Back Office

### Overview

Sales documents (quotes, proposals, contracts) are stored in OpenKM and linked
to SuiteCRM Account / Opportunity records. Users can attach documents from
OpenKM directly in the SuiteCRM record view without leaving the CRM.

### Implementation Steps

- [ ] Create SuiteCRM-OpenKM API client: ``suitecrm-dms`` in OpenKM
- [ ] Install or write SuiteCRM-OpenKM connector module:
  - REST calls to OpenKM API: ``GET /api/rest/document/``, ``POST /api/rest/document/create``
  - Add "Documents" subpanel to Accounts, Opportunities, Contacts in SuiteCRM
  - Allow browsing OpenKM folder tree from SuiteCRM
  - Allow uploading from SuiteCRM -> auto-created OpenKM path: ``/CRM/{module}/{record-id}/``
- [ ] Configure connector settings in SuiteCRM admin: OpenKM URL, user, password (Vault)
- [ ] Create OpenKM folder structure: ``/CRM/Accounts/``, ``/CRM/Opportunities/``, ``/CRM/Contacts/``
- [ ] Ansible task: ``roles/suitecrm/tasks/openkm-connector.yml``

### Acceptance Criteria

- [ ] OpenKM Documents subpanel visible on SuiteCRM Account record
- [ ] User can upload a file from SuiteCRM; appears in correct OpenKM folder
- [ ] User can browse and open existing OpenKM docs from within SuiteCRM
- [ ] ``test-lab-12-05.sh`` DMS-link assertion exits 0
"@
  }

  @{
    id        = "INT-15"
    category  = "business"
    title     = "Integration: Odoo <-> FreeIPA (employee directory sync)"
    repo      = "it-stack-odoo"
    labels    = "integration,module-01,module-13,phase-3,business,priority-med,status-todo"
    milestone = "Phase 3: Back Office"
    body      = @"
## INT-15: Odoo <-> FreeIPA (Employee Directory Sync)

**Type:** HR directory sync
**Services:** Odoo (``lab-biz1``) <- FreeIPA (``lab-id1``)
**Protocol:** LDAP (read-only) + Odoo XML-RPC write
**Phase:** 3 -- Back Office

### Overview

Odoo HR module maintains an Employee list. Rather than dual-entry, a sync job
reads FreeIPA LDAP and creates/updates Odoo ``hr.employee`` records from user
attributes (name, email, job title, department, manager).

### Implementation Steps

- [ ] Create FreeIPA service account: ``uid=odoo-svc,cn=sysaccounts,...``
- [ ] Write sync script ``/opt/it-stack/integrations/freeipa-odoo-hr-sync.py``:
  - LDAP search: ``(objectClass=inetOrgPerson)`` in ``cn=users,cn=accounts,...``
  - Map LDAP attributes: ``uid`` -> job position, ``mail`` -> work email,
    ``cn`` -> name, ``title`` -> job title, ``departmentNumber`` -> department
  - Odoo XML-RPC: ``search_read`` + ``write`` + ``create`` on ``hr.employee``
  - Match on email address to avoid duplicates
- [ ] Schedule via systemd timer: daily at 02:00
- [ ] Add home phone / mobile from ``telephoneNumber`` / ``mobile`` LDAP attrs
- [ ] Ansible task: ``roles/odoo/tasks/freeipa-hr-sync.yml``

### Acceptance Criteria

- [ ] New FreeIPA user appears in Odoo HR within 24 hours (or manual sync)
- [ ] Name/email changes in FreeIPA update Odoo employee record on next sync
- [ ] Terminated user (disabled in FreeIPA) archived (not deleted) in Odoo HR
- [ ] ``test-lab-13-05.sh`` HR sync assertion exits 0
"@
  }

  @{
    id        = "INT-16"
    category  = "business"
    title     = "Integration: Odoo <-> Taiga (time tracking export)"
    repo      = "it-stack-odoo"
    labels    = "integration,module-13,module-15,phase-4,business,priority-med,status-todo"
    milestone = "Phase 4: IT Management"
    body      = @"
## INT-16: Odoo <-> Taiga (Time Tracking Export to ERP)

**Type:** Timesheet sync
**Services:** Taiga (``lab-mgmt1``) -> Odoo (``lab-biz1``)
**Protocol:** Taiga REST API -> Odoo XML-RPC
**Phase:** 4 -- IT Management

### Overview

Time logged against Taiga user stories and tasks (via the Taiga timetracking
feature or contrib timelog module) is exported to Odoo Timesheets for billable
hours tracking and project cost reporting.

### Implementation Steps

- [ ] Enable Taiga timelog module / contrib ``taiga-contrib-timeline`` 
- [ ] Write export script ``/opt/it-stack/integrations/taiga-odoo-timelog.py``:
  - GET ``/api/v1/timelog/list?project={id}`` for each active Taiga project
  - Map Taiga user -> Odoo employee (by username/email)
  - Map Taiga project -> Odoo project analytic account
  - POST to ``account.analytic.line`` in Odoo (hourly timesheet entry)
  - Track last-exported timestamp to avoid re-importing entries
- [ ] Schedule via systemd timer: nightly at 01:00
- [ ] Ansible task: ``roles/odoo/tasks/taiga-timelog.yml``

### Acceptance Criteria

- [ ] Time logged in Taiga appears in Odoo Timesheets the following morning
- [ ] Correct employee and project mapped on each entry
- [ ] Re-running export does not create duplicate timesheet lines
- [ ] ``test-lab-13-05.sh`` timesheet sync assertion exits 0
"@
  }

  @{
    id        = "INT-17"
    category  = "business"
    title     = "Integration: Odoo <-> Snipe-IT (asset procurement flow)"
    repo      = "it-stack-odoo"
    labels    = "integration,module-13,module-16,phase-4,business,priority-med,status-todo"
    milestone = "Phase 4: IT Management"
    body      = @"
## INT-17: Odoo <-> Snipe-IT (Asset Procurement Flow)

**Type:** Procurement -> asset registry
**Services:** Odoo (``lab-biz1``) -> Snipe-IT (``lab-mgmt1``)
**Protocol:** Odoo XML-RPC -> Snipe-IT REST API
**Phase:** 4 -- IT Management

### Overview

When a Purchase Order for hardware/assets is confirmed in Odoo, the items
are automatically created as assets in Snipe-IT. This closes the loop between
procurement (Odoo) and asset management (Snipe-IT).

### Implementation Steps

- [ ] Create Snipe-IT API token for Odoo integration user
- [ ] Write Odoo server action / automated action triggered on ``purchase.order`` state = ``purchase``:
  - For each PO line where product category = ``IT Assets``:
    - POST to Snipe-IT ``/api/v1/hardware``: asset name, model, purchase price, purchase date, supplier
    - Store Snipe-IT asset ID in Odoo PO line custom field ``snipeit_asset_id``
- [ ] Create Odoo product category: ``IT Assets`` with ``asset_category_id`` set
- [ ] Map Odoo supplier -> Snipe-IT Supplier (sync if needed)
- [ ] Ansible task: ``roles/odoo/tasks/snipeit-procurement.yml``
- [ ] Store Snipe-IT API token in Ansible Vault

### Acceptance Criteria

- [ ] PO confirmed in Odoo with IT Asset line creates asset in Snipe-IT within 2 min
- [ ] Asset created with correct model, purchase price, date, and supplier
- [ ] Re-processing the same PO does not create duplicate assets (idempotent)
- [ ] ``test-lab-13-05.sh`` procurement sync assertion exits 0
"@
  }

  @{
    id        = "INT-18"
    category  = "business"
    title     = "Integration: Taiga <-> Mattermost (project notifications)"
    repo      = "it-stack-taiga"
    labels    = "integration,module-07,module-15,phase-4,it-management,priority-med,status-todo"
    milestone = "Phase 4: IT Management"
    body      = @"
## INT-18: Taiga <-> Mattermost (Project Notifications via Webhook)

**Type:** Webhook notifications
**Services:** Taiga (``lab-mgmt1``) -> Mattermost (``lab-app1``)
**Protocol:** Taiga webhooks -> Mattermost incoming webhook
**Phase:** 4 -- IT Management

### Overview

Taiga fires webhooks for project activity (issue created, sprint started,
task assigned, story moved to Done). These are posted as formatted messages
to the relevant Mattermost ``#dev-*`` channel via incoming webhooks.

### Implementation Steps

- [ ] Mattermost Admin: create Incoming Webhook for each team channel:
  - ``#dev-notifications`` (default catch-all)
  - ``#sprint-board`` (sprint activity)
- [ ] Taiga Admin -> Project -> Integrations -> Webhooks: add Mattermost URL
- [ ] Write Taiga webhook forwarder (optional -- Taiga webhooks are raw JSON):
  - Lightweight Python Flask app ``/opt/it-stack/integrations/taiga-mm-webhook.py``
  - Formats Taiga payload into Mattermost attachment with color, title, link
  - Events handled: ``userstory.create``, ``userstory.change``, ``task.create``,
    ``sprint.create``, ``issue.create``
- [ ] Deploy forwarder as systemd service on ``lab-mgmt1``
- [ ] Configure event filter: only notify on specific event types (avoid noise)
- [ ] Ansible task: ``roles/taiga/tasks/mattermost-webhook.yml``

### Acceptance Criteria

- [ ] Creating a Taiga story posts a message to ``#dev-notifications``
- [ ] Sprint activation posts sprint start summary to ``#sprint-board``
- [ ] Message format includes: project name, story title, assignee, link
- [ ] High-priority issues trigger @here mention
- [ ] ``test-lab-15-05.sh`` webhook assertion exits 0
"@
  }

  @{
    id        = "INT-19"
    category  = "business"
    title     = "Integration: Snipe-IT <-> GLPI (asset registry sync)"
    repo      = "it-stack-snipeit"
    labels    = "integration,module-16,module-17,phase-4,it-management,priority-med,status-todo"
    milestone = "Phase 4: IT Management"
    body      = @"
## INT-19: Snipe-IT <-> GLPI (Asset Registry Sync to CMDB)

**Type:** Asset -> CMDB sync
**Services:** Snipe-IT (``lab-mgmt1``) <-> GLPI (``lab-mgmt1``)
**Protocol:** Snipe-IT REST API -> GLPI REST API
**Phase:** 4 -- IT Management

### Overview

Snipe-IT is the asset tracking master (physical hardware, purchase info, checkout).
GLPI is the ITSM/CMDB master (configuration items, service relationships, incident links).
Assets in Snipe-IT sync to GLPI as Configuration Items (CI) so incidents and
changes in GLPI can be linked to specific hardware.

### Implementation Steps

- [ ] Map Snipe-IT asset categories -> GLPI CI types
- [ ] Write sync script ``/opt/it-stack/integrations/snipeit-glpi-sync.py``:
  - GET ``/api/v1/hardware`` from Snipe-IT (paginated)
  - For each asset: create or update GLPI Computer/Device CI via GLPI API
  - Map: serial number, model, location, assigned user, purchase date
  - Store Snipe-IT ID in GLPI CI custom field ``snipeit_id`` for dedup
  - Sync checkout status -> GLPI CI user assignment
- [ ] Schedule: hourly via systemd timer
- [ ] Ansible task: ``roles/snipeit/tasks/glpi-sync.yml``

### Acceptance Criteria

- [ ] New asset in Snipe-IT appears in GLPI CMDB within 1 hour
- [ ] Asset checkout in Snipe-IT updates assigned user in GLPI CI
- [ ] Retired assets (in Snipe-IT) archived in GLPI (not deleted)
- [ ] ``test-lab-16-05.sh`` CMDB sync assertion exits 0
"@
  }

  @{
    id        = "INT-20"
    category  = "business"
    title     = "Integration: GLPI <-> Zammad (ticket escalation)"
    repo      = "it-stack-glpi"
    labels    = "integration,module-11,module-17,phase-4,it-management,priority-med,status-todo"
    milestone = "Phase 4: IT Management"
    body      = @"
## INT-20: GLPI <-> Zammad (Ticket Escalation)

**Type:** Ticket escalation bridge
**Services:** GLPI (``lab-mgmt1``) <-> Zammad (``lab-comm1``)
**Protocol:** GLPI REST API + Zammad REST API (bidirectional)
**Phase:** 4 -- IT Management

### Overview

GLPI handles internal IT change management and incidents. Zammad handles
customer-facing help desk tickets. When an issue escalates from customer
(Zammad) to infrastructure/change management (GLPI), or when a GLPI major
incident needs customer notification (Zammad), the two systems exchange data.

### Scenarios

1. **Escalation up:** Zammad ticket tagged ``needs-change`` -> creates GLPI Change request
2. **Major incident:** GLPI incident severity=Critical -> creates Zammad ticket for customer comms
3. **Resolution sync:** GLPI ticket closed -> updates Zammad ticket status

### Implementation Steps

**Zammad -> GLPI (escalation):**
- [ ] Zammad trigger: when tag ``escalate-to-glpi`` added to ticket
- [ ] Webhook fires to escalation forwarder: ``POST /api/v1/webhooks/zammad``
- [ ] Forwarder creates GLPI ticket (type: Problem) via ``POST /apirest.php/Ticket``
- [ ] Store GLPI ticket ID in Zammad ticket custom field

**GLPI -> Zammad (major incident):**
- [ ] GLPI API rule/webhook on Ticket priority = ``Very High``
- [ ] Creates Zammad ticket with group ``Incident,`` pre-populated KB article link

**Sync:**
- [ ] GLPI ticket close -> PATCH Zammad ticket state to ``closed``
- [ ] Write forwarder service ``/opt/it-stack/integrations/glpi-zammad-bridge.py``
- [ ] Ansible task: ``roles/glpi/tasks/zammad-bridge.yml``

### Acceptance Criteria

- [ ] Escalation from Zammad creates linked GLPI ticket within 1 minute
- [ ] GLPI critical incident creates Zammad ticket with correct group and priority
- [ ] Closure in GLPI closes corresponding Zammad ticket
- [ ] ``test-lab-17-05.sh`` escalation assertion exits 0
"@
  }

  @{
    id        = "INT-21"
    category  = "business"
    title     = "Integration: OpenKM <-> Nextcloud (document storage backend)"
    repo      = "it-stack-openkm"
    labels    = "integration,module-06,module-14,phase-3,business,priority-med,status-todo"
    milestone = "Phase 3: Back Office"
    body      = @"
## INT-21: OpenKM <-> Nextcloud (Document Storage Backend)

**Type:** Document repository integration
**Services:** OpenKM (``lab-biz1:8080``) <-> Nextcloud (``lab-app1``)
**Protocol:** OpenKM REST API + Nextcloud WebDAV / REST API
**Phase:** 3 -- Back Office

### Overview

OpenKM is the formal Document Management System (versioning, workflow, approval).
Nextcloud is the everyday file sharing and collaboration platform.

The integration makes approved OpenKM documents accessible in Nextcloud (read-only
shared folder) and allows users to submit files from Nextcloud into OpenKM for
formal document processing/approval.

### Implementation Steps

**OpenKM -> Nextcloud (approved docs publish):**
- [ ] Write script ``/opt/it-stack/integrations/openkm-nextcloud-publish.py``:
  - Queries OpenKM for documents in ``/Published`` category (approved)
  - Downloads and places in Nextcloud shared folder ``/Company Documents`` via WebDAV
  - Preserves folder structure and metadata
  - Runs every 15 minutes via systemd timer

**Nextcloud -> OpenKM (submission):**
- [ ] Nextcloud ``External Sites`` or app plugin: "Submit to DMS" button
  - Calls OpenKM REST API: ``POST /services/rest/document/create``
  - Places document in OpenKM ``/Inbox`` for review workflow
- [ ] Alternatively: Nextcloud External Storage pointing to OpenKM WebDAV endpoint

**Ansible:**
- [ ] Task: ``roles/openkm/tasks/nextcloud-bridge.yml``
- [ ] Task: ``roles/nextcloud/tasks/openkm-external-storage.yml``

### Acceptance Criteria

- [ ] Approved OpenKM document appears in Nextcloud ``/Company Documents`` within 15 min
- [ ] User can submit a file from Nextcloud to OpenKM inbox via the integration
- [ ] File metadata (author, date, version) preserved in both systems
- [ ] ``test-lab-14-05.sh`` document bridge assertion exits 0
"@
  }

  @{
    id        = "INT-22"
    category  = "business"
    title     = "Integration: Zabbix <-> Mattermost (infrastructure alerts)"
    repo      = "it-stack-zabbix"
    labels    = "integration,module-07,module-19,phase-4,infrastructure,priority-high,status-todo"
    milestone = "Phase 4: IT Management"
    body      = @"
## INT-22: Zabbix <-> Mattermost (Infrastructure Alerts to #ops-alerts)

**Type:** Monitoring alerting
**Services:** Zabbix (``lab-comm1``) -> Mattermost (``lab-app1``)
**Protocol:** Zabbix media type (webhook) -> Mattermost incoming webhook
**Phase:** 4 -- IT Management

### Overview

Zabbix sends Problem, Recovery, and Acknowledgement alerts to the Mattermost
``#ops-alerts`` channel. Messages are colour-coded by severity and include
host, trigger, and runbook links.

### Implementation Steps

- [ ] Mattermost: create Incoming Webhook for ``#ops-alerts`` channel
- [ ] Zabbix Admin -> Alerts -> Media Types: import or create "Mattermost" media type
  - Use community Zabbix-Mattermost webhook script (``mattermost.js`` or Python CGI)
  - Parameters: ``webhook_url``, ``channel``, ``bot_username``, ``severity_colours``
- [ ] Zabbix: create Alert Action -> "Notify Mattermost":
  - Condition: Trigger severity >= Warning
  - Operations: Send message via "Mattermost" media type to user/group
- [ ] Configure problem and recovery message templates with:
  - Severity emoji (DISASTER = 🔴, HIGH = 🟠, AVERAGE = 🟡, WARNING = 🔵)
  - Host name, trigger name, current value
  - Zabbix dashboard link
  - Runbook URL (from trigger URL field)
- [ ] Add Recovery actions (green OK message on resolve)
- [ ] Add Acknowledgement actions
- [ ] Ansible task: ``roles/zabbix/tasks/mattermost-alerts.yml``
- [ ] Store Mattermost webhook URL in Ansible Vault

### Acceptance Criteria

- [ ] Zabbix test alert appears in Mattermost ``#ops-alerts`` within 30 seconds
- [ ] Message contains: severity, host, trigger, current value, timestamp
- [ ] Recovery message (green) posted when trigger resolves
- [ ] Acknowledged alerts show ACK author and comment
- [ ] ``test-lab-19-05.sh`` alerting assertion exits 0
"@
  }

  @{
    id        = "INT-23"
    category  = "business"
    title     = "Integration: Graylog <-> Zabbix (log-based alert triggers)"
    repo      = "it-stack-graylog"
    labels    = "integration,module-19,module-20,phase-4,infrastructure,priority-med,status-todo"
    milestone = "Phase 4: IT Management"
    body      = @"
## INT-23: Graylog <-> Zabbix (Log-Based Alert Triggers)

**Type:** Observability integration
**Services:** Graylog (``lab-proxy1:9000``) -> Zabbix (``lab-comm1``)
**Protocol:** Graylog Event Notification -> Zabbix external check / HTTP item
**Phase:** 4 -- IT Management

### Overview

Zabbix monitors infrastructure metrics (CPU, disk, network). Graylog monitors
log patterns (error rates, security events, application crashes). When Graylog
detects a significant log pattern (e.g., 50+ auth failures in 5 min, application
ERROR spike), it triggers a Zabbix event so alerting and escalation are centralised
in Zabbix / Mattermost rather than having two alert systems.

### Approach: Graylog -> Zabbix via HTTP sender

Graylog Event Notification (webhook) -> lightweight receiver on Zabbix server
that creates a Zabbix problem event via ``zabbix_sender``.

### Implementation Steps

- [ ] Write Zabbix receiver script ``/opt/it-stack/integrations/graylog-zabbix-bridge.py``:
  - Flask HTTP endpoint ``POST /zabbix-event``
  - Parses Graylog event JSON: ``event_definition_title``, ``severity``, ``stream``
  - Calls ``zabbix_sender -z lab-comm1 -s "Graylog" -k graylog.alert -o "{title}:{severity}"``
  - Deploys as systemd service on ``lab-proxy1``
- [ ] Zabbix: create host ``Graylog`` with Trapper item ``graylog.alert``
- [ ] Create Zabbix trigger on ``graylog.alert``: value != "" -> Problem
- [ ] Link Zabbix trigger to INT-22 alert action (Mattermost notification)
- [ ] Graylog: create Event Definitions for key patterns:
  - ``AuthFailure``: > 50 SSH/LDAP auth failures in 5 min (severity: HIGH)
  - ``AppErrorSpike``: > 100 ERROR messages per service in 1 min (severity: AVERAGE)
  - ``DiskFull``: kernel messages containing "No space left" (severity: DISASTER)
- [ ] Create Graylog Notification for each event -> HTTP webhook -> Zabbix receiver
- [ ] Ansible task: ``roles/graylog/tasks/zabbix-bridge.yml``

### Acceptance Criteria

- [ ] Simulated auth failure spike in Graylog creates Zabbix problem event within 60 sec
- [ ] Zabbix problem triggers Mattermost alert (via INT-22 chain)
- [ ] Problem recovers in Zabbix when Graylog event resolves / 30 min timeout
- [ ] Receiver service restarts automatically on crash (systemd Restart=on-failure)
- [ ] ``test-lab-20-05.sh`` log-alert chain assertion exits 0
"@
  }

)

# ─── Filtering ────────────────────────────────────────────────────────────────
$targets = $integrations

if ($Category -ne "") {
  $targets = $targets | Where-Object { $_.category -eq $Category }
}
if ($Id -ne "") {
  $targets = $targets | Where-Object { $_.id -eq $Id }
}

if ($targets.Count -eq 0) {
  Write-Host "No matching integrations found." -ForegroundColor Yellow
  exit 0
}

Write-Host ""
Write-Host "IT-Stack Integration Issues" -ForegroundColor Cyan
Write-Host "  Org      : $Org" -ForegroundColor DarkGray
Write-Host "  Category : $(if ($Category) { $Category } else { 'all' })" -ForegroundColor DarkGray
Write-Host "  Filter   : $(if ($Id) { $Id } else { 'all' })" -ForegroundColor DarkGray
Write-Host "  Total    : $($targets.Count)" -ForegroundColor DarkGray
Write-Host ""

$created = 0
$failed  = 0

foreach ($integ in $targets) {
  $repoName = "it-stack-$($integ.repo -replace '^it-stack-','')"

  $result = gh issue create `
    --repo      "$Org/$repoName" `
    --title     $integ.title `
    --body      $integ.body `
    --label     $integ.labels `
    --milestone $integ.milestone 2>&1

  if ($LASTEXITCODE -eq 0) {
    Write-Host "  [+] $($integ.id) -- $($integ.title)" -ForegroundColor DarkGray
    $created++
  } else {
    Write-Host "  [!] $($integ.id) -- $($integ.title)" -ForegroundColor Yellow
    Write-Host "      $result" -ForegroundColor DarkGray
    $failed++
  }
  Start-Sleep -Milliseconds 400
}

Write-Host ""
Write-Host "Integration issues -- Created: $created  |  Errors: $failed" -ForegroundColor Cyan
