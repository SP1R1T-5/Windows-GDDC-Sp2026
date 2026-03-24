# Windows SSH Private Key Retrieval Script
# This script finds and displays SSH private keys from the user's .ssh directory

# Create output directory if it doesn't exist
$outputDir = "$env:USERPROFILE\SSHKeyBackup"
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

# Navigate to the SSH directory
$sshDir = "$env:USERPROFILE\.ssh"
$keyFound = $false

# Check if .ssh directory exists
if (Test-Path $sshDir) {
    Write-Host "SSH directory found at: $sshDir"
    
    # Get all potential private key files (files without .pub extension)
    $privateKeys = Get-ChildItem -Path $sshDir | Where-Object { 
        $_.Extension -ne ".pub" -and $_.Name -match "(id_rsa|id_ed25519|id_dsa|id_ecdsa|identity|private)" -or $_.Extension -eq ""
    }
    
    # If no keys found with standard naming, get all files that don't have .pub extension
    if ($privateKeys.Count -eq 0) {
        $privateKeys = Get-ChildItem -Path $sshDir | Where-Object { $_.Extension -ne ".pub" }
    }
    
    # Process each potential private key
    foreach ($key in $privateKeys) {
        $keyContent = Get-Content -Path $key.FullName -Raw -ErrorAction SilentlyContinue
        
        # Check if file content looks like an SSH key
        if ($keyContent -match "-----BEGIN.*PRIVATE KEY-----") {
            $keyFound = $true
            
            # Display key info
            Write-Host "`nFound SSH private key: $($key.Name)" -ForegroundColor Green
            
            # Create backup of the key
            $backupPath = Join-Path -Path $outputDir -ChildPath $key.Name
            Copy-Item -Path $key.FullName -Destination $backupPath -Force
            
            # Output the key
            Write-Host "`nKey content:"
            Write-Host "----------------------------------------"
            Write-Host $keyContent
            Write-Host "----------------------------------------"
            
            # Save to a text file as well
            $textPath = Join-Path -Path $outputDir -ChildPath "$($key.Name).txt"
            $keyContent | Out-File -FilePath $textPath -Force
            
            Write-Host "Key saved to: $backupPath"
            Write-Host "Key content saved to: $textPath"
        }
    }
    
    if (-not $keyFound) {
        Write-Host "No SSH private keys found in $sshDir" -ForegroundColor Yellow
    }
} else {
    Write-Host "SSH directory not found at: $sshDir" -ForegroundColor Yellow
    
    # Check for alternative locations
    $altLocations = @(
        "$env:USERPROFILE\Documents\.ssh",
        "C:\ProgramData\ssh",
        "$env:LOCALAPPDATA\ssh"
    )
    
    foreach ($loc in $altLocations) {
        if (Test-Path $loc) {
            Write-Host "Alternative SSH directory found at: $loc" -ForegroundColor Green
            
            # Repeat similar key finding logic
            $privateKeys = Get-ChildItem -Path $loc | Where-Object { 
                $_.Extension -ne ".pub" -and ($_.Name -match "(id_rsa|id_ed25519|id_dsa|id_ecdsa|identity|private)" -or $_.Extension -eq "")
            }
            
            foreach ($key in $privateKeys) {
                $keyContent = Get-Content -Path $key.FullName -Raw -ErrorAction SilentlyContinue
                
                if ($keyContent -match "-----BEGIN.*PRIVATE KEY-----") {
                    $keyFound = $true
                    
                    # Display key info
                    Write-Host "`nFound SSH private key: $($key.Name)" -ForegroundColor Green
                    
                    # Create backup of the key
                    $backupPath = Join-Path -Path $outputDir -ChildPath $key.Name
                    Copy-Item -Path $key.FullName -Destination $backupPath -Force
                    
                    # Output the key
                    Write-Host "`nKey content:"
                    Write-Host "----------------------------------------"
                    Write-Host $keyContent
                    Write-Host "----------------------------------------"
                    
                    # Save to a text file as well
                    $textPath = Join-Path -Path $outputDir -ChildPath "$($key.Name).txt"
                    $keyContent | Out-File -FilePath $textPath -Force
                    
                    Write-Host "Key saved to: $backupPath"
                    Write-Host "Key content saved to: $textPath"
                }
            }
        }
    }
}

if ($keyFound) {
    Write-Host "`nAll SSH private keys have been saved to: $outputDir" -ForegroundColor Green
} else {
    Write-Host "`nNo SSH private keys were found on this system." -ForegroundColor Yellow
    
    # Provide guidance
    Write-Host "If you need to generate an SSH key, run: ssh-keygen -t rsa -b 4096" -ForegroundColor Cyan
}

Pause
