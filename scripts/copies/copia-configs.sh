#!/usr/bin/env bash
# copia-configs.sh — Orquestrador de còpies de configuració (Tasca 5 Apte+ · a105)
# S'executa a SRV-SERVEIS (192.168.13.22) com a usuari local "copies", amb claus SSH (cap contrasenya a l'script).
# Arreplega la configuració dels equips crítics que estiguen encesos i la puja al NAS (192.168.13.20:/mnt/copies) amb rsync.
#
#   R1 MikroTik      -> /export (usuari "copies" de només lectura al router)   -> routers/r1/
#   R2 OPNsense      -> /conf/config.xml (només si root té la clau instal·lada) -> routers/r2/
#   R3 Debian nft    -> nft list ruleset + tar de /etc/nftables.conf, xarxa...  -> routers/r3/
#   Nodes Proxmox    -> tar de /etc/pve, xarxa, hosts, corosync                 -> linux/<node>/
#   Servidors Linux  -> tar de /etc + llista de paquets                         -> linux/<servidor>/
#
# Instal·lació (vegeu docs/04-installacio.md §10):
#   sudo install -m 755 copia-configs.sh /usr/local/bin/
#   sudo cp copia-configs.service copia-configs.timer /etc/systemd/system/
#   sudo systemctl daemon-reload && sudo systemctl enable --now copia-configs.timer
# Prova manual: sudo systemctl start copia-configs.service && journalctl -u copia-configs -n 30
set -uo pipefail

NAS="copies@192.168.13.20"
NAS_DIR="/mnt/copies"
R1=192.168.13.1; R2=192.168.13.2; R3=192.168.13.3
PVE_NODES="192.168.13.32 192.168.13.33 192.168.13.34"
LINUX_SRV="192.168.13.22 192.168.13.23"
LINUX_USR="ivancambra"   # usuari de cloud-init (sudo sense contrasenya); les VM cloud no accepten root per SSH
KEEP_DAYS=14             # rotació: només s'esborren fitxers *-auto-* creats per aquest script
WORK=$(mktemp -d); DATA=$(date +%F_%H%M)
SSH="ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new"
OK=0; KO=0; OMES=0
log()  { echo "[$(date +%T)] $*"; }
fet()  { OK=$((OK+1));     log "OK  $1"; }
err()  { KO=$((KO+1));     log "ERR $1"; }
omes() { OMES=$((OMES+1)); log "--  $1"; }
viu()  { timeout 3 bash -c "</dev/tcp/$1/22" 2>/dev/null; }    # l'equip respon per SSH?
ple()  { [ -s "$1" ] || { rm -f "$1"; return 1; }; }            # el fitxer no ha d'estar buit
trap 'rm -rf "$WORK"' EXIT

# --- R1 MikroTik (router principal) ---
if viu $R1; then
  mkdir -p "$WORK/routers/r1"; f="$WORK/routers/r1/r1-export-auto-$DATA.rsc"
  $SSH copies@$R1 '/export' > "$f" 2>/dev/null && ple "$f" && fet "R1 MikroTik /export" || err "R1 MikroTik"
else omes "R1 $R1 no respon"; fi

# --- R2 OPNsense (alternatiu: normalment apagat) ---
if viu $R2; then
  mkdir -p "$WORK/routers/r2"; f="$WORK/routers/r2/r2-config-auto-$DATA.xml"
  scp -q -o BatchMode=yes -o ConnectTimeout=5 root@$R2:/conf/config.xml "$f" 2>/dev/null && ple "$f" \
    && fet "R2 OPNsense config.xml" || err "R2 OPNsense (cal la clau de copies a root)"
else omes "R2 $R2 apagat"; fi

# --- R3 Debian + nftables (alternatiu: normalment apagat) ---
if viu $R3; then
  mkdir -p "$WORK/routers/r3"; f="$WORK/routers/r3/r3-etc-auto-$DATA.tgz"
  $SSH root@$R3 'nft list ruleset' > "$WORK/routers/r3/r3-ruleset-auto-$DATA.txt" 2>/dev/null
  $SSH root@$R3 'tar czf - /etc/nftables.conf /etc/network /etc/sysctl.d /etc/dnsmasq.d 2>/dev/null' > "$f" && ple "$f" \
    && fet "R3 nftables" || err "R3 nftables"
else omes "R3 $R3 apagat"; fi

# --- Nodes Proxmox: configuració del clúster (les imatges de VM van per vzdump) ---
for n in $PVE_NODES; do
  viu "$n" || { omes "node $n apagat"; continue; }
  h=$($SSH root@$n hostname 2>/dev/null) || { err "node $n sense accés"; continue; }
  mkdir -p "$WORK/linux/$h"; f="$WORK/linux/$h/$h-pve-auto-$DATA.tgz"
  $SSH root@$n 'tar czf - /etc/pve /etc/network/interfaces /etc/hosts /etc/corosync 2>/dev/null' > "$f" && ple "$f" \
    && fet "Proxmox $h" || err "Proxmox $h"
done

# --- Servidors GNU/Linux: /etc i llista de paquets (permet reinstal·lar i restaurar) ---
for s in $LINUX_SRV; do
  viu "$s" || { omes "servidor $s apagat"; continue; }
  h=$($SSH $LINUX_USR@$s hostname 2>/dev/null) || { err "servidor $s sense accés"; continue; }
  mkdir -p "$WORK/linux/$h"; f="$WORK/linux/$h/$h-etc-auto-$DATA.tgz"
  $SSH $LINUX_USR@$s 'sudo -n tar czf - --one-file-system /etc 2>/dev/null' > "$f" && ple "$f" && \
  $SSH $LINUX_USR@$s 'dpkg --get-selections' > "$WORK/linux/$h/$h-paquets-auto-$DATA.txt" \
    && fet "Linux $h" || err "Linux $h"
done

# --- Pujada al NAS i rotació (només els fitxers d'aquest script) ---
if [ "$OK" -gt 0 ] && rsync -a "$WORK/" "$NAS:$NAS_DIR/"; then
  fet "rsync al NAS ($(du -sh "$WORK" | cut -f1))"
  $SSH $NAS "find $NAS_DIR/routers $NAS_DIR/linux -type f -name '*-auto-*' -mtime +$KEEP_DAYS -delete" || true
else
  err "rsync al NAS"
fi
log "Resum: $OK correctes, $KO errors, $OMES omesos (apagats)"
[ "$KO" -eq 0 ]
