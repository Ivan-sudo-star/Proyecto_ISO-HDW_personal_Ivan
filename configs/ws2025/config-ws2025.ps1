# config-ws2025.ps1 — primer inici de SRV-WS2025 (VM 210, PVE1) · a237-a239
# L'executa autounattend.xml (FirstLogonCommands) com a Administrator. Registre: C:\config-ws2025.log
Start-Transcript -Path C:\config-ws2025.log -Force | Out-Null
"# Primer inici - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

# 1. Controladors VirtIO (disc, xarxa, balloon...) i agent QEMU, des del CD de virtio-win
$v = (Get-Volume | Where-Object { $_.FileSystemLabel -like 'virtio-win*' }).DriveLetter
"CD de virtio-win: ${v}:"
Start-Process msiexec.exe -Wait -ArgumentList "/i ${v}:\virtio-win-gt-x64.msi /qn /norestart ADDLOCAL=ALL"
Start-Process msiexec.exe -Wait -ArgumentList "/i ${v}:\guest-agent\qemu-ga-x86_64.msi /qn /norestart"
"qemu-ga: $((Get-Service QEMU-GA -ErrorAction SilentlyContinue).Status)"

# 2. Xarxa (a239): IP fixa 192.168.13.21/24, porta d'enllaç i DNS a R1
Start-Sleep 10
$nic = Get-NetAdapter | Where-Object Status -eq 'Up' | Select-Object -First 1
"Targeta: $($nic.Name) ($($nic.InterfaceDescription))"
Set-NetIPInterface -InterfaceIndex $nic.ifIndex -Dhcp Disabled
Get-NetIPAddress -InterfaceIndex $nic.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Remove-NetIPAddress -Confirm:$false
New-NetIPAddress -InterfaceIndex $nic.ifIndex -IPAddress 192.168.13.21 -PrefixLength 24 -DefaultGateway 192.168.13.1 | Out-Null
Set-DnsClientServerAddress -InterfaceIndex $nic.ifIndex -ServerAddresses 192.168.13.1
Set-DnsClient -InterfaceIndex $nic.ifIndex -ConnectionSpecificSuffix lan13.local
Set-NetConnectionProfile -InterfaceIndex $nic.ifIndex -NetworkCategory Private -ErrorAction SilentlyContinue

# 3. Tallafocs: permetre el ping (per a les proves de connectivitat de la LAN)
Enable-NetFirewallRule -Name FPS-ICMP4-ERQ-In -ErrorAction SilentlyContinue

Get-NetIPConfiguration | Format-List | Out-String
"FI $(Get-Date -Format 'HH:mm:ss')"
Stop-Transcript | Out-Null
