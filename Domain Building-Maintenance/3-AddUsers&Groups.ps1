# ==============================
# Create AD Users and Groups
# ==============================

$DomainName     = "DOG.local"
$LLUserPassword = ConvertTo-SecureString "bb123#123#123" -AsPlainText -Force

$Users = @(
    @{ Username = "cdo";          Groups = "Domain Admins,Administrators" },
    @{ Username = "jsmith";       Groups = "WinRM Access,SSH Access,SMB Access" },
    @{ Username = "amarino";      Groups = "WinRM Access,SSH Access,SMB Access" },
    @{ Username = "johnlinux";    Groups = "WinRM Access,SSH Access,SMB Access" },
    @{ Username = "alvin";        Groups = "WinRM Access,SSH Access,SMB Access" },
    @{ Username = "theodore";     Groups = "WinRM Access,SSH Access,SMB Access" },
    @{ Username = "simon";        Groups = "WinRM Access,SSH Access,SMB Access" },
    @{ Username = "abauer";       Groups = "WinRM Access,SSH Access,SMB Access" },
    @{ Username = "linuswindows"; Groups = "WinRM Access,SSH Access,SMB Access" },
    @{ Username = "acapece";      Groups = "WinRM Access,SSH Access,SMB Access" },
    @{ Username = "mdesocio";     Groups = "WinRM Access,SSH Access,SMB Access" },
    @{ Username = "analyst1";     Groups = "WinRM Access,SSH Access,SMB Access" },
    @{ Username = "analyst2";     Groups = "WinRM Access,SSH Access,SMB Access" },
    @{ Username = "analyst3";     Groups = "WinRM Access,SSH Access,SMB Access" },
    @{ Username = "analyst4";     Groups = "WinRM Access,SSH Access,SMB Access" },
    @{ Username = "analyst5";     Groups = "WinRM Access,SSH Access,SMB Access" },
    @{ Username = "analyst6";     Groups = "WinRM Access,SSH Access,SMB Access" },
    @{ Username = "analyst7";     Groups = "WinRM Access,SSH Access,SMB Access" }
)

$CustomGroups = @(
    "WinRM Access",
    "SSH Access",
    "SMB Access"
)

Import-Module ActiveDirectory

$DomainDN = "DC=" + ($DomainName -replace "\.", ",DC=")

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

# ---- Create Users and Assign Groups ----
Write-Host "`n=== Creating Users ===" -ForegroundColor Cyan
foreach ($User in $Users) {
    $Username = $User.Username
    $Groups   = $User.Groups -split "," | ForEach-Object { $_.Trim() }

    if (-not (Get-ADUser -Filter { SamAccountName -eq $Username } -ErrorAction SilentlyContinue)) {
        New-ADUser `
            -SamAccountName        $Username `
            -UserPrincipalName     "$Username@$DomainName" `
            -Name                  $Username `
            -AccountPassword       $LLUserPassword `
            -ChangePasswordAtLogon $false `
            -PasswordNeverExpires  $true `
            -Enabled               $true `
            -Path                  "CN=Users,$DomainDN"

        Write-Host "Created user: $Username" -ForegroundColor Green
    } else {
        Write-Host "User '$Username' already exists. Skipping." -ForegroundColor Gray
    }

    foreach ($Group in $Groups) {
        try {
            Add-ADGroupMember -Identity $Group -Members $Username -ErrorAction Stop
            Write-Host "  Added $Username -> $Group" -ForegroundColor Green
        } catch {
            Write-Warning "  Could not add $Username to '$Group': $_"
        }
    }
}

Write-Host "`n=== Done ===" -ForegroundColor Cyan
