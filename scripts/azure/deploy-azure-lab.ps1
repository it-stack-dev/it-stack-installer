<#
.SYNOPSIS
    Deploys the IT-Stack lab environment on Azure.

.DESCRIPTION
    Three lab profiles matching the recommended deployment progression:

      -Profile Phase1
          Standard_D8s_v4  (8 vCPU / 32 GB RAM)    ~$3/day @ 8hrs
          Single VM . Labs 01-03 . Phase 1 modules (FreeIPA, Keycloak, PostgreSQL, Redis, Traefik)
          Ideal for: first-time setup, Azure Student credit, learning Phase 1

      -Profile FullStack
          Standard_E16s_v4 (16 vCPU / 128 GB RAM)   ~$8/day @ 8hrs
          Single VM . All 20 modules . Labs 01-05
          Ideal for: running all phases end-to-end, integration testing

      -Profile Lab06HA
          8-VM cluster mirroring production layout    ~$16/day @ 8hrs
          Labs 01-06 . Full HA, Ansible, production playbooks
          Ideal for: Lab 06 production deployment, Ansible testing, DR drills

    The script is idempotent - safe to re-run. Existing resources are skipped.

.PARAMETER Profile
    Phase1 | FullStack | Lab06HA

.PARAMETER ResourceGroup
    Azure resource group name.
    Defaults: rg-it-stack-phase1 | rg-it-stack-fullstack | rg-it-stack-lab06

.PARAMETER Location
    Azure region (default: westus2 - compatible with Azure for Students policy)

.PARAMETER AdminUser
    SSH admin username on all VMs (default: itstack)

.PARAMETER SshPublicKeyPath
    Path to your SSH public key file (default: ~/.ssh/id_rsa.pub on Linux/macOS,
    ~\.ssh\id_rsa.pub on Windows). Auto-generates a key if none exists.

.PARAMETER Mode
    Legacy alias kept for backward compatibility (Phase1=SingleVM, Lab06HA=MultiVM).
    Prefer -Profile Phase1|FullStack|Lab06HA.

.PARAMETER AutoShutdownTime
    Daily auto-shutdown in HHmm 24hr UTC (default: 2200).
    Set to empty string "" to disable auto-shutdown.

.PARAMETER DryRun
    Print the full deployment plan without creating any Azure resources.

.EXAMPLE
    # Phase 1 - cheapest, good for learning (Azure Student recommended start)
    .\deploy-azure-lab.ps1 -Profile Phase1

    # Full stack test - all 20 modules on one big VM
    .\deploy-azure-lab.ps1 -Profile FullStack

    # Lab 06 HA - full 8-VM production replica
    .\deploy-azure-lab.ps1 -Profile Lab06HA

    # Preview what would be created
    .\deploy-azure-lab.ps1 -Profile FullStack -DryRun

    # Custom resource group and region
    .\deploy-azure-lab.ps1 -Profile Phase1 -ResourceGroup my-rg -Location westus2
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("Phase1","FullStack","Lab06HA","")]
    [string]$Profile = "",

    # Legacy -Mode alias (SingleVM -> Phase1, MultiVM -> Lab06HA)
    [Parameter(Mandatory=$false)]
    [ValidateSet("SingleVM","MultiVM","")]
    [string]$Mode = "",

    [string]$ResourceGroup    = "",
    [string]$Location         = "westus2",
    [string]$AdminUser        = "itstack",
    [string]$SshPublicKeyPath = "",
    [string]$AutoShutdownTime = "2200",
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# --- Backward-compat: map -Mode to -Profile -----------------------------------
if ($Mode -and -not $Profile) {
    Write-Warning "-Mode is deprecated. Use -Profile Phase1|FullStack|Lab06HA instead."
    $Profile = if ($Mode -eq "SingleVM") { "Phase1" } else { "Lab06HA" }
    Write-Warning "Mapped -Mode $Mode  ->  -Profile $Profile"
}
if (-not $Profile) {
    Write-Host "Usage: .\deploy-azure-lab.ps1 -Profile <Phase1|FullStack|Lab06HA>" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  -Profile Phase1    Standard_D8s_v4 single VM  ~`$3/day   Labs 01-03" -ForegroundColor Cyan
    Write-Host "  -Profile FullStack  Standard_E16s_v4 single VM ~`$8/day   Labs 01-05" -ForegroundColor Cyan
    Write-Host "  -Profile Lab06HA    8-VM cluster               ~`$16/day  Labs 01-06" -ForegroundColor Cyan
    throw "Missing required parameter: -Profile"
}

