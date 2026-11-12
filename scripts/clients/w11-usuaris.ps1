Start-Transcript -Path C:\Users\Public\w11-usuaris.txt -Force | Out-Null
"# Accions amb privilegis - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
"Elevat: " + ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
"## a247 requisits"
"Secure Boot actiu: " + (Confirm-SecureBootUEFI)
Get-Tpm | Select-Object TpmPresent,TpmReady,TpmEnabled,ManufacturerVersion | Format-List
"## a248 usuaris"
$pw = Read-Host 'Contrasenya per als usuaris nous' -AsSecureString
$admins = (Get-LocalGroup -SID S-1-5-32-544).Name
$users  = (Get-LocalGroup -SID S-1-5-32-545).Name
foreach ($u in @(@{n='admin-ivan';d='Administrador del client (lloc 13)';g=$admins}, @{n='usuari';d='Usuari estandard de treball';g=$users})) {
  if (-not (Get-LocalUser -Name $u.n -ErrorAction SilentlyContinue)) {
    New-LocalUser -Name $u.n -Password $pw -Description $u.d -PasswordNeverExpires | Out-Null; "creat: $($u.n)"
  } else { "ja existia: $($u.n)" }
  if (-not (Get-LocalGroupMember -Name $u.g -Member $u.n -ErrorAction SilentlyContinue)) { Add-LocalGroupMember -Name $u.g -Member $u.n }
}
Get-LocalUser | Where-Object Enabled | Select-Object Name,Description,PasswordExpires | Format-Table -AutoSize
"Administradors:"; Get-LocalGroupMember -SID S-1-5-32-544 | Select-Object Name | Format-Table -HideTableHeaders
"Usuaris:"; Get-LocalGroupMember -SID S-1-5-32-545 | Select-Object Name | Format-Table -HideTableHeaders
"UAC (EnableLUA): " + (Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System).EnableLUA
Stop-Transcript | Out-Null
