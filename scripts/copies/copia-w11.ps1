$ErrorActionPreference='Continue'
$share='\\192.168.13.20\clients'; $dst="$share\w11"; $cfg="$env:TEMP\w11-config"
"# a250 copia del client Windows 11 - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
net use $share /delete /y 2>$null | Out-Null
net use $share * /user:copies /persistent:no   # demana la contrasenya
# 1) configuracio exportada
New-Item -ItemType Directory -Force $cfg | Out-Null
ipconfig /all > "$cfg\ipconfig.txt"
Get-NetIPConfiguration -Detailed | Out-String -Width 200 > "$cfg\netipconfig.txt"
Get-LocalUser | Select Name,Enabled,Description | Out-String > "$cfg\usuaris.txt"
Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*,HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* -EA SilentlyContinue | ? DisplayName | Select DisplayName,DisplayVersion | Sort DisplayName | Out-String -Width 200 > "$cfg\aplicacions.txt"
Get-ComputerInfo | Select CsName,OsName,OSDisplayVersion,OsBuildNumber | Out-String > "$cfg\versio.txt"
# 2) dades de l'usuari
$prova="$env:USERPROFILE\Documents\prova-copia-w11.txt"
"Fitxer de prova de la copia del client W11 - $(Get-Date)" | Set-Content $prova
$h1=(Get-FileHash $prova).Hash
"## robocopy"
foreach ($p in @(@{s=$cfg;d="$dst\config"},@{s="$env:USERPROFILE\Documents";d="$dst\dades\Ivan\Documents"},@{s="$env:USERPROFILE\Desktop";d="$dst\dades\Ivan\Desktop"})) {
  robocopy $p.s $p.d /MIR /R:1 /W:1 /XJ /NFL /NDL /NP | Select-String 'Directorios|Archivos|Bytes|Dirs|Files' ; "robocopy $($p.s) -> $($p.d) codi=$LASTEXITCODE (0-7 = correcte)"
}
"## contingut al NAS"
Get-ChildItem -Recurse $dst -File | Select @{n='Fitxer';e={$_.FullName.Replace($dst,'')}},Length | Format-Table -AutoSize | Out-String -Width 200
"## prova de restauracio"
Remove-Item $prova; "esborrat local: " + -not (Test-Path $prova)
robocopy "$dst\dades\Ivan\Documents" "$env:USERPROFILE\Documents" prova-copia-w11.txt /R:1 /W:1 /NFL /NDL /NP /NJH /NJS | Out-Null
$h2=(Get-FileHash $prova).Hash
"SHA256 abans:  $h1"; "SHA256 despres: $h2"; "Restauracio correcta: " + ($h1 -eq $h2)
net use $share /delete /y | Out-Null
