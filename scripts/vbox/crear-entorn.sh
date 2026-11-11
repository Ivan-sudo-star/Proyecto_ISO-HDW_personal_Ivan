#!/usr/bin/env bash
# crear-entorn.sh — Crea l'entorn individual de proves (lloc 13) en VirtualBox.
# - Totes les VM van al grup /ISO_HWD.
# - Xarxa interna LAN: "LAN13" (192.168.13.0/24). WAN dels routers: NAT de VirtualBox.
# - Idempotent: si una VM ja existeix, no la toca.
# Ús: bash scripts/vbox/crear-entorn.sh
set -euo pipefail

GROUP="/ISO_HWD"
LAN="LAN13"
ISO_DIR="$HOME/Escritorio/ISOS"
BASE="$HOME/VirtualBox VMs/ISO_HWD"

ISO_DEBIAN="$ISO_DIR/debian-13.1.0-amd64-netinst.iso"
ISO_MIKROTIK="$ISO_DIR/mikrotik-7.24.5.iso"
ISO_OPNSENSE="$ISO_DIR/OPNsense-26.7-dvd-amd64.iso"
ISO_TRUENAS="$ISO_DIR/TrueNAS-SCALE-25.10.7.iso"
ISO_PROXMOX="$ISO_DIR/proxmox-ve_9.2-1.iso"
# ISO de Windows Server 2025: es puja a l'emmagatzematge de PVE1 (no és una VM de VirtualBox)

exists() { VBoxManage showvminfo "$1" >/dev/null 2>&1; }

# crear_vm NOM OSTYPE RAM_MB VCPU FIRMWARE(bios|efi)
crear_vm() {
  local name=$1 os=$2 ram=$3 cpu=$4 fw=$5
  VBoxManage createvm --name "$name" --ostype "$os" --groups "$GROUP" \
    --basefolder "$HOME/VirtualBox VMs" --register
  VBoxManage modifyvm "$name" --memory "$ram" --cpus "$cpu" --firmware "$fw" \
    --audio-enabled off --usb-ohci off --usb-ehci off --usb-xhci off \
    --graphicscontroller vmsvga --vram 16 --boot1 dvd --boot2 disk --boot3 none --boot4 none
  VBoxManage storagectl "$name" --name SATA --add sata --controller IntelAhci --portcount 8
}

# disc NOM PORT MIDA_MB [nom_fitxer] [discard on|off]
# Nota: FreeBSD (OPNsense) dona timeouts amb TRIM al controlador AHCI de VirtualBox → discard off
disc() {
  local name=$1 port=$2 size=$3 file=${4:-disk$2} discard=${5:-on}
  local path="$BASE/$name/$file.vdi"
  [ -f "$path" ] || VBoxManage createmedium disk --filename "$path" --size "$size" --format VDI
  VBoxManage storageattach "$name" --storagectl SATA --port "$port" --device 0 \
    --type hdd --medium "$path" --nonrotational on --discard "$discard"
}

iso() {  # iso NOM FITXER
  local name=$1 f=$2
  if [ -f "$f" ]; then
    VBoxManage storageattach "$name" --storagectl SATA --port 7 --device 0 --type dvddrive --medium "$f"
  else
    echo "  [AVÍS] ISO no trobada: $f — VM $name creada sense ISO"
    VBoxManage storageattach "$name" --storagectl SATA --port 7 --device 0 --type dvddrive --medium emptydrive
  fi
}

nic_lan() {  # nic_lan NOM N [promisc]
  VBoxManage modifyvm "$1" --nic"$2" intnet --intnet"$2" "$LAN" --nictype"$2" 82540EM \
    --nicpromisc"$2" "${3:-deny}"
}
nic_nat() { VBoxManage modifyvm "$1" --nic"$2" nat --nictype"$2" 82540EM; }

