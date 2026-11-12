#!/usr/bin/env bash
# infra-config.sh — servidors GNU/Linux d'infraestructura (VM 220 srv-serveis, VM 230 srv-dades) · a242, a243, a246
# S'executa com a ivancambra (usuari de cloud-init, sudo sense contrasenya):
#   ssh ivancambra@192.168.13.22 "PASS_LAB='<contrasenya>' bash -s" < infra-config.sh
# Fa: actualització completa, qemu-guest-agent, zona horària, usuaris admin-ivan (sudo) i suport (sense sudo),
#     i SSH sense root ni contrasenyes (només claus).
set -u
: "${PASS_LAB:?Cal definir PASS_LAB amb la contrasenya del laboratori (no es guarda al repositori)}"
export DEBIAN_FRONTEND=noninteractive
echo "### $(hostname) — $(date '+%F %T')"
echo "## a242 actualització"
echo "abans: $(cat /etc/debian_version) · nucli $(uname -r)"
sudo -n apt-get -o Acquire::http::Timeout=30 -o Acquire::Retries=3 update -qq
echo "paquets per actualitzar: $(apt list --upgradable 2>/dev/null | grep -vc Listing)"
sudo -n apt-get -y -q -o Dpkg::Options::=--force-confold full-upgrade 2>&1 | grep -E '^[0-9]+ (actualizados|upgraded)' 
echo "## a246 programari: només l'agent de Proxmox"
sudo -n apt-get -y -q install qemu-guest-agent 2>&1 | grep -E '^[0-9]+ (actualizados|upgraded)'
sudo -n systemctl enable --now qemu-guest-agent 2>/dev/null; echo "qemu-guest-agent: $(systemctl is-active qemu-guest-agent)"
sudo -n timedatectl set-timezone Europe/Madrid
echo "## a243 usuaris"
for u in admin-ivan suport; do id "$u" >/dev/null 2>&1 || sudo -n useradd -m -s /bin/bash -c "$([ $u = admin-ivan ] && echo 'Administrador (lloc 13)' || echo 'Consulta, sense privilegis')" "$u"; done
sudo -n usermod -aG sudo admin-ivan
printf 'admin-ivan:%s\nsuport:%s\n' "$PASS_LAB" "$PASS_LAB" | sudo -n chpasswd
sudo -n install -d -m 700 -o admin-ivan -g admin-ivan /home/admin-ivan/.ssh
sudo -n install -m 600 -o admin-ivan -g admin-ivan /home/ivancambra/.ssh/authorized_keys /home/admin-ivan/.ssh/authorized_keys
printf '# Lloc 13: root no entra per SSH; només claus (sense contrasenya)\nPermitRootLogin no\nPasswordAuthentication no\n' | sudo -n tee /etc/ssh/sshd_config.d/10-lloc13.conf >/dev/null
sudo -n sshd -t && sudo -n systemctl reload ssh && echo "sshd recarregat"
