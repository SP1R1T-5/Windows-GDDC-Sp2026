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
Write-Host "`n=== Installing OpenSSH Server ===" -ForegroundColor Cyan

# Check if already installed
$sshCapability = Get-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 -ErrorAction SilentlyContinue

if ($sshCapability.State -eq "Installed") {
    Write-Host "OpenSSH Server already installed." -ForegroundColor Yellow
} else {
    Write-Host "Attempting online install of OpenSSH..."
    $result = Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 -ErrorAction SilentlyContinue

    # Fallback: source from local Windows image (no internet needed)
    if ((Get-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0).State -ne "Installed") {
        Write-Warning "Online install failed. Attempting install from local Windows image..."
        Add-WindowsCapability -Online `
            -Name OpenSSH.Server~~~~0.0.1.0 `
            -Source "C:\Windows\WinSxS" `
            -LimitAccess  # Prevents reaching out to Windows Update
    }
}

# Confirm install before trying to start
if ((Get-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0).State -eq "Installed") {
    Set-Service -Name sshd -StartupType Automatic
    Start-Service sshd

    # Use PowerShell firewall cmdlet instead of netsh (more reliable on Server)
    if (-not (Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -Name "OpenSSH-Server-In-TCP" `
            -DisplayName "OpenSSH Server (sshd)" `
            -Enabled True `
            -Direction Inbound `
            -Protocol TCP `
            -Action Allow `
            -LocalPort 22
    }
    Get-Service sshd
    Write-Host "SSH installed and running." -ForegroundColor Green
} else {
    Write-Warning "OpenSSH Server could not be installed. Check Windows Update connectivity or mount the Server ISO as a source."
}

# ------------------------------
# Completion
# ------------------------------
Write-Host "`n=== All services processed. ===" -ForegroundColor Cyan