# --- Cross-platform SSH key default path --------------------------------------
# $IsWindows is PS6+ only; use $env:OS which works on all versions
if (-not $SshPublicKeyPath) {
    $SshPublicKeyPath = if ($env:OS -eq 'Windows_NT') {
        Join-Path (Join-Path $HOME '.ssh') 'id_rsa.pub'
    } else {
        "$HOME/.ssh/id_rsa.pub"
    }
}

# --- Colour helpers -----------------------------------------------------------
function Write-Step { param($m) Write-Host "`n>> $m" -ForegroundColor Cyan }
function Write-OK   { param($m) Write-Host "  [OK] $m" -ForegroundColor Green }
function Write-Warn { param($m) Write-Host "  [!] $m" -ForegroundColor Yellow }
function Write-Info { param($m) Write-Host "  . $m" -ForegroundColor Gray }
function Write-Dry  { param($m) Write-Host "  [DRY-RUN] $m" -ForegroundColor Magenta }

# --- Profile definitions ------------------------------------------------------
$Profiles = @{
    Phase1 = @{
        Description   = "Phase 1 - Foundation (Labs 01-03, Phase 1 modules)"
        Mode          = "SingleVM"
        VMSize        = "Standard_D8s_v4"
        OsDiskGB      = 64
        DailyEst      = '~$3/day @ 8hrs'
        RGDefault     = "rg-it-stack-phase1"
        Modules       = @("freeipa","keycloak","postgresql","redis","traefik")
        LabsSupported = "Labs 01-03"
    }
    FullStack = @{
        Description   = "Full Stack - All 20 modules (Labs 01-05)"
        Mode          = "SingleVM"
        VMSize        = "Standard_E16s_v4"
        OsDiskGB      = 128
        DailyEst      = '~$8/day @ 8hrs'
        RGDefault     = "rg-it-stack-fullstack"
        Modules       = @("all")
        LabsSupported = "Labs 01-05"
    }
    Lab06HA = @{
        Description   = "Lab 06 - Production HA (8-VM cluster, all labs)"
        Mode          = "MultiVM"
        VMSize        = ""
        OsDiskGB      = 64
        DailyEst      = '~$16/day @ 8hrs'
        RGDefault     = "rg-it-stack-lab06"
        Modules       = @("all")
        LabsSupported = "Labs 01-06"
    }
}

$P = $Profiles[$Profile]
if (-not $ResourceGroup) { $ResourceGroup = $P.RGDefault }

# --- 8-VM cluster layout (Lab06HA) --------------------------------------------
$MultiVMLayout = @(
    @{ Name="lab-id1";    IP="10.0.50.11"; Size="Standard_D4s_v4";  DiskGB=64;  Role="FreeIPA, Keycloak";                PublicIP=$false }
    @{ Name="lab-db1";    IP="10.0.50.12"; Size="Standard_E8s_v4";  DiskGB=100; Role="PostgreSQL, Redis, Elasticsearch"; PublicIP=$false }
    @{ Name="lab-app1";   IP="10.0.50.13"; Size="Standard_D8s_v4";  DiskGB=128; Role="Nextcloud, Mattermost, Jitsi";     PublicIP=$false }
    @{ Name="lab-comm1";  IP="10.0.50.14"; Size="Standard_D4s_v4";  DiskGB=64;  Role="iRedMail, Zammad, Zabbix";         PublicIP=$false }
    @{ Name="lab-proxy1"; IP="10.0.50.15"; Size="Standard_D2s_v4";  DiskGB=64;  Role="Traefik, Graylog";                 PublicIP=$true  }
    @{ Name="lab-pbx1";   IP="10.0.50.16"; Size="Standard_D2s_v4";  DiskGB=64;  Role="FreePBX";                          PublicIP=$false }
    @{ Name="lab-biz1";   IP="10.0.50.17"; Size="Standard_D8s_v4";  DiskGB=100; Role="SuiteCRM, Odoo, OpenKM";           PublicIP=$false }
    @{ Name="lab-mgmt1";  IP="10.0.50.18"; Size="Standard_D4s_v4";  DiskGB=64;  Role="Taiga, Snipe-IT, GLPI";            PublicIP=$false }
)

