# DRBD · espill entre dos equips

Comprova abans el nom dels discos amb `lsblk`: el disc de 2 GB de cada VM (a `srv-serveis` és `sdb`; a `srv-dades` és `sdg` perquè hi ha els 5 discos del RAID davant).

```bash
# A LES DUES VM (root)
apt install -y drbd-utils
cp r0.res /etc/drbd.d/r0.res        # i canviar shared-secret a mà
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
