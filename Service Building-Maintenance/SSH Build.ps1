# Download the ZIP
curl.exe -L -o "C:\Temp\OpenSSH-Win64.zip" "https://github.com/PowerShell/Win32-OpenSSH/releases/download/10.0.0.0p2-Preview/OpenSSH-Win64.zip"

# Create destination folder
New-Item -ItemType Directory -Force -Path "C:\Program Files\OpenSSH"

# Extract the ZIP
Expand-Archive -Path "C:\Temp\OpenSSH-Win64.zip" -DestinationPath "C:\Program Files\OpenSSH" -Force

# Move files up if extracted into a subdirectory
Move-Item -Path "C:\Program Files\OpenSSH\OpenSSH-Win64\*" -Destination "C:\Program Files\OpenSSH\" -Force

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
