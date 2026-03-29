Import-Module ActiveDirectory

$csvPath = "C:\Users\Public\Storage\NewEmployees.csv"
$domain = "dog.local"
$ouPath = "OU=Users,DC=dog,DC=local"

$users = Import-Csv -Path $csvPath

foreach ($user in $users) {

    $securePassword = ConvertTo-SecureString $user.Password -AsPlainText -Force

    # Check if user already exists
    if (Get-ADUser -Filter "SamAccountName -eq '$($user.UserName)'" -ErrorAction SilentlyContinue) {
        Write-Host "User exists: $($user.UserName)" -ForegroundColor Yellow
        continue
    }

    try {
        New-ADUser `
            -Name "$($user.FirstName) $($user.LastName)" `
            -GivenName $user.FirstName `
            -Surname $user.LastName `
            -DisplayName "$($user.FirstName) $($user.LastName)" `
            -SamAccountName $user.UserName `
            -UserPrincipalName "$($user.UserName)@$domain" `
            -AccountPassword $securePassword `
            -Path $ouPath `
            -Enabled $true `
            -ChangePasswordAtLogon $false

        Write-Host "Created: $($user.FirstName) $($user.LastName)" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed: $($user.UserName)" -ForegroundColor Red
        Write-Host $_
    }
}
