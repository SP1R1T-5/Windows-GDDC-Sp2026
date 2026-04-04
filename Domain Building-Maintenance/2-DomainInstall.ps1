# ==============================
# Rename Computer
# ==============================
$NewHostname = "DOG-DC#"
Write-Host "`n=== Renaming Computer to '$NewHostname' ===" -ForegroundColor Cyan
if ($env:COMPUTERNAME -ne $NewHostname) {
    Rename-Computer -NewName $NewHostname -Force
    Write-Host "Renamed. Reboot required." -ForegroundColor Green
} else {
    Write-Host "Already named '$NewHostname'. Skipping." -ForegroundColor Gray
}


# ==============================
# Install AD DS and Create Domain
# ==============================

$DomainName  = "DOG.local"
$NetBIOSName = "DOG"
$AdminPassword = ConvertTo-SecureString "UAUKnow67!" -AsPlainText -Force

Write-Host "`n=== Installing AD DS Role ===" -ForegroundColor Cyan
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools -Verbose

Write-Host "`n=== Promoting to Domain Controller ===" -ForegroundColor Cyan
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
