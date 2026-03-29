# Import the Active Directory module
Import-Module ActiveDirectory

# Define the path to your CSV file
$csvPath = "C:\Users\Public\Storage\users.csv"

# Check if the file exists
if (-Not (Test-Path $csvPath)) {
    Write-Error "CSV file not found at $csvPath"
    return
}

# Import the CSV data. Since there are no headers, we assign them manually.
$users = Import-Csv -Path $csvPath -Header "Username", "Password"

foreach ($user in $users) {
    $samAccountName = $user.Username
    $password = $user.Password
    $upn = "$samAccountName@dog.local"
    
    # Convert the plain text password to a Secure String
    $securePassword = ConvertTo-SecureString $password -AsPlainText -Force

    try {
        # Check if user already exists
        Get-ADUser -Identity $samAccountName -ErrorAction Stop | Out-Null
        Write-Host "User '$samAccountName' already exists. Skipping..." -ForegroundColor Yellow
    }
    catch {
        # Create the new AD User
        Write-Host "Creating user: $samAccountName" -ForegroundColor Cyan
        
        New-ADUser -Name $samAccountName `
                   -SamAccountName $samAccountName `
                   -UserPrincipalName $upn `
                   -AccountPassword $securePassword `
                   -Enabled $true `
                   -ChangePasswordAtLogon $false
                   
        Write-Host "Successfully added $samAccountName" -ForegroundColor Green
    }
}
