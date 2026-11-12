# 06 · Tasca 7 — Rendiment i diagnòstic de l'equip físic (FDM RA1 · ISO RA6)

Accions: a22, a23, a24, a119, a120, a121 (Apte) · a123, a124, a125 (Apte+).

## 1. Mètode

| Recurs | Eina a l'amfitrió (Linux Mint) | Eina dins de les VM |
|---|---|---|
| CPU | `vmstat 1` (us, sy, id, `r` = processos en cua), `top`/`htop` | `top` · Administrador de tasques / Monitor de rendiment |
| RAM | `free -m`, `vmstat` (swpd, si/so) | `free -m` · `perfmon` *Memory\Available MBytes* |
| Disc | `vmstat` (bi/bo, **wa**), `iostat -x 1` (paquet `sysstat`) | `iostat` · *PhysicalDisk\Avg. Disk sec/Transfer* |
| Xarxa | comptadors de `/sys/class/net/*/statistics` | `iperf3`, `ip -s link` |
| Successos | `journalctl -k -p warning`, `dmesg` (OOM killer, errors USB) | `journalctl -p err` · Visor d'esdeveniments |
| Càrrega dirigida | — | `stress-ng --cpu N`, `stress-ng --vm 1 --vm-bytes 80%`, `fio`, `iperf3` |

Script de mesura: [`scripts/host/mesura-carrega.sh`](../scripts/host/mesura-carrega.sh) `<etiqueta> 60`.
Durant 60 s desa `vmstat`, `free`, el trànsit de xarxa, els processos que més consumeixen i les VM enceses,
i escriu una línia de resum per a la taula de baix.

**Criteri de «no bloqueja l'equip»**, fixat abans de mesurar:
1. RAM disponible de l'amfitrió **≥ 2 GB**;
2. **swap si/so ≈ 0** de manera sostinguda;
3. `r` (cua de CPU) **≤ nombre de fils**;
4. `wa` (espera d'E/S) **< 20 %**;
5. l'escriptori respon: el ratolí no s'encalla i les finestres s'obrin en menys de 2 s.

Si es trenca qualsevol d'aquests cinc punts, l'escenari no és viable.

**Equip:** s'indica sempre en quin amfitrió es mesura (classe o casa). Tots dos tenen 32 GB, però casa té 12 fils i classe en té 18.

## 2. Mesures (a22, a119)

Totes les del 12/11 són a l'**equip de casa** (12 fils, 32 GB), amb `mesura-carrega.sh` durant 45–60 s. **CPU usada = us + sy + gu** (`gu` és el temps de CPU de les VM: sense sumar-lo, la càrrega de les VM no es veu; corregit a l'script el 12/11). «Disponible» és la RAM que encara pot donar l'amfitrió (`free`, columna *disponible*).

| Escenari | VM enceses (VirtualBox) | `r` mitjà | CPU usada % | wa % | RAM disponible | swap | Respon? | Fitxer |
|---|---|---|---|---|---|---|---|---|
| 0-base casa (11/11) | cap (Chrome i Discord oberts) | 1,4 | 12 | 0 | 19,8 GB lliures | 0 | ✅ | [`…casa-0-base`](../evidencias/t7-rendiment/20261111-1506-casa-0-base.txt) |
| 0-base classe (12/11) | cap | 0,3 | 4 | 2 | 19,4 GB lliures | 0 | ✅ | [`…classe-0-base`](../evidencias/t7-rendiment/20261112-0810-classe-0-base.txt) |
| E3 clúster en repòs | R1 + NAS + PVE2 + PVE3 (VM 220 i 230 dins) + CLI | 0,9 | 4 | 0 | 12,8 GB | 0 | ✅ | [`…E3-cluster-repos`](../evidencias/t7-rendiment/20261112-1623-casa-E3-cluster-repos.txt) |
| E3 clúster amb càrrega | ídem + CPU al 100 % a VM 220 + escriptures síncrones a VM 230 + descàrrega a CLI | 2,3 | 19 | 0 | 12,9 GB | 0 | ✅ | [`…E3-cluster-carrega`](../evidencias/t7-rendiment/20261112-1624-casa-E3-cluster-carrega.txt) |
| E3 + `vzdump` | ídem + còpia de la VM 230 al NAS | 1,1 | 8 | 0 | 12,2 GB | 0 | ✅ | [`…E3-vzdump`](../evidencias/t7-rendiment/20261112-1626-casa-E3-vzdump.txt) |
| E3 + W11 actualitzant | ídem + **W11 fent Windows Update** (4,7 MiB/s de descàrrega) | 2,7 | 25 | 0 | 7,8 GB | 0 | ✅ | [`…E3+W11-update`](../evidencias/t7-rendiment/20261112-1629-casa-E3+W11-update.txt) |
| Límit: 7 VM | ídem + PVE1 | 4,7 | 25 | 1 | 5,6 GB | 0 | ⚠️ l'escriptori es va congelar **26 s** una vegada (vegeu el registre de successos) | [`…limit-7VM`](../evidencias/t7-rendiment/20261112-1632-casa-limit-7VM.txt) |
| Límit: **9 VM (totes)** | ídem + R2 + R3 | 2,5 | 18 | 0 | **3,0 GB** | 0 | ✅ (al límit) | [`…limit-9VM`](../evidencias/t7-rendiment/20261112-1634-casa-limit-9VM.txt) |
| Límit: 9 VM + WS2025 simulat | ídem + 2,5 GB ocupats dins de PVE1 (com si hi corrés el WS2025) | 4,6 | 34 | 0 | **0,96 GB** | **663 MB**, `so` > 0 | ❌ **criteri trencat** | [`…WS2025-simulat`](../evidencias/t7-rendiment/20261112-1636-casa-limit-9VM+WS2025-simulat.txt) |