$VNetName   = "vnet-it-stack-lab"
$SubnetName = "snet-servers"
$NsgName    = "nsg-it-stack-lab"
$VNetPrefix = "10.0.50.0/24"
$DnsZone    = "lab.it-stack.local"

# --- Pre-flight checks --------------------------------------------------------
Write-Step "Pre-flight checks"

if ($DryRun) {
    Write-Info "DryRun mode - skipping Azure CLI and login checks"
} else {
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        throw "Azure CLI not found. Install: https://aka.ms/installazurecliwindows"
    }
    Write-OK "Azure CLI: $(az version --query '\"azure-cli\"' -o tsv 2>$null)"

    $loginCheck = az account show --query "id" -o tsv 2>$null
    if (-not $loginCheck) {
        Write-Warn "Not logged in - running az login..."
        az login
    }
    $sub = az account show --query "{name:name,id:id}" -o json | ConvertFrom-Json
    Write-OK "Subscription: $($sub.name) [$($sub.id)]"
}

if (-not (Test-Path $SshPublicKeyPath)) {
    Write-Warn "SSH key not found at $SshPublicKeyPath - generating..."
    if (-not $DryRun) {
        # Build key path using the platform path separator
        $keyBase = $SshPublicKeyPath -replace [regex]::Escape('.pub'), ''
        $keyDir  = Split-Path $keyBase -Parent
        if ($keyDir -and (-not (Test-Path $keyDir))) {
            New-Item -ItemType Directory -Path $keyDir -Force | Out-Null
        }
        try {
            # Empty passphrase: use bare "" (not '""' which passes literal double-quotes)
            ssh-keygen -t rsa -b 4096 -f $keyBase -N ""
        } catch {
            Write-Warn "ssh-keygen failed: $_"
            Write-Warn "You can generate a key manually: ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa"
        }
    }
}
$SshPublicKey = if (Test-Path $SshPublicKeyPath) {
    Get-Content $SshPublicKeyPath -Raw
} else {
    if (-not $DryRun) { Write-Warn "SSH public key not found - deploy will fail. Generate one first." }
    "DRY-RUN-KEY"
}
Write-OK "SSH key: $SshPublicKeyPath"

# --- Print plan ---------------------------------------------------------------
Write-Step "Deployment plan"
Write-Host ""
Write-Host "  Profile       : $Profile" -ForegroundColor White
Write-Host "  Description   : $($P.Description)"
Write-Host "  Cost estimate : $($P.DailyEst)"
Write-Host "  Labs covered  : $($P.LabsSupported)"
Write-Host "  Resource Group: $ResourceGroup"
Write-Host "  Location      : $Location"
Write-Host "  Admin user    : $AdminUser"
Write-Host "  Auto-shutdown : $(if ($AutoShutdownTime) { $AutoShutdownTime + ' UTC' } else { 'disabled' })"
Write-Host ""

if ($P.Mode -eq "SingleVM") {
    Write-Host "  VM layout:" -ForegroundColor White
    Write-Host "    lab-single    10.0.50.10   $($P.VMSize.PadRight(20))   All services via Docker Compose"
    Write-Host "    OS disk:      $($P.OsDiskGB) GB"
} else {
    Write-Host "  VM layout (8-server cluster):" -ForegroundColor White
    foreach ($vm in $MultiVMLayout) {
        $pip = if ($vm.PublicIP) { " ← public IP" } else { "" }
        Write-Host "    $($vm.Name.PadRight(12)) $($vm.IP)   $($vm.Size.PadRight(20))  $($vm.DiskGB) GB   $($vm.Role)$pip"
    }
}
Write-Host ""

if ($DryRun) {
    Write-Dry "No resources will be created (dry run). Remove -DryRun to deploy."
    return
}

# --- Resource Group -----------------------------------------------------------
Write-Step "Resource group: $ResourceGroup"
$rgExists = az group exists --name $ResourceGroup | ConvertFrom-Json
if (-not $rgExists) {
    az group create --name $ResourceGroup --location $Location --output none
    if ($LASTEXITCODE -ne 0) { throw "[ERROR] Failed to create resource group '$ResourceGroup' in '$Location'" }
    Write-OK "Created"
} else {
    Write-OK "Already exists"
}

