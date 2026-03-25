# ==============================
# Install and Enable Services
# ==============================

Import-Module ServerManager

# ------------------------------
# IIS (Web Server)
# ------------------------------
Write-Host "Installing IIS..."
Install-WindowsFeature -Name Web-Server -IncludeManagementTools

# Ensure IIS service is running
Set-Service -Name W3SVC -StartupType Automatic
Start-Service W3SVC

# Allow HTTP/HTTPS through firewall
Enable-NetFirewallRule -DisplayGroup "World Wide Web Services (HTTP)"
Enable-NetFirewallRule -DisplayGroup "World Wide Web Services (HTTPS)"


# ------------------------------
# RDP
# ------------------------------
Write-Host "Enabling RDP..."

Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" `
    -Name "fDenyTSConnections" -Value 0

Set-Service -Name TermService -StartupType Automatic
Start-Service TermService

Enable-NetFirewallRule -DisplayGroup "Remote Desktop"


# ------------------------------
# CA (Active Directory Certificate Services)
# ------------------------------
Write-Host "Installing Certificate Authority..."

Install-WindowsFeature ADCS-Cert-Authority -IncludeManagementTools

# Configure CA (Basic setup)
Install-AdcsCertificationAuthority `
    -CAType EnterpriseRootCA `
    -CryptoProviderName "RSA#Microsoft Software Key Storage Provider" `
    -KeyLength 2048 `
    -HashAlgorithmName SHA256 `
    -ValidityPeriod Years `
    -ValidityPeriodUnits 5 `
    -Force

Write-Host "Certificate Authority installed and configured"


# ------------------------------
# SMB
# ------------------------------
Write-Host "Configuring SMB..."

Set-Service -Name LanmanServer -StartupType Automatic
Start-Service LanmanServer

# Enable SMB Shares firewall rules
Enable-NetFirewallRule -DisplayGroup "File and Printer Sharing"


# ------------------------------
# SSH
# ------------------------------
Write-Host "Installing SSH..."

Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0

Set-Service -Name sshd -StartupType Automatic
Start-Service sshd

# Firewall rule for SSH
New-NetFirewallRule -Name "SSHD" `
    -DisplayName "OpenSSH Server (SSH)" `
    -Enabled True `
    -Direction Inbound `
    -Protocol TCP `
    -Action Allow `
    -LocalPort 22

Get-Service sshd


# ------------------------------
# Completion
# ------------------------------
Write-Host "`nAll services installed and enabled."
