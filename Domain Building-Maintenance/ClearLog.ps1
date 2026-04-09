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
