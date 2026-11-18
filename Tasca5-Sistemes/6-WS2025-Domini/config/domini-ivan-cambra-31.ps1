# domini-ivan-cambra-31.ps1 — SRV-WS2025 (192.168.31.21) passa a controlador del domini ivan-cambra-31.lan
# Ús (PowerShell d'administrador al servidor; la contrasenya NO va al repositori):
#   .\domini-ivan-cambra-31.ps1 -Fase 1 -Contrasenya '<contrasenya>'   # instal·la AD DS i crea el bosc (reinicia sol)
#   .\domini-ivan-cambra-31.ps1 -Fase 2 -Contrasenya '<contrasenya>'   # després del reinici: política, OU, grup i usuari ivan
param(
    [Parameter(Mandatory)][ValidateSet(1, 2)][int]$Fase,
    [Parameter(Mandatory)][string]$Contrasenya
)
$ErrorActionPreference = 'Stop'
$Domini  = 'ivan-cambra-31.lan'     # FQDN: el guió baix no és vàlid en noms DNS
$NetBIOS = 'IVANCAMBRA31'           # màxim 15 caràcters
$Pw = ConvertTo-SecureString $Contrasenya -AsPlainText -Force

if ($Fase -eq 1) {
    Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
    Import-Module ADDSDeployment
    # Bosc nou amb DNS integrat. La contrasenya de DSRM (mode de restauració) és la del laboratori.
    Install-ADDSForest -DomainName $Domini -DomainNetbiosName $NetBIOS -InstallDns `
        -ForestMode WinThreshold -DomainMode WinThreshold `
        -SafeModeAdministratorPassword $Pw -NoRebootOnCompletion:$false -Force
    return
}

# --- Fase 2 ---
Import-Module ActiveDirectory
# DNS: el servidor es resol a si mateix; el que no és del domini es reenvia a R1
Set-DnsClientServerAddress -InterfaceAlias (Get-NetIPAddress -IPAddress 192.168.31.21).InterfaceAlias -ServerAddresses 127.0.0.1, 192.168.31.1
Set-DnsServerForwarder -IPAddress 192.168.31.1
# Zona inversa per a la LAN31
# Just després del reinici, la partició DomainDnsZones encara no existeix (error 9901): s'espera
while (-not (Get-DnsServerDirectoryPartition -Name "DomainDnsZones.$Domini" -ErrorAction SilentlyContinue)) { Start-Sleep 15 }
if (-not (Get-DnsServerZone -Name '31.168.192.in-addr.arpa' -ErrorAction SilentlyContinue)) {
    Add-DnsServerPrimaryZone -NetworkId '192.168.31.0/24' -ReplicationScope Domain
}
# Política de contrasenyes del domini: laboratori (contrasenya curta, sense complexitat ni caducitat)
Set-ADDefaultDomainPasswordPolicy -Identity $Domini -ComplexityEnabled $false -MinPasswordLength 4 `
    -MaxPasswordAge 0 -PasswordHistoryCount 0 -MinPasswordAge 0
# Estructura: una OU per als usuaris i una per als equips del lloc 31
$base = (Get-ADDomain).DistinguishedName
foreach ($ou in 'Usuaris-Lloc31', 'Equips-Lloc31') {
    if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$ou'")) { New-ADOrganizationalUnit -Name $ou -Path $base }
}
# Usuari del domini per iniciar sessió als clients
if (-not (Get-ADUser -Filter "SamAccountName -eq 'ivan'")) {
    New-ADUser -Name 'Ivan Cambra' -GivenName 'Ivan' -Surname 'Cambra' -SamAccountName 'ivan' `
        -UserPrincipalName "ivan@$Domini" -Path "OU=Usuaris-Lloc31,$base" `
        -AccountPassword $Pw -Enabled $true -PasswordNeverExpires $true
}
# Els equips nous que s'unisquen al domini van a la seua OU
redircmp "OU=Equips-Lloc31,$base" | Out-Null
# GPO d'inici de sessió per als equips del lloc 31: la pantalla demana usuari i contrasenya del domini
# (no mostra l'últim usuari) i no hi ha inici automàtic (el W11 tenia AutoAdminLogon de l'usuari local)
$gpo = 'Lloc31-Inici-de-sessio'
if (-not (Get-GPO -Name $gpo -ErrorAction SilentlyContinue)) {
    New-GPO -Name $gpo -Comment "Pantalla d'inici: demana usuari i contrasenya del domini" | Out-Null
    $pol = 'HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System'
    Set-GPRegistryValue -Name $gpo -Key $pol -ValueName DontDisplayLastUserName -Type DWord -Value 1 | Out-Null
    Set-GPRegistryValue -Name $gpo -Key $pol -ValueName DisableAutomaticRestartSignOn -Type DWord -Value 1 | Out-Null
    $wl = 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
    Set-GPPrefRegistryValue -Name $gpo -Context Computer -Action Update -Key $wl -ValueName AutoAdminLogon -Value '0' -Type String | Out-Null
    Set-GPPrefRegistryValue -Name $gpo -Context Computer -Action Delete -Key $wl -ValueName DefaultPassword -Value 'x' -Type String | Out-Null
    New-GPLink -Name $gpo -Target "OU=Equips-Lloc31,$base" | Out-Null
}
Get-ADDomain | Format-List DNSRoot, NetBIOSName, DomainMode, PDCEmulator
Get-ADUser ivan -Properties Enabled, UserPrincipalName | Format-List Name, SamAccountName, UserPrincipalName, Enabled
