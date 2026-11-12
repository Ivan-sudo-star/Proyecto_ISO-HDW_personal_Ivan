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

| Etiqueta | Equip | VM enceses | `r` mitjà | swap MB | RAM lliure MB | si/so | CPU us+sy % | wa % | idle % | Respon? |
|---|---|---|---|---|---|---|---|---|---|---|
| 0-base | casa | cap (Chrome i Discord oberts) | 1,4 | 0 | 19 757 | 0/0 | 12 | 0 | 88 | ✅ |
| 0-base | classe | cap (escriptori obert) | 0,3 | 0 | 19 413 | 0/0 | 2 | 2 | 96 | ✅ |
| 1-router | | R3 | | | | | | | | |
| 2-E1 | | router + CLI + W11 + NAS | | | | | | | | |
| 3-E2 | | R1 + PVE1 + PVE2 + PVE3 + CLI | | | | | | | | |
| 3b-E2-migracio | | E2 durant `qm migrate 220` | | | | | | | | |
| 4-E2b | | E2 + NAS (`vzdump` en marxa) | | | | | | | | |
| 4b-WS2025 | | R1 + PVE1 amb el WS2025 arrancant | | | | | | | | |
| 5-límit | | afegir VM fins que es trenque el criteri | | | | | | | | |
| 6-W11-update | | W11 fent Windows Update | | | | | | | | |
| 7-stress-cpu | | CLI amb `stress-ng --cpu 2` | | | | | | | | |
| 8-fio-disc | | SRV-DADES amb `fio` randwrite | | | | | | | | |

Registres de les línies base de casa i de classe: [`evidencias/t7-rendiment/`](../evidencias/t7-rendiment/).

## 3. Quina VM satura quin recurs (a23)

*Hipòtesi* (a confirmar o descartar amb les mesures de dalt):

| VM | Recurs que preveig que satura | Per què | Confirmat? |
|---|---|---|---|
| Windows 11 / WS2025 | **Disc** (wa alt) i RAM | Actualitzacions, indexació, Defender: molta E/S petita i síncrona sobre el SSD USB | |
| NAS-TrueNAS | **RAM** | ZFS usa la RAM com a memòria cau (ARC) | |
| PVE1 (amb el WS2025 dins) | **CPU i disc** | Doble virtualització niuada (VirtualBox → KVM → Windows). Windows fa molta E/S | |
| PVE2 / PVE3 | RAM | 3 GB per node: Proxmox + VM + CT van justos, sobretot durant una migració | |
| Routers | Res | 1 vCPU, poca RAM, poc trànsit | |
| CLI-Debian amb navegador | RAM | Moltes pestanyes | |

## 4. Quantes VM puc arrancar (a24, a120)

| Equip | Nombre màxim de VM simultànies que compleixen el criteri | Recurs que limita primer | Combinació |
|---|---|---|---|
| Casa | | | |
| Classe | | | |

## 5. Informe i conclusions (a121)

*(Redactar en acabar les mesures: què he mesurat, en quines condicions, què s'ha saturat, quantes VM es poden tenir
arrancades, si les hipòtesis de la secció 3 es confirmen, i com ho he comprovat al registre de successos.)*

---

## Optimitzacions (Apte+ · a123–a125)

Per a cada optimització es repeteix **la mateixa mesura en les mateixes condicions** abans i després.

| # | Optimització | VM | Mesura | Abans | Després | Millora? |
|---|---|---|---|---|---|---|
| 1 | Arrencada sense entorn gràfic (`multi-user.target`) + RAM 4 → **1 GB** + vCPU 2 → **1** (un router no necessita GNOME) | Debian_NFtables (R3) | RAM usada dins la VM · processos · temps d'arrencada (`systemd-analyze`) | 806 MB de 3 921 · 200 processos · 11,45 s | **284 MB** de 967 · **120** processos · **5,56 s** | ✅ −65 % de RAM usada, arrencada 2 vegades més ràpida, 3 GB alliberats a l'amfitrió; el router continua funcionant (`opt1-r3-*.txt`) |
| 2 | Activar *Use Host I/O Cache* al controlador SATA i passar el disc a **VDI de mida fixa** | Cliente_windows_1 | Temps d'arrencada fins a l'escriptori (cronòmetre) i `wa` de l'amfitrió durant l'arrencada | | | |
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
