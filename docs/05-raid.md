# 05 · Tasca 6 — Emmagatzematge: RAID i espill entre equips (ISO RA3)

## Tasca 6.2 — Tres tipus de RAID o més (Apte · a102, a103)

**On:** VM 230 `SRV-DADES` (Debian 13 sense GUI) **dins del node PVE3**, com la «VM Debian · dades» del grup. Té el disc del sistema `sda` i
**5 discos d'1 GB** (`sdb`–`sdf`) creats des de Proxmox (`for i in 1 2 3 4 5; do qm set 230 --scsi$i local-lvm:1; done`). Totes les dades són fictícies.

**Script:** [`scripts/raid/raid-proves.sh`](../scripts/raid/raid-proves.sh). Per a cada nivell:
1. Crea el RAID amb `mdadm`, formata en ext4 i el munta.
2. Hi copia 20 fitxers aleatoris de 5 MB i una «factura» de prova, i en guarda el SHA-256.
3. Provoca la fallada d'un disc i comprova si les dades continuen **íntegres** (`sha256sum -c`).
4. Substitueix el disc i mesura el temps de reconstrucció.

```bash
apt install -y mdadm
bash raid-proves.sh 0      # i després 1, 5 i 10 (cada nivell neteja els discos abans de començar)
bash raid-proves.sh neteja
# Copiar els registres a l'amfitrió: scp ivan@192.168.13.23:/root/evidencies-raid/* evidencias/t6-raid/
```

Abans de començar: instantània `qm snapshot 230 raid-net` a PVE3. Si alguna cosa va malament, `qm rollback 230 raid-net`.

### Resultats (omplir amb els registres d'`evidencias/t6-raid/`)

| Nivell | Discos | Capacitat útil (teòrica / `df -h`) | Fallada provocada | Dades després de la fallada | Reconstrucció | Escriptura `dd` |
|---|---|---|---|---|---|---|
| RAID 0 | sdb + sdc | 2 GB / | sdc perdut | ❌ esperat: no es pot assemblar | — | |
| RAID 1 | sdb + sdc (+ sdd de substitució) | 1 GB / | `--fail sdc` | ✅ esperat: íntegres, `[U_]` | s | |
| RAID 5 | sdb + sdc + sdd + **spare sde** | 2 GB / | `--fail sdc` | ✅ esperat: el spare entra sol | s | |
| RAID 10 | sdb + sdc + sdd + sde (+ sdf) | 2 GB / | `--fail sdb` | ✅ esperat | s | |

### Què aporta cada nivell (a103) — *conclusions pròpies a partir dels resultats*

| Nivell | Mínim de discos | Capacitat útil amb n discos de mida C | Tolerància | Rendiment | Quan l'usaria a l'empresa |
|---|---|---|---|---|---|
| **0** (striping) | 2 | n × C | **Cap**: si falla un disc, es perd tot | Llegir i escriure és més ràpid (paral·lel) | Dades temporals que es poden regenerar: memòria cau, renderitzat. **Mai** per a dades úniques |
| **1** (espill) | 2 | C | n − 1 discos | Lectura bona; escriptura com un sol disc | Disc del sistema dels servidors, i el NAS quan només té 2 discos |
| **5** (paritat distribuïda) | 3 | (n − 1) × C | 1 disc | Lectura bona; escriptura més lenta pel càlcul de paritat. La reconstrucció és llarga i arrisca el volum | Dades de departaments amb pocs discos: bon equilibri entre capacitat i seguretat |
| **10** (espill + striping) | 4 | n/2 × C | 1 per parella (fins a n/2 si cauen en parelles diferents) | El millor dels quatre en escriptura | Bases de dades i VM: moltes escriptures petites |

**Idees clau:**
- **RAID no és còpia de seguretat.** Si esborre un fitxer o un ransomware el xifra, el RAID replica el desastre a tots els discos.
- Un disc de **reserva** (*spare*) redueix el temps en què el volum està degradat: ho demostra la prova del RAID 5.

