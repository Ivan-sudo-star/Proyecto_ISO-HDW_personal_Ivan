#!/usr/bin/env bash
# crea-srv-ws2025.sh — SRV-WS2025 com a VM de VirtualBox (estructura individual del professor: el WS2025 va
# directament a la xarxa interna LAN31, no dins d'un node Proxmox). 16/11/2026.
# Origen del disc: la VM 210 de PVE1 (instal·lació desatesa del 14/11), copiada sense reinstal·lar:
#   ssh root@pve1 'dd if=/dev/pve/vm-210-disk-1 bs=4M | zstd -1 -T0 -c' | zstd -d -c \
#     | VBoxManage convertfromraw stdin "$DIR/srv-ws2025.vdi" 34359738368 --format VDI
# Controlador virtio-scsi i targeta virtio-net: Windows ja té els controladors VirtIO (vioscsi, NetKVM),
# així que arrenca sense canviar res. La IP .21 la torna a posar la tasca d'inici «lloc31-xarxa»
# (configs/ws2025/xarxa-inici.ps1), perquè la targeta de VirtualBox és nova per a Windows.
set -euo pipefail
VM=SRV-WS2025; GROUP=/ISO_HWD; LAN=LAN31
DIR="$HOME/VirtualBox VMs/ISO_HWD/$VM"; DISK="$DIR/srv-ws2025.vdi"
VBoxManage createvm --name "$VM" --ostype Windows2025_64 --groups "$GROUP" --basefolder "$HOME/VirtualBox VMs" --register
VBoxManage modifyvm "$VM" --memory 4096 --cpus 2 --firmware efi --chipset ich9 \
  --graphicscontroller vboxsvga --vram 64 --audio-enabled off --usb-ohci off --usb-ehci off --usb-xhci off \
  --nic1 intnet --intnet1 "$LAN" --nictype1 virtio --nicpromisc1 deny \
  --boot1 disk --boot2 dvd --boot3 none --boot4 none --rtc-use-utc off \
  --description "Windows Server 2025 Standard Evaluation · 192.168.31.21 · a237-a241"
VBoxManage storagectl "$VM" --name VirtIO --add virtio --controller VirtIO --portcount 2 --bootable on
VBoxManage storageattach "$VM" --storagectl VirtIO --port 0 --device 0 --type hdd --medium "$DISK" --nonrotational on --discard off
VBoxManage storagectl "$VM" --name SATA --add sata --controller IntelAhci --portcount 1
VBoxManage storageattach "$VM" --storagectl SATA --port 0 --device 0 --type dvddrive --medium emptydrive
VBoxManage showvminfo "$VM" --machinereadable | grep -E '^(memory|cpus|firmware|nic1|intnet1|nictype1|"VirtIO-0-0")='
