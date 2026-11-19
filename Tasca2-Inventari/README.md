# Tasca 2 · Inventari, tests i colls de botella

**FDM RA1** · a19–a21 (Apte), a27–a29 (Apte+) · Estat: ✅

**Mètode:** ordres `lscpu`, `free`, `lsblk`, `lshw`, `lspci`, `inxi` i `smartctl` (inventari), i `memtester`, `fio`, `dd`, `iperf3` i `ping` (tests). Fet als dos equips: casa (11/11) i classe (12/11).

## 1. Inventari i comparativa (a19, a20)

| Component | Classe | Casa | Comparació |
|---|---|---|---|
| Equip | Portàtil ASUS ExpertBook B3605 | Sobretaula MSI B760M | Portàtil: bateria i límit tèrmic |
| CPU | Core Ultra 5 125H · **18 fils** | Core i5-12400F · **12 fils** | Classe +50 % de fils |
| RAM | 2×16 GB DDR5-5600 · **cap ranura lliure** | 2×16 GB DDR5-6000 · **2 ranures lliures** | Només casa es pot ampliar |
| Disc de l'entorn | El mateix SSD USB (UAS) | El mateix, per un hub de 5 Gb/s | **Coll de botella comú** |
| SMART | PASSED · 0 sectors reassignats | PASSED · 0 sectors reassignats | El disc està sa |
| Xarxa | Intel **1 Gb/s** | Realtek 2,5 GbE a **100 Mb/s** (adaptador PLC) | Casa limitada pel PLC |
| Firmware | UEFI · Secure Boot off · TPM 2.0 | UEFI · Secure Boot **on** · TPM 2.0 | Resolt amb la clau MOK |

## 2. Tests de diagnòstic (Apte+ · a27, a28)

| Test | Eina | Classe | Casa |
|---|---|---|---|
| Memòria 2 GB | memtester 4.6 | ✅ cap error | ✅ cap error |
| Disc seqüencial (lect./escr.) | fio 1M QD8 | 433 / 429 MB/s | 439 / 406 MB/s |
| Disc aleatori 4K QD32 (lect./escr.) | fio | 27 323 / 20 157 IOPS | 23 088 / 18 332 IOPS |
| **Escriptura 4K + fsync** | fio | **179 IOPS** | **422 IOPS** |
| Enllaç de xarxa | ethtool | 1000 Mb/s | 100 Mb/s |
| Descàrrega d'Internet | curl 100 MB | 8,5 Mb/s (sortida de l'aula; ICMP bloquejat) | ≈ 48 Mb/s |
| LAN equip ↔ equip | iperf3 | **934 Mb/s**, 0 retransmissions | — |

## 3. Colls de botella (a21, a29)

| Previst | Dades | Confirmat? | Solució |
|---|---|---|---|
| **E/S síncrona del SSD USB** | Amb fsync, de ~20 000 a **179–422 IOPS** | ✅ | No fer dues tasques pesades de disc alhora; port USB directe; memòria cau de l'amfitrió als discos dels nodes |
| RAM per a totes les VM | 26,5 GB necessaris, 24 disponibles | ✅ | Treballar per escenaris; R3 a 1 GB ([Tasca 7](../Tasca7-Rendiment/)) |
| Fils de CPU a casa | 12 fils | ✅ | ≤ 10 vCPU a casa |
| Xarxa de casa | PLC a 100 Mb/s | ✅ | PLC Gigabit o cable (no afecta la LAN interna) |
| Temperatura del portàtil | 97–100 °C amb 7 VM ([registre](../Tasca7-Rendiment/evidencies/20261116-temperatura-classe.txt)) | ✅ | No fer actualitzacions de Windows amb totes les VM enceses |
| Secure Boot a casa | `vboxdrv` no carrega | ✅ resolt | Registrar la clau MOK |

**Conclusió:** el que més limita no és cap dels dos PC, sinó **el disc USB** que comparteixen.

## 4. Evidències

- Tests: [`classe`](evidencies/tests/tests-classe-20261112-0800.txt) · [`casa`](evidencies/tests/tests-casa-20261111-1545.txt)
