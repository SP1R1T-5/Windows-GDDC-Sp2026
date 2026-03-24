# ==============================
# Install and Enable Services
# ==============================

Import-Module ServerManager

# ------------------------------
# LDAP (Active Directory)
# ------------------------------
# Already enabled when AD DS is installed
Write-Host "LDAP is active via Active Directory Domain Services"

# ------------------------------
# WinRM
# ------------------------------
Enable-PSRemoting -Force
Set-Service WinRM -StartupType Automatic
Start-Service WinRM


# Allow WinRM through firewall
Set-NetFirewallRule -Name "WINRM-HTTP-In-TCP" -Enabled True

# ------------------------------
# RDP
# ------------------------------
# Enable Remote Desktop
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" `
    -Name "fDenyTSConnections" -Value 0

# Allow RDP in firewall
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"

# ------------------------------
# SMB
# ------------------------------
# Ensure SMB service is running
Set-Service -Name LanmanServer -StartupType Automatic
Start-Service LanmanServer

# ------------------------------
# SSH
# ------------------------------
Start-Service sshd
Set-Service -Name sshd -StartupType Automatic

# Allow SSH through firewall
New-NetFirewallRule -Name "OpenSSH-Server-In-TCP" `
    -DisplayName "OpenSSH Server (TCP-In)" `
    -Enabled True `
    -Direction Inbound `
    -Protocol TCP `
    -Action Allow `
    -LocalPort 22

Write-Host "`nAll services installed and enabled."
