# Tasca 0 · Entorn propi de proves

**FDM RA1** · a17, a18, a127 · Estat: ✅

## 1. On viu l'entorn

| Element | Valor |
|---|---|
| Suport | SSD extern Intenso 1 TB per USB amb Linux Mint 22.3 (funciona igual a classe i a casa) |
| Hipervisor | VirtualBox 7.2.18 · grup de VM **`/ISO_HWD`** |
| Xarxa | LAN interna **`LAN31`** = 192.168.31.0/24 · WAN dels routers = NAT de VirtualBox |

## 2. Equips amfitrió

| | Classe | Casa |
|---|---|---|
| Equip | ASUS ExpertBook B3605 (portàtil) | MSI B760M (sobretaula) |
| CPU / fils | Core Ultra 5 125H · **18 fils** | Core i5-12400F · **12 fils** |
| RAM | 32 GB (30,6 útils) | 32 GB DDR5 (31,2 útils) |
| Límit principal | RAM i temperatura | Fils de CPU |

Detall a la [Tasca 2](../Tasca2-Inventari/).

## 3. Màquines virtuals

| VM (VirtualBox) | Funció | IP | vCPU | RAM |
|---|---|---|---|---|
| R1-MikroTik | Router principal, DHCP, DNS | .1 | 1 | 0,5 GB |
| R2-OPNsense | Router alternatiu | .2 | 2 | 2 GB |
| Debian_NFtables (R3) | Router alternatiu | .3 | 1 | 1 GB |
| NAS-TrueNAS | Còpies (SMB, NFS, SSH) | .20 | 2 | 8 GB |
| SRV-WS2025 | Windows Server 2025, controlador del domini `ivan-cambra-31.lan` | .21 | 2 | 4 GB |
| PVE1 · PVE2 · PVE3 | Clúster Proxmox `cluster31` | .32 · .33 · .34 | 2 | 3 GB |
| CLI-Debian | Client Linux i equip de gestió | DHCP (.200) | 2 | 2 GB |
| Cliente_windows_1 | Client Windows 11 Pro | DHCP (.199) | 2 | 4 GB |

**Dins del clúster:** VM 220 SRV-SERVEIS (.22, PVE2), VM 230 SRV-DADES (.23, PVE3) i CT 100 (.41, PVE2).

## 4. Càlculs i limitacions (a18)

- Disponible per a VM: 30,6 − 6 GB per a l'amfitrió ≈ **24 GB**; vCPU: **≤ 10 a casa**, ≤ 16 a classe.
- Totes alhora (amb un sol router): **26,5 GB i 15 vCPU** → no hi caben. Es treballa per **escenaris**:

| Escenari | VM | RAM | Cap? |
|---|---|---|---|
| Comunicacions | 1 router + CLI + W11 + NAS | 16 GB | ✅ |
| Clúster | R1 + 3 nodes + CLI | 11,5 GB | ✅ |
| Còpies | R1 + NAS + nodes | 17,5 GB | ✅ |
| RAID / DRBD | R1 + PVE2 + PVE3 | 6,5 GB | ✅ |

Capacitat mesurada a la [Tasca 7](../Tasca7-Rendiment/): **8 VM** a classe amb 4,5 GB de marge.

## 5. Problemes i solució (a127)

| # | Problema | Causa | Solució |
|---|---|---|---|
| 1 | A casa no carrega `vboxdrv` | Secure Boot activat i clau MOK desconeguda | Registrar la clau MOK del disc al firmware (Secure Boot continua actiu) |
| 2 | Disc USB lent en escriptura síncrona | Pont USB / UAS | No fer dues tasques pesades de disc alhora ([Tasca 2](../Tasca2-Inventari/)) |
| 3 | VM niuades sense xarxa | El bridge `vmbr0` necessita MAC alienes | NIC promíscua als 3 nodes |
| 4 | Contrasenya de root de Proxmox massa curta | L'instal·lador exigeix 8 caràcters | Instal·lar amb 8 i canviar-la amb `passwd` |
| 5 | Teclat virtual escriu malament la `/` | Teclat espanyol vs US | Teclat US a l'instal·lador; gestió per SSH |
| 6 | Discos de TrueNAS canvien de nom | Ordre de detecció | Identificar-los per mida o número de sèrie |
| 7 | R2 i els nodes Proxmox es pengen (`DISCARD` cancel·lat) | El TRIM no funciona bé amb l'AHCI de VirtualBox | `--discard off` + memòria cau de l'amfitrió als discos de R2 i dels 3 nodes |
| 8 | Client W11 Home (no es pot unir a un domini) | VM existent amb Home | Canvi in situ a **Pro** amb la clau genèrica |
| 9 | `guestcontrol` sense privilegis a W11 | UAC | PowerShell elevat des de la consola |
| 10 | WS2025 dins de PVE1 penjava el node (*Guru Meditation*) | Virtualització niuada (VirtualBox → KVM → Windows) | WS2025 com a **VM de VirtualBox**, com a l'estructura del professor |
| 11 | L'equip de classe s'apaga amb molta càrrega | Temperatura: 97–100 °C | No fer actualitzacions de Windows amb totes les VM enceses |
| 12 | El nom «DC_Ivan_Cambra_31» no és vàlid; W11 entrava sol amb l'usuari local | Guió baix no permés en DNS; `AutoAdminLogon=1` | Domini `ivan-cambra-31.lan` + GPO que demana usuari i contrasenya |
| 13 | **Lloc equivocat: tot estava a 192.168.13.0/24** | El lloc correcte és el **31** | Canvi complet a 192.168.31.0/24 el 17/11 ([Tasca 4 §6](../Tasca4-Xarxa/README.md#4-canvi-de-lloc-13--31)) |

## 6. Evidències

- Les VM del grup amb RAM, vCPU i firmware: [`evidencies/vms.txt`](evidencies/vms.txt)
