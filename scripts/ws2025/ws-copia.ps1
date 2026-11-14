# ws-copia.ps1 — a240: còpia de SRV-WS2025 al NAS (recurs SMB \\192.168.13.20\windows, usuari copies)
# Ús: $env:PASS_NAS='<contrasenya>' ; powershell -File ws-copia.ps1   (o per qm guest exec amb -EncodedCommand)
"## a240 còpia - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$share='\\192.168.13.20\windows'; $pass=$env:PASS_NAS
net use $share /delete /y 2>$null | Out-Null
net use $share $pass /user:copies /persistent:no
# 1) Configuració exportada en text (es pot llegir sense restaurar res)
$cfg="$share\srv-ws2025\config"; New-Item -ItemType Directory -Force $cfg | Out-Null
Get-ComputerInfo | Out-File "$cfg\computerinfo.txt" -Width 200
Get-NetIPConfiguration -Detailed | Out-File "$cfg\xarxa.txt" -Width 200
Get-LocalUser | Out-File "$cfg\usuaris.txt"
Get-WindowsFeature | Where-Object Installed | Out-File "$cfg\rols-i-caracteristiques.txt" -Width 200
"config exportada: $((Get-ChildItem $cfg).Count) fitxers"
# 2) Estat del sistema i volums crítics amb Windows Server Backup
if (-not (Get-WindowsFeature Windows-Server-Backup).Installed) { Install-WindowsFeature Windows-Server-Backup | Out-Null }
"Windows Server Backup: $((Get-WindowsFeature Windows-Server-Backup).InstallState)"
$t0=Get-Date
wbadmin start backup "-backupTarget:$share" "-user:copies" "-password:$pass" -allCritical -systemState -vssFull -quiet
"wbadmin: codi $LASTEXITCODE en $([math]::Round(((Get-Date)-$t0).TotalMinutes,1)) min"
wbadmin get versions "-backupTarget:$share"
Get-ChildItem "$share\WindowsImageBackup" -Recurse -Directory -Depth 1 | Select-Object FullName | Format-Table -HideTableHeaders | Out-String
net use $share /delete /y | Out-Null
"FI $(Get-Date -Format 'HH:mm:ss')"
