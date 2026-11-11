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
} >> "$OUT"
# Resum d'una línia per a la taula de docs/06-rendiment.md
awk -v t="$TAG" 'NF==18 && $1~/^[0-9]+$/ && $18~/^[0-9]+$/ {n++; r+=$1; sw+=$3; fr+=$4; si+=$7; so+=$8; us+=$13; sy+=$14; id+=$15; wa+=$16}
  END {if(n) printf "| %s | %.1f | %.0f | %.0f | %.0f/%.0f | %.0f | %.0f | %.0f |\n", t, r/n, sw/n, fr/n, si/n, so/n, us/n+sy/n, wa/n, id/n}' "$OUT" | tee -a "$OUT"
echo "Desat en $OUT"
