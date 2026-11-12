# Índex de captures

Totes les imatges són captures reals de la pantalla de les VM (VirtualBox), fetes el 11/11 i el 12/11/2026.
Les webs de gestió s'han obert **des de CLI-Debian (192.168.13.200), dins de la LAN13**, que és l'accés de gestió escollit ([03 §5](../docs/03-xarxa.md#5-accés-de-gestió-a-les-webs-de-la-lan13)).
Les adreces MAC (i la IPv6 que en deriva) estan tapades amb un rectangle negre.
Cada imatge és a la carpeta `captures/` de la seua tasca, al costat de l'evidència de text corresponent.

## T5 · R1 MikroTik ([evidències](t5-mikrotik/))
| Captura | Què demostra |
|---|---|
| ![](t5-mikrotik/captures/01-installador-paquets.png) | a203: instal·lador de RouterOS 7.24.5 amb el paquet `system` |
| ![](t5-mikrotik/captures/02-installacio-completada.png) | a203: instal·lació acabada |
| ![](t5-mikrotik/captures/03-llicencia-x86-24h.png) | a203: llicència x86 sense clau (24 h de funcionament) |
| ![](t5-mikrotik/captures/04-bridge-lan13.png) | Bridge `bridge-lan13` de la LAN (WebFig) |
| ![](t5-mikrotik/captures/05-bridge-port-ether2.png) | `ether2` és l'únic port del bridge |
| ![](t5-mikrotik/captures/06-interficies-ether2-esclau.png) | Interfícies: `ether2` marcada com a esclava (`S`) del bridge |
| ![](t5-mikrotik/captures/07-llistes-lan-wan.png) | Llistes d'interfícies: LAN = `bridge-lan13`, WAN = `ether1` |
| ![](t5-mikrotik/captures/08-tallafocs-amb-llistes.png) | a207: regles del tallafocs amb les llistes LAN/WAN; la regla «PROVA: SSH a Internet» compta 5 paquets bloquejats |

## T5 · R2 OPNsense ([evidències](t5-opnsense/))
| Captura | Què demostra |
|---|---|
| ![](t5-opnsense/captures/01-panell-opnsense-26.7.png) | a210/a212: OPNsense 26.7, WAN 10.0.2.15 i LAN 192.168.13.2 (el panell anuncia la 26.7.9: pendent d'a79) |
| ![](t5-opnsense/captures/02-regles-lan.png) | a214: regles de la LAN: «Default allow» desactivada, bloqueig de tcp/22 (R2-BLOQ-SSH) i eixida permesa |
| ![](t5-opnsense/captures/03-registre-en-viu-bloquejat-i-permes.png) | a214: registre en viu filtrat pel client .200: connexions SSH **bloquejades** (vermell, 12/11) i eixides **permeses** R2-FWD-OK (verd, de la prova de l'11/11) |

## T5 · NAS TrueNAS ([evidències](t5-truenas/))
| Captura | Què demostra |
|---|---|
| ![](t5-truenas/captures/01-disc-installacio-sda.png) | a224: instal·lació només al disc de 20 GiB |
| ![](t5-truenas/captures/02-installacio-completada.png) | a224: instal·lació acabada |
| ![](t5-truenas/captures/03-panell-versio-25.10.7.png) | a224: panell amb la versió 25.10.7 i el nom `nas13` |
| ![](t5-truenas/captures/04-pool-copies-sa.png) | a227: pool `copies` sa (Online, sense errors), 47,48 GiB útils |
| ![](t5-truenas/captures/05-datasets-smb-nfs.png) | a227: datasets `clients`, `linux`, `proxmox`, `routers`, `usuaris` i `windows` |
| ![](t5-truenas/captures/06-recursos-smb-nfs.png) | a227: recursos SMB (`clients`, `windows`) i NFS (`/mnt/copies/proxmox`) actius |
| ![](t5-truenas/captures/07-usuaris.png) | a225: usuaris `root` (sense contrasenya), `truenas_admin` (administrador) i `copies` (només SMB i SSH) |

## T5 · Proxmox ([evidències](t5-proxmox/))
| Captura | Què demostra |
|---|---|
| ![](t5-proxmox/captures/01-pve1-resum-installacio.png) | a228: resum de la instal·lació de PVE1 |
| ![](t5-proxmox/captures/02-pve2-resum-installacio.png) | a228: resum de la instal·lació de PVE2 |
| ![](t5-proxmox/captures/03-pve3-resum-installacio.png) | a228: resum de la instal·lació de PVE3 |
| ![](t5-proxmox/captures/04-cluster13-nodes-vm-ct.png) | a232: clúster `cluster13` amb els 3 nodes en línia, la VM 220 a PVE2, la VM 230 a PVE3, el CT 100 i `nas-proxmox` als tres nodes |
| ![](t5-proxmox/captures/05-cluster-3-nodes-3-vots.png) | a232: 3 nodes, 1 vot cadascun |
| ![](t5-proxmox/captures/06-copia-programada-a105.png) | a105: tasca de còpia `copia-setmanal` (diumenge 03:00, `keep-last=3`, VM 100, 220 i 230) |
| ![](t5-proxmox/captures/07-emmagatzematge-nfs-compartit.png) | Emmagatzematge `nas-proxmox` (NFS) compartit pels nodes |
| ![](t5-proxmox/captures/08-copies-vzdump-al-nas.png) | a231/a105: còpies `vzdump` al NAS; la retenció ja ha esborrat la còpia més antiga de la VM 230 |

## T5 · Clients ([evidències](t5-clients/))
| Captura | Què demostra |
|---|---|
| ![](t5-clients/captures/cli-01-gestio-des-de-la-lan.png) | CLI-Debian (192.168.13.200, GW .1) amb les quatre webs de gestió obertes: R1, TrueNAS, Proxmox i OPNsense |

## T5 · Incidència d'arrencada ([evidències](t5-linux-infra/incidencia-grub.md))
| Captura | Què demostra |
|---|---|
| ![](t5-linux-infra/captures/a258-grub-prompt.png) | a258: símptoma, prompt `grub>` |
| ![](t5-linux-infra/captures/a258-grub-diagnosi.png) | a258: diagnosi, falta `grub.cfg` |
| ![](t5-linux-infra/captures/a258-grub-menu.png) | a258: el menú de GRUB carregat a mà |
