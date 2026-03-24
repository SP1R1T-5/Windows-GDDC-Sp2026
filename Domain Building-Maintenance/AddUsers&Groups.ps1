# ==============================
# Create AD Users and Groups
# ==============================

$DomainName = "DOG.local"
$LLUserPassword = ConvertTo-SecureString "bb123#123#123" -AsPlainText -Force

$Users = @(
    @{ Username = "cdo";       FullName = "cdo";            Groups = "Domain Admins,Administrators"; AccountPassword = $LLUserPassword },
    @{ Username = "jsmith";    FullName = "jsmith";     Groups = "Domain Admins"; AccountPassword = $LLUserPassword },
    @{ Username = "amarino";    FullName = "amarino";     Groups = "Domain Users"; AccountPassword = $LLUserPassword },
    @{ Username = "johnlinux";   FullName = "johnlinux";     Groups = "Domain Users"; AccountPassword = $LLUserPassword },
    @{ Username = "alvin"; FullName = "alvin"; Groups = "Backup Operators"; AccountPassword = $LLUserPassword },
    @{ Username = "theodore";   FullName = "theodore";     Groups = "Domain Users"; AccountPassword = $LLUserPassword },
    @{ Username = "simon";   FullName = "simon";     Groups = "Domain Users"; AccountPassword = $LLUserPassword },
    @{ Username = "abauer";   FullName = "abauer";     Groups = "Domain Users"; AccountPassword = $LLUserPassword },
    @{ Username = "linuswindows";   FullName = "linuswindows";     Groups = "Domain Users"; AccountPassword = $LLUserPassword },
    @{ Username = "acapece";   FullName = "acapece";     Groups = "Domain Users"; AccountPassword = $LLUserPassword },
    @{ Username = "mdesocio";   FullName = "mdesocio";     Groups = "Domain Users"; AccountPassword = $LLUserPassword },
    @{ Username = "analyst1";   FullName = "analyst1";     Groups = "Domain Users"; AccountPassword = $LLUserPassword },
    @{ Username = "analyst2";   FullName = "analyst2";     Groups = "Domain Users"; AccountPassword = $LLUserPassword },
    @{ Username = "analyst3";   FullName = "analyst3";     Groups = "Domain Users"; AccountPassword = $LLUserPassword },
    @{ Username = "analyst4";   FullName = "analyst4";     Groups = "Domain Users"; AccountPassword = $LLUserPassword },
    @{ Username = "analyst5";   FullName = "analyst5";     Groups = "Domain Users"; AccountPassword = $LLUserPassword },
    @{ Username = "analyst6";   FullName = "analyst6";     Groups = "Domain Users"; AccountPassword = $LLUserPassword },
    @{ Username = "analyst7";   FullName = "analyst7";     Groups = "Domain Users"; AccountPassword = $LLUserPassword },
    @{ Username = "theodore"; FullName = "theodore";    Groups = "Domain Users"; AccountPassword = $LLUserPassword }
)

$CustomGroups = @(
    "WinRM Access",
    "SSH Access",
    "SMB Access"
)

Import-Module ActiveDirectory

$DomainDN = "DC=" + ($DomainName -replace "\.", ",DC=")

Write-Host "`n=== Creating Groups ===" -ForegroundColor Cyan
foreach ($Group in $CustomGroups) {
    if (-not (Get-ADGroup -Filter { Name -eq $Group } -ErrorAction SilentlyContinue)) {
        New-ADGroup -Name $Group -GroupScope Global -GroupCategory Security -Path "CN=Users,$DomainDN"
        Write-Host "Created group: $Group" -ForegroundColor Green
    } else {
        Write-Host "Group '$Group' exists. Skipping." -ForegroundColor Gray
    }
}

Write-Host "`n=== Creating Users ===" -ForegroundColor Cyan
foreach ($User in $Users) {
    $Username = $User.Username
    $FullName = $User.FullName
    $Password = $User.AccountPassword
    $Groups   = $User.Groups -split "," | ForEach-Object { $_.Trim() }

    if (-not (Get-ADUser -Filter { SamAccountName -eq $Username } -ErrorAction SilentlyContinue)) {
        New-ADUser `
            -SamAccountName        $Username `
            -UserPrincipalName     "$Username@$DomainName" `
            -Name                  $FullName `
            -GivenName             ($FullName.Split(" ")[0]) `
            -Surname               ($FullName.Split(" ")[-1]) `
            -AccountPassword       $Password `
            -ChangePasswordAtLogon $false `
            -Enabled               $true `
            -Path                  "CN=Users,$DomainDN"

        Write-Host "Created user: $Username" -ForegroundColor Green
    } else {
        Write-Host "User '$Username' exists. Skipping." -ForegroundColor Gray
    }

    foreach ($Group in $Groups) {
        try {
            Add-ADGroupMember -Identity $Group -Members $Username
            Write-Host "Added $Username to $Group" -ForegroundColor Green
        } catch {
            Write-Warning "Failed to add $Username to $Group"
        }
    }
}

Write-Host "`n=== Done ===" -ForegroundColor Cyan
