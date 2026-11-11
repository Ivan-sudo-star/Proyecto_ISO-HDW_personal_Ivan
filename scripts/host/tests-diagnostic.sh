#!/usr/bin/env bash
# tests-diagnostic.sh — Tests de diagnòstic de l'equip físic (Tasca 2 Apte+: a27, a28).
# Funciona en qualsevol Linux (equip de classe i de casa). Genera un informe amb
# eina, versió, condicions i resultat de cada test.
# Ús: bash scripts/host/tests-diagnostic.sh <classe|casa> [directori_proves_disc]
set -uo pipefail
EQUIP=${1:-classe}
DIR=${2:-$HOME}
OUT="evidencias/t2-tests/tests-$EQUIP-$(date +%Y%m%d-%H%M).txt"
mkdir -p "$(dirname "$OUT")"
exec > >(tee "$OUT") 2>&1

echo "# Tests de diagnòstic — equip: $EQUIP — $(date '+%F %T')"
echo "## Condicions"
echo "- Host: $(hostname) | Kernel: $(uname -r) | Uptime: $(uptime -p)"
echo "- Alimentació: $(cat /sys/class/power_supply/AC*/online 2>/dev/null | sed 's/1/endollat/;s/0/bateria/' || echo N/C)"
echo "- VM en marxa: $(VBoxManage list runningvms 2>/dev/null | wc -l)"
echo "- Càrrega (1/5/15 min): $(cut -d' ' -f1-3 /proc/loadavg)"
echo "- Memòria: $(free -h | awk '/Mem/{print "total "$2", usada "$3", disponible "$7}')"
echo

echo "## 1. Memòria"
if command -v memtester >/dev/null; then
  echo "Eina: $(memtester 2>&1 | head -1)"
  echo "Ordre: sudo memtester 1G 1"; sudo memtester 1G 1 | tail -15
else
  echo "memtester no instal·lat (sudo apt install memtester). Alternatives: MemTest86 (USB arrencable) o"
  echo "Diagnòstic de memòria de Windows (mdsched.exe) en l'equip de casa."
fi
echo "Errors de memòria registrats pel nucli (EDAC/MCE):"
journalctl -k -b --no-pager 2>/dev/null | grep -iE 'edac|mce|memory error' | tail -5 || true
echo "(cap línia = cap error registrat)"
echo

echo "## 2. Disc ($DIR)"
echo "Eina: $(dd --version | head -1) | Dispositiu: $(df --output=source "$DIR" | tail -1) | FS: $(df --output=fstype "$DIR" | tail -1)"
F="$DIR/.ddtest.$$"
echo "Escriptura seqüencial 1 GiB (oflag=direct, sense memòria cau):"
dd if=/dev/zero of="$F" bs=1M count=1024 oflag=direct conv=fsync 2>&1 | tail -1
sync; echo "Lectura seqüencial 1 GiB (iflag=direct):"
dd if="$F" of=/dev/null bs=1M iflag=direct 2>&1 | tail -1
echo "Escriptura síncrona 4 KiB x 2000 (oflag=direct,dsync; límit 90 s) — aproximació a IOPS d'escriptura:"
timeout 90 dd if=/dev/zero of="$F" bs=4k count=2000 oflag=direct,dsync 2>&1 | tail -1 || echo "  >90 s: menys de 22 IOPS síncrones"
rm -f "$F"
if command -v fio >/dev/null; then
  echo "fio randread 4k QD32 30 s:"
  fio --name=rr --filename="$DIR/.fiotest" --size=1G --rw=randread --bs=4k --iodepth=32 \
      --ioengine=libaio --direct=1 --runtime=30 --time_based --group_reporting | grep -E 'IOPS|lat \('
  rm -f "$DIR/.fiotest"
else
  echo "fio no instal·lat (sudo apt install fio) — prova d'IOPS real pendent."
fi
echo "Estat SMART: sudo smartctl -H /dev/sdX (requereix smartmontools i sudo)"
echo

echo "## 3. Xarxa"
IF=$(ip route | awk '/^default/{print $5; exit}'); GW=$(ip route | awk '/^default/{print $3; exit}')
echo "Interfície: $IF | Velocitat negociada: $(cat /sys/class/net/$IF/speed 2>/dev/null || echo N/C) Mb/s | Porta d'enllaç: $GW"
echo "Latència a la porta d'enllaç (20 paquets):"; ping -c 20 -q "$GW" | tail -2
echo "Latència a Internet 1.1.1.1 (20 paquets):"; ping -c 20 -q 1.1.1.1 | tail -2
echo "Descàrrega 100 MB (curl, speed.cloudflare.com):"
curl -s -o /dev/null -m 60 -w 'velocitat mitjana: %{speed_download} B/s en %{time_total} s\n' \
  'https://speed.cloudflare.com/__down?bytes=100000000' \
  | awk '{printf "%s %s %.1f Mb/s (%s s)\n",$1,$2,$3*8/1e6,$6}'
if command -v iperf3 >/dev/null; then
  echo "iperf3: executa 'iperf3 -s' en un altre equip i després 'iperf3 -c <IP>'"
else
  echo "iperf3 no instal·lat — prova LAN equip↔equip pendent."
fi
echo; echo "Informe desat en $OUT"
