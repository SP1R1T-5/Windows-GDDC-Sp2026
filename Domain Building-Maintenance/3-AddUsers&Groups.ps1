# ============================================================
# AD User Creation & Group Assignment Script
# ============================================================

#Requires -Module ActiveDirectory

param(
    [SecureString]$DefaultPassword = (ConvertTo-SecureString "ChangeMe123!" -AsPlainText -Force)
)

$Domain = "dog.local"
$OUPath = "OU=Users,DC=dog,DC=local"

# ── User definitions ────────────────────────────────────────
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

# ── Groups that must exist before we start ──────────────────
$RequiredGroups = @(
    "WinRM Access",
    "SSH Access",
    "SMB Access"
)

# ── Helper: write coloured status lines ─────────────────────
function Write-Status {
    param([string]$Msg, [string]$Color = "Cyan")
    Write-Host $Msg -ForegroundColor $Color
}

# ============================================================
# PHASE 1 – Ensure custom groups exist
# ============================================================
Write-Status "`n[Phase 1] Verifying / creating required groups..."

foreach ($Group in $RequiredGroups) {
    if (-not (Get-ADGroup -Filter { Name -eq $Group } -ErrorAction SilentlyContinue)) {
        New-ADGroup -Name $Group `
                    -GroupScope Global `
                    -GroupCategory Security `
                    -Path $OUPath `
                    -Description "Auto-created by provisioning script"
        Write-Status "  Created group: $Group" "Yellow"
    } else {
        Write-Status "  Group exists: $Group" "Green"
    }
}

# ============================================================
# PHASE 2 – Create users and assign groups
# ============================================================
Write-Status "`n[Phase 2] Creating users and assigning group memberships..."

foreach ($Entry in $Users) {
    $Username = $Entry.Username
    $GroupList = $Entry.Groups -split "," | ForEach-Object { $_.Trim() }

    # ── Create user if not already present ──────────────────
    $ExistingUser = Get-ADUser -Filter { SamAccountName -eq $Username } -ErrorAction SilentlyContinue

    if (-not $ExistingUser) {
        try {
            New-ADUser -SamAccountName       $Username `
                       -UserPrincipalName    "$Username@$Domain" `
                       -Name                 $Username `
                       -AccountPassword      $DefaultPassword `
                       -Enabled              $true `
                       -Path                 $OUPath `
                       -ChangePasswordAtLogon $true
            Write-Status "  [+] Created user: $Username" "Yellow"
        } catch {
            Write-Status "  [!] Failed to create $Username – $($_.Exception.Message)" "Red"
            continue
        }
    } else {
        Write-Status "  [~] User exists, skipping creation: $Username" "DarkCyan"
    }

    # ── Assign groups ────────────────────────────────────────
    foreach ($Group in $GroupList) {
        try {
            Add-ADGroupMember -Identity $Group -Members $Username -ErrorAction Stop
            Write-Status "      -> Added to '$Group'" "Green"
        } catch {
            Write-Status "      [!] Could not add $Username to '$Group': $($_.Exception.Message)" "Red"
        }
    }
}

Write-Status "`n[Done] Provisioning complete.`n" "Cyan"
