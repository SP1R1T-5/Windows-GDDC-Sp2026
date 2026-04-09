# ==============================
# Install and Enable Services
# (Run AFTER DC promotion reboot)
# ==============================

Import-Module ServerManager

# ------------------------------
# IIS (Web Server)
# ------------------------------
Write-Host "`n=== Installing IIS ===" -ForegroundColor Cyan
Install-WindowsFeature -Name Web-Server -IncludeManagementTools
Set-Service -Name W3SVC -StartupType Automatic
Start-Service W3SVC
Write-Host "IIS installed and started." -ForegroundColor Green

# ------------------------------
# RDP
# ------------------------------
Write-Host "`n=== Enabling RDP ===" -ForegroundColor Cyan
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" `
    -Name "fDenyTSConnections" -Value 0
Set-Service -Name TermService -StartupType Automatic
Start-Service TermService
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
Write-Host "RDP enabled." -ForegroundColor Green

# ------------------------------
# CA (Active Directory Certificate Services)
# ------------------------------
Write-Host "`n=== Installing Certificate Authority ===" -ForegroundColor Cyan

Install-WindowsFeature ADCS-Cert-Authority -IncludeManagementTools

# Verify the AD DS role is available before configuring CA
if ((Get-Service NTDS -ErrorAction SilentlyContinue).Status -ne "Running") {
    Write-Warning "AD DS is not running. CA must be installed after DC promotion. Skipping CA config."
} else {
    Install-AdcsCertificationAuthority `
        -CAType EnterpriseRootCA `
        -CACommonName "DOG-CA" `
        -CADistinguishedNameSuffix "DC=DOG,DC=local" `
        -CryptoProviderName "RSA#Microsoft Software Key Storage Provider" `
        -KeyLength 2048 `
        -HashAlgorithmName SHA256 `
        -ValidityPeriod Years `
        -ValidityPeriodUnits 5 `
        -DatabaseDirectory "C:\Windows\system32\CertLog" `
        -LogDirectory "C:\Windows\system32\CertLog" `
        -Force
    Write-Host "Certificate Authority installed and configured." -ForegroundColor Green
}

# ------------------------------
# SMB
# ------------------------------
Write-Host "`n=== Configuring SMB ===" -ForegroundColor Cyan
Set-Service -Name LanmanServer -StartupType Automatic
Start-Service LanmanServer
Enable-NetFirewallRule -DisplayGroup "File and Printer Sharing"
Write-Host "SMB configured." -ForegroundColor Green

# ------------------------------
# SSH
# ------------------------------
# 1. Setup paths
$installPath = "C:\Program Files\OpenSSH-Win64"
if (!(Test-Path $installPath)) { New-Item -ItemType Directory -Force -Path $installPath }

# 2. Updated URL (Points to the latest stable release)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$url = "https://github.com/PowerShell/Win32-OpenSSH/releases/latest/download/OpenSSH-Win64.zip"
$zipFile = "$env:TEMP\openssh.zip"

Write-Host "Downloading OpenSSH..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri $url -OutFile $zipFile -ErrorAction Stop
} catch {
    Write-Error "Download failed again. Please check your internet connection or if GitHub is blocked."
    return
}

# 3. Verify file exists before extracting
if (Test-Path $zipFile) {
    Write-Host "Extracting files..." -ForegroundColor Cyan
    Expand-Archive -Path $zipFile -DestinationPath "$env:TEMP\ssh_temp" -Force
    
    # Move files to Program Files
    Copy-Item -Path "$env:TEMP\ssh_temp\OpenSSH-Win64\*" -Destination $installPath -Recurse -Force
    
    # 4. Register the Service
    Set-Location $installPath
    if (Test-Path ".\install-sshd.ps1") {
        .\install-sshd.ps1
        Write-Host "Installation script executed successfully." -ForegroundColor Green
    } else {
        Write-Error "Could not find install-sshd.ps1 in $installPath"
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

Write-Host "`nAll services installed and enabled."

# Clear all Windows Event Logs
$logs = Get-WinEvent -ListLog * -ErrorAction SilentlyContinue

foreach ($log in $logs) {
    try {
        [System.Diagnostics.Eventing.Reader.EventLogSession]::GlobalSession.ClearLog($log.LogName)
        Write-Host "Cleared: $($log.LogName)" -ForegroundColor Green
    } catch {
        Write-Host "Skipped: $($log.LogName) - $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Write-Host "`nAll accessible logs cleared." -ForegroundColor Cyan


# ------------------------------
# Completion
# ------------------------------
Write-Host "`n=== All services processed. ===" -ForegroundColor Cyan
