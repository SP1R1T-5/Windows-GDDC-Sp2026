$CustomGroups = @(
    "WinRM Access",
    "SSH Access",
    "SMB Access"
)

# Define domain information
$Domain = "dog.local"
$DomainDN = "DC=Dog,DC=local"
$UsersOU = "LDAP://OU=Users,$Dog.local"

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

#Declare username and password variables.
$users = Import-Csv "C:\Public\Storage\users.csv" -Header @("Name", "Password")

foreach ($user in $users) {
    # Pull the name and password from the current user entry
    $name = $user.Name.Trim()
    $password = $user.Password.Trim()
    
    # Split name into first and last name
    $nameParts = $name -split " "
    $first = $nameParts[0]
    $last = $nameParts[1]
    
    # Create login name (firstname.lastname format)
    $loginName = "$($first.ToLower()).$($last.ToLower())"
    
    Write-Host "Creating user: $loginName" -ForegroundColor Green
    
    try {
        # Get the Users OU
        $adsi = [ADSI]$UsersOU
        
        # Create the user object
        $newUser = $adsi.Create("user", "cn=$name")
        
        # Set user properties
        $newUser.Put("sAMAccountName", $loginName)
        $newUser.Put("userPrincipalName", "$loginName@$Domain")
        $newUser.Put("givenName", $first)
        $newUser.Put("sn", $last)
        $newUser.Put("displayName", $name)
        $newUser.SetInfo()
        
        # Set the password
        $newUser.SetPassword($password)
        
        # Enable the account
        $newUser.Put("userAccountControl", 512)  # 512 = Normal account
        $newUser.SetInfo()
        
        Write-Host "✓ Successfully created $loginName with assigned password" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ Failed to create $loginName : $_" -ForegroundColor Red
    }
}

Write-Host "`nUser creation complete!" -ForegroundColor Cyan
