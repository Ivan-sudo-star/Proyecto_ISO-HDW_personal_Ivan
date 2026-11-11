#!/usr/bin/env bash
# inventari.sh — Inventari de maquinari de l'equip físic (Tasca 2 Apte: a19).
# Ús: bash scripts/host/inventari.sh <classe|casa>
# Amb sudo afig RAM (tipus, velocitat, ranures) i SMART: sudo -E bash scripts/host/inventari.sh casa
set -uo pipefail
EQUIP=${1:?classe o casa}
OUT="evidencias/t2-inventari/inventari-$EQUIP-raw.txt"
mkdir -p "$(dirname "$OUT")"
sec() { echo; echo "## $1"; }
{
echo "# Inventari equip de ${EQUIP^^} - $(date -Iseconds)"
sec "Equip (DMI)"; cat /sys/class/dmi/id/{sys_vendor,product_name,board_vendor,board_name,bios_vendor,bios_version,bios_date} 2>/dev/null
sec "SO"; grep PRETTY_NAME /etc/os-release; uname -r
sec "CPU"; lscpu | grep -vE 'Vulnerab|Indicadores|Flags'
echo "Virtualització HW (vmx/svm): $(grep -cE 'vmx|svm' /proc/cpuinfo) fils"; lsmod | grep -E '^kvm' || true
sec "Memòria"; free -h; swapon --show
if [ "$(id -u)" = 0 ]; then dmidecode -t memory | grep -E 'Size|Type:|Speed|Locator|Manufacturer|Part Number' | grep -v 'Bank'; else echo "(tipus/velocitat/ranures: executar amb sudo)"; fi
sec "Discos"; lsblk -o NAME,SIZE,ROTA,TYPE,TRAN,MODEL,FSTYPE,MOUNTPOINTS; df -hT -x tmpfs -x devtmpfs -x squashfs -x overlay
if [ "$(id -u)" = 0 ] && command -v smartctl >/dev/null; then for d in $(lsblk -dno NAME | grep -vE 'zram|loop'); do echo "--- SMART /dev/$d"; smartctl -H -A /dev/$d | grep -E 'result|Percentage|Power_On|Reallocated|Wear|Temperature' ; done; else echo "(SMART: sudo + smartmontools)"; fi
sec "Firmware i arrencada"; [ -d /sys/firmware/efi ] && echo "UEFI" || echo "BIOS/Legacy"
mokutil --sb-state 2>/dev/null || echo "Secure Boot: N/C"
ls /dev/tpm* 2>/dev/null && echo "TPM present" || echo "TPM no detectat"
sec "Xarxa"; ip -br link; ip -br addr
for i in $(ls /sys/class/net | grep -vE 'lo|docker|veth|vbox'); do echo "$i: driver=$(basename "$(readlink /sys/class/net/$i/device/driver 2>/dev/null)") speed=$(cat /sys/class/net/$i/speed 2>/dev/null)Mb/s"; done
ip route
sec "PCI"; lspci
sec "USB"; lsusb
sec "Resum inxi"; inxi -Fxz -c0 2>/dev/null || echo "inxi no disponible"
sec "Alimentació"; ls /sys/class/power_supply/ 2>/dev/null || true
for b in /sys/class/power_supply/BAT*; do [ -d "$b" ] && echo "$(basename $b): $(cat $b/capacity)% estat=$(cat $b/status) disseny=$(cat $b/energy_full_design 2>/dev/null) actual=$(cat $b/energy_full 2>/dev/null)"; done
sec "VirtualBox"; VBoxManage --version; VBoxManage list vms
} 2>&1 | sed -E 's/([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}/xx:xx:xx:xx:xx:xx/g' > "$OUT"   # MAC anonimitzades
echo "Desat en $OUT ($(wc -l < "$OUT") línies)"
