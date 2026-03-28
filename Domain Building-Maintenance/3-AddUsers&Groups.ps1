#Requires -Module ActiveDirectory
#Requires -RunAsAdministrator

# ============================================================
# AD User Creation & Group Assignment Script (Improved)
# ============================================================

param(
    [string]$Domain = "dog.local",
    [string]$OUPath = "OU=Users,DC=dog,DC=local",
    [string]$DefaultPassword = "ChangeMe123!",
    [switch]$Verbose
)

$SecurePassword = ConvertTo-SecureString $DefaultPassword -AsPlainText -Force

# ── User definitions ────────────────────────────────────────
$Users = @(
    @{ Username = "cdo";          Groups = @("Domain Admins", "Administrators") },
    @{ Username = "jsmith";       Groups = @("WinRM Access", "SSH Access", "SMB Access") },
    @{ Username = "amarino";      Groups = @("WinRM Access", "SSH Access", "SMB Access") },
    @{ Username = "johnlinux";    Groups = @("WinRM Access", "SSH Access", "SMB Access") },
    @{ Username = "alvin";        Groups = @("WinRM Access", "SSH Access", "SMB Access") },
    @{ Username = "theodore";     Groups = @("WinRM Access", "SSH Access", "SMB Access") },
    @{ Username = "simon";        Groups = @("WinRM Access", "SSH Access", "SMB Access") },
    @{ Username = "abauer";       Groups = @("WinRM Access", "SSH Access", "SMB Access") },
    @{ Username = "linuswindows"; Groups = @("WinRM Access", "SSH Access", "SMB Access") },
    @{ Username = "acapece";      Groups = @("WinRM Access", "SSH Access", "SMB Access") },
    @{ Username = "mdesocio";     Groups = @("WinRM Access", "SSH Access", "SMB Access") },
    @{ Username = "analyst1";     Groups = @("WinRM Access", "SSH Access", "SMB Access") },
    @{ Username = "analyst2";     Groups = @("WinRM Access", "SSH Access", "SMB Access") },
    @{ Username = "analyst3";     Groups = @("WinRM Access", "SSH Access", "SMB Access") },
    @{ Username = "analyst4";     Groups = @("WinRM Access", "SSH Access", "SMB Access") },
    @{ Username = "analyst5";     Groups = @("WinRM Access", "SSH Access", "SMB Access") },
    @{ Username = "analyst6";     Groups = @("WinRM Access", "SSH Access", "SMB Access") },
    @{ Username = "analyst7";     Groups = @("WinRM Access", "SSH Access", "SMB Access") }
)

# ── Helper functions ────────────────────────────────────────
function Write-Status {
    param([string]$Msg, [string]$Status = "INFO")
    $color = @{
        "✓" = "Green"
        "!" = "Red"
        "~" = "Yellow"
        ">" = "Cyan"
        "INFO" = "Cyan"
    }[$Status]
    Write-Host "[$Status] $Msg" -ForegroundColor $color
}

function Ensure-GroupExists {
    param([string]$GroupName)
    $group = Get-ADGroup -Filter { Name -eq $GroupName } -ErrorAction SilentlyContinue
    if ($group) {
        return $true
    }
    try {
        New-ADGroup -Name $GroupName `
                    -GroupScope Global `
                    -GroupCategory Security `
                    -Path $OUPath `
                    -Description "Auto-created by provisioning script"
        Write-Status "Created group: $GroupName" "✓"
        return $true
    } catch {
        Write-Status "Failed to create group '$GroupName': $($_.Exception.Message)" "!"
        return $false
    }
}

function New-ADUserSafe {
    param([string]$Username, [securestring]$Password, [string]$Domain, [string]$OUPath)
    
    try {
        New-ADUser -SamAccountName $Username `
                   -UserPrincipalName "$Username@$Domain" `
                   -Name $Username `
                   -AccountPassword $Password `
                   -Enabled $true `
                   -Path $OUPath `
                   -ChangePasswordAtLogon $true `
                   -ErrorAction Stop
        Write-Status "Created user: $Username" "✓"
        return $true
    } catch {
        Write-Status "Failed to create user '$Username': $($_.Exception.Message)" "!"
        return $false
    }
}

function Add-UserToGroupSafe {
    param([string]$Username, [string]$GroupName)
    
    try {
        Add-ADGroupMember -Identity $GroupName -Members $Username -ErrorAction Stop
        Write-Status "  → Added to '$GroupName'" "✓"
        return $true
    } catch {
        # Check if user is already a member
        if ($_.Exception.Message -like "*already a member*") {
            Write-Status "  → Already member of '$GroupName'" "~"
            return $true
        }
        Write-Status "  Failed to add to '$GroupName': $($_.Exception.Message)" "!"
        return $false
    }
}

# ============================================================
# PHASE 1 – Verify all groups exist
# ============================================================
Write-Status "`nPhase 1: Verifying required groups..." ">"
$allGroups = $Users | ForEach-Object { $_.Groups } | Select-Object -Unique
$groupsOK = $true

foreach ($group in $allGroups) {
    if (-not (Ensure-GroupExists $group)) {
        $groupsOK = $false
    }
}

if (-not $groupsOK) {
    Write-Status "Some groups could not be created. Continuing anyway..." "!"
}

# ============================================================
# PHASE 2 – Create users and assign groups
# ============================================================
Write-Status "`nPhase 2: Creating users and assigning groups..." ">"

$created = 0
$skipped = 0
$failed = 0

foreach ($entry in $Users) {
    $username = $entry.Username
    
    # Check if user exists
    $existingUser = Get-ADUser -Filter { SamAccountName -eq $username } -ErrorAction SilentlyContinue
    
    if ($existingUser) {
        Write-Status "User already exists: $username" "~"
        $skipped++
    } else {
        if (New-ADUserSafe -Username $username -Password $SecurePassword -Domain $Domain -OUPath $OUPath) {
            $created++
        } else {
            $failed++
            continue  # Skip group assignment if user creation failed
        }
    }
    
    # Assign groups
    foreach ($group in $entry.Groups) {
        Add-UserToGroupSafe -Username $username -GroupName $group | Out-Null
    }
}

# ============================================================
# Summary
# ============================================================
Write-Status "`n✓ Provisioning Complete" ">"
Write-Host @"
  Created: $created
  Skipped: $skipped
  Failed:  $failed
  Total:   $($Users.Count)
"@
Write-Status "`nIMPORTANT: Users must change password on first login!`n" "!"
