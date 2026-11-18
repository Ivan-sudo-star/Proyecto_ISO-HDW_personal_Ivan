# Còpies de seguretat

**a259** (espai de còpies) · **a105** (Apte+, automatització) · Estat: ✅ · Scripts: [`scripts/`](scripts/)

## Què, com i on (a259)

| Tipus | Com | On (NAS `/mnt/copies`) |
|---|---|---|
| Configuració dels routers | `/export` + backup (R1) · `config.xml` (R2) · `tgz` (R3) | `routers/r1`, `r2`, `r3` |
| `/etc` dels Linux | `tar` + llista de paquets | `linux/`, `clients/cli-debian` |
| Nodes Proxmox | `/etc/pve`, xarxa, corosync | `proxmox/config` |
| Imatges de VM i CT | `vzdump` (NFS) | `proxmox/dump` |
| Windows Server | `wbadmin` (estat del sistema + AD) + export d'AD i GPO | `windows/` |
| Dades dels clients | `robocopy` (W11) · `tar` (Linux) | `clients/` |
| Configuració del NAS | API de TrueNAS | `nas/` |
| **No són còpia** | RAID, DRBD i instantànies: protegeixen d'una fallada de disc, però són al mateix disc USB | — |

**Limitació:** el NAS també és al disc USB. Si es perd el disc, es perd tot. Mitigació (3-2-1): copiar `/mnt/copies` a un segon suport fora del disc.

## Còpies automàtiques (a105)

| Part | Estat |
|---|---|
| Imatges (VM 220, VM 230, CT 100) | ✅ **Automàtica:** tasca de clúster `copia-setmanal` (diumenge 03:00, es guarden les 3 últimes). Provada avançant l'hora: s'executa sola → [`a105-copia-automatica-vzdump.txt`](../5-Proxmox/evidencies/a105-copia-automatica-vzdump.txt) |
| Configuracions | 🟡 Orquestrador [`copia-configs.sh`](scripts/copia-configs.sh) + timer de systemd instal·lat a SRV-SERVEIS; falta repartir la clau SSH als equips (cal autorització) |

## Còpies refetes amb el lloc 31 (17/11)

Les còpies anteriors eren de la xarxa 192.168.13.x; després del canvi **es van refer totes**. Inventari amb mides i SHA-256: [`copies-lloc31.txt`](evidencies/copies-lloc31.txt).

| Equip | Comprovació |
|---|---|
| R1 · R2 · R3 | Configuració ja amb 192.168.31.x |
| NAS | Configuració desada (nova) |
| Nodes Proxmox | `cluster31` i IP .31 |
| CT 100, VM 220, VM 230 | `vzdump` verificat amb `zstd -t` |
| VM 220/230 · CLI-Debian | `/etc` (i `/home`) amb la configuració nova |
| Windows 11 | Els dos usuaris (local i del domini), restauració comprovada |
| SRV-WS2025 | `wbadmin` codi 0, recuperable fins a *System State* · [evidència](../6-WS2025-Domini/evidencies/a240-copia-ws2025-dc-lloc31.txt) |

**Lliçó:** una còpia completa de `wbadmin` substitueix l'anterior quan comença: no s'ha de tallar.

## Pla de contingència: temps observats

| Escenari | Recuperació | Temps |
|---|---|---|
| R1 sense NAT ni IP de LAN | `backup load` des del NAS | **42 s** |
| R2 sense regles | restaurar `config.xml` | **48 s** |
| R3 sense regles | `tgz` des del NAS | **22 s** |
| Disc RAID fallit | RAID 1/5 + reconstrucció | **0 s** de servei perdut |
| Node DRBD caigut | l'altre node passa a primari | **7,3 s** |
| Configuració de Linux trencada | `/etc` des del NAS | **2,8 s** |
