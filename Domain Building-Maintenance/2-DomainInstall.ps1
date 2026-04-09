# Renames the VM and Creates a Team's Domain
# The VM will reboot after Successful Creation of the Domain
# Designed for Windows Server 2016 
# GDDC Sp26 - DC1 Setup Script

Enable-NetFirewallRule -DisplayGroup "Remote Desktop"

# Optional: Create a custom rule if the built-in ones don't exist
New-NetFirewallRule `
    -DisplayName "Allow Inbound RDP" `
    -Direction Inbound `
    -Protocol TCP `
    -LocalPort 3389 `
    -Action Allow `
    -Profile Any `
    -Enabled True

# Rename Computer
$NewHostname = "DOG-DC1"
Write-Host "`n=== Renaming Computer to '$NewHostname' ===" -ForegroundColor Cyan
if ($env:COMPUTERNAME -ne $NewHostname) {
    Rename-Computer -NewName $NewHostname -Force
    Write-Host "Renamed. Reboot required." -ForegroundColor Green
} else {
    Write-Host "Already named '$NewHostname'. Skipping." -ForegroundColor Gray
}


# Install AD DS and Create Domain
$DomainName  = "DOGTeam#.local"  # Rename the # for the Team Number
$NetBIOSName = "DOG#" # Rename the # for the Team Number
$AdminPassword = ConvertTo-SecureString "bb123#123#123" -AsPlainText -Force # This is seperate from the Admin User, this is for break glass if there is an issue during install

Write-Host " Installing AD DS Role " -ForegroundColor Cyan
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools -Verbose

Write-Host " Promoting to Domain Controller " -ForegroundColor Cyan
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

# Jon Fortnite