# --- NSG ----------------------------------------------------------------------
Write-Step "Network security group: $NsgName"
$nsgExists = az network nsg show --resource-group $ResourceGroup --name $NsgName `
    --query "name" -o tsv 2>$null
if (-not $nsgExists) {
    az network nsg create --resource-group $ResourceGroup --name $NsgName `
        --location $Location --output none
    if ($LASTEXITCODE -ne 0) { throw "[ERROR] Failed to create NSG '$NsgName' - region '$Location' may be restricted for this subscription" }

    $nsgRules = @(
        @{ Name="Allow-SSH";           Priority=100; Ports=@("22");                                              Desc="SSH access" }
        @{ Name="Allow-VNet-Internal"; Priority=200; Ports=@("*"); Source="VirtualNetwork";                     Desc="VNet internal traffic" }
        @{ Name="Allow-HTTP-HTTPS";    Priority=300; Ports=@("80","443");                                        Desc="Web traffic" }
        @{ Name="Allow-Lab-Ports";     Priority=400; Ports=@("8080","8443","8065","8069","9000","3000","5601");  Desc="Lab service ports" }
        @{ Name="Allow-Mail";          Priority=500; Ports=@("25","143","587","993");                            Desc="Email (iRedMail)" }
        @{ Name="Allow-VoIP";          Priority=600; Ports=@("5060","5061");                                     Desc="SIP/VoIP (FreePBX)" }
    )
    foreach ($r in $nsgRules) {
        $src = if ($r['Source']) { $r['Source'] } else { "*" }
        az network nsg rule create `
            --resource-group $ResourceGroup --nsg-name $NsgName `
            --name $r.Name --priority $r.Priority --direction Inbound --access Allow `
            --protocol Tcp --source-address-prefixes $src `
            --destination-address-prefixes "*" `
            --destination-port-ranges $r.Ports `
            --output none
    }
    Write-OK "NSG created with SSH + web + mail + VoIP + VNet rules"
} else {
    Write-OK "Already exists"
}

# --- VNet + Subnet ------------------------------------------------------------
Write-Step "Virtual network: $VNetName ($VNetPrefix)"
$vnetExists = az network vnet show --resource-group $ResourceGroup --name $VNetName `
    --query "name" -o tsv 2>$null
if (-not $vnetExists) {
    az network vnet create `
        --resource-group $ResourceGroup --name $VNetName --location $Location `
        --address-prefix $VNetPrefix --subnet-name $SubnetName --subnet-prefix $VNetPrefix `
        --output none
    if ($LASTEXITCODE -ne 0) { throw "[ERROR] Failed to create VNet '$VNetName'" }
    az network vnet subnet update `
        --resource-group $ResourceGroup --vnet-name $VNetName --name $SubnetName `
        --network-security-group $NsgName --output none
    Write-OK "Created"
} else {
    Write-OK "Already exists"
}

