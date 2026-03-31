Import-Module ActiveDirectory

$Users = Import-Csv -Delimiter "," -Path "C:\Users\Public\Storage\Employees.csv"

# --- NEW: Extract unique OUs from the CSV and create them if they don't exist ---
$UniqueContainers = $Users.Container | Select-Object -Unique

foreach ($Container in $UniqueContainers) {
    # Clean up the container string just like in the user loop
    $OU_DN = $Container.Trim() -replace ",\s+", ","
    
    try {
        # Check if the OU already exists
        Get-ADOrganizationalUnit -Identity $OU_DN -ErrorAction Stop | Out-Null
    } catch {
        # If it fails, the OU doesn't exist. Parse the DN to get the Name and Path.
        # Example: OU=Engineering, DC=dog, DC=local -> Name: Engineering, Path: DC=dog, DC=local
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

foreach ($User in $Users) {
    $SAM         = $User.Username
    $Displayname = $User.Displayname
    $Firstname   = $User.Firstname
    $Lastname    = $User.Lastname
    $OU          = $User.Container.Trim() -replace ",\s+", ","   # <-- strips extra spaces
    $UPN         = $User.Username + "@dog.local"
    $Password    = ConvertTo-SecureString $User.Password -AsPlainText -Force

    # Verify the OU exists before trying to create the user
    try {
        Get-ADOrganizationalUnit -Identity $OU -ErrorAction Stop | Out-Null
    } catch {
        Write-Warning "OU not found: '$OU' — skipping user $SAM"
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

        Write-Host "Created user: $SAM" -ForegroundColor Green
    } catch {
        Write-Warning "Failed to create user $SAM`: $_"
    }
}S
