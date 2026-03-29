# Import AD module
Import-Module ActiveDirectory

# Config
$csvPath = "C:\Users\Public\Storage\users.csv"
$domain = "dog.local"
$ouPath = "OU=Users,DC=dog,DC=local"

# Import CSV (no headers, so define them)
$users = Import-Csv -Path $csvPath -Header Username,Password

foreach ($user in $users) {

    $securePassword = ConvertTo-SecureString $user.Password -AsPlainText -Force

    # Skip if user already exists
    if (Get-ADUser -Filter "SamAccountName -eq '$($user.Username)'" -ErrorAction SilentlyContinue) {
        Write-Host "User already exists: $($user.Username)" -ForegroundColor Yellow
        continue
    }

    try {
        New-ADUser `
            -Name $user.Username `
            -SamAccountName $user.Username `
            -UserPrincipalName "$($user.Username)@$domain" `
            -AccountPassword $securePassword `
            -Path $ouPath `
            -Enabled $true `
            -ChangePasswordAtLogon $false

        Write-Host "Created user: $($user.Username)" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed: $($user.Username)" -ForegroundColor Red
        Write-Host $_
    }
}
