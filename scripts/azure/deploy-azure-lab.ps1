<#
.SYNOPSIS
    Deploys the IT-Stack lab environment on Azure.

.DESCRIPTION
    Supports two modes:
      -Mode SingleVM  : One large VM running all services via Docker Compose (Option B).
                        Cheapest. Good for Labs 01-05. (~$3-8/day depending on size)
      -Mode MultiVM   : Full 8-VM layout mirroring production (Option A).
                        Full fidelity. Good for Lab 06. (~$16/day all running)

.PARAMETER Mode
    SingleVM or MultiVM (default: SingleVM)

.PARAMETER VMSize
    Azure VM size override. SingleVM default: Standard_D8s_v4. MultiVM uses per-server defaults.

.PARAMETER ResourceGroup
    Azure resource group name (default: rg-it-stack-lab)

.PARAMETER Location
    Azure region (default: eastus — cheapest for student accounts)

.PARAMETER AdminUser
    SSH admin username (default: itstack)

.PARAMETER SshPublicKeyPath
    Path to SSH public key file (default: ~/.ssh/id_rsa.pub)

.PARAMETER AutoShutdownTime
    Daily auto-shutdown time in HHmm 24hr UTC (default: 2200 = 10pm UTC)

.PARAMETER DryRun
    Print what would be created without actually creating it.

.EXAMPLE
    # Deploy single VM for student labs
    .\deploy-azure-lab.ps1 -Mode SingleVM

    # Deploy full 8-VM production lab
    .\deploy-azure-lab.ps1 -Mode MultiVM

    # Custom size + dry run
    .\deploy-azure-lab.ps1 -Mode SingleVM -VMSize Standard_E16s_v4 -DryRun
#>

[CmdletBinding()]
param(
    [ValidateSet("SingleVM","MultiVM")]
    [string]$Mode = "SingleVM",

    [string]$VMSize = "",
    [string]$ResourceGroup = "rg-it-stack-lab",
    [string]$Location = "eastus",
    [string]$AdminUser = "itstack",
    [string]$SshPublicKeyPath = "$HOME\.ssh\id_rsa.pub",
    [string]$AutoShutdownTime = "2200",
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ─── Colour helpers ───────────────────────────────────────────────────────────
function Write-Step  { param($m) Write-Host "`n▶ $m" -ForegroundColor Cyan }
function Write-OK    { param($m) Write-Host "  ✓ $m" -ForegroundColor Green }
function Write-Warn  { param($m) Write-Host "  ⚠ $m" -ForegroundColor Yellow }
function Write-Dry   { param($m) Write-Host "  [DRY-RUN] $m" -ForegroundColor Magenta }

# ─── Pre-flight checks ────────────────────────────────────────────────────────
Write-Step "Pre-flight checks"

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw "Azure CLI (az) not found. Install from https://aka.ms/installazurecliwindows"
}
Write-OK "Azure CLI found: $(az version --query '\"azure-cli\"' -o tsv 2>$null)"

$loginCheck = az account show --query "id" -o tsv 2>$null
if (-not $loginCheck) {
    Write-Warn "Not logged in. Running 'az login'..."
    az login
}
$subscription = az account show --query "{name:name, id:id, state:state}" -o json | ConvertFrom-Json
Write-OK "Subscription: $($subscription.name) [$($subscription.id)]"

if (-not (Test-Path $SshPublicKeyPath)) {
    Write-Warn "SSH public key not found at $SshPublicKeyPath"
    Write-Warn "Generating a new SSH key pair..."
    if (-not $DryRun) {
        ssh-keygen -t rsa -b 4096 -f "$HOME\.ssh\id_rsa" -N '""'
    }
}
$SshPublicKey = if (Test-Path $SshPublicKeyPath) { Get-Content $SshPublicKeyPath -Raw } else { "DRY-RUN-KEY" }
Write-OK "SSH key: $SshPublicKeyPath"

# ─── Configuration ────────────────────────────────────────────────────────────
$VNetName    = "vnet-it-stack-lab"
$SubnetName  = "snet-servers"
$NsgName     = "nsg-it-stack-lab"
$VNetPrefix  = "10.0.50.0/24"
$SubnetPrefix = "10.0.50.0/24"

# SingleVM defaults
$SingleVMDefaults = @{
    Standard_D4s_v4  = "4 vCPU / 16 GB  — ~\$0.19/hr — minimal (Lab 01-02 only)"
    Standard_D8s_v4  = "8 vCPU / 32 GB  — ~\$0.38/hr — recommended (Labs 01-05)"
    Standard_E16s_v4 = "16 vCPU / 128 GB — ~\$1.01/hr — full stack (all labs)"
}

