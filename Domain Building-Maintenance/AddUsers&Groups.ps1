# ==============================
# Create AD Users and Groups
# ==============================

$DomainName = "DOG.local"
$LLUserPassword = ConvertTo-SecureString "bb123#123#123" -AsPlainText -Force

$Users = @(
    @{ Username = "cdo";       FullName = "cdo";            Groups = "Domain Admins,Administrators"; AccountPassword = $LLUserPassword },
    @{ Username = "jsmith";    FullName = "John Smith";     Groups = "Domain Admins";                AccountPassword = $LLUserPassword },
    @{ Username = "mjones";    FullName = "Mary Jones";     Groups = "Domain Users";                 AccountPassword = $LLUserPassword },
    @{ Username = "bwilson";   FullName = "Bob Wilson";     Groups = "Domain Users";                 AccountPassword = $LLUserPassword },
    @{ Username = "svcbackup"; FullName = "Backup Service"; Groups = "Backup Operators";             AccountPassword = $LLUserPassword },
    @{ Username = "helpdesk1"; FullName = "Help Desk 1";    Groups = "HelpDesk";                     AccountPassword = $LLUserPassword }
)

$CustomGroups = @(
    "HelpDesk",
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
