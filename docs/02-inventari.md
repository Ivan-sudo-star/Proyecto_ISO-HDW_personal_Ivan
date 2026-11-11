# 02 · Tasca 2 — Inventari, comparativa i colls de botella (FDM RA1 · a19–a21, a27–a29)

**Mètode:** [`scripts/host/inventari.sh`](../scripts/host/inventari.sh) llança `lscpu`, `free`, `lsblk`, `df`, `ip`,
`lshw`, `lspci`, `lsusb`, `inxi` i llig el DMI del firmware. Com que el sistema està al disc USB, s'executa
igual als dos equips. Les dades que necessiten `sudo` (tipus de RAM, ranures i SMART) s'obtenen amb `sudo -E bash scripts/host/inventari.sh <equip>`. A casa ja estan; a classe, pendents.

- Classe: [`inventari-classe-raw.txt`](../evidencias/t2-inventari/inventari-classe-raw.txt) — 11/11/2026 13:29
- Casa: [`inventari-casa-raw.txt`](../evidencias/t2-inventari/inventari-casa-raw.txt) — 11/11/2026 15:05

## 1. Inventari i comparativa (a19, a20)

| Component | Equip de classe | Equip de casa | Comparació |
|---|---|---|---|
| Format | Portàtil ASUS ExpertBook B3605CCA | Sobretaula, placa MSI B760M Gaming Plus WiFi (MS-7D99) | Portàtil: bateria, límit tèrmic |
| BIOS | AMI B3605CCA.303 (06/11/2025) | American Megatrends H.31 (23/02/2024) | — |
| CPU | Core Ultra 5 125H (Meteor Lake) · 14 nuclis 4P+8E+2LP-E · **18 fils** · 0,4–4,5 GHz · L3 18 MB | Core i5-12400F (Alder Lake) · 6 nuclis P · **12 fils** · 0,8–4,4 GHz · L3 18 MB | Classe: +50 % fils, però els nuclis E i LP-E són més lents |
| Virtualització | VT-x (vmx) · mòdul kvm_intel carregat | VT-x (vmx) | Totes dues admeten virtualització niuada |
| RAM | 32 GB · 30,6 GiB útils (la iGPU en reserva) · tipus/velocitat N/C (portàtil: probablement soldada; `sudo dmidecode -t memory` a classe) | **2×16 GB DDR5-6000** Corsair CMK32GX5M2B6000Z30 · doble canal (DIMMA2 + DIMMB2) · **2 ranures lliures** (A1, B1) · sense ECC · 31,2 GiB útils | Casa es pot ampliar fins a 4 mòduls. Cap dels dos té ECC (normal en equips personals) |
| Swap | zram 7,6 GB + swapfile 8 GB | zram 7,8 GB + swapfile 8 GB | La configura el SO del disc USB |
| Disc intern | NVMe Samsung MZVMA1T0HCLD 1 TB (no l'usa l'entorn) | 2× NVMe Kingston NV2 (500 GB + 1 TB, **sense DRAM**) (no els usa l'entorn) | No s'usen: l'entorn és al USB |
| Disc de l'entorn | SSD Intenso 1 TB per USB (UAS) | el mateix, connectat a **5 Gb/s a través d'un hub** USB | **Coll de botella comú** |
| Estat SMART | SSD USB: el mateix disc (vegeu casa) · NVMe Samsung: N/C | SSD USB Intenso: **PASSED**, 500 h d'ús, 0 sectors reassignats, desgast 0, 35 °C · NVMe 500 GB: PASSED, 1 % usat, 47 °C · NVMe 1 TB: PASSED, 8 % usat, 38 °C | El disc de l'entorn està sa: la lentitud de l'E/S síncrona no és una avaria, és del tipus de disc i de la connexió |
| GPU | Intel Arc integrada (Meteor Lake) | AMD Radeon RX 7600 dedicada | Sense impacte en VM de servidor |
| Xarxa cablejada | Intel (e1000e) · **1000 Mb/s full** | Realtek RTL8125 2,5 GbE · **100 Mb/s full** | **Casa limitada a 100 Mb/s** |
| Wi-Fi / BT | Realtek RTL8852BE 802.11ax · BT | Intel AX211 (CNVi) · BT | — |
| Firmware | UEFI · Secure Boot **off** · TPM 2.0 | UEFI · Secure Boot **on** · TPM 2.0 | SB a casa bloquejava `vboxdrv` → **resolt registrant la clau MOK** |
| Alimentació | Bateria 47 Wh, salut **93,9 %** (47,0/50,1 Wh) + carregador | Font ATX, model/potència N/C | Portàtil: rendiment menor amb bateria |
| Perifèrics | Webcam USB2 FHD, ratolí Cherry USB, hub USB2 | N/C (`lsusb` a l'inventari de casa) | — |

## 2. Tests de diagnòstic (Apte+ · a27, a28)

Script: [`scripts/host/tests-diagnostic.sh`](../scripts/host/tests-diagnostic.sh). Desa l'eina, la versió, les condicions i el resultat.

| Test | Eina | Condicions | Classe | Casa |
|---|---|---|---|---|
| Memòria 2 GB, 1 passada | memtester 4.6.0 | 0 VM, escriptori obert, RAM bloquejada (mlock) | ⬜ | ✅ **totes les proves OK** · cap error EDAC/MCE al nucli |
| Disc seqüencial escriptura 1 GiB | `dd` coreutils 9.4, `oflag=direct` | /home ext4 al SSD USB, 0 VM | **384 MB/s** ¹ | 358–359 MB/s |
| Disc seqüencial lectura 1 GiB | `dd iflag=direct` | ídem | **419 MB/s** ¹ | 310–402 MB/s |
| Disc seqüencial 1M QD8 | fio 3.36 (libaio, direct, 20 s) | ídem | ⬜ | lectura **439 MB/s** · escriptura **406 MB/s** |
| Disc aleatori 4K QD32 | fio | ídem | ⬜ | lectura **23 088 IOPS** · escriptura **18 332 IOPS** |
| Disc aleatori 4K QD1 | fio | ídem | ⬜ | lectura **3 707 IOPS** |
| Disc escriptura 4K QD1 **+ fsync** | fio · `dd oflag=dsync` | ídem | no acaba en ~110 s (≈ 7 IOPS?) ¹ ² | **422 IOPS (1,6 MB/s)** · dd: 2,1 MB/s |
| SMART del disc de l'entorn | smartctl (sudo) | — | el mateix disc | **PASSED** · 500 h · 0 sectors reassignats |
| Xarxa: enllaç | `/sys/class/net/*/speed`, `ethtool` | — | 1000 Mb/s | **100 Mb/s** (el router només anuncia 10/100) |
| Xarxa: latència GW / Internet | `ping -c 20` | — | ⬜ | 4,4–5,5 ms / 11,2–12,4 ms · 0 % pèrdua |
| Xarxa: descàrrega | `curl` 100 MB (OVH, Hetzner) | — | ⬜ | ≈ 6 MB/s ≈ **48 Mb/s** |
| Xarxa: LAN equip↔equip | `iperf3` | — | ⬜ | ⬜ (no hi ha un segon equip a casa: es pot fer amfitrió ↔ VM) |

¹ Primera execució a classe (11/11 13:39). Les dades de seqüencial són de la sortida del test. El fitxer de
registre es va sobreescriure en repetir-lo, així que **s'ha de repetir a classe** amb `bash scripts/host/tests-diagnostic.sh classe`.
² El procés es va aturar quan duia 3,4 MB escrits. Pot ser una mesura real o un efecte del port USB del portàtil: N/C fins que es repetisca.

Registres de casa: [`tests-casa-20261111-1504.txt`](../evidencias/t2-tests/tests-casa-20261111-1504.txt) (dd + xarxa) i [`tests-casa-20261111-1545.txt`](../evidencias/t2-tests/tests-casa-20261111-1545.txt) (memtester + dd + fio + xarxa).

## 3. Colls de botella

| # | Coll de botella previst | Equip | Dades (a29) | Confirmat? | Solució amb el maquinari que tinc (a21) |
|---|---|---|---|---|---|
| 1 | **E/S síncrona del SSD USB**: els Windows, TrueNAS i Proxmox fan moltes escriptures petites i síncrones | tots dos | `fio`: amb cua (QD32) el disc fa 18 000–23 000 IOPS, però **amb `fsync` en baixa a 422** (43 vegades menys). El disc està sa (SMART PASSED): és el cost de confirmar cada escriptura a través del pont USB | ✅ casa · classe N/C | Connectar el disc a un port USB 3.2 Gen2 directe (sense hub). No arrancar mai dues VM pesades d'E/S alhora. Activar *Use Host I/O Cache* al controlador SATA de les VM de proves (compte: es pot perdre l'última escriptura si s'apaga de cop). Ús de VM sense GUI |
| 2 | **RAM**: 30 GB per a totes les VM i en tinc 24 | tots dos | Càlcul a [01 §4](01-entorn.md#4-càlculs-i-limitacions-a18) | ✅ per càlcul; mesura a T7 | Treballar per escenaris. Reduir RAM de les VM sense GUI (R3 4 → 1 GB). Si cal, provar TrueNAS amb menys RAM |
| 3 | **Fils de CPU a casa**: 12 en lloc de 18 | casa | `lscpu` | ✅ | Suma de vCPU ≤ 10 a casa. 1 vCPU als servidors Linux lleugers |
| 4 | **Xarxa de casa a 100 Mb/s**: descàrregues d'ISO i actualitzacions lentes | casa | `ethtool`: l'altre extrem només anuncia 10/100. Descàrrega ≈ 48 Mb/s | ✅ | Provar un altre port del router o un cable Cat5e/Cat6 nou. Si el router és Fast Ethernet, no té solució sense canviar-lo. **No afecta la LAN13**, que és interna de VirtualBox i va per memòria |
| 5 | **Secure Boot a casa** impedeix carregar `vboxdrv` | casa | Avís de `VBoxManage`; `modinfo vboxdrv` mostra que el mòdul està signat amb una clau que la placa no té registrada | ✅ **resolt** | Registrar la clau MOK del disc al firmware de casa (una sola vegada), sense desactivar el Secure Boot. Comprovat: `mokutil --sb-state` → *enabled* i `lsmod` mostra `vboxdrv`, `vboxnetflt` i `vboxnetadp` (vegeu [01 §5](01-entorn.md#5-problemes-trobats-i-solució-a127)) |
| 6 | **Límit tèrmic / bateria** del portàtil | classe | ⬜ mesurar la freqüència de la CPU amb càrrega (T7) | N/C | Treballar sempre amb el carregador. Perfil d'energia de rendiment |
| 7 | Disc NVMe de casa sense DRAM | casa | No l'usa l'entorn | ❌ descartat | — |

**Conclusió provisional:** el que més limita no és cap dels dos PC, sinó **el disc USB que comparteixen**.
La RAM obliga a treballar per escenaris, però una vegada fet això no és el que frena més.
