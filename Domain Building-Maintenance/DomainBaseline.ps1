# =============================================================================
# Windows Server 2016 - Domain Controller Setup (Phase 1)
# Steps: Rename Host | Create Forest/Domain | Add Users & Groups
# Run as Administrator in an elevated PowerShell session.
# =============================================================================

# ----------------------------- CONFIGURATION ----------------------------------

$NewHostname      = "DC1"
$DomainName       = "DOG.local"
$NetBIOSName      = "DOG"
$AdminPassword = (ConvertTo-SecureString "UAUKnow67!" -AsPlainText -Force)  # Admin recovery password
$LLUserPassowrd = (ConvertTo-SecureString "bb123#123#123" -AsPlainText -Force)  # Low Level User recovery password

# --- User List ---
# Use "Groups" for all users (comma-separated if multiple groups needed)
$Users = @(
    @{ Username = "cdo";       FullName = "cdo";            Groups = "Domain Admins,Administrators"; AccountPassword = $LLUserPassowrd },
    @{ Username = "jsmith";    FullName = "John Smith";      Groups = "Domain Admins";                AccountPassword = $LLUserPassowrd },
    @{ Username = "mjones";    FullName = "Mary Jones";      Groups = "Domain Users";                 AccountPassword = $LLUserPassowrd },
    @{ Username = "bwilson";   FullName = "Bob Wilson";      Groups = "Domain Users";                 AccountPassword = $LLUserPassowrd },
    @{ Username = "svcbackup"; FullName = "Backup Service";  Groups = "Backup Operators";             AccountPassword = $LLUserPassowrd },
    @{ Username = "helpdesk1"; FullName = "Help Desk 1";     Groups = "HelpDesk";                     AccountPassword = $LLUserPassowrd }
)

# --- Custom Groups to create (beyond built-in AD groups) ---
$CustomGroups = @(
    "HelpDesk",
    "WinRM Access",
    "SSH Access",
    "SMB Access"
)

# ==============================================================================
# PHASE 1 — Rename Computer & Promote to Domain Controller
# ==============================================================================
function Invoke-DomainSetup {

    Write-Host "`n=== STEP 1: Renaming Computer to '$NewHostname' ===" -ForegroundColor Cyan
    if ($env:COMPUTERNAME -ne $NewHostname) {
        Rename-Computer -NewName $NewHostname -Force
        Write-Host "     Renamed. Change takes effect after reboot." -ForegroundColor Green
    } else {
        Write-Host "     Already named '$NewHostname'. Skipping." -ForegroundColor Gray
    }

    Write-Host "`n=== STEP 2: Installing AD DS Role ===" -ForegroundColor Cyan
    Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools -Verbose
    Write-Host "     AD DS role installed." -ForegroundColor Green

    Write-Host "`n=== STEP 3: Promoting to Domain Controller for '$DomainName' ===" -ForegroundColor Cyan
    Import-Module ADDSDeployment

    Install-ADDSForest `
        -DomainName                    $DomainName `
        -DomainNetbiosName             $NetBIOSName `
        -DomainMode                    "WinThreshold" `
        -ForestMode                    "WinThreshold" `
        -SafeModeAdministratorPassword $AdminPassword `
        -InstallDns:$true `
        -NoRebootOnCompletion:$false `
        -Force:$true

    # Server reboots automatically after promotion
}

# ==============================================================================
# PHASE 2 — Create Groups & Users (run after reboot)
# ==============================================================================
function Invoke-UserSetup {

    Import-Module ActiveDirectory

    # Build DN directly from $DomainName to avoid null query issue post-promotion
    $DomainDN = "DC=" + ($DomainName -replace "\.", ",DC=")

    Write-Host "`n=== STEP 4: Creating Custom AD Groups ===" -ForegroundColor Cyan
    foreach ($Group in $CustomGroups) {
        if (-not (Get-ADGroup -Filter { Name -eq $Group } -ErrorAction SilentlyContinue)) {
            New-ADGroup -Name $Group -GroupScope Global -GroupCategory Security `
                        -Path "CN=Users,$DomainDN"
            Write-Host "     Created group: $Group" -ForegroundColor Green
        } else {
            Write-Host "     Group '$Group' already exists. Skipping." -ForegroundColor Gray
        }
    }

    Write-Host "`n=== STEP 5: Creating Users & Assigning Groups ===" -ForegroundColor Cyan
    foreach ($User in $Users) {
        $Username = $User.Username
        $FullName = $User.FullName
        $Password = (ConvertTo-SecureString $User.AccountPassword -AsPlainText -Force)
        # Split comma-separated groups and trim whitespace
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

        # Assign all groups (handles single or multiple)
        foreach ($Group in $Groups) {
            try {
                Add-ADGroupMember -Identity $Group -Members $Username
                Write-Host "     Added '$Username' to group '$Group'." -ForegroundColor Green
            } catch {
                Write-Warning "     Could not add '$Username' to '$Group': $_"
            }
        }
    }

    Write-Host "`n=== SETUP COMPLETE ===" -ForegroundColor Cyan
    Write-Host "Domain '$DomainName' is ready. Run the services script next." -ForegroundColor Green
}

# ==============================================================================
# ENTRY POINT — Auto-detect which phase to run
# ==============================================================================
$adInstalled  = (Get-WindowsFeature -Name AD-Domain-Services).Installed
$domainJoined = (Get-WmiObject Win32_ComputerSystem).PartOfDomain

if (-not $adInstalled -or -not $domainJoined) {
    Invoke-DomainSetup
} else {
    Invoke-UserSetup
}
