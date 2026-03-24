# =============================================================================
# Windows Server 2016 - Domain Controller Setup (Phase 1)
# Steps: Rename Host | Create Forest/Domain | Add Users & Groups
# Run as Administrator in an elevated PowerShell session.
#
# The script uses a flag file to track progress across reboots:
#   Run 1 — Renames computer, registers scheduled task, reboots
#   Run 2 — (auto) Installs AD DS, promotes to DC, reboots
#   Run 3 — (auto) Creates groups and users, removes scheduled task
# =============================================================================

# ----------------------------- CONFIGURATION ----------------------------------

$NewHostname      = "DC1"
$DomainName       = "DOG.local"
$NetBIOSName      = "DOG"
$SafeModePassword = (ConvertTo-SecureString "UAUKnow67!" -AsPlainText -Force)  # DSRM recovery password

# Path to this script (used by the scheduled task to re-run after reboot)
$ScriptPath = $MyInvocation.MyCommand.Path

# Flag file to track which stage we are on across reboots
$StageFlagPath = "C:\Windows\Temp\dc_setup_stage.txt"

# --- User List ---
# Use "Groups" for all users (comma-separated if multiple groups needed)
$Users = @(
    @{ Username = "cdo";       FullName = "cdo";            Groups = "Domain Admins,Administrators"; AccountPassword = "bb123#123#123" },
    @{ Username = "jsmith";    FullName = "John Smith";      Groups = "Domain Admins";                AccountPassword = "bb123#123#123" },
    @{ Username = "mjones";    FullName = "Mary Jones";      Groups = "Domain Users";                 AccountPassword = "bb123#123#123" },
    @{ Username = "bwilson";   FullName = "Bob Wilson";      Groups = "Domain Users";                 AccountPassword = "bb123#123#123" },
    @{ Username = "svcbackup"; FullName = "Backup Service";  Groups = "Backup Operators";             AccountPassword = "bb123#123#123" },
    @{ Username = "helpdesk1"; FullName = "Help Desk 1";     Groups = "HelpDesk";                     AccountPassword = "bb123#123#123" }
)

# --- Custom Groups to create (beyond built-in AD groups) ---
$CustomGroups = @(
    "HelpDesk",
    "WinRM Access",
    "SSH Access",
    "SMB Access"
)

# ==============================================================================
# HELPER — Register a scheduled task to re-run this script after reboot
# ==============================================================================
function Register-RebootTask {
    Write-Host "     Registering scheduled task to continue after reboot..." -ForegroundColor Yellow

    $Action  = New-ScheduledTaskAction -Execute "PowerShell.exe" `
                   -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
    $Trigger = New-ScheduledTaskTrigger -AtStartup
    $Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest

    Register-ScheduledTask -TaskName "DC_Setup_Continue" `
        -Action $Action -Trigger $Trigger -Principal $Principal -Force | Out-Null

    Write-Host "     Scheduled task registered. Script will resume after reboot." -ForegroundColor Green
}

# ==============================================================================
# HELPER — Remove the scheduled task once setup is complete
# ==============================================================================
function Remove-RebootTask {
    if (Get-ScheduledTask -TaskName "DC_Setup_Continue" -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName "DC_Setup_Continue" -Confirm:$false
        Write-Host "     Scheduled task removed." -ForegroundColor Gray
    }
}

# ==============================================================================
# STAGE 1 — Rename Computer, then reboot
# ==============================================================================
function Invoke-Stage1 {
    Write-Host "`n=== STAGE 1: Renaming Computer to '$NewHostname' ===" -ForegroundColor Cyan

    if ($env:COMPUTERNAME -ne $NewHostname) {
        Rename-Computer -NewName $NewHostname -Force
        Write-Host "     Computer renamed to '$NewHostname'." -ForegroundColor Green
    } else {
        Write-Host "     Already named '$NewHostname'. Skipping rename." -ForegroundColor Gray
    }

    # Write next stage flag before rebooting
    Set-Content -Path $StageFlagPath -Value "2"
    Register-RebootTask

    Write-Host "`n     Rebooting to apply hostname change..." -ForegroundColor Yellow
    Start-Sleep -Seconds 3
    Restart-Computer -Force
}

