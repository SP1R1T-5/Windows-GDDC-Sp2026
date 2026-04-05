# Run Sysprep, If this step is Missed the VM won't connect to the domain
# The VM will reboot after Successful Completion of Sysprep
# Designed for Windows Server 2016 
# GDDC Sp26 - DC1 & DC2 Setup Script

Write-Host "`n=== Running Sysprep ===" -ForegroundColor Cyan
$SysprepPath = "C:\Windows\System32\Sysprep\sysprep.exe"

if (Test-Path $SysprepPath) {
    Write-Host "Starting Sysprep with OOBE, Generalize, and Shutdown..." -ForegroundColor Yellow
    Start-Process -FilePath $SysprepPath -ArgumentList "/oobe /generalize /shutdown /quiet" -Wait
    Write-Host "Sysprep completed." -ForegroundColor Green
} else {
    Write-Host "Sysprep not found at '$SysprepPath'." -ForegroundColor Red
}

#Jon Fortnite