**Consum per VM** (procés `VBoxHeadless`, als mateixos fitxers): W11 és de lluny la que més CPU gasta (130–160 %, és a dir, les 2 vCPU quasi plenes mentre s'actualitza); els nodes Proxmox, un 20–25 % cadascun encara que estiguen en repòs; el NAS un 10 %; els routers menys del 15 %.

**Limitació de la mesura per VM:** la RAM de cada VM que dona `ps` (RSS) **no és fiable amb VirtualBox**. En simular el WS2025, l'amfitrió va perdre ≈ 2 GB i el RSS de PVE1 quasi no va pujar, perquè VirtualBox reserva la RAM de les VM a través del seu controlador del nucli. Per això el criteri es calcula amb la RAM disponible total de l'amfitrió.

## 3. Quina VM satura quin recurs (a23)

| VM | Recurs que preveia que saturaria | Resultat de les mesures |
|---|---|---|
| Windows 11 / WS2025 | **Disc** i RAM | ✅ **Confirmat per a CPU i RAM**: W11 actualitzant ocupa les 2 vCPU (130–160 %) i 4,2 GB. El disc no arriba a saturar (`wa` ≤ 1 %), però alenteix les arrencades de les altres VM del mateix SSD (opt. 2) |
| NAS-TrueNAS | **RAM** | 🟡 Parcial: té 8 GB assignats però en ús normal en toca ≈ 2 GB. Pot créixer quan ZFS ompli la memòria cau (ARC) |
| PVE1 (amb el WS2025 dins) | CPU i disc | ✅ **Confirmat per a RAM**: és la que trenca el límit. Amb el WS2025 (4 GB) dins de PVE1, l'amfitrió es queda sense RAM i comença a usar la swap |
| PVE2 / PVE3 | RAM | 🟡 Usen ≈ 2,5 GB i un 20–25 % de CPU **en repòs** (els serveis del clúster: corosync, pmxcfs). Són el «cost fix» més gran després del NAS |
| Routers | Res | ✅ Confirmat: R1 < 5 % de CPU i < 0,5 GB; R3 371 MB, R2 818 MB |
| CLI-Debian amb navegador | RAM | 🟡 ≈ 2 GB i 6 % de CPU amb GNOME |

**El recurs que s'esgota primer és la RAM**, no la CPU: amb totes les VM la CPU continua un 66 % lliure, però la RAM disponible baixa d'1 GB i comença el swap. El disc USB no satura en aquestes proves (`wa` ≈ 0), encara que es nota en les tasques d'E/S síncrona (arrencades, Windows Update).

## 4. Quantes VM puc arrancar (a24, a120)

| Equip | VM simultànies que compleixen el criteri | Recurs que limita primer | Combinació |
|---|---|---|---|
| Casa (32 GB, 12 fils) | **9 VM** (totes les de VirtualBox) **sense** el WS2025: queden 3 GB disponibles, sense swap i amb la CPU al 82 % lliure. **Amb el WS2025** dins de PVE1 el criteri es trenca (0,96 GB disponibles i swap) | **RAM** | Per treballar còmode: **un sol router** (R1) + NAS + 3 nodes + CLI + W11 = 7 VM amb 5,6 GB de marge. Per al WS2025: no encendre W11 alhora (allibera ≈ 4 GB) o apagar R2/R3 |
| Classe (32 GB, 18 fils) | N/C: no s'han repetit les proves a classe. Té la mateixa RAM útil (30,6 GB, la iGPU en reserva una part) i més fils, així que el límit hauria de ser el mateix (RAM) | RAM | La mateixa recomanació |

**Detall important:** VirtualBox **no torna a l'amfitrió la RAM** que una VM ja ha tocat fins que la VM s'apaga (després de la simulació, PVE1 va continuar ocupant-la). Per això l'ordre d'encesa i apagat per escenaris és el que més ajuda.

## 5. Informe i conclusions (a121)

*Redactat amb l'IA a partir de les mesures; l'alumne l'ha de revisar i saber-lo explicar.*

- **Què he mesurat:** l'equip de casa amb 0, 5, 6, 7 i 9 VM enceses, en repòs i amb càrrega (CPU, escriptura síncrona, descàrrega, còpia `vzdump`, Windows Update), amb `vmstat` cada segon durant 45–60 s, la RAM disponible, la swap i el consum de cada procés de VM.
- **Què s'ha saturat:** la **RAM**. És el primer criteri que es trenca (amb totes les VM i el WS2025 simulat: 0,96 GB disponibles i 663 MB de swap). La CPU mai ha passat del 34 % d'ús mitjà i el disc no ha donat espera d'E/S apreciable.
- **Quantes VM:** 9 (totes) sense el WS2025, al límit; 7 amb marge (amb l'avís del bloqueig gràfic d'una vegada, que no és de recursos). Amb el WS2025 cal apagar el client Windows o els routers alternatius.
- **Hipòtesis:** es confirma que Windows és la VM més pesada i que la RAM és el límit; es descarta que el disc USB sature en ús normal (sí que alenteix les arrencades quan hi ha altra E/S).
- **Registre de successos** (`dmesg -T`; `journalctl -k` necessita `sudo` o el grup `adm`): **cap OOM** ni error USB/UAS durant les proves. Sí que hi ha **un bloqueig de l'escriptori de 26 s** a les 16:32:14–16:32:40, mentre arrancava PVE1: `watchdog: BUG: soft lockup - CPU#11 stuck for 26s! [Xorg]`, dins del controlador **`amdgpu`** de la gràfica (RX 7600) mentre canviava les freqüències de la pantalla (`dcn32_update_clocks`). En aquell moment quedaven 5,6 GB de RAM i un 74 % de CPU lliures, així que **no és per falta de recursos de les VM**: és un problema del controlador gràfic de l'amfitrió (o del canvi de mode de pantalla). Només ha passat una vegada. Per confirmar-ho caldria repetir l'escenari i mirar si torna a passar, o actualitzar el nucli/controlador de Linux Mint.
- **Millores possibles:** reduir la RAM dels nodes Proxmox sense VM, provar el NAS amb menys RAM (ja documentat com a N/C), i fer les proves de classe per comparar.

---

## Optimitzacions (Apte+ · a123–a125)

Per a cada optimització es repeteix **la mateixa mesura en les mateixes condicions** abans i després.

| # | Optimització | VM | Mesura | Abans | Després | Millora? |
|---|---|---|---|---|---|---|
| 1 | Arrencada sense entorn gràfic (`multi-user.target`) + RAM 4 → **1 GB** + vCPU 2 → **1** (un router no necessita GNOME) | Debian_NFtables (R3) | RAM usada dins la VM · processos · temps d'arrencada (`systemd-analyze`) | 806 MB de 3 921 · 200 processos · 11,45 s | **284 MB** de 967 · **120** processos · **5,56 s** | ✅ −65 % de RAM usada, arrencada 2 vegades més ràpida, 3 GB alliberats a l'amfitrió; el router continua funcionant (`opt1-r3-*.txt`) |
| 2 | **Desactivar els serveis que no calen a l'arrencada** (CUPS, Avahi, ModemManager, wpa_supplicant, switcheroo, power-profiles) | CLI-Debian | Serveis, ports, processos, RAM i temps d'arrencada als 2 min, 2 arrencades de cada | 26 serveis · **8 ports** · 198 processos · 632 MB · 6,9 s | **20 serveis · 2 ports (només SSH)** · 192 processos · 626 MB · 9,6 s (no concloent) | ✅ en **seguretat** (cap servei publicat llevat de SSH) i serveis; RAM −1 %; el temps d'arrencada no es pot comparar perquè W11 s'actualitzava al mateix disc ([`opt2-cli-serveis.txt`](../evidencias/t7-rendiment/opt2-cli-serveis.txt)) |
| 2b | *(proposta, no aplicada)* Activar *Use Host I/O Cache* al controlador SATA i passar el disc a **VDI de mida fixa** | Cliente_windows_1 | Temps d'arrencada fins a l'escriptori i `wa` de l'amfitrió | | | |
| 3 | Llevar el `log` de la regla `NFT-FWD-OK` (registra cada connexió nova) | R3 | Línies/min a `journalctl -k` i CPU del router amb `iperf3` | | | |
| 4 | Desactivar els serveis i les aplicacions d'inici que no calen (Indexació, OneDrive, Xbox...) | Cliente_windows_1 | RAM en repòs i temps d'arrencada | | | |

Ordres de referència:
```bash
VBoxManage modifyvm Debian_NFtables --memory 1024 --cpus 1
VBoxManage storagectl Cliente_windows_1 --name SATA --hostiocache on
VBoxManage clonemedium disk Windows11_1.vdi Windows11_1-fix.vdi --variant Fixed   # amb la VM apagada
```
**Compte:** des del 12/11 `Cliente_windows_1` té la instantània `W11-Home-a250-ok`. El `.vdi` base ja no conté l'estat actual: abans de clonar-lo cal esborrar la instantània (que fusiona els canvis) o clonar la VM sencera amb `VBoxManage clonevm`.

Si una optimització **no** millora o empitjora alguna cosa, també es documenta. Per exemple, la memòria cau d'E/S de
l'amfitrió accelera, però si s'apaga de cop es pot perdre la darrera escriptura.
