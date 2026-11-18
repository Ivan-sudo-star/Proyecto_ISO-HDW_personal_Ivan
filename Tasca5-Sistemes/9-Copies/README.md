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

**Objectiu:** buscar una eina que faça les còpies sola, explicar com funciona, provar-la i comprovar que funciona.

### Eines estudiades

| Eina | Què fa | Com funcionaria aquí | Provada? |
|---|---|---|---|
| **TrueNAS · Periodic Snapshot Task** | Instantànies ZFS automàtiques del pool amb horari i caducitat. Només guarden els canvis, així que ocupen poc | Versions diàries de totes les còpies del NAS: si s'esborra o es xifra (ransomware) una còpia, es recupera de la instantània | ✅ **Sí** (sota) |
| **Proxmox · Backup job** | `vzdump` programat de VM i CT cap a un emmagatzematge | Imatge setmanal de les VM 220, 230 i el CT 100 al NAS, guardant les 3 últimes | ✅ **Sí**: tasca `copia-setmanal`, provada avançant l'hora ([evidència](../5-Proxmox/evidencies/a105-copia-automatica-vzdump.txt)) |
| TrueNAS · Rsync Task | `rsync` programat que porta (*pull*) o envia (*push*) carpetes d'un altre equip per SSH | El NAS aniria a buscar cada nit el `/etc` dels servidors Linux | ➖ Necessita una clau SSH del NAS als servidors (accés permanent) |
| TrueNAS · Replication Task | Envia les instantànies a un altre equip ZFS | La còpia fora del disc (regla 3-2-1) | ➖ No hi ha un segon NAS |
| TrueNAS · Cloud Sync | Puja carpetes a un núvol (S3, Drive…) | Còpia fora de l'empresa | ➖ Necessita un compte al núvol |
| MikroTik · `/system scheduler` | Executa un script amb horari | R1 faria `/export` + backup i el pujaria al NAS per SFTP ([`r1-scheduler-copia.rsc`](../1-R1-MikroTik/config/r1-scheduler-copia.rsc)) | ➖ L'script ha de guardar la contrasenya del NAS dins del router |
| `copia-configs.sh` + timer de systemd | Script propi que recull les configuracions de tots els equips | Des de SRV-SERVEIS, cada nit, per SSH ([`scripts/`](scripts/)) | 🟡 Instal·lat; falta repartir la clau SSH |

### Prova: instantànies automàtiques de TrueNAS (18/11)

1. **Configuració** (per l'API; a la web: *Data Protection → Periodic Snapshot Tasks*): pool `copies`, recursiva, nom `auto-%Y-%m-%d_%H-%M`. Per a la prova: **cada 2 minuts** i es guarden 1 h.
2. **Funciona sola:** sense fer res, el NAS va crear les instantànies de les 11:46 i les 11:48 a **tots els datasets**.
3. **Recuperació:** s'esborra un fitxer de prova i es copia des de `.zfs/snapshot/auto-…_11-48/`: **mateix SHA-256** que l'original.
4. **Horari definitiu:** cada dia a les **02:00**, es guarden **14 dies**; s'exclouen `proxmox` i `windows` (ja tenen versions pròpies i són grans).

Evidència: [`a105-truenas-snapshots-automatiques.txt`](evidencies/a105-truenas-snapshots-automatiques.txt)

**Conclusió:** les instantànies **no substitueixen** la còpia (són al mateix NAS), però hi afigen el que faltava: **versions automàtiques**. Un error o un ransomware que esborre una còpia ja no és definitiu durant 14 dies.

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
