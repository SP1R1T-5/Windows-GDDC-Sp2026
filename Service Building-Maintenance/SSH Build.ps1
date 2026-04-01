# Download the ZIP
Import-Module BitsTransfer
Start-BitsTransfer -Source "https://github.com/PowerShell/Win32-OpenSSH/releases/download/10.0.0.0p2-Preview/OpenSSH-Win64.zip" -Destination "C:\Program Files\OpenSSH\OpenSSH-Win64.zip"

# Extract the ZIP
Expand-Archive -Path "C:\Program Files\OpenSSH\OpenSSH-Win64.zip" -DestinationPath "C:\Program Files\OpenSSH\OpenSSH-Win64" -Force

# Run the install script
Set-Location "C:\Program Files\OpenSSH"
powershell.exe -ExecutionPolicy Bypass -File ".\install-sshd.ps1"

# Set the SSH services to start automatically
Set-Service -Name sshd -StartupType Automatic
Set-Service -Name ssh-agent -StartupType Automatic

# Start the services
Start-Service sshd
Start-Service ssh-agent

# Open firewall port 22
New-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -DisplayName "OpenSSH Server (sshd)" -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
