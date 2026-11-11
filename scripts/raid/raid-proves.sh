#!/usr/bin/env bash
# raid-proves.sh — Tasca 6 apartat 2 (a102, a103): crear i verificar RAID 0, 1, 5 i 10 amb mdadm
# VM: 230 SRV-DADES dins de PVE3 (5 discos d'1 GB: sdb..sdf). Dades fictícies.
# Discos (al node PVE3): for i in 1 2 3 4 5; do qm set 230 --scsi$i local-lvm:1; done ; qm set 230 --scsi6 local-lvm:2  (DRBD)
# Ús (root):  bash raid-proves.sh <0|1|5|10|estat|neteja>
# Cada nivell es crea, s'hi copien dades de prova, se'n calcula el hash, es provoca la
# fallada d'un disc (excepte RAID 0, on es demostra que no hi ha tolerància) i es reconstrueix.
# Tota la sortida es guarda a /root/evidencies-raid/ per a copiar-la al repositori.
set -uo pipefail
NIVELL=${1:?Indica 0, 1, 5, 10, estat o neteja}
EV=/root/evidencies-raid; mkdir -p "$EV"
LOG="$EV/raid$NIVELL-$(date +%H%M%S).log"
MD=/dev/md$NIVELL; MNT=/mnt/raid$NIVELL
DISCOS=(/dev/sdb /dev/sdc /dev/sdd /dev/sde /dev/sdf)

pas() { echo; echo "===== $* ====="; }
dades() {   # crea dades fictícies i en guarda el hash
  mkdir -p "$MNT/dades"
  for i in $(seq 1 20); do head -c 5M /dev/urandom > "$MNT/dades/fitxer$i.bin"; done
  echo "Factura fictícia 2026-0001 · client Exemple SL · 1.234,56 €" > "$MNT/dades/factura.txt"
  (cd "$MNT/dades" && sha256sum * > /root/hash-raid$NIVELL.txt)
}
verifica() { (cd "$MNT/dades" && sha256sum -c --quiet /root/hash-raid$NIVELL.txt) && echo "DADES ÍNTEGRES" || echo "DADES DANYADES/INACCESSIBLES"; }
crea() {   # crea N_DISCOS
  local n=$1; shift
  mdadm --create "$MD" --level="$NIVELL" --raid-devices="$n" "$@" --run
  [ "$NIVELL" != 0 ] && mdadm --wait "$MD"
  mkfs.ext4 -q -F "$MD"; mkdir -p "$MNT"; mount "$MD" "$MNT"
  cat /proc/mdstat; mdadm --detail "$MD"; df -h "$MNT"
}
falla_i_reconstrueix() {   # DISC_FALLAT DISC_NOU
  pas "Fallada simulada de $1"; mdadm "$MD" --fail "$1"; cat /proc/mdstat; mdadm --detail "$MD" | grep -E 'State|Failed|Active'
  pas "Accés a les dades amb el RAID degradat"; verifica
  pas "Substitució: es retira $1 i s'afig $2"; mdadm "$MD" --remove "$1"; mdadm --zero-superblock "$1"
  mdadm "$MD" --add "$2"; sleep 2; cat /proc/mdstat
  local t0=$(date +%s); mdadm --wait "$MD"; echo "Reconstrucció: $(( $(date +%s)-t0 )) s"
  mdadm --detail "$MD" | grep -E 'State|Active|Working'; verifica
}
neteja() {
  for m in /dev/md0 /dev/md1 /dev/md5 /dev/md10; do umount "/mnt/raid${m#/dev/md}" 2>/dev/null; mdadm --stop "$m" 2>/dev/null; done
  for d in "${DISCOS[@]}"; do mdadm --zero-superblock "$d" 2>/dev/null; wipefs -aq "$d"; done
  echo "Discos nets"; lsblk "${DISCOS[@]}"
}

exec > >(tee "$LOG") 2>&1
echo "# RAID $NIVELL — $(hostname) — $(date '+%F %T')"; lsblk -o NAME,SIZE,TYPE "${DISCOS[@]}"
case $NIVELL in
  0)  neteja; pas "Creació RAID 0 (sdb+sdc)"; crea 2 /dev/sdb /dev/sdc; dades; verifica
      pas "Rendiment d'escriptura"; dd if=/dev/zero of=$MNT/prova bs=1M count=300 oflag=direct 2>&1 | tail -1; rm $MNT/prova
      pas "Pèrdua de sdc: RAID 0 NO té tolerància (mdadm ni tan sols deixa marcar-lo com a fallit)"
      mdadm "$MD" --fail /dev/sdc || echo "-> mdadm rebutja --fail en RAID 0"
      umount "$MNT"; mdadm --stop "$MD"
      echo "Intent d'assemblar només amb sdb (com si sdc s'haguera perdut):"
      mdadm --assemble "$MD" /dev/sdb --run || echo "-> IMPOSSIBLE: falten les meitats de cada bloc que estaven a sdc. Dades perdudes."
      cat /proc/mdstat
      pas "Retorn (el disc no estava trencat de veritat)"; mdadm --stop "$MD" 2>/dev/null
      mdadm --assemble "$MD" /dev/sdb /dev/sdc && mount "$MD" "$MNT" && verifica ;;
  1)  neteja; pas "Creació RAID 1 (sdb+sdc)"; crea 2 /dev/sdb /dev/sdc; dades; verifica
      falla_i_reconstrueix /dev/sdc /dev/sdd ;;
  5)  neteja; pas "Creació RAID 5 (sdb+sdc+sdd) + disc de reserva sde"; crea 3 /dev/sdb /dev/sdc /dev/sdd --spare-devices=1 /dev/sde
      dades; verifica
      pas "Fallada de sdc: el disc de reserva entra automàticament"; mdadm "$MD" --fail /dev/sdc
      sleep 2; cat /proc/mdstat; t0=$(date +%s); mdadm --wait "$MD"; echo "Reconstrucció amb spare: $(( $(date +%s)-t0 )) s"
      mdadm --detail "$MD" | grep -E 'State|Active|Spare|faulty'; verifica ;;
  10) neteja; pas "Creació RAID 10 (sdb+sdc+sdd+sde)"; crea 4 /dev/sdb /dev/sdc /dev/sdd /dev/sde; dades; verifica
      falla_i_reconstrueix /dev/sdb /dev/sdf ;;
  estat)  cat /proc/mdstat; for m in /dev/md*; do [ -b "$m" ] && mdadm --detail "$m"; done ;;
  neteja) neteja ;;
esac
echo; echo "Registre: $LOG"
