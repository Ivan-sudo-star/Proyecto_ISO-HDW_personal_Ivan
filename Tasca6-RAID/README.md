# Tasca 6 · RAID i espill entre equips

**ISO RA3** · a102, a103 (Apte) · a107–a109 (Apte+) · Estat: ✅

## 1. RAID 0, 1, 5 i 10 (a102)

**On:** VM 230 SRV-DADES (Debian sense GUI, node PVE3) amb **5 discos d'1 GB**. Dades fictícies.
**Script:** [`scripts/raid-proves.sh`](scripts/raid-proves.sh) (detecta els discos per mida, no per `sdX`): crea el RAID amb `mdadm`, hi copia fitxers amb el seu SHA-256, provoca la fallada d'un disc, comprova la integritat i mesura la reconstrucció.

| Nivell | Discos | Capacitat útil | Fallada provocada | Dades | Reconstrucció |
|---|---|---|---|---|---|
| RAID 0 | 2 | 2,0 G | Es perd un disc | ❌ **perdudes** (no s'assembla) | — |
| RAID 1 | 2 (+1) | 988 M | `--fail` | ✅ íntegres, volum degradat | **8 s** |
| RAID 5 | 3 + spare | 2,0 G | `--fail` | ✅ íntegres, **el spare entra sol** | **12 s**, automàtica |
| RAID 10 | 4 (+1) | 2,0 G | `--fail` | ✅ íntegres | **3 s** |

Registres: [`raid1`](evidencies/raid/raid1.log) · [`raid5`](evidencies/raid/raid5.log). El rendiment no es pot comparar perquè tots els discos són al mateix SSD USB.

**Conclusions a partir de les proves** (redactades amb l'IA a partir dels registres; l'alumne les ha de revisar i saber explicar):
- **RAID 0** dona la capacitat dels dos discos, però la prova demostra que **perdre'n un és perdre-ho tot**: no hi ha manera d'assemblar-lo. Només per a dades que es poden regenerar.
- **RAID 1** perd la meitat de la capacitat (988 M de 2 GB), però el servei **no s'atura** quan falla un disc, i la reconstrucció només copia un disc.
- **RAID 5** aprofita més la capacitat (2 de 3 discos) i, amb un **spare**, es recupera sol: és l'únic dels quatre on no ha calgut fer res després de la fallada. La reconstrucció ha sigut la més lenta (12 s), perquè ha de recalcular la paritat amb tots els discos.
- **RAID 10** té la mateixa capacitat que el RAID 5 amb un disc més, però la reconstrucció és la més ràpida (3 s), perquè només es copia el disc germà de la parella.
- Cap d'ells substitueix la còpia: un esborrat es replica a tots els discos a l'instant.

## 2. Què aporta cada nivell (a103)

| Nivell | Mínim de discos | Capacitat útil amb n discos de mida C | Tolerància | Rendiment | Quan l'usaria a l'empresa |
|---|---|---|---|---|---|
| **0** (striping) | 2 | n × C | **Cap**: si falla un disc, es perd tot | Llegir i escriure és més ràpid (paral·lel) | Dades temporals que es poden regenerar: memòria cau, renderitzat. **Mai** per a dades úniques |
| **1** (espill) | 2 | C | n − 1 discos | Lectura bona; escriptura com un sol disc | Disc del sistema dels servidors, i el NAS quan només té 2 discos |
| **5** (paritat distribuïda) | 3 | (n − 1) × C | 1 disc | Lectura bona; escriptura més lenta pel càlcul de paritat. La reconstrucció és llarga i arrisca el volum | Dades de departaments amb pocs discos: bon equilibri entre capacitat i seguretat |
| **10** (espill + striping) | 4 | n/2 × C | 1 per parella (fins a n/2 si cauen en parelles diferents) | El millor dels quatre en escriptura | Bases de dades i VM: moltes escriptures petites |

**RAID no és còpia de seguretat:** un esborrat o un ransomware es replica a tots els discos.

## 3. Espill entre dos equips (Apte+ · a107–a109)

**Solució escollida (a107): DRBD** (RAID 1 per xarxa). Alternatives: mdadm + disc remot (sense failover real), GlusterFS (fitxers, millor amb 3 nodes) i Ceph (mínim 3 nodes i molta RAM: no hi cap).

**Implementació (a108):** DRBD entre **VM 220 (PVE2, .22)** i **VM 230 (PVE3, .23)**, un disc de 2 GB a cada una, protocol C (síncron). Configuració: [`config-drbd/r0.res`](config-drbd/r0.res) ([passos](config-drbd/README.md)).

**Cas d'ús (a109):** la carpeta del departament **Comercial** replicada en dos servidors de nodes diferents.

| Pas | Resultat | Evidència |
|---|---|---|
| Sincronització inicial | `UpToDate/UpToDate` en 87 s | — |
| Escriptura al primari | 4 fitxers amb SHA-256 | — |
| Caiguda brusca del node A | detectada pel node B | — |
| B passa a primari | **4/4 fitxers íntegres** | [`04-failover`](evidencies/drbd/04-failover.txt) |
| Torna A | entra com a secundari i rep el que s'havia escrit a B | — |
| Canvi planificat de primari | 2,8 s, 5/5 OK | — |
| **Temps sense servei** | **7,3 s**, cap fitxer perdut | — |

**Límits:** failover manual (automàtic necessitaria Pacemaker i un tercer vot); risc de *split-brain* si els dos són primaris; la latència de xarxa s'afig a cada escriptura; **no substitueix la còpia**.
