$CustomGroups = @(
    "WinRM Access",
    "SSH Access",
    "SMB Access"
)

# Define domain information
$Domain = "dog.local"
$DomainDN = "DC=Dog,DC=local"
$UsersOU = "LDAP://OU=Users,$DomainDN"

# ---- Create Custom Groups ----
Write-Host "`n=== Creating Groups ===" -ForegroundColor Cyan
foreach ($Group in $CustomGroups) {
    try {
        $adsi = [ADSI]$UsersOU
        $newGroup = $adsi.Create("group", "cn=$Group")
        $newGroup.Put("objectClass", "group")
        $newGroup.Put("groupType", -2147483646)  # Universal Security Group
        $newGroup.SetInfo()
        Write-Host "Created group: $Group" -ForegroundColor Green
    }
    catch {
        Write-Host "Group '$Group' already exists or error: $_" -ForegroundColor Gray
    }
}

# ---- Create Users ----
Write-Host "`n=== Creating Users ===" -ForegroundColor Cyan

# Import users from CSV file (username, password format)
$userLines = Get-Content "C:\Users\Public\Storage\users.csv"
foreach ($line in $userLines) {
    # Skip empty lines
    if ([string]::IsNullOrWhiteSpace($line)) {
        continue
    }
    
    # Split the line by comma
    $parts = $line -split ","
    $username = $parts[0].Trim()
    $password = $parts[1].Trim()
    
    Write-Host "Creating user: $username" -ForegroundColor Green
    
    try {
        # Get the Users container
        $adsi = [ADSI]$UsersPath
        
        # Check if user already exists
        $existingUser = $adsi.Children | Where-Object { $_.sAMAccountName -eq $username }
        if ($null -ne $existingUser) {
            Write-Host "  User '$username' already exists. Skipping." -ForegroundColor Yellow
            continue
        }
        
        # Create the user object
        $newUser = $adsi.Create("user", "cn=$username")
        
        # Set user properties
        $newUser.Put("sAMAccountName", $username)
        $newUser.Put("userPrincipalName", "$username@$Domain")
        $newUser.Put("displayName", $username)
        $newUser.SetInfo()
        
        # Set the password
        $newUser.SetPassword($password)
        
        # Enable the account (512 = Normal account, enabled)
        $newUser.Put("userAccountControl", 512)
        $newUser.SetInfo()
        
        Write-Host "  ✓ Successfully created $username" -ForegroundColor Green
    }
    catch {
        Write-Host "  ✗ Failed to create $username : $_" -ForegroundColor Red
    }
}

Write-Host "`nUser creation complete!" -ForegroundColor Cyan
