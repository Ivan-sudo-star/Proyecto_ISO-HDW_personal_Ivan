#!/usr/bin/env bash
# crea-vm-ws2025.sh — VM 210 SRV-WS2025 a PVE1 amb instal·lació desatesa (a237-a239)
# HISTÒRIC: es va fer servir el 14/11. Des del 16/11 el WS2025 és una VM de VirtualBox (scripts/vbox/crea-srv-ws2025.sh)
# perquè niuat dins de PVE1 penjava el node (docs/01, problemes 13 i 14).
# S'executa com a root a PVE1, amb autounattend.xml i config-ws2025.ps1 al mateix directori:
#   PASS_LAB='<contrasenya>' bash crea-vm-ws2025.sh
# Necessita a local:iso: la ISO del WS2025 (avaluació) i virtio-win.iso.
set -euo pipefail
: "${PASS_LAB:?Cal definir PASS_LAB (no es guarda al repositori)}"
VMID=210; ISO=ws2025-eval-26100.32230-en-us.iso; DIR=/var/lib/vz/template/iso
D=$(mktemp -d)
sed "s/CANVIAR-CONTRASENYA/${PASS_LAB}/g" autounattend.xml > "$D/autounattend.xml"
cp config-ws2025.ps1 "$D/"
genisoimage -quiet -J -r -V UNATTEND -o "$DIR/ws2025-unattend.iso" "$D"
rm -rf "$D"     # la còpia amb la contrasenya només queda dins de la ISO local (no al NAS ni al Git)

qm create $VMID --name srv-ws2025 --ostype win11 --machine q35 --bios ovmf \
  --efidisk0 local-lvm:1,efitype=4m,pre-enrolled-keys=1 \
  --cpu host --cores 2 --memory 3072 --balloon 0 \
  --scsihw virtio-scsi-single --scsi0 local-lvm:32,discard=on,ssd=1,iothread=1 \
  --net0 virtio,bridge=vmbr0 --agent enabled=1 \
  --ide2 local:iso/$ISO,media=cdrom \
  --ide0 local:iso/virtio-win.iso,media=cdrom \
  --ide3 local:iso/ws2025-unattend.iso,media=cdrom \
  --boot order='ide2;scsi0' --description "Windows Server 2025 Standard Evaluation (Desktop Experience) - a237-a241"
qm config $VMID
