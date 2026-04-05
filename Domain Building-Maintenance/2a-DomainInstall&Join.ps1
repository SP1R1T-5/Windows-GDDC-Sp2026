# Renames the VM and Joins the Team's Domain
# The VM will reboot after Successful Join of the Domain
# Designed for Windows Server 2016 
# GDDC Sp26 - DC2 Setup Script


# Rename Computer
$NewHostname = "DOG-DC2"
Write-Host " Renaming Computer to '$NewHostname' " -ForegroundColor Cyan
if ($env:COMPUTERNAME -ne $NewHostname) {
    Rename-Computer -NewName $NewHostname -Force
    Write-Host "Renamed. Reboot required." -ForegroundColor Green
} else {
    Write-Host "Already named '$NewHostname'. Skipping." -ForegroundColor Gray
}


# Define domain, user, and password variables to join the Domain with the Domain Admin
$domain = "DOG#.local" # Replace the # with the Team Number
$user = "DOG\Administrator"
$password = "bb123#123" 

# Convert password to a secure string
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force

# Create the credential object
$credential = New-Object System.Management.Automation.PSCredential ($user, $securePassword)

# Join the computer to the domain
Add-Computer -DomainName $domain -Credential $credential -Restart -Force

# Jon Fortnite
