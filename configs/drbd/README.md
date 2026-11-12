# DRBD · espill entre dos equips

**Abans de res, identifica el disc de 2 GB de cada VM per mida, no pel nom.** A la VM 230 els noms `sdX` no segueixen l'ordre `scsiN`, i un `sdX` equivocat esborraria un disc del RAID o el del sistema:

```bash
lsblk -dbnpo NAME,SIZE | awk '$2==2147483648'     # el disc de 2 GiB
ls -l /dev/disk/by-path/ | grep -w "$(basename <disc>)"   # el seu camí estable
```
Posa aquest camí `/dev/disk/by-path/...` a la línia `disk` de cada node a `r0.res`, **entre cometes** (si no, DRBD dona *Parse error* pels `:`).

**Versions (12/11/2026):** mòdul del nucli DRBD **8.4.11** (el que porta Debian 13) i `drbd-utils` **9.22**, que el detecta i usa `drbdsetup-84`. `drbd-utils` instal·la com a recomanat `exim4` (correu local per als avisos): només escolta a `127.0.0.1:25`.

```bash
# A LES DUES VM (root)
apt install -y drbd-utils
modprobe drbd
install -m 600 r0.res /etc/drbd.d/r0.res   # i canviar shared-secret a mà (openssl rand -hex 16)
drbdadm dump r0                     # comprova la sintaxi
# hostname ha de coincidir amb les seccions "on": srv-serveis / srv-dades
drbdadm create-md r0
drbdadm up r0
# NOMÉS A srv-serveis (primari inicial)
drbdadm primary --force r0
drbdadm status r0                    # esperar a "peer-disk:UpToDate"
mkfs.ext4 /dev/drbd0 && mkdir -p /srv/espill && mount /dev/drbd0 /srv/espill
# Cas d'ús: carpeta compartida de "Comercial" replicada
cp -r /usr/share/doc/drbd-utils /srv/espill/comercial && sha256sum /srv/espill/comercial/* > /root/hash-espill.txt
```

## Prova de failover manual (a109)
```bash
# srv-serveis cau (simulació): "qm stop 220" al node PVE2 (tall brusc)
# A srv-dades:
drbdadm status r0            # peer: connection:Connecting -> l'altre node no hi és
drbdadm primary r0
mount /dev/drbd0 /srv/espill
cd /srv/espill/comercial && sha256sum -c /root/hash-espill.txt   # (copiar abans el fitxer de hash)
```
Quan `srv-serveis` torna, entra com a secundari i es resincronitza només el que ha canviat (`drbdadm status`).
