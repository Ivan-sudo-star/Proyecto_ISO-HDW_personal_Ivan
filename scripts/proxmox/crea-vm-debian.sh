#!/usr/bin/env bash
# crea-vm-debian.sh — Crea una VM Debian 13 sense entorn gràfic dins del clúster cluster13
# a partir de la imatge cloud oficial (debian-13-generic-amd64.qcow2, verificada amb SHA512SUMS)
# i la configura amb cloud-init (usuari, contrasenya, clau SSH, IP fixa).
#
# Ús (com a root en un node Proxmox):
#   bash crea-vm-debian.sh <VMID> <nom> <IP> <discos-extra-GB separats per comes|-> [/ruta/clau.pub]
#   bash crea-vm-debian.sh 220 srv-serveis 192.168.13.22 2
#   bash crea-vm-debian.sh 230 srv-dades   192.168.13.23 1,1,1,1,1,2
# La contrasenya NO va a l'script: es llig de la variable d'entorn CIPASS.
set -euo pipefail
VMID=$1; NOM=$2; IP=$3; EXTRA=${4:--}; CLAU=${5:-}
IMG=/mnt/pve/nas-proxmox/import/debian-13-generic-amd64.qcow2
: "${CIPASS:?Defineix CIPASS amb la contrasenya del usuari ivancambra}"

qm create "$VMID" --name "$NOM" --ostype l26 --memory 1024 --cores 1 --cpu host \
  --scsihw virtio-scsi-single --net0 virtio,bridge=vmbr0 --agent 1 \
  --serial0 socket --vga serial0 --onboot 0
# Disc del sistema: s'importa la imatge cloud a local-lvm (thin) i s'amplia a 10 GB
qm set "$VMID" --scsi0 "local-lvm:0,import-from=$IMG,discard=on,ssd=1"
qm disk resize "$VMID" scsi0 10G
qm set "$VMID" --boot order=scsi0
# Discos addicionals (RAID / DRBD): scsi1, scsi2...
if [ "$EXTRA" != "-" ]; then
  i=1; for g in ${EXTRA//,/ }; do qm set "$VMID" --scsi$i "local-lvm:$g,discard=on,ssd=1"; i=$((i+1)); done
fi
# cloud-init: usuari amb sudo, contrasenya, clau i xarxa
qm set "$VMID" --ide2 local-lvm:cloudinit --ciuser ivancambra --cipassword "$CIPASS" \
  --ipconfig0 "ip=$IP/24,gw=192.168.13.1" --nameserver 192.168.13.1 --searchdomain lan13.local --ciupgrade 1
[ -n "$CLAU" ] && qm set "$VMID" --sshkeys "$CLAU"
qm config "$VMID"
