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
$usernames = Get-Content "C:\Users\Matt\Desktop\users.txt"
$passwords = bb123#123#123

# Ensure there are the same number of usernames and passwords
if ($usernames.Count -ne $passwords.Count) {
    Write-Error "The number of usernames and passwords does not match."
    exit
}

# Loop through usernames and assign a corresponding password
for ($i = 0; $i -lt $usernames.Count; $i++) {
    $u = $usernames[$i]
    $p = $passwords[$i]
    $pwd = ConvertTo-SecureString -String $p -AsPlainText -Force

    $first = $u.Split(" ")[0].ToLower()
    $last = $u.Split(" ")[1].ToLower()

    New-ADUser -Name "$first $last" -GivenName "$first" -Surname "$last" -SamAccountName "$first.$last" -Path "OU=IT, DC=MATT, DC=corp" -PasswordNeverExpires $true -AccountPassword $pwd -Enabled $true
}