# MultiVM layout
$MultiVMLayout = @(
    @{ Name="lab-id1";    IP="10.0.50.11"; Size="Standard_D4s_v4";  Role="FreeIPA, Keycloak" }
    @{ Name="lab-db1";    IP="10.0.50.12"; Size="Standard_E8s_v4";  Role="PostgreSQL, Redis, Elasticsearch" }
    @{ Name="lab-app1";   IP="10.0.50.13"; Size="Standard_D8s_v4";  Role="Nextcloud, Mattermost, Jitsi" }
    @{ Name="lab-comm1";  IP="10.0.50.14"; Size="Standard_D4s_v4";  Role="iRedMail, Zammad, Zabbix" }
    @{ Name="lab-proxy1"; IP="10.0.50.15"; Size="Standard_D2s_v4";  Role="Traefik, Graylog" }
    @{ Name="lab-pbx1";   IP="10.0.50.16"; Size="Standard_D2s_v4";  Role="FreePBX" }
    @{ Name="lab-biz1";   IP="10.0.50.17"; Size="Standard_D8s_v4";  Role="SuiteCRM, Odoo, OpenKM" }
    @{ Name="lab-mgmt1";  IP="10.0.50.18"; Size="Standard_D4s_v4";  Role="Taiga, Snipe-IT, GLPI" }
)

if ($Mode -eq "SingleVM" -and -not $VMSize) { $VMSize = "Standard_D8s_v4" }

# ─── Print plan ───────────────────────────────────────────────────────────────
Write-Step "Deployment plan"
Write-Host "  Mode          : $Mode"
Write-Host "  Resource Group: $ResourceGroup"
Write-Host "  Location      : $Location"
Write-Host "  VNet          : $VNetName ($VNetPrefix)"
Write-Host "  Admin user    : $AdminUser"
Write-Host "  Auto-shutdown : $AutoShutdownTime UTC"
if ($Mode -eq "SingleVM") {
    Write-Host "  VM Size       : $VMSize  ($($SingleVMDefaults[$VMSize]))"
} else {
    Write-Host "  VMs (8):"
    foreach ($vm in $MultiVMLayout) {
        $sz = if ($VMSize) { $VMSize } else { $vm.Size }
        Write-Host "    $($vm.Name.PadRight(12)) $($vm.IP)   $($sz.PadRight(20))  — $($vm.Role)"
    }
}
if ($DryRun) { Write-Warn "DRY-RUN — no resources will be created"; return }

# ─── Resource Group ───────────────────────────────────────────────────────────
Write-Step "Resource group"
$rgExists = az group exists --name $ResourceGroup | ConvertFrom-Json
if (-not $rgExists) {
    az group create --name $ResourceGroup --location $Location --output none
    Write-OK "Created: $ResourceGroup"
} else {
    Write-OK "Already exists: $ResourceGroup"
}

