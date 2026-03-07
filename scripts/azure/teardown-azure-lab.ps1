<#
.SYNOPSIS
    Stops or deletes IT-Stack Azure lab resources to control costs.

.PARAMETER StopOnly
    Deallocate all VMs (no compute charge) but keep all resources.

.PARAMETER StartAll
    Start all deallocated VMs.

.PARAMETER DeleteAll
    Delete the entire resource group (IRREVERSIBLE — removes everything).

.PARAMETER ResourceGroup
    Azure resource group name (default: rg-it-stack-lab)

.EXAMPLE
    # Stop all VMs at end of the day (saves money, keeps config)
    .\teardown-azure-lab.ps1 -StopOnly

    # Start them back up next morning
    .\teardown-azure-lab.ps1 -StartAll

    # Delete everything when done (student credit used up or project done)
    .\teardown-azure-lab.ps1 -DeleteAll
#>

[CmdletBinding(DefaultParameterSetName="StopOnly")]
param(
    [Parameter(ParameterSetName="StopOnly")][switch]$StopOnly,
    [Parameter(ParameterSetName="StartAll")][switch]$StartAll,
    [Parameter(ParameterSetName="DeleteAll")][switch]$DeleteAll,
    [string]$ResourceGroup = "rg-it-stack-lab"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step { param($m) Write-Host "`n▶ $m" -ForegroundColor Cyan }
function Write-OK   { param($m) Write-Host "  ✓ $m" -ForegroundColor Green }
function Write-Warn { param($m) Write-Host "  ⚠ $m" -ForegroundColor Yellow }

# Verify login
$loginCheck = az account show --query "id" -o tsv 2>$null
if (-not $loginCheck) { az login }

# Check resource group exists
$rgCheck = az group exists --name $ResourceGroup | ConvertFrom-Json
if (-not $rgCheck) {
    Write-Warn "Resource group '$ResourceGroup' does not exist. Nothing to do."
    exit 0
}

if ($DeleteAll) {
    Write-Warn "This will PERMANENTLY DELETE the resource group '$ResourceGroup' and ALL resources inside it."
    Write-Warn "This includes all VMs, disks, NICs, VNet, DNS zones, and public IPs."
    Write-Host ""
    $confirm = Read-Host "Type the resource group name to confirm deletion"
    if ($confirm -ne $ResourceGroup) {
        Write-Host "Confirmation did not match. Aborting." -ForegroundColor Red
        exit 1
    }
    Write-Step "Deleting resource group $ResourceGroup (this takes 5-10 minutes)..."
    az group delete --name $ResourceGroup --yes --no-wait
    Write-OK "Deletion initiated. Check Azure Portal for status."
    Write-Host "  Estimated time to complete: 5-10 minutes" -ForegroundColor Gray

} elseif ($StopOnly) {
    Write-Step "Deallocating all VMs in $ResourceGroup"
    $vms = az vm list --resource-group $ResourceGroup --query "[].name" -o tsv 2>$null
    if (-not $vms) {
        Write-Warn "No VMs found in $ResourceGroup"
        exit 0
    }
    # Deallocate in parallel
    $jobs = foreach ($vm in ($vms -split "`n" | Where-Object { $_ })) {
        Write-Host "  Stopping $vm..." -NoNewline
        $job = Start-Job -ScriptBlock {
            param($rg, $name)
            az vm deallocate --resource-group $rg --name $name --output none 2>&1
        } -ArgumentList $ResourceGroup, $vm
        Write-Host " queued (job $($job.Id))"
        $job
    }
    Write-Host "  Waiting for all VMs to deallocate..." -ForegroundColor Gray
    $jobs | Wait-Job | Out-Null
    $jobs | ForEach-Object {
        $result = Receive-Job -Job $_
        if ($_.State -eq "Failed" -or $result -match "ERROR") {
            Write-Warn "Job $($_.Id) had issues: $result"
        }
    }
    $jobs | Remove-Job

    Write-OK "All VMs deallocated. No compute charges while stopped."
    Write-Host ""
    Write-Host "  Current status:" -ForegroundColor White
    az vm list --resource-group $ResourceGroup `
        --query "[].{Name:name, Status:powerState}" `
        --show-details -o table 2>$null

    Write-Host ""
    Write-Host "  Cost estimate while deallocated:" -ForegroundColor Gray
    Write-Host "  - Compute: \$0.00/hr" -ForegroundColor Green
    Write-Host "  - Managed disks: ~\$0.01-0.05/hr (minimal)" -ForegroundColor Yellow
    Write-Host "  - VNet/NSG/DNS: ~\$0.00/hr (free)" -ForegroundColor Green
    Write-Host ""
    Write-Host "  To restart: .\teardown-azure-lab.ps1 -StartAll" -ForegroundColor Cyan

} elseif ($StartAll) {
    Write-Step "Starting all VMs in $ResourceGroup"
    $vms = az vm list --resource-group $ResourceGroup --query "[].name" -o tsv 2>$null
    if (-not $vms) {
        Write-Warn "No VMs found in $ResourceGroup"
        exit 0
    }
    # Start in parallel
    $jobs = foreach ($vm in ($vms -split "`n" | Where-Object { $_ })) {
        Write-Host "  Starting $vm..." -NoNewline
        $job = Start-Job -ScriptBlock {
            param($rg, $name)
            az vm start --resource-group $rg --name $name --output none 2>&1
        } -ArgumentList $ResourceGroup, $vm
        Write-Host " queued (job $($job.Id))"
        $job
    }
    Write-Host "  Waiting for all VMs to start..." -ForegroundColor Gray
    $jobs | Wait-Job | Out-Null
    $jobs | Remove-Job

    Write-OK "All VMs started."
    Write-Host ""
    az vm list --resource-group $ResourceGroup `
        --query "[].{Name:name, Size:hardwareProfile.vmSize}" `
        --show-details -o table 2>$null

} else {
    Write-Host "No action specified. Use -StopOnly, -StartAll, or -DeleteAll." -ForegroundColor Yellow
    Get-Help $MyInvocation.MyCommand.Path
}
