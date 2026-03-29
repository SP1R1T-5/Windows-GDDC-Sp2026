$CustomGroups = @(
    "WinRM Access",
    "SSH Access",
    "SMB Access"
)
Import-Module ActiveDirectory

# ---- Create Custom Groups ----
Write-Host "`n=== Creating Groups ===" -ForegroundColor Cyan
foreach ($Group in $CustomGroups) {
    if (-not (Get-ADGroup -Filter { Name -eq $Group } -ErrorAction SilentlyContinue)) {
        New-ADGroup `
            -Name        $Group `
            -GroupScope  Global `
            -GroupCategory Security `
            -Path        "CN=Users,DC=Dog,DC=local"
        Write-Host "Created group: $Group" -ForegroundColor Green
    } else {
        Write-Host "Group '$Group' already exists. Skipping." -ForegroundColor Gray
    }
}

# ---- Create Users ----
Write-Host "`n=== Creating Users ===" -ForegroundColor Cyan

#Declare username and password variables.
$users = Import-Csv "C:Public\Storage\users.csv" -Header @("Name", "Password")

foreach ($user in $users) {
    # Pull the name and password from the current user entry
    $name = $user.Name.Trim()
    $password = $user.Password.Trim()
    
    # Split name into first and last name
    $nameParts = $name -split " "
    $first = $nameParts[0].ToLower()
    $last = $nameParts[1].ToLower()
    
    # Create SamAccountName (firstname.lastname format)
    $samAccountName = "$first.$last"
    
    # Convert password to secure string
    $pwd = ConvertTo-SecureString -String $password -AsPlainText -Force
    
    Write-Host "Creating user: $samAccountName" -ForegroundColor Green
    
    # Create the AD user with the paired password
    try {
        New-ADUser -Name "$name" `
            -SamAccountName "$samAccountName" `
            -Path "OU=Users,DC=Dog,DC=local" `
            -PasswordNeverExpires $true `
            -AccountPassword $pwd `
            -Enabled $true
                    
        Write-Host "✓ Successfully created $samAccountName with assigned password" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ Failed to create $samAccountName : $_" -ForegroundColor Red
    }

Write-Host "`nUser creation complete!" -ForegroundColor Cyan