# ─── NSG ──────────────────────────────────────────────────────────────────────
Write-Step "Network security group"
$nsgExists = az network nsg show --resource-group $ResourceGroup --name $NsgName --query "name" -o tsv 2>$null
if (-not $nsgExists) {
    az network nsg create --resource-group $ResourceGroup --name $NsgName --location $Location --output none

    # Allow SSH from anywhere (for lab; restrict to your IP in production)
    az network nsg rule create --resource-group $ResourceGroup --nsg-name $NsgName `
        --name "Allow-SSH" --priority 100 --direction Inbound --access Allow `
        --protocol Tcp --destination-port-ranges 22 --output none

    # Allow all internal VNet traffic
    az network nsg rule create --resource-group $ResourceGroup --nsg-name $NsgName `
        --name "Allow-VNet-Internal" --priority 200 --direction Inbound --access Allow `
        --protocol "*" --source-address-prefixes VirtualNetwork `
        --destination-address-prefixes VirtualNetwork --destination-port-ranges "*" --output none

    # Allow web ports for lab access (HTTP/HTTPS)
    az network nsg rule create --resource-group $ResourceGroup --nsg-name $NsgName `
        --name "Allow-Web" --priority 300 --direction Inbound --access Allow `
        --protocol Tcp --destination-port-ranges 80 443 8080 8443 8065 9000 3000 --output none

    Write-OK "Created NSG with SSH + web + VNet rules"
} else {
    Write-OK "NSG already exists: $NsgName"
}

# ─── VNet + Subnet ────────────────────────────────────────────────────────────
Write-Step "Virtual network"
$vnetExists = az network vnet show --resource-group $ResourceGroup --name $VNetName --query "name" -o tsv 2>$null
if (-not $vnetExists) {
    az network vnet create `
        --resource-group $ResourceGroup `
        --name $VNetName `
        --location $Location `
        --address-prefix $VNetPrefix `
        --subnet-name $SubnetName `
        --subnet-prefix $SubnetPrefix `
        --output none
    # Attach NSG to subnet
    az network vnet subnet update `
        --resource-group $ResourceGroup `
        --vnet-name $VNetName `
        --name $SubnetName `
        --network-security-group $NsgName `
        --output none
    Write-OK "Created VNet: $VNetName ($VNetPrefix) with subnet: $SubnetName"
} else {
    Write-OK "VNet already exists: $VNetName"
}

# ─── VM creation function ─────────────────────────────────────────────────────
function New-LabVM {
    param(
        [string]$VmName,
        [string]$PrivateIp,
        [string]$Size,
        [string]$Role
    )

    Write-Host "  Creating $VmName ($Size) [$Role]..." -NoNewline

    $exists = az vm show --resource-group $ResourceGroup --name $VmName --query "name" -o tsv 2>$null
    if ($exists) {
        Write-Host " already exists, skipping." -ForegroundColor Yellow
        return
    }

    # Create NIC with static private IP
    $nicName = "nic-$VmName"
    az network nic create `
        --resource-group $ResourceGroup `
        --name $nicName `
        --vnet-name $VNetName `
        --subnet $SubnetName `
        --private-ip-address $PrivateIp `
        --network-security-group $NsgName `
        --output none

    # Create VM
    az vm create `
        --resource-group $ResourceGroup `
        --name $VmName `
        --location $Location `
        --size $Size `
        --nics $nicName `
        --image Ubuntu2404 `
        --admin-username $AdminUser `
        --ssh-key-values $SshPublicKey `
        --os-disk-size-gb 64 `
        --storage-sku Premium_LRS `
        --output none

    # Auto-shutdown
    az vm auto-shutdown `
        --resource-group $ResourceGroup `
        --name $VmName `
        --time $AutoShutdownTime `
        --output none

    # Install Docker + common tools via cloud-init custom script extension
    $initScript = @"
#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq curl wget git vim htop net-tools dnsutils
# Install Docker
curl -fsSL https://get.docker.com | sh
usermod -aG docker $AdminUser
systemctl enable docker
systemctl start docker
# Install Docker Compose v2
mkdir -p /usr/local/lib/docker/cli-plugins
curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
     -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
# Set hostname
hostnamectl set-hostname $VmName
echo "IT-Stack lab VM $VmName ($Role) ready" > /etc/motd
"@

    $encodedScript = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($initScript))
    az vm extension set `
        --resource-group $ResourceGroup `
        --vm-name $VmName `
        --name CustomScript `
        --publisher Microsoft.Azure.Extensions `
        --settings "{`"commandToExecute`": `"echo $encodedScript | base64 -d | bash`"}" `
        --output none

    Write-Host " done." -ForegroundColor Green
}

# ─── Deploy VMs ───────────────────────────────────────────────────────────────
if ($Mode -eq "SingleVM") {
    Write-Step "Creating single lab VM"
    New-LabVM -VmName "lab-single" -PrivateIp "10.0.50.10" -Size $VMSize -Role "All IT-Stack services"

    # Add public IP for direct access
    Write-Host "  Creating public IP..." -NoNewline
    az network public-ip create `
        --resource-group $ResourceGroup `
        --name "pip-lab-single" `
        --sku Basic `
        --allocation-method Static `
        --output none
    az network nic ip-config update `
        --resource-group $ResourceGroup `
        --nic-name "nic-lab-single" `
        --name ipconfig1 `
        --public-ip-address "pip-lab-single" `
        --output none
    Write-Host " done." -ForegroundColor Green

} else {
    Write-Step "Creating 8-VM lab cluster"
    foreach ($vm in $MultiVMLayout) {
        $sz = if ($VMSize) { $VMSize } else { $vm.Size }
        New-LabVM -VmName $vm.Name -PrivateIp $vm.IP -Size $sz -Role $vm.Role
    }

    # Bastion-style jumpbox public IP on lab-proxy1 only
    Write-Host "  Adding public IP to lab-proxy1 for external access..." -NoNewline
    az network public-ip create `
        --resource-group $ResourceGroup `
        --name "pip-lab-proxy1" `
        --sku Basic `
        --allocation-method Static `
        --output none
    az network nic ip-config update `
        --resource-group $ResourceGroup `
        --nic-name "nic-lab-proxy1" `
        --name ipconfig1 `
        --public-ip-address "pip-lab-proxy1" `
        --output none
    Write-Host " done." -ForegroundColor Green
}

