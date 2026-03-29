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
            -Path        "CN=Users,$DomainDN"
        Write-Host "Created group: $Group" -ForegroundColor Green
    } else {
        Write-Host "Group '$Group' already exists. Skipping." -ForegroundColor Gray
    }
}


#Declare username and password variables.
$users = Import-Csv "C:\users.csv" -Header @("Name", "Password")

foreach ($user in $users) {
    # Pull the name and password from the current user entry
    $name = $user.Name.Trim()
    $password = $user.Password.Trim()
    
    # Split name into first and last name
    $first = $name.Split(" ")[0].ToLower()
    $last = $name.Split(" ")[1].ToLower()
    
    # Convert password to secure string
    $pwd = ConvertTo-SecureString -String $password -AsPlainText -Force
    
    Write-Host "Creating user: $first.$last" -ForegroundColor Green
    
    # Create the AD user with the paired password
    try {
        New-ADUser -Name "$first $last" `
            -GivenName "$first" `
            -Surname "$last" `
            -SamAccountName "$first.$last" `
            -Path "OU=IT, DC=MATT, DC=corp" `
            -PasswordNeverExpires $true `
            -AccountPassword $pwd `
            -Enabled $true
        
        Write-Host "✓ Successfully created $first.$last with assigned password" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ Failed to create $first.$last : $_" -ForegroundColor Red
    }
}

Write-Host "`nUser creation complete!" -ForegroundColor Cyan
