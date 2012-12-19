
$has_pscx = (Get-Module -ListAvailable | ? { $_.Name -eq 'pscx'} ) -ne $null

if (-not $has_pscx){
  Write-Error "SETUP ERROR: You MUST have PSCX (http://pscx.codeplex.com/) installed!"
} else {
  Write-Host PSCX Installed -Fore Green
}

$has_psake = (Get-Module -ListAvailable | ? { $_.Name -eq 'psake'} ) -ne $null
if (-not $has_psake){
  Write-Error "SETUP ERROR: You MUST have PSake (https://github.com/psake/psake/) installed!"
} else {
  Write-Host PSake Installed -Fore Green
}