# ─── Private DNS Zone ─────────────────────────────────────────────────────────
Write-Step "Private DNS zone (lab.it-stack.local)"
$dnsExists = az network private-dns zone show --resource-group $ResourceGroup `
    --name "lab.it-stack.local" --query "name" -o tsv 2>$null
if (-not $dnsExists) {
    az network private-dns zone create `
        --resource-group $ResourceGroup `
        --name "lab.it-stack.local" `
        --output none

    az network private-dns link vnet create `
        --resource-group $ResourceGroup `
        --zone-name "lab.it-stack.local" `
        --name "dns-link-lab" `
        --virtual-network $VNetName `
        --registration-enabled false `
        --output none

    # Add DNS A records
    $dnsRecords = if ($Mode -eq "MultiVM") {
        $MultiVMLayout | ForEach-Object { @{Name=$_.Name; IP=$_.IP} }
    } else {
        @(@{Name="lab-single"; IP="10.0.50.10"})
    }

    foreach ($rec in $dnsRecords) {
        az network private-dns record-set a create `
            --resource-group $ResourceGroup `
            --zone-name "lab.it-stack.local" `
            --name $rec.Name --output none
        az network private-dns record-set a add-record `
            --resource-group $ResourceGroup `
            --zone-name "lab.it-stack.local" `
            --record-set-name $rec.Name `
            --ipv4-address $rec.IP --output none
    }
    Write-OK "DNS zone created with $(($dnsRecords).Count) A records"
} else {
    Write-OK "DNS zone already exists"
}

# ─── Output summary ───────────────────────────────────────────────────────────
Write-Step "Deployment complete"

if ($Mode -eq "SingleVM") {
    $pip = az network public-ip show --resource-group $ResourceGroup `
        --name "pip-lab-single" --query "ipAddress" -o tsv 2>$null
    Write-Host ""
    Write-Host "  ┌─────────────────────────────────────────────────────┐" -ForegroundColor Cyan
    Write-Host "  │  IT-Stack Lab — Single VM                           │" -ForegroundColor Cyan
    Write-Host "  │                                                     │" -ForegroundColor Cyan
    Write-Host "  │  Public IP : $($pip.PadRight(38))│" -ForegroundColor Cyan
    Write-Host "  │  SSH       : ssh $AdminUser@$pip          │" -ForegroundColor Cyan
    Write-Host "  │  Size      : $($VMSize.PadRight(38))│" -ForegroundColor Cyan
    Write-Host "  │  Shutdown  : $AutoShutdownTime UTC daily (auto)                  │" -ForegroundColor Cyan
    Write-Host "  └─────────────────────────────────────────────────────┘" -ForegroundColor Cyan
} else {
    $pip = az network public-ip show --resource-group $ResourceGroup `
        --name "pip-lab-proxy1" --query "ipAddress" -o tsv 2>$null
    Write-Host ""
    Write-Host "  ┌─────────────────────────────────────────────────────┐" -ForegroundColor Cyan
    Write-Host "  │  IT-Stack Lab — 8-VM Cluster                        │" -ForegroundColor Cyan
    Write-Host "  │                                                     │" -ForegroundColor Cyan
    Write-Host "  │  Entry point : ssh $AdminUser@$pip        │" -ForegroundColor Cyan
    Write-Host "  │  (lab-proxy1 is the only VM with a public IP)       │" -ForegroundColor Cyan
    Write-Host "  │  SSH to others: ssh -J $AdminUser@$pip $AdminUser@10.0.50.11   │" -ForegroundColor Cyan
    Write-Host "  │                                                     │" -ForegroundColor Cyan
    foreach ($vm in $MultiVMLayout) {
        Write-Host "  │  $($vm.Name.PadRight(12)) $($vm.IP)  $($vm.Role.PadRight(26))│" -ForegroundColor Cyan
    }
    Write-Host "  └─────────────────────────────────────────────────────┘" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "  Next steps:" -ForegroundColor White
Write-Host "  1. Clone the Ansible repo onto the control machine:" -ForegroundColor Gray
Write-Host "     git clone https://github.com/it-stack-dev/it-stack-ansible.git" -ForegroundColor Gray
Write-Host "  2. Update inventory/hosts.ini with the IP(s) above" -ForegroundColor Gray
Write-Host "  3. Run: make deploy-phase1" -ForegroundColor Gray
Write-Host ""
Write-Host "  Cost control:" -ForegroundColor White
Write-Host "  - Auto-shutdown is set to $AutoShutdownTime UTC daily" -ForegroundColor Gray
Write-Host "  - To stop all VMs now: .\teardown-azure-lab.ps1 -StopOnly" -ForegroundColor Gray
Write-Host "  - To delete everything: .\teardown-azure-lab.ps1 -DeleteAll" -ForegroundColor Gray
