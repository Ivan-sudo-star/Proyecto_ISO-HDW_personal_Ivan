# w11-unir-domini.ps1 — Cliente_windows_1 s'uneix al domini ivan-cambra-13.lan i reinicia.
# Ús: PowerShell COM A ADMINISTRADOR (Ctrl+Maj+Intro a Win+R). Demana la contrasenya de l'administrador del domini.
# Requisit: el DNS del client (R1, per DHCP) ha de resoldre el domini -> R1 reenvia ivan-cambra-13.lan a 192.168.13.21.
param([string]$Contrasenya)
$Domini = 'ivan-cambra-13.lan'
$pw = if ($Contrasenya) { ConvertTo-SecureString $Contrasenya -AsPlainText -Force } else { Read-Host 'Contrasenya de IVANCAMBRA13\Administrator' -AsSecureString }
$cred = New-Object System.Management.Automation.PSCredential('IVANCAMBRA13\Administrator', $pw)
Resolve-DnsName -Type SRV "_ldap._tcp.dc._msdcs.$Domini" | Select-Object -First 1 NameTarget, Port
Add-Computer -DomainName $Domini -Credential $cred -Force -Verbose
"Unit al domini ${Domini}: $((Get-CimInstance Win32_ComputerSystem).Domain)"
Restart-Computer -Force
