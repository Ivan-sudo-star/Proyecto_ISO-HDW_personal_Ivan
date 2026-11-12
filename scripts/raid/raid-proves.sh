#!/usr/bin/env bash
# raid-proves.sh — Tasca 6 apartat 2 (a102, a103): crear i verificar RAID 0, 1, 5 i 10 amb mdadm
# VM: 230 SRV-DADES dins de PVE3 (5 discos d'1 GiB). Dades fictícies.
# COMPTE: a la VM 230 els noms sdX NO segueixen l'ordre scsiN. Els discos es detecten per MIDA (exactament 1 GiB),
# o es passen a mà: DISCOS_RAID="/dev/disk/by-path/... x5" bash raid-proves.sh 1
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
if [ -n "${DISCOS_RAID:-}" ]; then read -ra DISCOS <<<"$DISCOS_RAID"
else mapfile -t DISCOS < <(lsblk -dbnpo NAME,SIZE,TYPE | awk '$2==1073741824 && $3=="disk"{print $1}'); fi
ARREL=/dev/$(lsblk -no PKNAME "$(findmnt -no SOURCE /)" | head -1)
[ "${#DISCOS[@]}" -eq 5 ] || { echo "ERROR: calen 5 discos d'1 GiB i n'hi ha ${#DISCOS[@]}: ${DISCOS[*]:-cap}"; lsblk -o NAME,SIZE,TYPE,MOUNTPOINT; exit 1; }
for d in "${DISCOS[@]}"; do
  [ -b "$d" ] || { echo "ERROR: $d no és un dispositiu de blocs"; exit 1; }
  [ "$(readlink -f "$d")" = "$ARREL" ] && { echo "ERROR: $d és el disc del sistema"; exit 1; }
  lsblk -nro TYPE "$d" | grep -q '^part$' && { echo "ERROR: $d té particions (no és un disc de proves)"; exit 1; }
done
D1=${DISCOS[0]}; D2=${DISCOS[1]}; D3=${DISCOS[2]}; D4=${DISCOS[3]}; D5=${DISCOS[4]}
echo "Discos de proves: D1=$D1 D2=$D2 D3=$D3 D4=$D4 D5=$D5"

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
  0)  neteja; pas "Creació RAID 0 (D1+D2)"; crea 2 "$D1" "$D2"; dades; verifica
      pas "Rendiment d'escriptura"; dd if=/dev/zero of=$MNT/prova bs=1M count=300 oflag=direct 2>&1 | tail -1; rm $MNT/prova
      pas "Pèrdua de D2: RAID 0 NO té tolerància (mdadm ni tan sols deixa marcar-lo com a fallit)"
      mdadm "$MD" --fail "$D2" || echo "-> mdadm rebutja --fail en RAID 0"
      umount "$MNT"; mdadm --stop "$MD"
      echo "Intent d'assemblar només amb D1 (com si D2 s'haguera perdut):"
      mdadm --assemble "$MD" "$D1" --run || echo "-> IMPOSSIBLE: falten les meitats de cada bloc que estaven a D2. Dades perdudes."
      cat /proc/mdstat
      pas "Retorn (el disc no estava trencat de veritat)"; mdadm --stop "$MD" 2>/dev/null
      mdadm --assemble "$MD" "$D1" "$D2" && mount "$MD" "$MNT" && verifica ;;
  1)  neteja; pas "Creació RAID 1 (D1+D2)"; crea 2 "$D1" "$D2"; dades; verifica
      falla_i_reconstrueix "$D2" "$D3" ;;
  5)  neteja; pas "Creació RAID 5 (D1+D2+D3) + disc de reserva D4"; crea 3 "$D1" "$D2" "$D3" --spare-devices=1 "$D4"
      dades; verifica
      pas "Fallada de D2: el disc de reserva entra automàticament"; mdadm "$MD" --fail "$D2"
      sleep 2; cat /proc/mdstat; t0=$(date +%s); mdadm --wait "$MD"; echo "Reconstrucció amb spare: $(( $(date +%s)-t0 )) s"
      mdadm --detail "$MD" | grep -E 'State|Active|Spare|faulty'; verifica ;;
  10) neteja; pas "Creació RAID 10 (D1+D2+D3+D4)"; crea 4 "$D1" "$D2" "$D3" "$D4"; dades; verifica
      falla_i_reconstrueix "$D1" "$D5" ;;
  estat)  cat /proc/mdstat; for m in /dev/md*; do [ -b "$m" ] && mdadm --detail "$m"; done ;;
  neteja) neteja ;;
esac
echo; echo "Registre: $LOG"
