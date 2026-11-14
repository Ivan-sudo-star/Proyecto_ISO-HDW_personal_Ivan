# ws-info.ps1 — evidència de SRV-WS2025 (a237, a238, a239). S'executa amb: qm guest exec 210 -- powershell -EncodedCommand ...
"## a237 versió i funcionament - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Get-ComputerInfo | Select-Object CsName,WindowsProductName,WindowsEditionId,OSDisplayVersion,OsVersion,OsBuildNumber,OsArchitecture,BiosFirmwareType,CsTotalPhysicalMemory | Format-List | Out-String
"Llicència (avaluació):"; cscript //nologo C:\Windows\System32\slmgr.vbs /dlv | Select-String 'Nombre|Name|Descrip|Estado|License Status|Remaining|restante|Período|Timebased|Time remaining'
"Serveis automàtics aturats:"; Get-CimInstance Win32_Service -Filter "StartMode='Auto' AND State<>'Running'" | Select-Object Name | Format-Table -HideTableHeaders | Out-String
"Controladors VirtIO:"; Get-PnpDevice -PresentOnly | Where-Object FriendlyName -match 'VirtIO|Red Hat' | Select-Object Class,FriendlyName,Status | Format-Table -AutoSize | Out-String -Width 160
"Agent QEMU: $((Get-Service QEMU-GA).Status)"
"## a238 usuaris"
Get-LocalUser | Select-Object Name,Enabled,Description | Format-Table -AutoSize | Out-String
"Administrators:"; Get-LocalGroupMember -SID S-1-5-32-544 | Select-Object Name | Format-Table -HideTableHeaders | Out-String
"## a239 xarxa"
Get-NetIPConfiguration -Detailed | Select-Object InterfaceAlias,InterfaceDescription,IPv4Address,IPv4DefaultGateway,DNSServer | Format-List | Out-String
"DHCP: $((Get-NetIPInterface -AddressFamily IPv4 | Where-Object InterfaceAlias -notmatch 'Loopback').Dhcp)"
"Ping GW .1: $(Test-Connection 192.168.13.1 -Count 2 -Quiet) · Ping NAS .20: $(Test-Connection 192.168.13.20 -Count 2 -Quiet)"
"DNS debian.org: $((Resolve-DnsName debian.org -Type A -ErrorAction SilentlyContinue | Select-Object -First 1).IPAddress)"
"Internet HTTPS: $(try{(Invoke-WebRequest https://www.debian.org -UseBasicParsing -TimeoutSec 20).StatusCode}catch{$_.Exception.Message})"
"SMB NAS 445: $((Test-NetConnection 192.168.13.20 -Port 445 -WarningAction SilentlyContinue).TcpTestSucceeded)"
"## Registre del primer inici (C:\config-ws2025.log)"; Get-Content C:\config-ws2025.log -ErrorAction SilentlyContinue | Select-Object -Skip 18
