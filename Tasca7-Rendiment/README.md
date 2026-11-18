# Tasca 7 · Rendiment i diagnòstic de l'equip físic

**FDM RA1 · ISO RA6** · a22–a24, a119–a121 (Apte) · a123–a125 (Apte+) · Estat: ✅

## 1. Mètode

**Eina:** [`scripts/mesura-carrega.sh`](scripts/mesura-carrega.sh) `<etiqueta> 60`: durant 60 s desa `vmstat`, `free`, el trànsit de xarxa, els processos i el consum de cada VM. Càrrega dirigida amb `stress-ng`, `fio` i `iperf3`.

**Criteri «l'equip no es bloqueja»** (fixat abans de mesurar):
1. RAM disponible **≥ 2 GB**;
2. swap (`si`/`so`) ≈ 0;
3. cua de CPU (`r`) ≤ nombre de fils;
4. espera d'E/S (`wa`) < 20 %;
5. l'escriptori respon.

## 2. Mesures (a22, a119)

**Casa (12/11 · 12 fils, 32 GB)**

| Escenari | `r` | CPU | `wa` | RAM disponible | Swap | Resultat |
|---|---|---|---|---|---|---|
| Sense VM | 1,4 | 12 % | 0 | 19,8 GB | 0 | ✅ |
| Clúster en repòs (5 VM) | 0,9 | 4 % | 0 | 12,8 GB | 0 | ✅ |
| Clúster amb càrrega | 2,3 | 19 % | 0 | 12,9 GB | 0 | ✅ |
| + W11 actualitzant | 2,7 | 25 % | 0 | 7,8 GB | 0 | ✅ |
| **9 VM (totes)** | 2,5 | 18 % | 0 | **3,0 GB** | 0 | ✅ al límit |
| 9 VM + WS2025 simulat | 4,6 | 34 % | 0 | **0,96 GB** | 663 MB | ❌ criteri trencat |

**Classe (16/11 · 18 fils, 32 GB)**

| Escenari | `r` | CPU | `wa` | RAM disponible | Swap | Resultat |
|---|---|---|---|---|---|---|
| 6 VM en repòs | 1,1 | 5 % | 4 | 10,1 GB | 0 | ✅ |
| 6 VM + WS2025 **dins de PVE1**, amb càrrega | 2,0 | 10 % | 2 | 9,9 GB | 0 | ❌ **PVE1 es penja** amb RAM de sobra |
| 7 VM, WS2025 **a VirtualBox**, amb càrrega | 3,5 | 17 % | 3 | 8,8 GB | 0 | ✅ cap bloqueig |
| **8 VM** (+ W11) | 2,1 | 13 % | 2 | **4,5 GB** | 0 | ✅ |
| 10 VM (+ R2 + R3) | 2,7 | 12 % | 2 | **1,7 GB** | 174 MB | ❌ criteri trencat |

Totes les mesures són a [`evidencies/`](evidencies/) (un fitxer per escenari).

## 3. Quina VM satura quin recurs (a23)

| VM | Previst | Resultat |
|---|---|---|
| Windows 11 / WS2025 | Disc i RAM | ✅ CPU i RAM: W11 actualitzant ocupa les 2 vCPU i 4,2 GB. El disc no satura |
| WS2025 dins de PVE1 | CPU i disc | ❌ **Penja el node** (virtualització niuada) → passat a VirtualBox |
| NAS-TrueNAS | RAM | 🟡 8 GB assignats, ≈ 2 GB en ús normal |
| PVE2 / PVE3 | RAM | 🟡 ≈ 2,5 GB i 20–25 % de CPU en repòs (serveis del clúster) |
| Routers | Res | ✅ R1 < 0,5 GB; R2 818 MB; R3 371 MB |

**El recurs que s'esgota primer és la RAM**, no la CPU (amb totes les VM la CPU continua 2/3 lliure).

## 4. Quantes VM puc arrancar (a24, a120)

| Equip | VM | Limita | Combinació recomanada |
|---|---|---|---|
| Casa | **9 VM** sense el WS2025 (3 GB de marge) | RAM | Un sol router + NAS + 3 nodes + CLI + W11 (7 VM, 5,6 GB de marge) |
| Classe | **8 VM** amb el WS2025 a VirtualBox (4,5 GB de marge) · 10 trenquen el criteri | RAM | R1 + NAS + WS2025 + 3 nodes + CLI + W11; R2 i R3 en lloc de W11 o d'un node |

**Detall:** VirtualBox no torna la RAM que una VM ha usat fins que s'apaga. Per això cal encendre i apagar per escenaris.

## 5. Informe i conclusions (a121)

*Redactat amb l'IA a partir de les mesures*

- **Límit:** la **RAM**; la CPU no ha passat del 34 % i el disc no ha donat espera d'E/S apreciable.
- **Capacitat:** 9 VM a casa (sense WS2025) i 8 a classe (amb WS2025 a VirtualBox).
- **Problema greu:** el WS2025 **dins de PVE1** penjava el node encara que sobrava RAM. Com a VM de VirtualBox (estructura del professor), la mateixa càrrega no bloqueja res.
- **Registre de successos:** cap OOM ni error USB. Un bloqueig de 26 s de l'escriptori a casa, del controlador gràfic `amdgpu` de l'amfitrió (no per falta de recursos).
- **Temperatura (classe):** 97–100 °C amb 7 VM i el WS2025 actualitzant; un apagat de l'equip ([registre](evidencies/20261116-temperatura-classe.txt)). No fer actualitzacions de Windows amb totes les VM enceses.

## 6. Optimitzacions (Apte+ · a123–a125)

| # | Optimització | VM | Abans | Després | Resultat |
|---|---|---|---|---|---|
| 1 | Sense escriptori (`multi-user.target`), RAM 4 → 1 GB, 2 → 1 vCPU | R3 | 806 MB usats · 200 processos · arrencada 11,45 s | **284 MB** · 120 processos · **5,56 s** | ✅ −65 % de RAM, arrencada el doble de ràpida, 3 GB alliberats a l'amfitrió |
| 2 | Desactivar serveis innecessaris (CUPS, Avahi, ModemManager…) | CLI-Debian | 26 serveis · **8 ports oberts** · 632 MB | **20 serveis · 2 ports (només SSH)** · 626 MB | ✅ en seguretat; RAM −1 %; el temps d'arrencada no es va poder comparar (W11 s'actualitzava al mateix disc) |

Evidències: [`opt1-r3-abans.txt`](evidencies/opt1-r3-abans.txt) · [`opt1-r3-despres.txt`](evidencies/opt1-r3-despres.txt) · [`opt2-cli-serveis.txt`](evidencies/opt2-cli-serveis.txt)
