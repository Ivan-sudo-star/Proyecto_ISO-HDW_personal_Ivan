# 02 · Tasca 2 — Inventari, comparativa i colls de botella (FDM RA1 · a19–a21, a27–a29)

**Mètode:** [`scripts/host/inventari.sh`](../scripts/host/inventari.sh) llança `lscpu`, `free`, `lsblk`, `df`, `ip`,
`lshw`, `lspci`, `lsusb`, `inxi` i llig el DMI del firmware. Com que el sistema està al disc USB, s'executa
igual als dos equips. Les dades que necessiten `sudo` (tipus de RAM, ranures i SMART) estan marcades N/C.

- Classe: [`inventari-classe-raw.txt`](../evidencias/t2-inventari/inventari-classe-raw.txt) — 11/11/2026 13:29
- Casa: [`inventari-casa-raw.txt`](../evidencias/t2-inventari/inventari-casa-raw.txt) — 11/11/2026 15:05

## 1. Inventari i comparativa (a19, a20)

| Component | Equip de classe | Equip de casa | Comparació |
|---|---|---|---|
| Format | Portàtil ASUS ExpertBook B3605CCA | Sobretaula, placa MSI B760M Gaming Plus WiFi (MS-7D99) | Portàtil: bateria, límit tèrmic |
| BIOS | AMI B3605CCA.303 (06/11/2025) | N/C (`inventari-casa-raw.txt` § DMI) | — |
| CPU | Core Ultra 5 125H (Meteor Lake) · 14 nuclis 4P+8E+2LP-E · **18 fils** · 0,4–4,5 GHz · L3 18 MB | Core i5-12400F (Alder Lake) · 6 nuclis P · **12 fils** · 0,8–4,4 GHz · L3 18 MB | Classe: +50 % fils, però els nuclis E i LP-E són més lents |
| Virtualització | VT-x (vmx) · mòdul kvm_intel carregat | VT-x (vmx) | Totes dues admeten virtualització niuada |
| RAM | 32 GB · 30,6 GiB útils (la iGPU en reserva) · tipus/velocitat N/C | 32 GB · 31,2 GiB útils · tipus/velocitat/ranures N/C | Equivalents. Prova: `sudo dmidecode -t memory` |
| Swap | zram 7,6 GB + swapfile 8 GB | zram 7,8 GB + swapfile 8 GB | La configura el SO del disc USB |
| Disc intern | NVMe Samsung MZVMA1T0HCLD 1 TB (no l'usa l'entorn) | 2× NVMe Kingston NV2 (500 GB + 1 TB, **sense DRAM**) (no els usa l'entorn) | No s'usen: l'entorn és al USB |
| Disc de l'entorn | SSD Intenso 1 TB per USB (UAS) | el mateix, connectat a **5 Gb/s a través d'un hub** USB | **Coll de botella comú** |
| Estat SMART | N/C (`sudo smartctl -a /dev/sda`) | N/C | Pendent |
| GPU | Intel Arc integrada (Meteor Lake) | AMD Radeon RX 7600 dedicada | Sense impacte en VM de servidor |
| Xarxa cablejada | Intel (e1000e) · **1000 Mb/s full** | Realtek RTL8125 2,5 GbE · **100 Mb/s full** | **Casa limitada a 100 Mb/s** |
| Wi-Fi / BT | Realtek RTL8852BE 802.11ax · BT | Intel AX211 (CNVi) · BT | — |
| Firmware | UEFI · Secure Boot **off** · TPM 2.0 | UEFI · Secure Boot **on** · TPM 2.0 | **SB a casa bloqueja vboxdrv** |
| Alimentació | Bateria 47 Wh, salut **93,9 %** (47,0/50,1 Wh) + carregador | Font ATX, model/potència N/C | Portàtil: rendiment menor amb bateria |
| Perifèrics | Webcam USB2 FHD, ratolí Cherry USB, hub USB2 | N/C (`lsusb` a l'inventari de casa) | — |

## 2. Tests de diagnòstic (Apte+ · a27, a28)

Script: [`scripts/host/tests-diagnostic.sh`](../scripts/host/tests-diagnostic.sh). Desa l'eina, la versió, les condicions i el resultat.

| Test | Eina | Condicions | Classe | Casa |
|---|---|---|---|---|
| Memòria | memtester / MemTest86 | — | ⬜ N/C | ⬜ N/C (cap error EDAC/MCE al registre del nucli) |
| Disc seqüencial escriptura 1 GiB | `dd` coreutils 9.4, `oflag=direct` | /home ext4 al USB, 0 VM | **384 MB/s** ¹ | **359 MB/s** |
| Disc seqüencial lectura 1 GiB | `dd iflag=direct` | ídem | **419 MB/s** ¹ | **310 MB/s** |
| Disc 4 KiB síncron | `dd oflag=direct,dsync` | ídem | no acaba en ~110 s (≈ 7 IOPS?) ¹ ² | **1,7 MB/s ≈ 415 IOPS** |
| Xarxa: enllaç | `/sys/class/net/*/speed`, `ethtool` | — | 1000 Mb/s | **100 Mb/s** (el router només anuncia 10/100) |
| Xarxa: latència GW / Internet | `ping -c 20` | — | ⬜ | 4,4 ms / 11,2 ms · 0 % pèrdua |
| Xarxa: descàrrega | `curl` 100 MB (OVH, Hetzner) | — | ⬜ | ≈ 6 MB/s ≈ **48 Mb/s** |
| Xarxa: LAN equip↔equip | `iperf3` | — | ⬜ | ⬜ |

¹ Primera execució a classe (11/11 13:39). Les dades de seqüencial són de la sortida del test. El fitxer de
registre es va sobreescriure en repetir-lo, així que **s'ha de repetir a classe** amb `bash scripts/host/tests-diagnostic.sh classe`.
² El procés es va aturar quan duia 3,4 MB escrits. Pot ser una mesura real o un efecte del port USB del portàtil: N/C fins que es repetisca.

Registre de casa: [`tests-casa-20261111-1504.txt`](../evidencias/t2-tests/tests-casa-20261111-1504.txt).

## 3. Colls de botella

| # | Coll de botella previst | Equip | Dades (a29) | Confirmat? | Solució amb el maquinari que tinc (a21) |
|---|---|---|---|---|---|
| 1 | **E/S síncrona del SSD USB**: els Windows, TrueNAS i Proxmox fan moltes escriptures petites i síncrones | tots dos | Seqüencial correcte (310–420 MB/s), però 4K síncron només 415 IOPS a casa | ✅ casa · classe N/C | Connectar el disc a un port USB 3.2 Gen2 directe (sense hub). No arrancar mai dues VM pesades d'E/S alhora. Activar *Use Host I/O Cache* al controlador SATA de les VM de proves (compte: es pot perdre l'última escriptura si s'apaga de cop). Ús de VM sense GUI |
| 2 | **RAM**: 30 GB per a totes les VM i en tinc 24 | tots dos | Càlcul a [01 §4](01-entorn.md#4-càlculs-i-limitacions-a18) | ✅ per càlcul; mesura a T7 | Treballar per escenaris. Reduir RAM de les VM sense GUI (R3 4 → 1 GB). Si cal, provar TrueNAS amb menys RAM |
| 3 | **Fils de CPU a casa**: 12 en lloc de 18 | casa | `lscpu` | ✅ | Suma de vCPU ≤ 10 a casa. 1 vCPU als servidors Linux lleugers |
| 4 | **Xarxa de casa a 100 Mb/s**: descàrregues d'ISO i actualitzacions lentes | casa | `ethtool`: l'altre extrem només anuncia 10/100. Descàrrega ≈ 48 Mb/s | ✅ | Provar un altre port del router o un cable Cat5e/Cat6 nou. Si el router és Fast Ethernet, no té solució sense canviar-lo. **No afecta la LAN13**, que és interna de VirtualBox i va per memòria |
| 5 | **Secure Boot a casa** impedeix carregar `vboxdrv` | casa | Avís de `VBoxManage`; `modinfo vboxdrv` mostra que el mòdul està signat amb una clau que la placa no té registrada | ✅ | Registrar la clau MOK del disc al firmware de casa (una sola vegada), sense desactivar el Secure Boot (vegeu [01 §5](01-entorn.md#5-problemes-trobats-i-solució-a127)) |
| 6 | **Límit tèrmic / bateria** del portàtil | classe | ⬜ mesurar la freqüència de la CPU amb càrrega (T7) | N/C | Treballar sempre amb el carregador. Perfil d'energia de rendiment |
| 7 | Disc NVMe de casa sense DRAM | casa | No l'usa l'entorn | ❌ descartat | — |

**Conclusió provisional:** el que més limita no és cap dels dos PC, sinó **el disc USB que comparteixen**.
La RAM obliga a treballar per escenaris, però una vegada fet això no és el que frena més.
