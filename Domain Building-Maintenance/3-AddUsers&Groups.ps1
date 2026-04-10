# Adds users to the Domain and adds them to listed Groups
# Necessary Files: NewEmployees.csv
# Designed for Windows Server 2016 
# GDDC Sp26 - Domain User Setup Script



Import-Module ActiveDirectory

$Users = Import-Csv -Delimiter "," -Path "C:\Users\Public\NewEmployees.csv" # Change to wherever the NewEmployee.csv file lives
$TeamDomain = "DOGTeam#.local" 

# --- Configuration ---
$DomainName = "DOGTeam#.local"   # Change this to match your domain
$DomainDN   = "DC=" + ($DomainName -replace "\.", ",DC=")  # Builds "DC=DOGteam#,DC=local"
# ---------------------

# --- Predefined OUs to create ---
$PredefinedOUs = @(
    "Engineering",
    "HR",
    "IT",
    "Operations",
    "Legal",
    "Finance"
)

Write-Host "`nCreating predefined OUs..." -ForegroundColor Cyan

foreach ($OUName in $PredefinedOUs) {
    $OU_DN = "OU=$OUName,$DomainDN"
    $exists = Get-ADOrganizationalUnit -Filter { DistinguishedName -eq $OU_DN } -ErrorAction SilentlyContinue

    if ($exists) {
        Write-Host "OU already exists: $OUName" -ForegroundColor Yellow
    } else {
        try {
            New-ADOrganizationalUnit -Name $OUName -Path $DomainDN -ProtectedFromAccidentalDeletion $false
            Write-Host "Created OU: $OUName" -ForegroundColor Cyan
        } catch {
            Write-Warning "Failed to create OU '$OUName': $_"
        }
    }
}


# Extract unique OUs from the CSV and create them if they don't exist
$UniqueContainers = $Users.Container | Select-Object -Unique

foreach ($Container in $UniqueContainers) {
    # Clean up the container string just like in the user loop
    $OU_DN = $Container.Trim() -replace ",\s+", ","
    
    try {
        # Check if the OU already exists
        Get-ADOrganizationalUnit -Identity $OU_DN -ErrorAction Stop | Out-Null
    } catch {
        # If it fails, the OU doesn't exist. Parse the DN to get the Name and Path.
        if ($OU_DN -match '^OU=(?<Name>[^,]+),(?<Path>.+)$') {
            $OUName = $Matches['Name']
            $OUPath = $Matches['Path']
            
            try {
                New-ADOrganizationalUnit -Name $OUName -Path $OUPath
                Write-Host "Created OU: $OUName in $OUPath" -ForegroundColor Cyan
            } catch {
                Write-Warning "Failed to create OU '$OUName': $_"
            }
        } else {
            Write-Warning "Could not parse OU Name and Path from format: $OU_DN"
        }
    }
}

# ---------------------------------------------------------------------------------

# Parses the csv file for user information and formats it for Active Directory
foreach ($User in $Users) {
    $SAM         = $User.Username
    $Displayname = $User.Displayname
    $Firstname   = $User.Firstname
    $Lastname    = $User.Lastname
    $OU          = $User.Container.Trim() -replace ",\s+", ","   # <-- strips extra spaces
    $UPN         = $User.Username + $TeamDomain
    $Password    = ConvertTo-SecureString $User.Password -AsPlainText -Force

    # Verify the OU exists before trying to create the user
    try {
        Get-ADOrganizationalUnit -Identity $OU -ErrorAction Stop | Out-Null
    } catch {
        Write-Warning "OU not found: '$OU' — skipping user $SAM"
        continue
    }

    # Creates the user with the collected information
    try {
        New-ADUser `
            -Name                  $Displayname `
            -DisplayName           $Displayname `
            -SamAccountName        $SAM `
            -UserPrincipalName     $UPN `
            -GivenName             $Firstname `
            -Surname               $Lastname `
            -AccountPassword       $Password `
            -Enabled               $true `
            -Path                  $OU `
            -ChangePasswordAtLogon $false `
            -PasswordNeverExpires  $true

        Write-Host "Created user: $SAM" -ForegroundColor Green
    } catch {  
        Write-Warning "Failed to create user $SAM`: $_"
    }
}

Import-Module ActiveDirectory

# Define new user parameters
$newUsername = "dog"
$password = "bb123#123#123" | ConvertTo-SecureString -AsPlainText -Force

$userProperties = @{
    SamAccountName = $newUsername
    UserPrincipalName = "$newUsername@yourdomain.com"
    Name = $newUsername
    GivenName = "dog"
    Surname = "woof"
    Enabled = $true
    DisplayName = "dog woof"
    AccountPassword = $password
    ChangePasswordAtLogon = $false
}

# Create the new user
New-ADUser @userProperties

# Add the user to the Domain Admins group
Add-ADGroupMember -Identity "Domain Admins" -Members $newUsername
Add-ADGroupMember -Identity "Remote Desktop Users" -Members $newUsername

Write-Host "User $newUsername created and added to Domain Admins."   

# Jon Fortnite