nova() {  # nova NOM -> retorna 0 si cal crear-la
  if exists "$1"; then echo "= $1 ja existeix, no es modifica"; return 1; fi
  echo "+ Creant $1"; return 0
}

# ---------- Comunicacions: R1 .1 (porta d'enllaç principal), R2 .2, R3 .3 — només un DHCP actiu ----------
if nova R1-MikroTik; then
  crear_vm R1-MikroTik Linux26_64 512 1 bios
  disc R1-MikroTik 0 1024; iso R1-MikroTik "$ISO_MIKROTIK"
  nic_nat R1-MikroTik 1; nic_lan R1-MikroTik 2
fi

if nova R2-OPNsense; then
  crear_vm R2-OPNsense FreeBSD_64 2048 2 bios
  disc R2-OPNsense 0 20480 disk0 off; iso R2-OPNsense "$ISO_OPNSENSE"
  nic_nat R2-OPNsense 1; nic_lan R2-OPNsense 2
fi

# R3 = VM existent Debian_NFtables: WAN (NAT) a nic1, s'afig la LAN a nic2
if exists Debian_NFtables; then
  if VBoxManage showvminfo Debian_NFtables --machinereadable | grep -q "^intnet2=\"$LAN\""; then
    echo "= Debian_NFtables ja té nic2 a $LAN"
  else
    echo "~ Debian_NFtables: afegint nic2 -> $LAN"
    nic_lan Debian_NFtables 2
  fi
fi

# ---------- NAS / còpies ----------
if nova NAS-TrueNAS; then
  crear_vm NAS-TrueNAS Debian12_64 8192 2 efi
  disc NAS-TrueNAS 0 20480 boot
  disc NAS-TrueNAS 1 51200 copies       # disc addicional per a les còpies (a227)
  iso NAS-TrueNAS "$ISO_TRUENAS"
  nic_lan NAS-TrueNAS 1
fi

# ---------- Virtualització: clúster de 3 nodes Proxmox (igual que el grup) ----------
# Els servidors empresarials NO són VM de VirtualBox: són VM DINS dels nodes Proxmox
#   PVE1 -> SRV-WS2025 (Windows Server 2025)   PVE2 -> Debian serveis   PVE3 -> Debian dades
# Per això PVE1 té més RAM i disc (ha d'allotjar el Windows Server).
pve() {  # pve N RAM_MB VCPU DISC_MB
  local n=$1
  if nova PVE$n-Proxmox; then
    crear_vm PVE$n-Proxmox Debian13_64 "$2" "$3" bios
    VBoxManage modifyvm PVE$n-Proxmox --nested-hw-virt on
    disc PVE$n-Proxmox 0 "$4"
    iso PVE$n-Proxmox "$ISO_PROXMOX"
    nic_lan PVE$n-Proxmox 1 allow-all   # promiscu: les VM/CT niuades necessiten passar per vmbr0
  fi
}
pve 1 6144 4 65536
pve 2 3072 2 40960
pve 3 3072 2 40960

# ---------- Clients ----------
if nova CLI-Debian; then
  crear_vm CLI-Debian Debian13_64 2048 2 bios
  disc CLI-Debian 0 25600
  iso CLI-Debian "$ISO_DEBIAN"
  nic_lan CLI-Debian 1
fi

# Client Windows 11 = VM existent Cliente_windows_1: la seua NIC passa de NAT a la LAN
if exists Cliente_windows_1; then
  if VBoxManage showvminfo Cliente_windows_1 --machinereadable | grep -q "^intnet1=\"$LAN\""; then
    echo "= Cliente_windows_1 ja està a $LAN"
  else
    echo "~ Cliente_windows_1: nic1 NAT -> $LAN"
    nic_lan Cliente_windows_1 1
  fi
fi

echo; echo "Entorn creat. VM del grup $GROUP:"
VBoxManage list vms --long | awk -F': +' '/^Name:/{n=$2} /^Groups:/{if($2=="/ISO_HWD") print "  - " n}'