# --- VM creation function -----------------------------------------------------
function New-LabVM {
    param(
        [string]$VmName,
        [string]$PrivateIp,
        [string]$Size,
        [int]$DiskGB,
        [string]$Role,
        [bool]$AddPublicIp = $false
    )

    $exists = az vm show --resource-group $ResourceGroup --name $VmName `
        --query "name" -o tsv 2>$null
    if ($exists) {
        Write-OK "$VmName - already exists, skipping"
        return
    }

    Write-Host "  . Creating $VmName ($Size / ${DiskGB}GB) [$Role]..." -NoNewline -ForegroundColor Gray

    # NIC with static private IP
    $nicName = "nic-$VmName"
    az network nic create `
        --resource-group $ResourceGroup --name $nicName `
        --vnet-name $VNetName --subnet $SubnetName `
        --private-ip-address $PrivateIp `
        --network-security-group $NsgName `
        --output none
    if ($LASTEXITCODE -ne 0) { throw "[ERROR] Failed to create NIC '$nicName' for '$VmName'" }

    # VM (no-wait for parallel provisioning)
    az vm create `
        --resource-group $ResourceGroup --name $VmName --location $Location `
        --size $Size --nics $nicName `
        --image Ubuntu2404 `
        --admin-username $AdminUser `
        --ssh-key-values $SshPublicKey `
        --os-disk-size-gb $DiskGB `
        --storage-sku Premium_LRS `
        --no-wait --output none
    if ($LASTEXITCODE -ne 0) { throw "[ERROR] Failed to submit VM create for '$VmName' (size $Size may be unavailable in '$Location')" }

    # Wait for provisioning to finish
    az vm wait --resource-group $ResourceGroup --name $VmName --created --output none
    if ($LASTEXITCODE -ne 0) { throw "[ERROR] VM '$VmName' failed to reach running state" }

    # Auto-shutdown
    if ($AutoShutdownTime) {
        az vm auto-shutdown `
            --resource-group $ResourceGroup --name $VmName `
            --time $AutoShutdownTime --output none
    }

    # Bootstrap: Docker, Docker Compose v2, Ansible, IT-Stack repos, hostname
    $initScript = @"
#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq curl wget git vim htop net-tools dnsutils jq python3-pip ansible-core
# Docker
curl -fsSL https://get.docker.com | sh
usermod -aG docker $AdminUser
systemctl enable --now docker
# Docker Compose v2
mkdir -p /usr/local/lib/docker/cli-plugins
curl -fsSL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
     -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
# Ansible collections
ansible-galaxy collection install community.general community.crypto ansible.posix 2>/dev/null || true
# Clone IT-Stack repos
cd /home/$AdminUser
git clone https://github.com/it-stack-dev/it-stack-ansible.git   2>/dev/null || true
git clone https://github.com/it-stack-dev/it-stack-installer.git 2>/dev/null || true
chown -R ${AdminUser}:${AdminUser} /home/${AdminUser}/it-stack-*
# Hostname
hostnamectl set-hostname $VmName
echo "" >> /etc/hosts
echo "127.0.1.1  $VmName" >> /etc/hosts
# MOTD
cat > /etc/motd << 'MOTDEOF'
+-----------------------------------------------------------+
|  IT-Stack Lab - $VmName
|  Role : $Role
|  Repos: ~/it-stack-ansible   ~/it-stack-installer
|  Start: cd it-stack-ansible && make help
+-----------------------------------------------------------+
MOTDEOF
"@

    $encoded = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($initScript))
    az vm run-command invoke `
        --resource-group $ResourceGroup --name $VmName `
        --command-id RunShellScript `
        --scripts "echo $encoded | base64 -d | bash" `
        --output none

    # Public IP
    if ($AddPublicIp) {
        az network public-ip create `
            --resource-group $ResourceGroup --name "pip-$VmName" `
            --sku Basic --allocation-method Static --output none 2>$null
        az network nic ip-config update `
            --resource-group $ResourceGroup --nic-name $nicName `
            --name ipconfig1 --public-ip-address "pip-$VmName" --output none
    }

    Write-Host " done." -ForegroundColor Green
}

# --- Deploy VMs ---------------------------------------------------------------
Write-Step "Provisioning VMs (Profile: $Profile)"

if ($P.Mode -eq "SingleVM") {

    New-LabVM -VmName "lab-single" -PrivateIp "10.0.50.10" `
        -Size $P.VMSize -DiskGB $P.OsDiskGB `
        -Role "All IT-Stack services" -AddPublicIp $true

} else {
    # Lab06HA: deploy in dependency order
    $deployOrder = @("lab-id1","lab-db1","lab-proxy1","lab-app1","lab-comm1","lab-pbx1","lab-biz1","lab-mgmt1")
    foreach ($name in $deployOrder) {
        $vm = $MultiVMLayout | Where-Object { $_.Name -eq $name } | Select-Object -First 1
        New-LabVM -VmName $vm.Name -PrivateIp $vm.IP `
            -Size $vm.Size -DiskGB $vm.DiskGB `
            -Role $vm.Role -AddPublicIp $vm.PublicIP
    }
}

