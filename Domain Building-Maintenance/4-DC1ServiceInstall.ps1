# Creates/Enables Services for the DC1 
# Designed for Windows Server 2016 
# GDDC Sp26 - DC1 Setup Script

#Verifiying the Windows Update Server is Running and set to Automatic to fix source file issue for the "Invoke-WebRequest" cmdlet
Get-Service wuauserv | Start-Service
Set-Service wuauserv -StartupType Automatic


# Install and Enable Services Module
Import-Module ServerManager

# LDAP (Active Directory)
# Already enabled when AD DS is installed
Write-Host "LDAP is active via Active Directory Domain Services"

# WinRM
Enable-PSRemoting -Force
Set-Service WinRM -StartupType Automatic
Start-Service WinRM


# Allow WinRM through firewall
Set-NetFirewallRule -Name "WINRM-HTTP-In-TCP" -Enabled True

# RDP
# Enable Remote Desktop
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" `
    -Name "fDenyTSConnections" -Value 0

# Allow RDP in firewall
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"

# SMB
# Ensure SMB service is running
Set-Service -Name LanmanServer -StartupType Automatic
Start-Service LanmanServer



# Installing SSH Service (This is a pain ngl, pray this works)
# Setup paths
$installPath = "C:\Program Files\OpenSSH-Win64"
if (!(Test-Path $installPath)) { New-Item -ItemType Directory -Force -Path $installPath }

# Setting the URL and the FileName of the OpenSSH Server File
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$url = "https://github.com/PowerShell/Win32-OpenSSH/releases/latest/download/OpenSSH-Win64.zip"
$zipFile = "$env:TEMP\openssh.zip"

Write-Host " Downloading OpenSSH " -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri $url -OutFile $zipFile -ErrorAction Stop
} catch {
    Write-Error "Download failed again. Please check your internet connection or if GitHub is blocked."
    return
}

# Verify file exists before extracting
if (Test-Path $zipFile) {
    Write-Host " Extracting files " -ForegroundColor Cyan
    Expand-Archive -Path $zipFile -DestinationPath "$env:TEMP\ssh_temp" -Force
    
    # Move files to Program Files
    Copy-Item -Path "$env:TEMP\ssh_temp\OpenSSH-Win64\*" -Destination $installPath -Recurse -Force
    
    # Register the Service
    Set-Location $installPath
    if (Test-Path ".\install-sshd.ps1") {
        .\install-sshd.ps1
        Write-Host "Installation script executed successfully." -ForegroundColor Green
    } else {
        Write-Error " Could not find install-sshd.ps1 in $installPath"
    }
}

#Starting SSH and enabling automatic startup
write-output "Starting SSH"
Start-Service sshd
Set-Service -Name sshd -StartupType Automatic

#Setting Firewall for SSH Connection
write-output "Creating Firewall Rule"
netsh advfirewall firewall add rule name="SSHD" dir=in action=allow protocol=TCP localport=22

#Showing SSH Running
Get-Service sshd
write-output "Congrats SSH Survived! :) "

Write-Host " All services installed and enabled "
