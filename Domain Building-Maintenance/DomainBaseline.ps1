# =============================================================================
# Windows Server 2016 - Domain Controller Setup (Phase 1)
# Steps: Rename Host | Create Forest/Domain | Add Users & Groups
# Run as Administrator in an elevated PowerShell session.
# =============================================================================

# ----------------------------- CONFIGURATION ----------------------------------

$NewHostname      = "DC1"
$DomainName       = "DOG.local"
$NetBIOSName      = "DOG"
$LLUserPassword  = (ConvertTo-SecureString "bb123#123#123" -AsPlainText -Force) # Low Level User Password
$AdminPassword  = (ConvertTo-SecureString "UAUKnow67!" -AsPlainText -Force) # Admin Users Password

# --- User List --- 
# These users are not intended for red team access, but who knows :)
# Scoring User is cdo and will not be a red team asset
$Users = @(
    @{ Username = "cdo";    FullName = "cdo";     Groups = "Domain Admins, Administrators"; AccountPassword = "bb123#123#123"  },
    @{ Username = "jsmith";    FullName = "John Smith";     Group = "Domain Admins"; AccountPassword = "bb123#123#123"  },
    @{ Username = "mjones";    FullName = "Mary Jones";     Group = "Domain Users"; AccountPassword = "bb123#123#123"    },
    @{ Username = "bwilson";   FullName = "Bob Wilson";     Group = "Domain Users"; AccountPassword = "bb123#123#123"    },
    @{ Username = "svcbackup"; FullName = "Backup Service"; Group = "Backup Operators"; AccountPassword = "bb123#123#123" },
    @{ Username = "helpdesk1"; FullName = "Help Desk 1";    Group = "HelpDesk"; AccountPassword = "bb123#123#123"        }
)

# --- Custom Groups to create (beyond built-in AD groups) ---
$CustomGroups = @(
    "WinRM Access",
    "SSH Access",
    "SMB Access"
)

# ==============================================================================
# STEP 1 & 2 — Rename Computer & Promote to Domain Controller
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
        -SafeModeAdministratorPassword $SafeModePassword `
        -InstallDns:$true `
        -NoRebootOnCompletion:$false `
        -Force:$true

    # Server reboots automatically after promotion
}

# ==============================================================================
# STEP 3 — Create Users & Groups (run after reboot)
# ==============================================================================
function Invoke-UserSetup {

    Write-Host "`n=== STEP 4: Creating AD Groups ===" -ForegroundColor Cyan
    Import-Module ActiveDirectory
    $DomainDN = (Get-ADDomain).DistinguishedName

    foreach ($Group in $CustomGroups) {
        if (-not (Get-ADGroup -Filter { Name -eq $Group } -ErrorAction SilentlyContinue)) {
            New-ADGroup -Name $Group -GroupScope Global -GroupCategory Security `
                        -Path "CN=Users,$DomainDN"
            Write-Host "     Created group: $Group" -ForegroundColor Green
        } else {
            Write-Host "     Group '$Group' already exists. Skipping." -ForegroundColor Gray
        }
    }

    Write-Host "`n=== STEP 5: Creating Users ===" -ForegroundColor Cyan
    foreach ($User in $Users) {
        $Username = $User.Username
        $FullName = $User.FullName
        $Group    = $User.Group

        if (-not (Get-ADUser -Filter { SamAccountName -eq $Username } -ErrorAction SilentlyContinue)) {
            New-ADUser `
                -SamAccountName        $Username `
                -UserPrincipalName     "$Username@$DomainName" `
                -Name                  $FullName `
                -GivenName             ($FullName.Split(" ")[0]) `
                -Surname               ($FullName.Split(" ")[-1]) `
                -AccountPassword       $DefaultPassword `
                -ChangePasswordAtLogon $false `
                -Enabled               $true `
                -Path                  "CN=Users,$DomainDN"

            Write-Host "     Created user: $Username ($FullName)" -ForegroundColor Green
        } else {
            Write-Host "     User '$Username' already exists. Skipping." -ForegroundColor Gray
        }

        try {
            Add-ADGroupMember -Identity $Group -Members $Username
            Write-Host "     Added '$Username' to group '$Group'." -ForegroundColor Green
        } catch {
            Write-Warning "     Could not add '$Username' to '$Group': $_"
        }
    }

    Write-Host "`n=== SETUP COMPLETE ===" -ForegroundColor Cyan
    Write-Host "Domain '$DomainName' is ready. Run the services script next." -ForegroundColor Green
}

# ==============================================================================
# ENTRY POINT — Auto-detect which step to run
# ==============================================================================
$adInstalled  = (Get-WindowsFeature -Name AD-Domain-Services).Installed
$domainJoined = (Get-WmiObject Win32_ComputerSystem).PartOfDomain

if (-not $adInstalled -or -not $domainJoined) {
    Invoke-DomainSetup
} else {
    Invoke-UserSetup
}
