#Installing SSH Package
write-output "Downloading SSH..."
curl.exe -L "https://github.com/PowerShell/Win32-OpenSSH/releases/latest/download/OpenSSH-Win64.zip" -o "$env:TEMP\OpenSSH.zip"
Expand-Archive -Path "$env:TEMP\OpenSSH.zip" -DestinationPath "C:\Program Files\OpenSSH" -Force

#Starting SSH and enabling automatic startup
cd "C:\Program Files\OpenSSH\OpenSSH-Win64"
.\install-sshd.ps1
Start-Service sshd
Set-Service -Name sshd -StartupType Automatic

#Setting Firewall for SSH Connection
write-output "Creating Firewall Rule"
netsh advfirewall firewall add rule name="SSHD" dir=in action=allow protocol=TCP localport=22

#Showing SSH Running
Get-Service sshd

write-output "SSH setup complete, don't break it again >:(" 
pause
#Jon Fortnite
