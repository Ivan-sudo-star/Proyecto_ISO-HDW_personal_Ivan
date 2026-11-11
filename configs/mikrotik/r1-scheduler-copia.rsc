# r1-scheduler-copia.rsc — Còpia automàtica diària de R1 cap al NAS (Tasca 5 Apte+ / a105)
# La contrasenya de l'usuari "copies" del NAS es guarda en una variable global
# configurada a mà a l'equip (no al repositori):  :global nasPass "..."

/system script add name=copia-nas policy=read,write,test,sensitive,ftp source={
  :global nasPass
  :local data [/system clock get date]
  /export file=r1-export
  /system backup save name=r1-backup
  :delay 3s
  /tool fetch upload=yes mode=sftp address=192.168.13.20 user=copies password=$nasPass \
      src-path=r1-export.rsc dst-path=("/mnt/copies/routers/r1/r1-export-" . $data . ".rsc")
  /tool fetch upload=yes mode=sftp address=192.168.13.20 user=copies password=$nasPass \
      src-path=r1-backup.backup dst-path=("/mnt/copies/routers/r1/r1-" . $data . ".backup")
  :log info "copia-nas: còpia de R1 pujada al NAS"
}
/system scheduler add name=copia-diaria interval=1d start-time=02:00:00 on-event=copia-nas
# Prova manual: /system script run copia-nas ; /log print where message~"copia-nas"
