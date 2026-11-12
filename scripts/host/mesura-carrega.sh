#!/usr/bin/env bash
# mesura-carrega.sh — Mesura els recursos de l'equip físic durant N segons (Tasca 7: a22, a119).
# Registra CPU, RAM, swap, disc i xarxa amb vmstat + /proc, i quines VM estan en marxa.
# Ús: bash scripts/host/mesura-carrega.sh <etiqueta> [segons=60]
#   ex: bash scripts/host/mesura-carrega.sh 0-base 60
#       bash scripts/host/mesura-carrega.sh 3-router+nas+client 60
set -uo pipefail
TAG=${1:?Indica una etiqueta, p.ex. 0-base}; SECS=${2:-60}
OUT="evidencias/t7-rendiment/$(date +%Y%m%d-%H%M)-$TAG.txt"
mkdir -p "$(dirname "$OUT")"
IF=$(ip route | awk '/^default/{print $5; exit}')
rx0=$(cat /sys/class/net/$IF/statistics/rx_bytes); tx0=$(cat /sys/class/net/$IF/statistics/tx_bytes)
{
  echo "# Mesura '$TAG' — $(date '+%F %T') — durada ${SECS}s"
  echo "VM en marxa:"; VBoxManage list runningvms 2>&1 | grep -v '^ *$' | sed 's/^/  /'
  echo; echo "vmstat 1 (r=procés en cua, si/so=swap, wa=espera E/S, us/sy/id=CPU):"
  vmstat -w -S M 1 "$SECS"
} > "$OUT"
rx1=$(cat /sys/class/net/$IF/statistics/rx_bytes); tx1=$(cat /sys/class/net/$IF/statistics/tx_bytes)
{
  echo; echo "free -m al final:"; free -m
  echo; echo "Xarxa $IF: RX $(( (rx1-rx0)/SECS/1024 )) KiB/s, TX $(( (tx1-tx0)/SECS/1024 )) KiB/s (mitjana)"
  echo; echo "Processos que més consumeixen:"; ps -eo pid,comm,%cpu,%mem,rss --sort=-%cpu | head -8
  echo; echo "Consum per VM (procés VBoxHeadless: %CPU mitjà des que arrenca, RSS = RAM real ocupada a l'amfitrió):"
  ps -eo %cpu,rss,args --sort=-rss | awk '/VBoxHeadless/ && !/awk/ {for(i=1;i<=NF;i++) if($i=="--startvm"||$i=="--comment") {n=$(i+1); break} printf "  %-20s CPU %5s %%  RAM %6.0f MB\n", n, $1, $2/1024}'
  echo; echo "Carrega de l'amfitrió (loadavg 1/5/15 min): $(cut -d' ' -f1-3 /proc/loadavg) · fils: $(nproc)"
} >> "$OUT"
# Resum d'una línia per a la taula de docs/06-rendiment.md
# CPU usada = us + sy + gu (gu = temps de CPU de les VM; sense sumar-lo, la càrrega de les VM no es veu). Es descarta la 1a línia (mitjana des de l'arrencada)
awk -v t="$TAG" 'NF==18 && $1~/^[0-9]+$/ && $18~/^[0-9]+$/ {if(!s){s=1;next} n++; r+=$1; sw+=$3; fr+=$4; si+=$7; so+=$8; us+=$13; sy+=$14; id+=$15; wa+=$16; gu+=$18}
  END {if(n) printf "| %s | %.1f | %.0f | %.0f | %.0f/%.0f | %.0f | %.0f | %.0f |\n", t, r/n, sw/n, fr/n, si/n, so/n, (us+sy+gu)/n, wa/n, id/n}' "$OUT" | tee -a "$OUT"
echo "Desat en $OUT"