## Tasca 6.3 — Espill entre dos equips (Apte+ · a107–a109)

### Investigació i justificació (a107)

| Opció | Com funciona | Avantatges | Inconvenients | Per al meu entorn |
|---|---|---|---|---|
| **DRBD** | Mòdul del nucli: replica un dispositiu de blocs per xarxa. És un RAID 1 entre dos equips | Integrat a Debian, senzill amb 2 nodes, protocol síncron (C), resincronitza només el que ha canviat | Un sol primari alhora (o calen sistemes de fitxers de clúster). Risc de *split-brain* | ✅ **Escollida** |
| mdadm RAID 1 + disc remot per iSCSI/NBD | Un RAID local on un dels dos membres és un disc exportat per un altre equip | Reaprofita el que ja sé de mdadm | Si cau l'equip que té el RAID, no hi ha failover. El disc remot es veu com «fallit» davant qualsevol tall de xarxa | Alternativa didàctica |
| GlusterFS (volum replicat) | Replica fitxers entre servidors | Escala a més nodes | Treballa amb fitxers, no amb blocs. Recomana 3 nodes per evitar *split-brain* | Massa per a 2 VM d'1 GB |
| Ceph | Emmagatzematge distribuït d'objectes i blocs | És el que usa Proxmox per a HA | Mínim 3 nodes i molta RAM | ❌ no hi cap |

**Per què DRBD:** és l'única opció que fa realment un **espill de disc** amb 2 nodes i poca RAM, i el *failover* es pot
demostrar a mà. Ceph i Gluster tindrien sentit amb el clúster de 3 nodes de l'arquitectura de referència.

### Implementació (a108)

Nodes, en **dos nodes Proxmox diferents**, de manera que l'espill sobreviu a la caiguda d'un node sencer:
- `srv-serveis` (VM 220 a PVE2): 192.168.13.22, disc `/dev/sdb` de 2 GB.
- `srv-dades` (VM 230 a PVE3): 192.168.13.23, disc `/dev/sdg` de 2 GB.

Configuració: [`configs/drbd/r0.res`](../configs/drbd/r0.res), amb els passos al [README](../configs/drbd/README.md).

### Verificació i cas d'ús (a109)

**Cas d'ús:** la carpeta compartida del departament **Comercial** (ofertes i clients) està replicada en dos servidors.
Si el servidor principal cau, en pocs minuts es pot tornar a servir des del segon **sense perdre res del que s'havia guardat**,
perquè el protocol C és síncron.

| Pas | Ordre | Resultat esperat | Evidència |
|---|---|---|---|
| Sincronització inicial | `drbdadm status r0` | `disk:UpToDate peer-disk:UpToDate` | `t6-drbd/01-sync.txt` |
| Escriptura al primari | `cp ... /srv/espill/comercial; sha256sum` | Hashes guardats | `02-escriptura.txt` |
| Caiguda del node A | `qm stop 220` a PVE2 (tall brusc, com si caiguera el servidor) | B: `connection:Connecting` | `03-caiguda.txt` |
| Promoció del node B | `drbdadm primary r0; mount /dev/drbd0 /srv/espill` | Muntat | `04-failover.txt` |
| Integritat | `sha256sum -c` | Tots els fitxers OK | `05-integritat.txt` |
| Tornada del node A | arrancar A → `drbdadm status` | A secundari, resincronització parcial | `06-retorn.txt` |
| Temps total sense servei | cronòmetre | ___ min | — |

**Límits:**
- El *failover* és **manual**. Per fer-lo automàtic caldria Pacemaker o Corosync, més un tercer vot.
- La latència de la xarxa s'afig a cada escriptura (protocol C).
- Si els dos nodes es promouen a primari alhora, hi ha *split-brain* i la configuració desconnecta.
- **No substitueix la còpia:** un esborrat també es replica a l'instant.
