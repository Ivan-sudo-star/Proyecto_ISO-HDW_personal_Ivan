# 05 · Tasca 6 — Emmagatzematge: RAID i espill entre equips (ISO RA3)

## Tasca 6.2 — Tres tipus de RAID o més (Apte · a102, a103)

**On:** VM 230 `SRV-DADES` (Debian 13 sense GUI) **dins del node PVE3**, com la «VM Debian · dades» del grup. Té el disc del sistema `sda` i
**5 discos d'1 GB** creats des de Proxmox (`for i in 1 2 3 4 5; do qm set 230 --scsi$i local-lvm:1; done`). Totes les dades són fictícies.

**Compte:** dins de la VM, els noms `sdX` **no segueixen l'ordre** `scsiN`. L'script no usa noms fixos: detecta els discos de **exactament 1 GiB**, s'atura si no en troba 5 i no toca mai el disc del sistema ni un disc amb particions. També se li poden passar a mà: `DISCOS_RAID="/dev/disk/by-path/... (x5)" bash raid-proves.sh 1`.

**Script:** [`scripts/raid/raid-proves.sh`](../scripts/raid/raid-proves.sh). Per a cada nivell:
1. Crea el RAID amb `mdadm`, formata en ext4 i el munta.
2. Hi copia 20 fitxers aleatoris de 5 MB i una «factura» de prova, i en guarda el SHA-256.
3. Provoca la fallada d'un disc i comprova si les dades continuen **íntegres** (`sha256sum -c`).
4. Substitueix el disc i mesura el temps de reconstrucció.

```bash
apt install -y mdadm
bash raid-proves.sh 0      # i després 1, 5 i 10 (cada nivell neteja els discos abans de començar)
bash raid-proves.sh neteja
# Copiar els registres a l'amfitrió (amb la clau lab13_ed25519, saltant per R1): scp ivancambra@192.168.13.23:~/evidencies-raid/* evidencias/t6-raid/
# (abans, dins la VM: sudo cp -r /root/evidencies-raid ~ && sudo chown -R ivancambra ~/evidencies-raid)
```

Abans de començar: instantània `qm snapshot 230 raid-net` a PVE3. Si alguna cosa va malament, `qm rollback 230 raid-net`.

### ✅ Resultats (12/11/2026, VM 230 a PVE3, equip de casa)

Registres complets: [`raid0.log`](../evidencias/t6-raid/raid0.log), [`raid1.log`](../evidencias/t6-raid/raid1.log), [`raid5.log`](../evidencias/t6-raid/raid5.log), [`raid10.log`](../evidencias/t6-raid/raid10.log) i [`rendiment-escriptura.txt`](../evidencias/t6-raid/rendiment-escriptura.txt). Els discos D1–D5 van ser `sdb`–`sdf` (detectats per mida per l'script). A cada nivell s'hi copien 20 fitxers de 5 MB i una «factura» fictícia, i se'n comprova el SHA-256.

| Nivell | Discos | Capacitat útil (teòrica / `df -h`) | Fallada provocada | Dades després de la fallada | Reconstrucció |
|---|---|---|---|---|---|
| RAID 0 | D1 + D2 | 2 GB / **2,0 G** | D2 perdut | ❌ **Dades perdudes**: `mdadm` no deixa ni marcar el disc com a fallit, i amb un sol disc no s'arrenca («Not enough devices») | — (no n'hi ha) |
| RAID 1 | D1 + D2 (+ D3 de substitució) | 1 GB / **988 M** | `--fail D2` | ✅ Íntegres amb el volum degradat `[U_]` | **8 s** en afegir D3 |
| RAID 5 | D1 + D2 + D3 + **spare D4** | 2 GB / **2,0 G** | `--fail D2` | ✅ Íntegres; **el disc de reserva entra sol** sense fer res | **12 s**, automàtica |
| RAID 10 | D1 + D2 + D3 + D4 (+ D5) | 2 GB / **2,0 G** | `--fail D1` | ✅ Íntegres amb `[_UUU]` | **3 s** en afegir D5 (només copia la parella) |

**Rendiment:** la mesura amb `dd` no permet comparar els nivells, perquè tots els discos virtuals són al mateix SSD USB i les escriptures passen per diverses memòries cau (un disc sol dona 1,5 GB/s). Està explicat a [`rendiment-escriptura.txt`](../evidencias/t6-raid/rendiment-escriptura.txt).

**Conclusions a partir de les proves** (redactades amb l'IA a partir dels registres; l'alumne les ha de revisar i saber explicar):
- **RAID 0** dona la capacitat dels dos discos, però la prova demostra que **perdre'n un és perdre-ho tot**: no hi ha manera d'assemblar-lo. Només per a dades que es poden regenerar.
- **RAID 1** perd la meitat de la capacitat (988 M de 2 GB), però el servei **no s'atura** quan falla un disc, i la reconstrucció només copia un disc.
- **RAID 5** aprofita més la capacitat (2 de 3 discos) i, amb un **spare**, es recupera sol: és l'únic dels quatre on no ha calgut fer res després de la fallada. La reconstrucció ha sigut la més lenta (12 s), perquè ha de recalcular la paritat amb tots els discos.
- **RAID 10** té la mateixa capacitat que el RAID 5 amb un disc més, però la reconstrucció és la més ràpida (3 s), perquè només es copia el disc germà de la parella.
- Cap d'ells substitueix la còpia: un esborrat es replica a tots els discos a l'instant.

### Què aporta cada nivell (a103)