# --- Private DNS Zone ---------------------------------------------------------
Write-Step "Private DNS zone: $DnsZone"
$dnsExists = az network private-dns zone show --resource-group $ResourceGroup `
    --name $DnsZone --query "name" -o tsv 2>$null
if (-not $dnsExists) {
    az network private-dns zone create `
        --resource-group $ResourceGroup --name $DnsZone --output none
    az network private-dns link vnet create `
        --resource-group $ResourceGroup --zone-name $DnsZone `
        --name "dns-link-lab" --virtual-network $VNetName `
        --registration-enabled false --output none

    $records = if ($P.Mode -eq "MultiVM") {
        $MultiVMLayout | ForEach-Object { @{Name=$_.Name; IP=$_.IP} }
    } else {
        @(@{Name="lab-single"; IP="10.0.50.10"})
    }

    if ($P.Mode -eq "MultiVM") {
        # Service-name aliases for Traefik host routing inside the VNet
        $records += @(
            @{Name="ipa";      IP="10.0.50.11"}
            @{Name="cloud";    IP="10.0.50.13"}
            @{Name="chat";     IP="10.0.50.13"}
            @{Name="meet";     IP="10.0.50.13"}
            @{Name="mail";     IP="10.0.50.14"}
            @{Name="desk";     IP="10.0.50.14"}
            @{Name="proxy";    IP="10.0.50.15"}
            @{Name="crm";      IP="10.0.50.17"}
            @{Name="erp";      IP="10.0.50.17"}
            @{Name="dms";      IP="10.0.50.17"}
            @{Name="projects"; IP="10.0.50.18"}
            @{Name="assets";   IP="10.0.50.18"}
            @{Name="itsm";     IP="10.0.50.18"}
        )
    }

    foreach ($rec in $records) {
        az network private-dns record-set a add-record `
            --resource-group $ResourceGroup --zone-name $DnsZone `
            --record-set-name $rec.Name --ipv4-address $rec.IP `
            --output none 2>$null
    }
    Write-OK "DNS zone created with $($records.Count) A records"
} else {
    Write-OK "Already exists"
}

