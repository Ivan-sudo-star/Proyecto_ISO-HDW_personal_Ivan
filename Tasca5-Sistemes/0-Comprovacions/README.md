# Comprovacions generals

**a78, a79, a258** · Estat: ✅

## a78 · Origen i integritat de les imatges

| Sistema | ISO | SHA-256 coincideix amb el fabricant? |
|---|---|---|
| Debian 13.1.0 netinst | `debian-13.1.0-amd64-netinst.iso` | ✅ |
| Proxmox VE 9.2-1 | `proxmox-ve_9.2-1.iso` | ✅ |
| TrueNAS SCALE 25.10.7 | `TrueNAS-SCALE-25.10.7.iso` | ✅ |
| OPNsense 26.7 | `OPNsense-26.7-dvd-amd64.iso` | ✅ (contra el hash oficial del `.bz2`) |
| MikroTik RouterOS 7.24.5 i 7.25.1 | `mikrotik-*.iso` | ✅ |
| Windows 11 | `w11.iso` (23H2 multiedició) | ➖ Microsoft no publica el hash d'aquesta versió |
| Windows Server 2025 | ISO d'avaluació | ➖ Microsoft no en publica el hash; `setup.exe` signat per Microsoft |

**5 de 7 verificades** contra el fabricant; les dues de Windows estan justificades. Evidència: [`verificacio.txt`](evidencies/verificacio.txt) · [`sha256-local.txt`](evidencies/sha256-local.txt) · [`sha256-oficial.txt`](evidencies/sha256-oficial.txt)

## a79 · Actualització abans de «producció»

| Sistema | Versió final |
|---|---|
| R1 MikroTik | 7.24.5 → **7.25.1** |
| R2 OPNsense | 26.7 → **26.7.9** |
| R3 i Debian (VM 220/230, CLI) | nucli **6.12.116**, 0 pendents |
| TrueNAS | **25.10.7**, al dia |
| Proxmox | `pve-manager` **9.2.26** |
| Windows 11 | **25H2** 26200.9974, al dia |
| Windows Server 2025 | **26100.33822**, 0 pendents |

Evidència: [`a79-actualitzacions.txt`](evidencies/a79-actualitzacions.txt) i les de cada sistema.

## a258 · Problemes d'arrencada i temps de resposta

| Sistema | Problema possible | Configuració crítica | Temps objectiu |
|---|---|---|---|
| Routers | Interfícies WAN/LAN canviades, sense NAT | IP de LAN, NAT, filtre, usuaris | 15 min |
| TrueNAS | Instal·lat al disc equivocat, pool no importat | Pool, usuaris, recursos, configuració | 30 min |
| Proxmox | Sense VT-x niuat, pèrdua de quòrum, `/etc/hosts` incorrecte | `/etc/pve`, corosync, `vmbr0` | 30 min |
| Windows | UEFI/TPM/Secure Boot, controlador de disc | IP fixa, rols, AD | 60 min |
| Debian | GRUB, nom d'interfície diferent | `interfaces`, `fstab` | 20 min |

**Incidència provocada:** GRUB trencat a propòsit al CLI-Debian → diagnòstic i solució en ≈ **1,5 min** ([`incidencia-grub.md`](../7-Servidors-Linux/evidencies/incidencia-grub.md)).