| Nivell | Mínim de discos | Capacitat útil amb n discos de mida C | Tolerància | Rendiment | Quan l'usaria a l'empresa |
|---|---|---|---|---|---|
| **0** (striping) | 2 | n × C | **Cap**: si falla un disc, es perd tot | Llegir i escriure és més ràpid (paral·lel) | Dades temporals que es poden regenerar: memòria cau, renderitzat. **Mai** per a dades úniques |
| **1** (espill) | 2 | C | n − 1 discos | Lectura bona; escriptura com un sol disc | Disc del sistema dels servidors, i el NAS quan només té 2 discos |
| **5** (paritat distribuïda) | 3 | (n − 1) × C | 1 disc | Lectura bona; escriptura més lenta pel càlcul de paritat. La reconstrucció és llarga i arrisca el volum | Dades de departaments amb pocs discos: bon equilibri entre capacitat i seguretat |
| **10** (espill + striping) | 4 | n/2 × C | 1 per parella (fins a n/2 si cauen en parelles diferents) | El millor dels quatre en escriptura | Bases de dades i VM: moltes escriptures petites |

**Idees clau:**
- **RAID no és còpia de seguretat.** Si esborre un fitxer o un ransomware el xifra, el RAID replica el desastre a tots els discos.
- Un disc de **reserva** (*spare*) redueix el temps en què el volum està degradat: ho demostra la prova del RAID 5 (s'ha integrat sol en 12 s).

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
- `srv-serveis` (VM 220 a PVE2): 192.168.13.22, el disc de 2 GB.
- `srv-dades` (VM 230 a PVE3): 192.168.13.23, el disc de 2 GB.
- El disc s'identifica per mida (`lsblk -dbnpo NAME,SIZE | awk '$2==2147483648'`) i al `r0.res` es posa el seu camí estable de `/dev/disk/by-path/`, no `sdX`.

Configuració: [`configs/drbd/r0.res`](../configs/drbd/r0.res), amb els passos al [README](../configs/drbd/README.md). Els discos s'identifiquen pel camí `/dev/disk/by-path` (srv-serveis = `sdb`, srv-dades = `sdg`), i el secret compartit es genera amb `openssl rand` i no es puja al repositori.

### Verificació i cas d'ús (a109)

**Cas d'ús:** la carpeta compartida del departament **Comercial** (ofertes i clients) està replicada en dos servidors.
Si el servidor principal cau, en pocs minuts es pot tornar a servir des del segon **sense perdre res del que s'havia guardat**,
perquè el protocol C és síncron.

**✅ Resultat (12/11/2026):** DRBD 8.4.11 entre `srv-serveis` (VM 220, PVE2) i `srv-dades` (VM 230, PVE3), protocol C, disc de 2 GiB per node.

| Pas | Ordre | Resultat obtingut | Evidència |
|---|---|---|---|
| Sincronització inicial | `drbdadm primary --force r0` | `Connected · Primary/Secondary · UpToDate/UpToDate` en **87 s** (2 GiB) | [`01-sync.txt`](../evidencias/t6-drbd/01-sync.txt) |
| Escriptura al primari | `mkfs.ext4 /dev/drbd0`, carpeta `comercial` (3 ofertes + catàleg de 20 MB) i `sha256sum` | 4 fitxers, 21 MB, hashes guardats | [`02-escriptura.txt`](../evidencias/t6-drbd/02-escriptura.txt) |
| Caiguda del node A | `qm stop 220` a PVE2 (tall brusc) | B detecta que A no hi és després del temps d'espera de DRBD (uns segons) | [`03-caiguda.txt`](../evidencias/t6-drbd/03-caiguda.txt) |
| Promoció del node B | `drbdadm primary r0; mount /dev/drbd0 /srv/espill` | `Primary/Unknown`, muntat | [`04-failover.txt`](../evidencias/t6-drbd/04-failover.txt) |
| Integritat | `sha256sum -c` | **4/4 OK** | ídem |
| Tornada del node A | arrancar A → `drbdadm up r0` | A entra com a **secundari** i es resincronitza des de B (84 s, vegeu la nota). Té el fitxer escrit a B mentre era caigut | [`06-retorn.txt`](../evidencias/t6-drbd/06-retorn.txt) |
| Canvi planificat de primari | B: `umount` + `secondary` → A: `primary` + `mount` | **2,8 s**, 5/5 fitxers OK | [`07-failback.txt`](../evidencias/t6-drbd/07-failback.txt) |
| **Temps total sense servei** | de `qm stop` a dades verificades a B | **7,3 s** (failover manual fet per script) | — |

**Nota sobre la resincronització:** s'esperava que només es copiara el que havia canviat, però es va resincronitzar el disc sencer. El node A va caure sent primari, i DRBD marca com a dubtoses totes les zones del seu registre d'activitat (per defecte ≈ 4,8 GiB, més que el disc de 2 GiB de la prova). Amb un disc real gran només es resincronitzarien les zones actives, i si cau el secundari la resincronització és parcial (bitmap).

**Conclusió del cas d'ús:** la carpeta de Comercial ha sobreviscut a la caiguda brusca d'un servidor sencer (i del seu node Proxmox) **sense perdre cap fitxer**, i s'ha tornat a servir des de l'altre node en 7,3 s. El que es va escriure mentre un node era caigut s'ha replicat quan ha tornat.

**Límits:**
- El *failover* és **manual**. Per fer-lo automàtic caldria Pacemaker o Corosync, més un tercer vot.
- La latència de la xarxa s'afig a cada escriptura (protocol C).
- Si els dos nodes es promouen a primari alhora, hi ha *split-brain* i la configuració desconnecta.
- **No substitueix la còpia:** un esborrat també es replica a l'instant.