# --- Retrieve public IPs ------------------------------------------------------
$pipName  = if ($P.Mode -eq "SingleVM") { "pip-lab-single" }  else { "pip-lab-proxy1" }
$entryVM  = if ($P.Mode -eq "SingleVM") { "lab-single" }      else { "lab-proxy1" }
$PublicIP = az network public-ip show --resource-group $ResourceGroup `
    --name $pipName --query "ipAddress" -o tsv 2>$null

# --- Output summary -----------------------------------------------------------
$bar = "-" * 66
Write-Host ""
Write-Host "+$bar+" -ForegroundColor Green
Write-Host "|  IT-Stack Lab - Profile: $($Profile.PadRight(42))|" -ForegroundColor Green
Write-Host "+$bar+" -ForegroundColor Green
Write-Host "|  Public IP    : $($PublicIP.PadRight(51))|" -ForegroundColor Green
Write-Host "|  SSH access   : ssh $($AdminUser)@$($PublicIP.PadRight(47))|" -ForegroundColor Green
Write-Host "|  Cost est.    : $($P.DailyEst.PadRight(51))|" -ForegroundColor Green
Write-Host "|  Labs covered : $($P.LabsSupported.PadRight(51))|" -ForegroundColor Green
if ($AutoShutdownTime) {
Write-Host "|  Auto-shutdown: $($AutoShutdownTime) UTC daily$(' ' * 43)|" -ForegroundColor Green
}
Write-Host "+$bar+" -ForegroundColor Green

if ($P.Mode -eq "MultiVM") {
    Write-Host "|  8-VM Cluster$(' ' * 53)|" -ForegroundColor Green
    foreach ($vm in $MultiVMLayout) {
        $pip = if ($vm.PublicIP) { " ← entry point" } else { "" }
        Write-Host "|    $($vm.Name.PadRight(12)) $($vm.IP)  $($vm.Role.PadRight(32))$pip  |" -ForegroundColor Green
    }
    Write-Host "+$bar+" -ForegroundColor Green
    Write-Host "|  Jump to other servers:$(' ' * 43)|" -ForegroundColor Green
    Write-Host "|    ssh -J $($AdminUser)@$PublicIP $($AdminUser)@10.0.50.11   (lab-id1)$(' ' * 10)|" -ForegroundColor Green
    Write-Host "|    ssh -J $($AdminUser)@$PublicIP $($AdminUser)@10.0.50.12   (lab-db1)$(' ' * 10)|" -ForegroundColor Green
    Write-Host "+$bar+" -ForegroundColor Green
}

Write-Host "|  NEXT STEPS$(' ' * 55)|" -ForegroundColor Cyan

switch ($Profile) {
    "Phase1" {
        Write-Host "|    ssh $($AdminUser)@$PublicIP$(' ' * (53 - $PublicIP.Length))|" -ForegroundColor Cyan
        Write-Host "|    cd ~/it-stack-installer$(' ' * 41)|" -ForegroundColor Cyan
        Write-Host "|    # Run Phase 1 Docker Compose labs$(' ' * 31)|" -ForegroundColor Cyan
        Write-Host "|    bash tests/labs/01-01-standalone.sh$(' ' * 29)|" -ForegroundColor Cyan
        Write-Host "|    bash tests/labs/02-01-standalone.sh$(' ' * 29)|" -ForegroundColor Cyan
        Write-Host "|    # Or run all Phase 1 labs at once:$(' ' * 30)|" -ForegroundColor Cyan
        Write-Host "|    bash scripts/run-phase1-labs.sh$(' ' * 33)|" -ForegroundColor Cyan
    }
    "FullStack" {
        Write-Host "|    ssh $($AdminUser)@$PublicIP$(' ' * (53 - $PublicIP.Length))|" -ForegroundColor Cyan
        Write-Host "|    cd ~/it-stack-installer$(' ' * 41)|" -ForegroundColor Cyan
        Write-Host "|    # Run all phases sequentially:$(' ' * 35)|" -ForegroundColor Cyan
        Write-Host "|    for phase in 1 2 3 4; do$(' ' * 40)|" -ForegroundColor Cyan
        Write-Host "|      bash scripts/run-phase\${phase}-labs.sh$(' ' * 28)|" -ForegroundColor Cyan
        Write-Host "|    done$(' ' * 60)|" -ForegroundColor Cyan
        Write-Host "|    # Full integration test:$(' ' * 41)|" -ForegroundColor Cyan
        Write-Host "|    bash scripts/test-all-modules.sh$(' ' * 32)|" -ForegroundColor Cyan
    }
    "Lab06HA" {
        Write-Host "|    # From your Ansible control machine:$(' ' * 28)|" -ForegroundColor Cyan
        Write-Host "|    cd it-stack-ansible$(' ' * 45)|" -ForegroundColor Cyan
        Write-Host "|    # Update inventory - set $PublicIP for proxy:$(' ' * (19 - $PublicIP.Length))|" -ForegroundColor Cyan
        Write-Host "|    vim inventory/hosts.ini$(' ' * 41)|" -ForegroundColor Cyan
        Write-Host "|    make harden          # CIS hardening all 8 nodes$(' ' * 15)|" -ForegroundColor Cyan
        Write-Host "|    make tls             # Internal CA + per-host certs$(' ' * 13)|" -ForegroundColor Cyan
        Write-Host "|    make deploy-phase1 && make deploy-phase2$(' ' * 24)|" -ForegroundColor Cyan
        Write-Host "|    make deploy-phase3 && make deploy-phase4$(' ' * 24)|" -ForegroundColor Cyan
        Write-Host "|    make backup-setup    # Install backup crons$(' ' * 20)|" -ForegroundColor Cyan
        Write-Host "|    make smoke-test      # Verify all services up$(' ' * 18)|" -ForegroundColor Cyan
    }
}

Write-Host "+$bar+" -ForegroundColor Yellow
Write-Host "|  COST CONTROL$(' ' * 53)|" -ForegroundColor Yellow
Write-Host "|  Stop VMs (zero compute cost):$(' ' * 36)|" -ForegroundColor Yellow
Write-Host "|    .\teardown-azure-lab.ps1 -StopOnly -ResourceGroup $ResourceGroup$(' ' * (11 - $ResourceGroup.Length))|" -ForegroundColor Yellow
Write-Host "|  Start VMs again:$(' ' * 49)|" -ForegroundColor Yellow
Write-Host "|    .\teardown-azure-lab.ps1 -StartAll -ResourceGroup $ResourceGroup$(' ' * (11 - $ResourceGroup.Length))|" -ForegroundColor YellowWrite-Host "+$bar+" -ForegroundColor YellowWrite-Host "|  Delete everything:$(' ' * 47)|" -ForegroundColor Yellow
