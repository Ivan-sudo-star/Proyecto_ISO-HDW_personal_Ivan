$ErrorActionPreference='Continue'
"# Cliente_windows_1 (client Windows 11) - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
"## a247 versio i funcionament"
Get-ComputerInfo | Select-Object CsName,OsName,OSDisplayVersion,OsVersion,OsBuildNumber,OsArchitecture,BiosFirmwareType,CsTotalPhysicalMemory | Format-List | Out-String -Width 200
"Secure Boot: " + $(try{Confirm-SecureBootUEFI}catch{"no es pot llegir: $($_.Exception.Message)"})
"TPM:"; try{Get-Tpm | Select-Object TpmPresent,TpmReady,ManufacturerVersion | Format-List | Out-String}catch{"no es pot llegir: $($_.Exception.Message)"}
"Serveis automatics aturats:"; Get-CimInstance Win32_Service -Filter "StartMode='Auto' AND State<>'Running'" | Select-Object Name,State | Format-Table -AutoSize | Out-String
"## a248 usuaris (estat actual)"
whoami; whoami /groups | Select-String 'S-1-5-32-544|Mandatory Label|Etiqueta'
Get-LocalUser | Select-Object Name,Enabled,PasswordRequired,LastLogon | Format-Table -AutoSize | Out-String
"Membres del grup d'administradors (S-1-5-32-544):"; Get-LocalGroupMember -SID S-1-5-32-544 | Select-Object Name,PrincipalSource | Format-Table -AutoSize | Out-String
"## a249 xarxa"
ipconfig /all
Get-NetIPConfiguration | Format-List | Out-String
"Ping GW .1: " + (Test-Connection 192.168.13.1 -Count 2 -Quiet)
"DNS: "; Resolve-DnsName deb.debian.org -Type A -ErrorAction SilentlyContinue | Select-Object -First 2 Name,IPAddress | Out-String
"SMB NAS 445: " + (Test-NetConnection 192.168.13.20 -Port 445 -WarningAction SilentlyContinue).TcpTestSucceeded
"Internet HTTPS: " + $(try{(Invoke-WebRequest https://www.debian.org -UseBasicParsing -TimeoutSec 15).StatusCode}catch{$_.Exception.Message})
