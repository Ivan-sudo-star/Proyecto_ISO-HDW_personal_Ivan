# xarxa-inici.ps1 — SRV-WS2025: en cada arrencada (tasca programada «lloc31-xarxa», SYSTEM) posa la IP fixa a la targeta activa.
# Motiu: en moure el servidor de Proxmox a VirtualBox (16/11) la targeta és nova i Windows li posaria DHCP.
Start-Sleep 15
$log = 'C:\lloc31\xarxa.log'
$nic = Get-NetAdapter | Where-Object Status -eq 'Up' | Sort-Object ifIndex | Select-Object -First 1
if (-not $nic) { "$(Get-Date -f s) cap targeta activa" | Add-Content $log; exit }
$ip = Get-NetIPAddress -InterfaceIndex $nic.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
if ($ip.IPAddress -notcontains '192.168.31.21') {
  Set-NetIPInterface -InterfaceIndex $nic.ifIndex -Dhcp Disabled
  $ip | Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
  Remove-NetRoute -InterfaceIndex $nic.ifIndex -DestinationPrefix 0.0.0.0/0 -Confirm:$false -ErrorAction SilentlyContinue
  New-NetIPAddress -InterfaceIndex $nic.ifIndex -IPAddress 192.168.31.21 -PrefixLength 24 -DefaultGateway 192.168.31.1 | Out-Null
  # Des del 16/11 és controlador del domini ivan-cambra-31.lan: primer el seu propi DNS, després R1
  Set-DnsClientServerAddress -InterfaceIndex $nic.ifIndex -ServerAddresses 127.0.0.1, 192.168.31.1
  Set-DnsClient -InterfaceIndex $nic.ifIndex -ConnectionSpecificSuffix lan31.local
  "$(Get-Date -f s) IP .21 aplicada a $($nic.Name) ($($nic.InterfaceDescription))" | Add-Content $log
} else { "$(Get-Date -f s) $($nic.Name) ja té .21" | Add-Content $log }
Set-NetConnectionProfile -InterfaceIndex $nic.ifIndex -NetworkCategory Private -ErrorAction SilentlyContinue
Enable-NetFirewallRule -Name FPS-ICMP4-ERQ-In -ErrorAction SilentlyContinue