# ==============================================================================
# STAGE 2 — Install AD DS & Promote to Domain Controller, then reboot
# ==============================================================================
function Invoke-Stage2 {
    Write-Host "`n=== STAGE 2: Installing AD DS Role ===" -ForegroundColor Cyan
    Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools -Verbose
    Write-Host "     AD DS role installed." -ForegroundColor Green

    Write-Host "`n=== STAGE 2: Promoting to Domain Controller for '$DomainName' ===" -ForegroundColor Cyan
    Import-Module ADDSDeployment

    # Write next stage flag before promotion reboot
    Set-Content -Path $StageFlagPath -Value "3"

    Install-ADDSForest `
        -DomainName                    $DomainName `
        -DomainNetbiosName             $NetBIOSName `
        -DomainMode                    "WinThreshold" `
        -ForestMode                    "WinThreshold" `
        -SafeModeAdministratorPassword $SafeModePassword `
        -InstallDns:$true `
        -NoRebootOnCompletion:$false `
        -Force:$true

    # Server reboots automatically after promotion
}

# ==============================================================================
# STAGE 3 — Create Groups & Users
# ==============================================================================
function Invoke-Stage3 {
    Import-Module ActiveDirectory

    # Build DN directly from $DomainName to avoid null query issue post-promotion
    $DomainDN = "DC=" + ($DomainName -replace "\.", ",DC=")

    Write-Host "`n=== STAGE 3: Creating Custom AD Groups ===" -ForegroundColor Cyan
    foreach ($Group in $CustomGroups) {
        if (-not (Get-ADGroup -Filter { Name -eq $Group } -ErrorAction SilentlyContinue)) {
            New-ADGroup -Name $Group -GroupScope Global -GroupCategory Security `
                        -Path "CN=Users,$DomainDN"
            Write-Host "     Created group: $Group" -ForegroundColor Green
        } else {
            Write-Host "     Group '$Group' already exists. Skipping." -ForegroundColor Gray
        }
    }

    Write-Host "`n=== STAGE 3: Creating Users & Assigning Groups ===" -ForegroundColor Cyan
    foreach ($User in $Users) {
        $Username = $User.Username
        $FullName = $User.FullName
        $Password = (ConvertTo-SecureString $User.AccountPassword -AsPlainText -Force)
        $Groups   = $User.Groups -split "," | ForEach-Object { $_.Trim() }

        if (-not (Get-ADUser -Filter { SamAccountName -eq $Username } -ErrorAction SilentlyContinue)) {
            New-ADUser `
                -SamAccountName        $Username `
                -UserPrincipalName     "$Username@$DomainName" `
                -Name                  $FullName `
                -GivenName             ($FullName.Split(" ")[0]) `
                -Surname               ($FullName.Split(" ")[-1]) `
                -AccountPassword       $Password `
                -ChangePasswordAtLogon $false `
                -Enabled               $true `
                -Path                  "CN=Users,$DomainDN"

            Write-Host "     Created user: $Username ($FullName)" -ForegroundColor Green
        } else {
            Write-Host "     User '$Username' already exists. Skipping." -ForegroundColor Gray
        }

        foreach ($Group in $Groups) {
            try {
                Add-ADGroupMember -Identity $Group -Members $Username
                Write-Host "     Added '$Username' to group '$Group'." -ForegroundColor Green
            } catch {
                Write-Warning "     Could not add '$Username' to '$Group': $_"
            }
        }
    }

    # Clean up flag file and scheduled task
    Remove-Item -Path $StageFlagPath -Force -ErrorAction SilentlyContinue
    Remove-RebootTask

    Write-Host "`n=== SETUP COMPLETE ===" -ForegroundColor Cyan
    Write-Host "Domain '$DomainName' is configured. Run the services script next." -ForegroundColor Green
}

# ==============================================================================
# ENTRY POINT — Read stage flag to decide what to run
# ==============================================================================
$stage = if (Test-Path $StageFlagPath) { Get-Content $StageFlagPath } else { "1" }

switch ($stage) {
    "1" { Invoke-Stage1 }
    "2" { Invoke-Stage2 }
    "3" { Invoke-Stage3 }
    default {
        Write-Warning "Unknown stage '$stage' in flag file. Delete $StageFlagPath and re-run to start over."
    }
}
