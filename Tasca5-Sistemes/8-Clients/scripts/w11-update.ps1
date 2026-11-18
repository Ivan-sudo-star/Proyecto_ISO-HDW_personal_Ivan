# w11-update.ps1 — a79: Windows Update des de PowerShell (API Microsoft.Update.Session). Cal executar-lo elevat.
# Desa el registre a C:\Users\Public\w11-update.txt
Start-Transcript -Path C:\Users\Public\w11-update.txt -Force | Out-Null
"# Windows Update - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
"Abans: $((Get-CimInstance Win32_OperatingSystem).Caption) · compilació $([Environment]::OSVersion.Version.Build).$((Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').UBR)"
$s = New-Object -ComObject Microsoft.Update.Session
$r = $s.CreateUpdateSearcher().Search("IsInstalled=0 and Type='Software' and IsHidden=0")
"Actualitzacions trobades: $($r.Updates.Count)"
$r.Updates | ForEach-Object { "  - $($_.Title) ($([math]::Round($_.MaxDownloadSize/1MB)) MB)" }
if ($r.Updates.Count -gt 0) {
  $c = New-Object -ComObject Microsoft.Update.UpdateColl; $r.Updates | ForEach-Object { if (-not $_.EulaAccepted) { $_.AcceptEula() }; [void]$c.Add($_) }
  $t0 = Get-Date
  $d = $s.CreateUpdateDownloader(); $d.Updates = $c; $dr = $d.Download(); "Descàrrega: codi $($dr.ResultCode) (2 = correcte) en $([math]::Round(((Get-Date)-$t0).TotalMinutes,1)) min"
  $t1 = Get-Date
  $i = $s.CreateUpdateInstaller(); $i.Updates = $c; $ir = $i.Install(); "Instal·lació: codi $($ir.ResultCode) (2 = correcte) en $([math]::Round(((Get-Date)-$t1).TotalMinutes,1)) min · cal reiniciar: $($ir.RebootRequired)"
  for ($k=0; $k -lt $c.Count; $k++) { "  [$($ir.GetUpdateResult($k).ResultCode)] $($c.Item($k).Title)" }
}
"FI $(Get-Date -Format 'HH:mm:ss')"
Stop-Transcript | Out-Null
