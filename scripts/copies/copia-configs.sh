#!/usr/bin/env bash
# copia-configs.sh — Orquestrador de còpies de configuració (Tasca 5 Apte+ · a105)
# S'executa a SRV-SERVEIS (192.168.13.22) com a usuari "copies", amb claus SSH
# (sense contrasenyes al script). Arreplega les configuracions dels equips crítics i
# les puja al NAS TrueNAS (192.168.13.20:/mnt/copies) amb rsync.
#
# Instal·lació:
#   sudo install -m 755 copia-configs.sh /usr/local/bin/
#   sudo cp copia-configs.service copia-configs.timer /etc/systemd/system/
#   sudo systemctl daemon-reload && sudo systemctl enable --now copia-configs.timer
# Prova manual: sudo systemctl start copia-configs.service && journalctl -u copia-configs -n 30
set -uo pipefail

NAS="copies@192.168.13.20"
NAS_DIR="/mnt/copies"
ROUTERS="192.168.13.1 192.168.13.2 192.168.13.3"   # R1, R2, R3: es copien els que estiguen encesos
PVE_NODES="192.168.13.32 192.168.13.33 192.168.13.34"
LINUX_SRV="192.168.13.22 192.168.13.23"
WORK=$(mktemp -d); DATA=$(date +%F_%H%M)
SSH="ssh -o BatchMode=yes -o ConnectTimeout=5"
OK=0; KO=0
log() { echo "[$(date +%T)] $*"; }
fet() { OK=$((OK+1)); log "OK  $1"; }
err() { KO=$((KO+1)); log "ERR $1"; }

# --- Routers encesos: cadascun s'identifica pel sistema que respon ---
for ROUTER in $ROUTERS; do
  ping -c1 -W1 "$ROUTER" >/dev/null 2>&1 || { log "--  $ROUTER apagat, s'omet"; continue; }
  SO=$($SSH root@$ROUTER 'uname -s' 2>/dev/null || true)
  if [ "$SO" = "FreeBSD" ]; then                 # R2 OPNsense
    mkdir -p "$WORK/routers/r2"
    scp -q -o BatchMode=yes root@$ROUTER:/conf/config.xml "$WORK/routers/r2/config-$DATA.xml" \
      && fet "R2 OPNsense config.xml" || err "R2 OPNsense"
  elif [ "$SO" = "Linux" ]; then                 # R3 Debian nftables
    mkdir -p "$WORK/routers/r3"
    $SSH root@$ROUTER 'nft list ruleset; echo "#---"; cat /etc/network/interfaces' \
      > "$WORK/routers/r3/ruleset-$DATA.txt" && \
    $SSH root@$ROUTER 'tar czf - /etc/nftables.conf /etc/network /etc/sysctl.d /etc/dnsmasq.d 2>/dev/null' \
      > "$WORK/routers/r3/etc-$DATA.tgz" && fet "R3 nftables" || err "R3 nftables"
  elif $SSH admin-ivan@$ROUTER '/system identity print' >/dev/null 2>&1; then   # R1 MikroTik
    mkdir -p "$WORK/routers/r1"
    $SSH admin-ivan@$ROUTER '/export show-sensitive=no' > "$WORK/routers/r1/export-$DATA.rsc" \
      && fet "R1 MikroTik export" || err "R1 MikroTik"
  else
    err "$ROUTER respon al ping però no per SSH"
  fi
done

# --- Nodes Proxmox: configuració del clúster (no les imatges de VM: van per vzdump) ---
for n in $PVE_NODES; do
  mkdir -p "$WORK/proxmox/$n"
  $SSH root@$n 'tar czf - /etc/pve /etc/network/interfaces /etc/hosts /etc/corosync 2>/dev/null' \
    > "$WORK/proxmox/$n/pve-$DATA.tgz" && fet "Proxmox $n" || err "Proxmox $n"
done

# --- Servidors GNU/Linux: /etc i llista de paquets (permet reinstal·lar i restaurar) ---
for s in $LINUX_SRV; do
  mkdir -p "$WORK/linux/$s"
  $SSH root@$s 'tar czf - /etc 2>/dev/null' > "$WORK/linux/$s/etc-$DATA.tgz" && \
  $SSH root@$s 'dpkg --get-selections' > "$WORK/linux/$s/paquets-$DATA.txt" \
    && fet "Linux $s" || err "Linux $s"
done

# --- Pujada al NAS i rotació (es conserven 14 dies) ---
if rsync -a "$WORK/" "$NAS:$NAS_DIR/"; then
  fet "rsync al NAS"
  $SSH $NAS "find $NAS_DIR/routers $NAS_DIR/proxmox $NAS_DIR/linux -type f -mtime +14 -delete" || true
else
  err "rsync al NAS"
fi
rm -rf "$WORK"
log "Resum: $OK correctes, $KO errors"
[ "$KO" -eq 0 ]
