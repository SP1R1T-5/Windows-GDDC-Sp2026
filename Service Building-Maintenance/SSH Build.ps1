# 1. Create the directory first (otherwise BitsTransfer might fail)
$destPath = "C:\Program Files\OpenSSH"
if (!(Test-Path $destPath)) { New-Item -ItemType Directory -Path $destPath }

# 2. Download the ZIP
Import-Module BitsTransfer
Start-BitsTransfer -Source "https://github.com/PowerShell/Win32-OpenSSH/releases/download/v9.5.0.0p1-Beta/OpenSSH-Win64.zip" -Destination "$destPath\OpenSSH-Win64.zip"

# 3. Extract the ZIP
# Note: Expand-Archive often creates a subfolder (e.g., OpenSSH-Win64\OpenSSH-Win64)
Expand-Archive -Path "$destPath\OpenSSH-Win64.zip" -DestinationPath $destPath -Force

# 4. Run the install script from the correct sub-directory
$installScript = Get-ChildItem -Path $destPath -Filter "install-sshd.ps1" -Recurse | Select-Object -First 1
if ($installScript) {
    Set-Location $installScript.Directory.FullName
    & .\install-sshd.ps1
}

# 5. Set services to Automatic and Start
Get-Service sshd, ssh-agent | Set-Service -StartupType Automatic
Start-Service sshd, ssh-agent

# 6. Open Firewall Port 22
if (!(Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -DisplayName "OpenSSH Server (sshd)" -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
}
