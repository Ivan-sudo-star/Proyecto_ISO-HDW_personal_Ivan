# 07 · Tasca 8 — Cas final individual (dimecres 25/11/2026)

Accions Apte: a25 (maquinari), a80 (instal·lació/arrencada), a104 (recuperació), a122 (rendiment),
a26 (justificar i comprovar) i a50–a53 (cas FDM RA4). Apte+: qüestionari per RA (a30, a57, a84, a110, a126).

## 1. Preparació (abans del 25/11)
- [ ] Instantània `pre-final` de totes les VM del grup `/ISO_HWD`, i còpies del NAS al dia.
- [ ] Secure Boot de casa resolt i l'entorn comprovat **als dos equips**.
- [ ] Haver assajat almenys una avaria de cada tipus (taula de la secció 3) i haver-ne mesurat el temps.
- [ ] Portar aquest full de comandes i el pla de contingència de [04](04-installacio.md#pla-de-contingència-individual-temps-observats).

## 2. Mètode per a qualsevol incidència
1. **Acotar l'impacte:** quina funció falla, per a qui, des de quan. Què continua funcionant?
2. **Hipòtesi:** la causa més probable i una causa alternativa.
3. **Prova que les distingisca:** una sola ordre que done un resultat diferent segons la causa.
4. **Pla de contingència:** quin recurs de recuperació hi ha (còpia, instantània, RAID) i què es perdria.
5. **Aplicar-lo** amb un punt de retorn previ. **No** arriscar l'única còpia.
6. **Prova funcional final:** el servei torna a funcionar per a l'usuari, no n'hi ha prou que «la VM arranque».
7. **Documentar:** estat inicial, incidència, decisions, temps i limitacions.

## 3. Entrenament d'avaries

| Tipus | Avaria d'assaig | Símptoma | Prova que distingeix la causa | Solució | Temps |
|---|---|---|---|---|---|
| Maquinari (a25) | Treure un disc del RAID 1 (a PVE3: `qm set 230 --delete scsi2`) | `[U_]` a `/proc/mdstat` | `mdadm --detail` (removed) vs `dmesg` (errors d'E/S) | Afegir un disc nou + `mdadm --add` | |
| Maquinari (a25) | NIC desconnectada (`VBoxManage controlvm X setlinkstate1 off`) | Sense xarxa | `ip link` (NO-CARRIER) vs `ip a` (sense IP) | Reconnectar / revisar el cable | |
| Arrencada (a80) | `grub.cfg` esborrat / `fstab` amb un UUID incorrecte | `grub>` / *emergency mode* | `ls` a GRUB / `journalctl -xb` | `configfile` + `update-grub` / corregir el `fstab` | |
| Actualització (a80) | Paquet trencat després d'un `apt` | Servei que no arranca | `systemctl status`, `apt -f install` | Tornar a la instantània o a la versió anterior | |
| Recuperació (a104) | Esborrar `/etc/nftables.conf` de R3 | La LAN no té Internet | `nft list ruleset` buit | Restaurar-lo des del NAS | |
| Rendiment (a122) | `stress-ng --vm 1 --vm-bytes 90%` en una VM | L'amfitrió va lent | `vmstat` (si/so), `top` | Limitar la VM / reduir-ne la RAM | |
| Clúster | Apagar PVE3 de colp | VM 230 inaccessible | `pvecm status` (encara amb quòrum?) | Engegar el node o restaurar `vzdump` en un altre node | |

## 4. Full de comandes

| Àmbit | Linux | Windows | MikroTik |
|---|---|---|---|
| Maquinari | `lscpu`, `free -h`, `lsblk`, `lspci`, `lsusb`, `dmesg -T \| tail`, `sudo smartctl -H` | `msinfo32`, `Get-PhysicalDisk`, `mdsched` | `/system resource print`, `/system health print` |
| Xarxa | `ip a`, `ip route`, `ping`, `traceroute -n`, `ss -tulpn`, `resolvectl` | `ipconfig /all`, `route print`, `tracert -d`, `Test-NetConnection` | `/ip address print`, `/ip route print`, `/ping`, `/tool traceroute` |
| Tallafocs | `nft list ruleset`, `journalctl -k \| grep NFT` | `Get-NetFirewallRule` | `/ip firewall filter print stats`, `/log print` |
| Discos | `mdadm --detail`, `cat /proc/mdstat`, `df -hT`, `drbdadm status` | `Get-Volume`, `diskmgmt.msc` | — |
| Registres | `journalctl -p err -b`, `journalctl -u <servei>` | `eventvwr`, `Get-WinEvent -LogName System -MaxEvents 20` | `/log print` |
| Rendiment | `vmstat 1`, `iostat -x 1`, `top`, `free -m` | `perfmon`, `resmon` | `/tool profile` |
| Recuperació | `rsync`, `tar xzf`, `nft -f`, `VBoxManage snapshot <vm> restore <nom>` | `wbadmin get versions`, `wbadmin start recovery` | `/import`, `/system backup load` |

## 5. FDM RA4: el que he de saber explicar (a50–a53, a57)

- **Equips personals vs empresarials:** components redundants (fonts, discos *hot-swap*), RAM ECC, gestió remota fora de banda (iLO/iDRAC/IPMI), format de rack (U), garantia i suport amb SLA, i certificació del maquinari amb els SO de servidor.
- **CPD xicotet per a l'empresa de l'enunciat** (no un CPD de Google):
  - un rack de 19" amb panell de connexions, commutador i servidor de comunicacions;
  - els 3 nodes, el NAS i un SAI amb gestió per xarxa;
  - ventilació (passadís fred i calent, o almenys separació de l'entrada i l'eixida d'aire);
  - porta amb clau i registre d'accessos;
  - cablejat de dades separat del d'alimentació i etiquetat als dos extrems.
- **Rack:** unitats (1U = 44,45 mm), profunditat útil, càrrega, accés frontal i posterior, i guies de cables.
- **Alimentació:** cal separar el **consum mesurat** de la **potència nominal** de la font. El SAI es dimensiona amb el consum real × marge i el temps d'autonomia necessari per a una aturada ordenada. La connexió en calent només es fa amb maquinari certificat i seguint el procediment del fabricant.
- **Inventari i documentació:** etiqueta, ubicació (rack/U), ports, IP, responsable i data. Aquest repositori és un exemple de documentació versionada.
- Per al cas: **identificar** cada equip i la seua funció, **inventariar** connexions i ports, analitzar **alimentació, ventilació i ordre del cablejat**, i aportar un **esquema** propi amb draw.io, com el de [03](03-xarxa.md).

## 6. Estudi per al qüestionari (Apte+)

| RA | Conceptes | On ho he treballat |
|---|---|---|
| FDM RA1 (a30) | Inventari, arrencada (UEFI/BIOS, Secure Boot, TPM), arquitectura (nuclis P/E, fils), rendiment, diagnòstic, avaries, perifèrics | [02](02-inventari.md), [06](06-rendiment.md) |
| FDM RA4 (a57) | Secció 5 d'aquest document | — |
| ISO RA1 (a84) | Funcions del SO, tipus (client/servidor/comunicacions), llicències (GPL, BSD, propietàries, avaluació), versions i suport, instal·lació, actualització, recuperació, incidències d'arrencada | [04](04-installacio.md) |
| ISO RA3 (a110) | Sistemes de fitxers (ext4, ZFS, NTFS, XFS), particions i volums, RAID, còpies (completa/incremental/diferencial, 3-2-1), quotes, recuperació | [05](05-raid.md), [04 §1.4](04-installacio.md#14-espai-de-còpies-què-és-còpia-com-i-on-a259) |
| ISO RA6 (a126) | Recursos i successos, monitoratge en temps real, registres, alertes, càrrega simulada, optimització | [06](06-rendiment.md), registres de tallafocs a [04](04-installacio.md) |

## 7. Registre del dia 25/11
*(Enunciat rebut, anàlisi, solució aplicada, comprovacions i temps: s'omple durant la prova.)*
