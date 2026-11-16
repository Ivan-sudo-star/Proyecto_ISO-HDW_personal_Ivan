# domini-ivan-cambra-13.ps1 — SRV-WS2025 (192.168.13.21) passa a controlador del domini ivan-cambra-13.lan
# Ús (PowerShell d'administrador al servidor; la contrasenya NO va al repositori):
#   .\domini-ivan-cambra-13.ps1 -Fase 1 -Contrasenya '<contrasenya>'   # instal·la AD DS i crea el bosc (reinicia sol)
#   .\domini-ivan-cambra-13.ps1 -Fase 2 -Contrasenya '<contrasenya>'   # després del reinici: política, OU, grup i usuari ivan
param(
    [Parameter(Mandatory)][ValidateSet(1, 2)][int]$Fase,
    [Parameter(Mandatory)][string]$Contrasenya
)
$ErrorActionPreference = 'Stop'
$Domini  = 'ivan-cambra-13.lan'     # FQDN: el guió baix no és vàlid en noms DNS
$NetBIOS = 'IVANCAMBRA13'           # màxim 15 caràcters
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
Set-DnsClientServerAddress -InterfaceAlias (Get-NetIPAddress -IPAddress 192.168.13.21).InterfaceAlias -ServerAddresses 127.0.0.1, 192.168.13.1
Set-DnsServerForwarder -IPAddress 192.168.13.1
# Zona inversa per a la LAN13
if (-not (Get-DnsServerZone -Name '13.168.192.in-addr.arpa' -ErrorAction SilentlyContinue)) {
    Add-DnsServerPrimaryZone -NetworkId '192.168.13.0/24' -ReplicationScope Domain
}
# Política de contrasenyes del domini: laboratori (contrasenya curta, sense complexitat ni caducitat)
Set-ADDefaultDomainPasswordPolicy -Identity $Domini -ComplexityEnabled $false -MinPasswordLength 4 `
    -MaxPasswordAge 0 -PasswordHistoryCount 0 -MinPasswordAge 0
# Estructura: una OU per als usuaris i una per als equips del lloc 13
$base = (Get-ADDomain).DistinguishedName
foreach ($ou in 'Usuaris-Lloc13', 'Equips-Lloc13') {
    if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$ou'")) { New-ADOrganizationalUnit -Name $ou -Path $base }
}
# Usuari del domini per iniciar sessió als clients
if (-not (Get-ADUser -Filter "SamAccountName -eq 'ivan'")) {
    New-ADUser -Name 'Ivan Cambra' -GivenName 'Ivan' -Surname 'Cambra' -SamAccountName 'ivan' `
        -UserPrincipalName "ivan@$Domini" -Path "OU=Usuaris-Lloc13,$base" `
        -AccountPassword $Pw -Enabled $true -PasswordNeverExpires $true
}
# Els equips nous que s'unisquen al domini van a la seua OU
redircmp "OU=Equips-Lloc13,$base" | Out-Null
Get-ADDomain | Format-List DNSRoot, NetBIOSName, DomainMode, PDCEmulator
Get-ADUser ivan -Properties Enabled, UserPrincipalName | Format-List Name, SamAccountName, UserPrincipalName, Enabled
