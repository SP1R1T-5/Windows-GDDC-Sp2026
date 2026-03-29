#Install AD
Install-WindowsFeature RSAT-AD-PowerShell

#Luc PowerSheel From Scratch
Import-Module ActiveDirectory

#Import the file from C:
$ADUsers = Import-csv C:\Users\Public\Storage\NewEmployees.csv

#Added a LOOP $ADUsers is the folder PATH

foreach ($User in $ADUsers) {
	$Username = $User.UserName
	$Password = $User.Password
	$Firstname = $User.FirstName
	$Lastname = $User.LastName
	$Employees = $User.OrganizationalUnit  # ← Changed from $OUName
	$Path = "OU=$Employees,DC=dog,DC=local"  # ← Now $Employees is defined
  
  if (!(Get-ADOrganizationalUnit -Filter {Name -eq $Employees} -SearchBase "DC=dog,DC=local")) {
    New-ADOrganizationalUnit -Name $Employees -Path "DC=dog,DC=local"
  }

  if ($Password -ne '') {
    try {
      #Added Attribute
      $SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force
      New-ADUser -SamAccountName $Username `
      -UserPrincipalName "$Username@dog.local" `
      -Name "$Firstname $Lastname" `
      -GivenName $Firstname `
      -Surname $Lastname `
      -Enabled $True `
      -DisplayName "$Lastname, $Firstname" `
      -AccountPassword $SecurePassword `
      -ChangePasswordAtLogon $False `
      -PasswordNeverExpires $True `
      -Path $Path
    } catch {
      Write-Host "Password for $Username does not meet domain password policy requirements. Skipping account creation."
    }
  } else {
    Write-Host "Password for $Username is empty. Skipping account creation."
  }
}
