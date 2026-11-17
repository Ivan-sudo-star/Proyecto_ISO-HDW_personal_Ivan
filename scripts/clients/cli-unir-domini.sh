#!/usr/bin/env bash
# cli-unir-domini.sh — CLI-Debian s'uneix al domini ivan-cambra-31.lan (realmd + SSSD) i s'hi inicia sessió amb «ivan».
# Ús (com a root):  sudo bash cli-unir-domini.sh        (demana la contrasenya de l'administrador del domini)
#   o bé: sudo CONTRASENYA='<contrasenya>' bash cli-unir-domini.sh   (sense terminal interactiva)
# Requisit: el DNS del client (R1, per DHCP) resol el domini -> R1 reenvia ivan-cambra-31.lan a 192.168.31.21.
set -euo pipefail
DOMINI=ivan-cambra-31.lan
DC=192.168.31.21

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq realmd sssd sssd-tools libnss-sss libpam-sss adcli samba-common-bin \
    oddjob oddjob-mkhomedir packagekit krb5-user systemd-timesyncd

# Kerberos no admet més de 5 minuts de diferència: el client agafa l'hora del controlador de domini
mkdir -p /etc/systemd/timesyncd.conf.d
printf '[Time]\nNTP=%s\nFallbackNTP=pool.ntp.org\n' "$DC" > /etc/systemd/timesyncd.conf.d/domini.conf
systemctl restart systemd-timesyncd

realm discover "$DOMINI"
if [ -n "${CONTRASENYA:-}" ]; then
    echo "$CONTRASENYA" | realm join -v -U Administrator "$DOMINI"
else
    realm join -v -U Administrator "$DOMINI"
fi

# Iniciar sessió amb «ivan» (no ivan@domini) i carpeta personal /home/ivan
sed -i 's/^use_fully_qualified_names = .*/use_fully_qualified_names = False/; s|^fallback_homedir = .*|fallback_homedir = /home/%u|' /etc/sssd/sssd.conf
pam-auth-update --enable mkhomedir
systemctl restart sssd

# GDM: demanar el nom d'usuari en lloc de mostrar la llista (com la pantalla d'inici de Windows del domini)
f=/etc/gdm3/greeter.dconf-defaults
grep -q '^disable-user-list=true' "$f" || sed -i '/^\[org\/gnome\/login-screen\]/a disable-user-list=true' "$f"

realm list
id ivan
