Import-Module ActiveDirectory

$Users = Import-Csv -Delimiter "," -Path "C:\Users\Public\Storage\Employees.csv"

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
            -Name               $Displayname `
            -DisplayName        $Displayname `
            -SamAccountName     $SAM `
            -UserPrincipalName  $UPN `
            -GivenName          $Firstname `
            -Surname            $Lastname `
            -AccountPassword    $Password `
            -Enabled            $true `
            -Path               $OU `
            -ChangePasswordAtLogon $false `
            -PasswordNeverExpires  $true

        Write-Host "Created user: $SAM" -ForegroundColor Green
    } catch {
        Write-Warning "Failed to create user $SAM`: $_"
    }
}
