# Check if Active Directory module is available
if (!(Get-Module -ListAvailable ActiveDirectory)) {
    Write-Error "The Active Directory module is not installed. Please run: Install-WindowsFeature RSAT-AD-PowerShell"
    return
}

Import-Module ActiveDirectory

$csvPath = "C:\Users\Public\Storage\users.csv"

# Verify file exists
if (-Not (Test-Path $csvPath)) {
    Write-Error "Cannot find $csvPath. Ensure the file is in the same directory as this script."
    return
}

# Load the users from the CSV (Headerless)
$users = Import-Csv -Path $csvPath -Header "Username", "Password"

foreach ($user in $users) {
    $sam = $user.Username
    $pass = $user.Password
    $upn = "$sam@dog.local"
    
    # Secure the password
    $securePass = ConvertTo-SecureString $pass -AsPlainText -Force

    try {
        # Attempt to create the user
        New-ADUser -Name $sam `
                   -SamAccountName $sam `
                   -UserPrincipalName $upn `
                   -AccountPassword $securePass `
                   -Enabled $true `
                   -ChangePasswordAtLogon $false
        
        Write-Host "Successfully created user: $sam" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to create user $sam. It may already exist or there is a permission issue." -ForegroundColor Red
        Write-Error $_.Exception.Message
    }
}
