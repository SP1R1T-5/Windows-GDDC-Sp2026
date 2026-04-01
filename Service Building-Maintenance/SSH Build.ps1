# ------------------------------
# SSH Server Installation
# ------------------------------

Write-Output "Checking OpenSSH Server capability..."

$sshCap = Get-WindowsCapability -Online |
    Where-Object Name -like 'OpenSSH.Server*'

if (-not $sshCap) {
    Write-Error "OpenSSH Server capability not found on this OS."
    exit 1
}

if ($sshCap.State -ne "Installed") {
    Write-Output "OpenSSH Server not installed. Attempting installation..."

    try {
        Add-WindowsCapability -Online -Name $sshCap.Name -ErrorAction Stop
        Write-Output "OpenSSH Server installed successfully."
    }
    catch {
        Write-Error "ERROR: Unable to download OpenSSH Server."
        Write-Error "Likely causes:"
        Write-Error " - Windows Update disabled"
        Write-Error " - WSUS blocking Optional Features"
        Write-Error " - No internet access"
        Write-Error "Manual installation may be required."
        exit 1
    }
}
else {
    Write-Output "OpenSSH Server already installed."
}

# ------------------------------
# SSH Service Configuration
# ------------------------------

if (Get-Service sshd -ErrorAction SilentlyContinue) {
    Write-Output "Configuring SSH service..."
    Start-Service sshd
    Set-Service sshd -StartupType Automatic
}
else {
    Write-Error "SSHD service not found. Installation did not complete."
    exit 1
}

# ------------------------------
# Firewall Rule
# ------------------------------

if (-not (Get-NetFirewallRule -Name "SSHD" -ErrorAction SilentlyContinue)) {
    Write-Output "Creating firewall rule for SSH..."
    New-NetFirewallRule `
        -Name "SSHD" `
        -DisplayName "OpenSSH Server" `
        -Direction Inbound `
        -Protocol TCP `
        -LocalPort 22 `
        -Action Allow
}
else {
    Write-Output "Firewall rule already exists."
}

# ------------------------------
# Verification
# ------------------------------

Write-Output "SSH service status:"
Get-Service sshd
