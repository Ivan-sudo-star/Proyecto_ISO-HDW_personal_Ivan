# 01 · Tasca 0 — Entorn propi de proves (FDM RA1 · a17, a18, a127)

## 1. On viu l'entorn

| Element | Valor |
|---|---|
| Suport | SSD extern **Intenso 1 TB per USB** (UAS, 5 Gb/s) amb Linux Mint 22.3 instal·lat |
| Particions | `sda1` EFI 512 MB · `sda2` `/` 58 GB ext4 · `sda3` `/home` 880 GB ext4 (663 GB lliures) |
| Hipervisor | VirtualBox **7.2.18** r175117 (tipus 2, sobre Linux) |
| Grup de VM | **`/ISO_HWD`** — carpeta `~/VirtualBox VMs/ISO_HWD/` |
| ISOs | `~/Escritorio/ISOS/` (integritat comprovada a [04 §1](04-installacio.md#1-comprovacions-generals-a78-a79-a258-a259)) |
| Creació reproduïble | [`scripts/vbox/crear-entorn.sh`](../scripts/vbox/crear-entorn.sh) (idempotent: no toca les VM que ja existeixen) |

**Per què un disc extern:** el mateix entorn funciona a classe i a casa sense copiar VM. La contrapartida
és que el maquinari amfitrió canvia i que el rendiment de disc queda limitat pel USB (vegeu
[02-inventari](02-inventari.md#3-colls-de-botella)).

## 2. Recursos físics dels dos amfitrions

| Recurs | Equip de classe | Equip de casa | Limita el disseny? |
|---|---|---|---|
| Model | ASUS ExpertBook B3605CCA (portàtil) | MSI B760M Gaming Plus WiFi (sobretaula) | — |
| CPU | Intel Core Ultra 5 125H · 14 nuclis (4P+8E+2LP) · **18 fils** | Intel Core i5-12400F · 6 nuclis · **12 fils** | **Sí: casa té menys fils** |
| Virtualització HW | VT-x actiu | VT-x actiu | No |
| RAM | 32 GB (30,6 GiB útils: la gràfica integrada en reserva) | 32 GB DDR5-6000 2×16 (31,2 GiB útils, 2 ranures lliures) | **Sí** |
| Disc de l'entorn | el mateix SSD USB | el mateix SSD USB (a través d'un hub USB 5 Gb/s) | **Sí: E/S síncrona** |
| Xarxa | eno1 Intel 1 Gb/s | enp7s0 Realtek 2,5 Gb/s **negociada a 100 Mb/s** | Només descàrregues |
| Firmware | UEFI · Secure Boot **desactivat** · TPM 2.0 | UEFI · Secure Boot **activat** · TPM 2.0 | Resolt amb la clau MOK (§5) |

Dades brutes: [`evidencias/t2-inventari/`](../evidencias/t2-inventari/).

## 3. Màquines virtuals planificades

Totes al grup `/ISO_HWD`, LAN = xarxa interna `LAN13` (192.168.13.0/24), WAN dels routers = NAT.
El disseny **reprodueix el del grup 3** ([repositori del grup](https://github.com/varo010/asix-aula-grup-03-ISO)):
- 3 servidors de comunicacions alternatius;
- NAS TrueNAS;
- clúster de **3 nodes Proxmox**, amb els servidors empresarials (Windows Server 2025, Debian serveis i Debian dades) com a VM **dins** dels nodes;
- clients Windows i Linux.

La diferència és el suport. El grup usa maquinari físic (MikroTik hEX, PC-02 amb TrueNAS) i el servidor de classe per als nodes. Jo ho faig tot dins de VirtualBox.

### 3.1 Nivell 1: VM de VirtualBox

| VM | Funció | SO | vCPU | RAM | Disc(s) | Xarxa | Firmware |
|---|---|---|---|---|---|---|---|
| R1-MikroTik | Router/tallafocs principal (.1) | RouterOS **7.25.1** x86 (instal·lat amb la 7.24.5) | 1 | 512 MB | 1 GB | NAT + LAN13 | BIOS |
| R2-OPNsense | Router/tallafocs alternatiu (.2) | OPNsense 26.7 | 2 | 2 GB | 20 GB | NAT + LAN13 | BIOS |
| Debian_NFtables (R3) | Router/tallafocs alternatiu (.3) | Debian 13 + nftables | 2 → **1** | 4 GB → **1 GB** | 25 GB (existent, 7,3 GB ocupats) | NAT + LAN13 | BIOS |
| NAS-TrueNAS | Servidor de còpies (.20) | TrueNAS SCALE 25.10.7 | 2 | 8 GB | 20 GB boot + **50 GB còpies** | LAN13 | EFI |
| PVE1-Proxmox | Node 1 (.32): allotja el WS2025 | Proxmox VE 9.2 | 4 | 6 GB | 64 GB | LAN13 (promiscu) | BIOS · VT-x niuat |
| PVE2-Proxmox | Node 2 (.33): allotja Debian serveis + CT | Proxmox VE 9.2 | 2 | 3 GB | 40 GB | LAN13 (promiscu) | BIOS · VT-x niuat |
| PVE3-Proxmox | Node 3 (.34): allotja Debian dades | Proxmox VE 9.2 | 2 | 3 GB | 40 GB | LAN13 (promiscu) | BIOS · VT-x niuat |
| CLI-Debian | Client GNU/Linux i equip de gestió | Debian 13 + GNOME | 2 | 2 GB | 25 GB | LAN13 | BIOS |
| Cliente_windows_1 | Client Windows | Windows 11 **Pro** 23H2 (existent; era Home, problema 10) | 2 | 4 GB | 80 GB (existent, 14 GB ocupats) | LAN13 | EFI + TPM 2.0 + SB |

### 3.2 Nivell 2: VM i contenidors dins del clúster Proxmox

| VM/CT (Proxmox) | Node | Funció | SO | vCPU | RAM | Disc(s) | IP |
|---|---|---|---|---|---|---|---|
| 210 SRV-WS2025 | PVE1 | Centralització (domini) | Windows Server 2025 | 2 | 4 GB | 50 GB (thin) | 192.168.13.21 |
| 220 SRV-SERVEIS | PVE2 | Servidor d'infraestructura, orquestrador de còpies, DRBD node A | Debian 13 sense GUI | 1 | 1 GB | 10 GB + 2 GB (DRBD) | 192.168.13.22 |
| 230 SRV-DADES | PVE3 | Servidor de dades, proves de RAID, DRBD node B | Debian 13 sense GUI | 1 | 1 GB | 10 GB + 5×1 GB (RAID) + 2 GB (DRBD) | 192.168.13.23 |
| CT 100 | PVE2 | Contenidor de prova per a la migració | Debian 13 (LXC) | 1 | 512 MB | 4 GB | 192.168.13.41 |

**Comprovació interna dels nodes:**
- PVE1: 6 GB − 4 GB del WS2025 = 2 GB per a Proxmox (n'usa ≈ 1–1,5 GB). Just, però dins del marge.
- PVE2: 3 GB − 1 GB − 0,5 GB = 1,5 GB lliures. Hi cap una migració del CT o de la VM d'un altre node.
- PVE3: 3 GB − 1 GB = 2 GB lliures. Pot rebre SRV-SERVEIS en una migració.

R3 i el client Windows són VM que ja tenia instal·lades. L'script els ha afegit la interfície de la LAN13.
El canvi de RAM de R3 (4 GB → 1 GB) és la primera optimització de la [Tasca 7](06-rendiment.md#optimitzacions-apte-a123a125).

## 4. Càlculs i limitacions (a18)

**Reserva per a l'amfitrió.** La línia base de casa, amb Cinnamon, Chrome i Discord oberts, ocupa
**5,7 GB** ([mesura](../evidencias/t7-rendiment/)). Deixe **6 GB** a l'amfitrió.

- RAM disponible per a VM: 30,6 − 6 ≈ **24 GB** (classe, el cas pitjor).
- Fils: 12 a casa i 18 a classe. Deixe 2 fils a l'amfitrió, així que el límit és **≤ 10 vCPU a casa** i ≤ 16 a classe.

**Si s'arrancaren totes alhora** (amb un sol router, R1):

| | RAM | vCPU |
|---|---|---|
| Suma (R1 + NAS + PVE1 + PVE2 + PVE3 + CLI + W11) | 0,5 + 8 + 6 + 3 + 3 + 2 + 4 = **26,5 GB** | 1 + 2 + 4 + 2 + 2 + 2 + 2 = **15** |
| Disponible | 24 GB | 10 (casa) / 16 (classe) |
| Resultat | ❌ no hi caben | ❌ a casa / ✅ a classe |

Per això treballe per **escenaris**: només arranque les VM que necessita cada prova.

| Escenari | VM enceses (VirtualBox) | RAM | vCPU | Cap? |
|---|---|---|---|---|
| E1 Comunicacions | 1 router (cas pitjor: R2) + CLI-Debian + W11 + NAS | 2 + 2 + 4 + 8 = 16 GB | 8 | ✅ |
| E2 Clúster (migració) | R1 + PVE1 + PVE2 + PVE3 + CLI-Debian | 0,5 + 6 + 3 + 3 + 2 = 14,5 GB | 11 | ✅ RAM · ⚠️ vCPU a casa (sobreassignació, s'ha de mesurar) |
| E2b Clúster + còpies vzdump | E2 + NAS | 22,5 GB | 13 | ⚠️ al límit: millor a classe |
| E3 Còpies automàtiques | R1 + NAS + PVE2 + PVE3 | 0,5 + 8 + 3 + 3 = 14,5 GB | 7 | ✅ |
| E4 RAID i DRBD | R1 + PVE2 + PVE3 | 6,5 GB | 5 | ✅ |

**Sobreassignació de vCPU:** assignar més vCPU que fils físics és possible, perquè les vCPU només consumeixen quan
treballen. Amb tots els nodes ocupats alhora, però, la cua de CPU (`r` a `vmstat`) creix. Ho comprove a la [Tasca 7](06-rendiment.md).

**Virtualització niuada a dos nivells** (VirtualBox → Proxmox → WS2025): cada nivell afig sobrecàrrega. Que el Windows Server
vaja lent dins de PVE1 és previsible; serà una de les mesures de la T7.

**Disc:** els VDI són dinàmics. La mida nominal total és ≈ 365 GB i en queden 663 lliures, així que l'espai no limita.
El que limita és la **velocitat d'escriptura síncrona del SSD USB** ([02 §3](02-inventari.md#3-colls-de-botella)):
no arrancaré mai a la vegada dos Windows i TrueNAS mentre s'actualitzen.

**TrueNAS:** el mínim oficial és de 8 GB de RAM. És la VM més cara, i provar si funciona amb 4 GB en
escenaris curts és una optimització possible (N/C, s'ha de mesurar).

## 5. Problemes trobats i solució (a127)

| # | Problema | Causa | Solució | Estat |
|---|---|---|---|---|
| 1 | A casa, VirtualBox avisa: *«The vboxdrv kernel module is not loaded»* i cap VM arranca | La placa MSI té **Secure Boot activat**. Els mòduls `vboxdrv`, `vboxnetflt` i `vboxnetadp` **sí que estan signats** amb la clau MOK pròpia del disc (`/var/lib/shim-signed/mok/MOK.der`, sèrie `68:EA:5F…`, comprovat amb `modinfo` i `openssl`), però el firmware de casa no coneix aquesta clau. A classe el Secure Boot està desactivat, per això allà funciona | **Registrar la clau MOK al firmware de casa una sola vegada** (`sudo mokutil --import /var/lib/shim-signed/mok/MOK.der` → reiniciar → *MOK Manager* → *Enroll MOK*). Es manté el Secure Boot activat. Com que la clau viu al disc USB, DKMS torna a signar els mòduls amb la mateixa clau a cada actualització del nucli i no s'ha de repetir. Alternativa descartada: desactivar el Secure Boot, que redueix la seguretat i s'hauria de recordar a cada equip | ✅ 11/11: clau registrada a la MSI, Secure Boot encara *enabled*, `lsmod` mostra `vboxdrv`, `vboxnetflt` i `vboxnetadp` |
| 2 | En repetir el test de disc, el fitxer de proves acabava a l'equip equivocat | Sense adonar-me'n havia arrancat el disc USB a l'altre PC | Els scripts demanen l'etiqueta `classe` o `casa`, i l'inventari mostra el model de placa per comprovar-ho | ✅ |
| 3 | L'escriptura síncrona de 4 KiB al SSD USB és molt lenta (1,7 MB/s ≈ 415 IOPS a casa; a classe, el test de 20 000 blocs no acabava) | Disc USB amb controlador UAS, a través d'un hub | Test reduït amb límit de temps. Mesures de mitigació a [02 §3](02-inventari.md#3-colls-de-botella) | 🟡 |
| 4 | Les VM niuades de Proxmox no tenen xarxa si la NIC de VirtualBox no és promíscua | El bridge `vmbr0` necessita MAC alienes | `--nicpromisc1 allow-all` als 3 nodes PVE (ja aplicat per l'script) | 🟡 funciona (les VM 220/230 i el CT 100 es gestionen per SSH i es descarreguen paquets), però falta guardar-ne la prova (`ping` des de CLI-Debian, amb a244) |
| 5 | Falta la ISO de Windows Server 2025 | No era a `~/Escritorio/ISOS/` | Descarregar l'avaluació de 180 dies del Microsoft Evaluation Center i pujar-la a l'emmagatzematge ISO de PVE1 (o al NFS del NAS) | ⬜ |
| 6 | Proxmox exigeix una contrasenya de root de **8 caràcters com a mínim**, i la de laboratori és més curta | Política de l'instal·lador | S'instal·la amb una de 8 caràcters i després es canvia amb `passwd`: el sistema base ho permet, perquè `root@pam` és un usuari de Linux | ✅ |
| 7 | L'instal·lador de Proxmox posava el teclat **espanyol**, i el teclat virtual de VirtualBox (`keyboardputstring`) envia les tecles com un teclat US: la `/` de les IP eixia malament | Distribució de teclat diferent | Teclat «U.S. English» a l'instal·lador; la gestió posterior es fa per SSH i web | ✅ |
| 8 | TrueNAS: el disc d'arrencada va canviar de nom (`sda` → `sdb`) després del reinici | Linux assigna `sdX` per ordre de detecció | Identificar els discos per mida o número de sèrie, no pel nom | ✅ |

| 9 | OPNsense (R2) es penjava: la web no responia i la consola mostrava `DSM TRIM ... Command timeout` | FreeBSD i el TRIM del controlador AHCI de VirtualBox no s'entenen | `--discard off` al disc de R2, corregit també a `crear-entorn.sh` ([04 §3](04-installacio.md#3-r2--opnsense-a210a216)) | ✅ |
| 10 | El client és **Windows 11 Home**, però el disseny del grup preveu **Windows 11 Pro** (unió al domini, GPO, BitLocker). Home no es pot unir a un domini | La VM ja existia amb Home | La ISO `w11.iso` és multiedició (es-ES) i inclou Pro. Canvi d'edició *in situ* amb la clau genèrica de Microsoft per a Pro (només canvia l'edició, no activa): es conserven usuaris i configuració. Instantània prèvia `W11-Home-a250-ok` | ✅ 12/11: ara és Pro, sense activar ([evidència](../evidencias/t5-clients/a247-w11-pro.txt)) |
| 11 | `VBoxManage guestcontrol` no pot fer tasques d'administrador a W11 (accés denegat a Secure Boot/TPM i a crear usuaris) | El procés s'executa amb el testimoni filtrat de l'UAC | S'obri un PowerShell elevat a la consola de la VM (Win+R, Ctrl+Maj+Retorn) i s'accepta l'UAC | ✅ |

*(Afegir ací cada problema nou que aparega durant la instal·lació, amb símptoma, causa, solució i com ho he comprovat.)*

## 6. Evidències
- [x] Les 9 VM del grup `/ISO_HWD` amb RAM, vCPU, firmware i estat (`VBoxManage list vms --long`) → [`evidencias/t0-entorn/vms.txt`](../evidencias/t0-entorn/vms.txt)
- [ ] (Opcional) Captura de la finestra de VirtualBox amb el grup `/ISO_HWD` desplegat → `evidencias/t0-entorn/vbox-grup.png`

