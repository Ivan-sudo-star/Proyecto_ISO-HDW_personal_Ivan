# 04 · Tasca 5 — Instal·lació i configuració dels sistemes (ISO RA1 / RA3 / RA6)

Instal·le en el meu entorn **els mateixos sistemes que el grup**. Tots segueixen la mateixa plantilla:
**instal·lar i comprovar la versió → usuaris d'administració → xarxa → còpia al NAS (què sí i què no)**.
Els routers, a més, han de passar la prova de NAT, una connexió permesa i una bloquejada, i una fallada amb recuperació.

**Ordre d'instal·lació** (cadascú depén de l'anterior):
1. R1 MikroTik, que és la porta d'enllaç principal. Si dona problemes, R3, que ja està instal·lat i es pot configurar com a .3 →
2. CLI-Debian (navegador per a les webs de gestió) →
3. NAS →
4. R2 i R3 →
5. els 3 nodes Proxmox i el clúster →
6. les VM dins del clúster (SRV-SERVEIS, SRV-DADES i SRV-WS2025) →
7. el client Windows.

**Punt de retorn:** abans de cada canvi important es fa una instantània de VirtualBox amb nom
`<vm>-<estat>`, p.ex. `VBoxManage snapshot R1-MikroTik take R1-instal-ok`.

---

## 1. Comprovacions generals (a78, a79, a258, a259)

### 1.1 Requisits, origen i integritat de les imatges (a78)

Hash local calculat l'11/11/2026 amb `sha256sum` ([`sha256-local.txt`](../evidencias/t5-isos/sha256-local.txt)).
Hash oficial descarregat de la font del fabricant el mateix dia.

| Sistema | ISO | Arquitectura | Font oficial | SHA-256 local (inici…final) | Coincideix amb l'oficial? |
|---|---|---|---|---|---|
| Debian 13.1.0 netinst | `debian-13.1.0-amd64-netinst.iso` | amd64 | cdimage.debian.org/cdimage/archive/13.1.0/amd64/iso-cd/SHA256SUMS | `658b28e2…c65568b3` | ✅ **Sí** |
| Proxmox VE 9.2-1 | `proxmox-ve_9.2-1.iso` | amd64 | enterprise.proxmox.com/iso/SHA256SUMS | `4e88fe41…73ef2c6c` | ✅ **Sí** |
| TrueNAS SCALE 25.10.7 | `TrueNAS-SCALE-25.10.7.iso` | amd64 | download.sys.truenas.net/…/TrueNAS-SCALE-25.10.7.iso.sha256 | `54ce9441…7a007c8e` | ✅ **Sí** |
| OPNsense 26.7 | `OPNsense-26.7-dvd-amd64.iso` | amd64 | pkg.opnsense.org/releases/26.7/OPNsense-26.7-checksums-amd64.sha256 | `1efd5dc9…48d5dcd` | ⚠️ **N/C**: el fabricant publica el hash del `.iso.bz2` comprimit (`95cafedd…bfb`). Prova: tornar a descarregar el `.bz2`, comprovar-ne el hash i descomprimir-lo |
| MikroTik RouterOS 7.24.5 | `mikrotik-7.24.5.iso` | x86 | mikrotik.com/download (secció *Checksums*) | `4bff16b8…75aaec02` | ⬜ **N/C**: comparar amb el valor de la web de descàrregues |
| Windows 11 | `w11.iso` | x64 | microsoft.com/software-download/windows11 (hashes per idioma) | `5210deed…89119dc8` | ⬜ **N/C**: identificar l'idioma i l'edició i comparar |
| Windows Server 2025 | *(falta)* | x64 | Microsoft Evaluation Center | — | ⬜ falta la ISO |

Hashes complets a les evidències.

**Requisits mínims oficials i recursos assignats:**

| Sistema | Mínim oficial (N/C = comprovar a la doc. del fabricant) | Assignat | Firmware / dispositius virtuals |
|---|---|---|---|
| RouterOS x86 | 256 MB de RAM, disc ≥ 128 MB (N/C) | 512 MB · 1 GB | BIOS · NIC Intel PRO/1000 (82540EM), que RouterOS reconeix |
| OPNsense | 1 GB RAM (recomanat 2 GB +), disc 8 GB+ (N/C) | 2 GB · 20 GB | BIOS · NIC em (82540EM) |
| Debian 13 sense GUI | 512 MB RAM, 2 GB de disc (N/C) | 1 GB · 20 GB | BIOS |
| TrueNAS SCALE | **8 GB RAM**, disc d'arrencada 16 GB, discos de dades a part | 8 GB · 20 + 50 GB | EFI · cal un disc diferent per al pool |
| Proxmox VE 9 | 2 GB + RAM per a les VM, CPU amb VT-x | 4 GB · 32 GB | BIOS · **VT-x niuat activat** · NIC promíscua |
| Windows Server 2025 | 2 GB (Desktop Experience), disc 32 GB, UEFI | 4 GB · 50 GB | EFI (TPM no obligatori en servidor) |
| Windows 11 | 4 GB, 64 GB, **UEFI + Secure Boot + TPM 2.0** | 4 GB · 80 GB | EFI · SB · TPM 2.0 ✅ (comprovat al `.vbox`) |

### 1.2 Actualització i comprovació abans de "producció" (a79)

| Sistema | Versió abans | Ordre d'actualització | Versió després | Prova de funcionament |
|---|---|---|---|---|
| MikroTik | `/system resource print` | `/system package update check-for-updates` → `install` | | ping 1.1.1.1 des de la LAN |
| OPNsense | Panell | `opnsense-update` o System → Firmware → Updates | | web de gestió + eixida LAN |
| Debian (R3, INFRA, RAID, CLI) | `cat /etc/debian_version; uname -r` | `apt update && apt full-upgrade` | | `systemctl --failed` buit + servei |
| TrueNAS | Dashboard | System → Update | | pool ONLINE, recurs accessible |
| Proxmox | `pveversion -v` | repositori *no-subscription* + `apt update && apt full-upgrade` | | `pvecm status`, CT arrenca |
| Windows (WS / W11) | `winver` | Windows Update | | `Test-NetConnection 192.168.13.1` |

### 1.3 Problemes possibles, configuracions crítiques i temps de resposta (a258)

| Sistema | Problema possible d'instal·lació o arrencada | Configuració crítica | Temps de resposta objectiu |
|---|---|---|---|
| Routers | Interfícies WAN/LAN canviades (ether1/ether2, em0/em1), sense NAT, regla que talla la gestió | IP LAN, NAT, regles de filtre, usuari admin | 15 min (importar la còpia) |
| TrueNAS | Instal·lat al disc equivocat (esborra el de còpies), pool no importat després d'una actualització | Pool `copies`, usuaris, recursos compartits, **config + secret seed** | 30 min |
| Proxmox | Sense VT-x niuat (no arrenquen les VM KVM), pèrdua de quòrum si cauen 2 dels 3 nodes, `/etc/hosts` sense el nom del node (problema del grup), repositori enterprise sense subscripció | `/etc/pve`, corosync, `vmbr0` | 30 min |
| Windows Server | Requisits UEFI, controlador de disc, activació | IP estàtica, rols, (AD si es promou) | 60 min |
| Windows 11 | TPM/Secure Boot desactivats a la VM → «Aquest PC no pot executar Windows 11» | Usuaris i perfil | 60 min (reinstal·lació + dades) |
| Debian | GRUB al disc equivocat, nom d'interfície diferent (`enp0s3`/`enp0s8`) | `/etc/network/interfaces`, `/etc/fstab` | 20 min |

**Incidència d'arrencada provocada (ISO RA1 h):** en una instantània descartable de `CLI-Debian`, renomenar
`/boot/grub/grub.cfg` → símptoma (prompt `grub>`) → hipòtesi (falta la configuració de GRUB) → comprovació
(`ls (hd0,msdos1)/boot/grub`) → solució (`configfile` manual i després `update-grub`) → retorn (restaurar la instantània).
Evidència a `evidencias/t5-linux-infra/incidencia-grub.md`.

### 1.4 Espai de còpies: què és còpia, com i on (a259)

| Tipus | Què | Com | On (TrueNAS `copies`) | Freqüència |
|---|---|---|---|---|
| **Configuració** | Export dels routers, `/etc` dels Linux, `/etc/pve`, `config.xml` | `copia-configs.sh` (rsync/SSH) · scheduler MikroTik (SFTP) | `/mnt/copies/routers`, `/linux`, `/proxmox` | Diària |
| **Imatge de VM** | Còpia completa de les VM i els CT de Proxmox | `vzdump` cap a l'emmagatzematge NFS del NAS | `/mnt/copies/proxmox/dump` | Setmanal + abans de cada canvi |
| **Estat del sistema Windows** | System State + volums crítics del WS2025 | `wbadmin` cap al recurs SMB | `/mnt/copies/windows` | Setmanal |
| **Dades d'usuari** | Documents dels clients | `robocopy` (W11) · `rsync` (Linux) | `/mnt/copies/clients` | Diària |
| **No és còpia** | RAID, DRBD i instantànies de VirtualBox | — | — | Protegeixen davant la fallada d'un disc o són punts de retorn locals, però **estan al mateix disc USB** |

**Limitació acceptada:** el NAS també és una VM del mateix SSD USB. Si es perd el disc USB, es perd tot.
Mitigació (regla 3-2-1): exportar regularment `/mnt/copies` i la configuració del TrueNAS a un **segon suport**
fora del disc (disc intern de casa o un altre pendrive), sense pujar-ho a GitHub.

---

## 2. R1 · MikroTik RouterOS (a203–a209)

**Configuració:** [`configs/mikrotik/r1-config.rsc`](../configs/mikrotik/r1-config.rsc) · evidències a `evidencias/t5-mikrotik/`

1. **Instal·lació (a203):**
   - Arrancar la VM amb la ISO, marcar el paquet `system` i prémer `i`. Després, reiniciar i desmuntar la ISO.
   - `/system resource print` → versió 7.24.5, arquitectura x86 i RAM.
   - `/system license print` → nivell de llicència. **N/C:** sense clau, RouterOS x86 pot funcionar en mode demostració de temps limitat. Si passa, l'alternativa és la imatge CHR, que té llicència gratuïta limitada a 1 Mb/s.
2. **Usuaris (a204):** importar el bloc d'usuaris del `.rsc` i fer `/user set admin-ivan password=<...>`. Comprovar l'accés amb el nou usuari i deshabilitar `admin`. L'usuari `suport` és de només lectura.
3. **Xarxa (a205):** `/ip address print`, `/ip dhcp-client print` → WAN 10.0.2.15, LAN 192.168.13.1.
4. **Internet per a la LAN (a206):** regla `masquerade`. Des de CLI-Debian: `ping 1.1.1.1` i `curl -I https://debian.org`.
5. **Permesa / bloquejada (a207):**
   - `curl` (permesa) i `nc -zv github.com 22` (bloquejada).
   - `/log print where message~"R1-"` → interpretar una línia de cada tipus: cadena, interfície d'entrada i d'eixida, origen, destí, protocol, port i acció.
6. **Còpia al NAS (a208):**
   - `/export file=r1-export` (text, regenera la configuració) i `/system backup save` (binari, inclou usuaris; es xifra i **no es puja al Git**).
   - Pujada per SFTP al NAS (§10).
   - **Què NO:** el sistema sencer. Reinstal·lar la ISO tarda menys de 5 min.
7. **Fallada i recuperació (a209):**
   - Instantània `R1-ok` → esborrar la regla NAT i la IP LAN (`/ip firewall nat remove 0`, `/ip address remove [find interface=ether2]`) → símptoma: els clients no tenen Internet.
   - Diagnòstic: `/ip address print`, `/ip firewall nat print`.
   - Recuperació: entrar per la consola de VirtualBox i fer `/import r1-export.rsc` (o `/system backup load`).
   - Prova final: el client torna a navegar. **Anotar el temps.**


### ✅ Resultat R1 (11/11/2026, equip de casa)

| Acció | Estat | Evidència |
|---|---|---|
| a203 instal·lació i versió | ✅ RouterOS **7.24.5 (stable)** x86_64, paquet `system`. **Llicència: sense clau, 24 h de funcionament** (el comptador només avança amb la VM encesa: s'apaga quan no s'usa) | `t5-mikrotik/01-installador-paquets.png`, `02-installacio-completada.png`, `03-llicencia-x86-24h.png`, `a203-versio.txt` |
| a204 usuaris | ✅ `admin-ivan` (grup full) i `suport` (grup `lectura`, només lectura). `admin` **deshabilitat** després de comprovar l'accés amb `admin-ivan` | `a204-usuaris.txt` |
| a205 xarxa | ✅ ether1 WAN 10.0.2.15/24 per DHCP (GW 10.0.2.2), ether2 LAN 192.168.13.1/24 | `a205-xarxa.txt` |
| a206 Internet per a la LAN | ✅ masquerade + DHCP .100–.200. CLI-Debian i TrueNAS s'han instal·lat descarregant paquets a través de R1 (leases .199 i .200). El NAS fa ping a 1.1.1.1 | `a206-nat-dhcp.txt` |
| a207 permesa/bloquejada | ✅ des de CLI-Debian: `curl https://www.debian.org` → `HTTP/2 200` (registre `R1-FWD-OK ... ->130.89.148.77:443`). `nc github.com 22` → timeout (registre `R1-BLOQ-SSH`: 5 SYN, el primer i 4 retransmissions; comptador de la regla = 5 paquets). Interpretació a l'evidència | `a207-filtre.txt`, `a207-prova-permesa-bloquejada.txt` |
| a208 còpia al NAS | ✅ `/export` (text, sense dades sensibles) + `/system backup save` (binari xifrat) pujats per SFTP a `/mnt/copies/routers/r1/` | `a208-copia-al-nas.txt` |
| a209 fallada i recuperació | ✅ s'esborren la IP de la LAN, el NAT i la còpia local → els clients perden la porta d'enllaç. Recuperació: es torna a posar la IP de la LAN, es baixa `r1-backup.backup` del NAS per SFTP i es fa `/system backup load`. Prova final: CLI-Debian torna a obtindre `HTTP/2 200`. **Temps d'inactivitat: 42 s** | `a209-fallada-recuperacio.txt` |

**Accés de gestió afegit:** redirecció de port NAT de VirtualBox `127.0.0.1:2201 → R1:22`, i regla `input` que només accepta SSH per la WAN des de 10.0.2.2 (l'amfitrió). Amb `/ip ssh set forwarding-enabled=local`, R1 fa de **bastió**: des de l'amfitrió s'entra a la resta de la LAN13 amb `ssh -J admin-ivan@127.0.0.1:2201 usuari@192.168.13.x`.

## 3. R2 · OPNsense (a210–a216)

Evidències a `evidencias/t5-opnsense/`.

1. **Instal·lació (a210):**
   - Arrancar la ISO, entrar com a `installer` i instal·lar sobre ZFS o UFS al disc de 20 GB.
   - Assignar les interfícies a la consola (opció 1): **em0 = WAN**, **em1 = LAN**.
   - La versió apareix al Dashboard. Després, actualitzar (§1.2).
2. **Usuaris (a211):**
   - Canviar la contrasenya de `root`.
   - System → Access → Users: crear `admin-ivan` al grup `admins`.
   - Optativament, desactivar el login de root a la web (System → Settings → Administration).
3. **Xarxa (a212):**
   - Opció 2 de la consola: LAN **192.168.13.2/24**. Servidor DHCP .100–.200 **només mentre R1 està apagat**. La WAN funciona per DHCP.
   - Accés a la web des de CLI-Debian: `https://192.168.13.2`.
4. **Internet (a213):** l'*Outbound NAT* automàtic ja fa masquerade de la LAN. Prova des del client.
5. **Permesa / bloquejada (a214):**
   - Firewall → Rules → LAN: regla 1 *Block* TCP, destí qualsevol, port 22, amb **Log** activat. Regla 2 *Pass* LAN net → any, amb log.
   - Llegir Firewall → Log Files → **Live View**: interpretar la línia vermella (bloquejada) i la verda (permesa).
6. **Còpia (a215):** System → Configuration → Backups → *Download* `config.xml` (tota la configuració en un fitxer). Pujada automàtica amb `copia-configs.sh`, que fa `scp root@192.168.13.2:/conf/config.xml`.
7. **Fallada i recuperació (a216):**
   - Instantània → esborrar les regles de LAN o fer *Reset to factory defaults*. Símptoma: no hi ha eixida, o bé la IP LAN torna a 192.168.1.1.
   - Restaurar `config.xml` (Backups → *Restore*) i reiniciar. Comprovar el client. **Temps.**

## 4. R3 · Debian 13 + nftables (a217–a223)

**Configuració:** [`configs/nftables/`](../configs/nftables/) (vegeu-ne el README) · evidències a `evidencias/t5-nftables/`

1. **Instal·lació i versió (a217):** VM `Debian_NFtables` existent. `cat /etc/debian_version`, `uname -r`, `nft --version`, `apt update && apt full-upgrade`.
2. **Usuaris (a218):** usuari `ivan` al grup `sudo`. A `/etc/ssh/sshd_config`: `PermitRootLogin no`. Accés per clau des de SRV-SERVEIS (usuari `copies`, només per a les còpies).
3. **Xarxa (a219):** fitxer `interfaces`: `enp0s3` per DHCP (WAN) i `enp0s8` **192.168.13.3/24** (LAN). Activar `ip_forward`. El `dnsmasq` dona DHCP amb porta d'enllaç .3 i només s'activa quan R1 està apagat.
4. **Internet (a220):** `masquerade` a la taula `ip nat`, més `dnsmasq` per al DHCP i el DNS de la LAN. Prova des del client.
5. **Permesa / bloquejada (a221):**
   - `journalctl -k | grep NFT-`: interpretar `NFT-FWD-OK` i `NFT-FWD-BLOQ-SSH`, amb `IN`, `OUT`, `SRC`, `DST`, `PROTO`, `DPT` i `SYN`.
   - Comptadors: `nft list chain inet filtre forward`.
6. **Còpia (a222):**
   - `nft list ruleset` i `tar` de `/etc/nftables.conf`, `/etc/network`, `/etc/sysctl.d` i `/etc/dnsmasq.d`.
   - **Què NO:** `/usr` i els paquets, perquè es reinstal·len amb `apt` a partir de la llista de paquets.
7. **Fallada i recuperació (a223):**
   - `nft flush ruleset`, o bé `sysctl net.ipv4.ip_forward=0`.
   - Diagnòstic: `nft list ruleset` buit, `sysctl net.ipv4.ip_forward`, `ip route`.
   - Recuperació: `nft -f /etc/nftables.conf` o restaurar la còpia del NAS amb `rsync`. **Temps.**

## 5. NAS · TrueNAS SCALE (a224–a227, a259)

Evidències a `evidencias/t5-truenas/`.

1. **Instal·lació (a224):**
   - Instal·lar **només al disc de 20 GB** (`boot`). Compte: si es tria el de 50 GB, es perd el disc de còpies.
   - La versió apareix al Dashboard (25.10.7).
2. **Usuaris (a225):**
   - `truenas_admin` (administrador creat a la instal·lació).
   - Usuari `copies`: no administrador, amb home a `/mnt/copies` i clau SSH pública de SRV-SERVEIS. Té permisos d'escriptura només al pool de còpies.
3. **Xarxa (a226):** consola → *Configure network interfaces*: 192.168.13.20/24, GW 192.168.13.1, DNS 192.168.13.1. Desactivar el DHCP.
4. **Disc addicional per a còpies (a227):**
   - Storage → *Create pool* `copies` sobre el disc de 50 GB (stripe). Sense redundància, perquè a l'entorn individual és un únic disc. Ho justifique a §1.4.
   - Datasets: `routers`, `linux`, `proxmox` (NFS cap a .21 i .22), `windows` i `clients` (SMB).
   - Serveis: SSH (amb SFTP), NFS i SMB.
5. **Equips crítics** que es copien: els 3 routers (sense ells no hi ha xarxa), els nodes Proxmox, el WS2025 (identitats) i el mateix NAS.
6. **Còpia del propi NAS:** System → General → *Manage configuration* → *Download file*, amb el secret seed. Es guarda **fora** del NAS i **fora** del Git.


### ✅ Resultat NAS (11/11/2026)

| Acció | Estat | Evidència |
|---|---|---|
| a224 instal·lació i versió | ✅ TrueNAS SCALE **25.10.7**, instal·lat **només** al disc de 20 GiB | `t5-truenas/01-disc-installacio-sda.png`, `02-installacio-completada.png` |
| a225 usuaris | ✅ `truenas_admin` (administrador, creat a l'instal·lador; el login de root amb contrasenya queda desactivat) i `copies` (uid 3000, **sense** privilegis d'administrador, home `/mnt/copies/usuaris/copies`) | — |
| a226 xarxa | ✅ enp0s3 **192.168.13.20/24** estàtica (sense DHCP), GW i DNS 192.168.13.1, nom `nas13.lan13.local`. Canvi aplicat amb *commit* i *checkin* (si no es confirma en 120 s, TrueNAS torna sol a la configuració anterior) | — |
| a227 disc addicional | ✅ pool **`copies`** (stripe, 48 GB útils) sobre el disc de 50 GiB · datasets `routers` (r1, r2, r3), `linux`, `proxmox` (NFS per a 192.168.13.0/24), `windows` i `clients` (SMB) · propietari `copies`, permisos 770 · serveis SSH/SFTP, NFS i SMB actius | — |

**Problema trobat i evitat:** després de reiniciar, el disc d'arrencada (20 GiB) va passar a anomenar-se **`sdb`** i el de 50 GiB **`sda`**. La primera ordre de creació del pool (amb `sdb`) va fallar amb *«disks are already in use: sdb»*: TrueNAS va impedir esborrar el disc del sistema.
**Lliçó:** no s'han d'identificar els discos pel nom `sdX`, que pot canviar en cada arrencada, sinó per la mida o el número de sèrie (`/api/v2.0/disk`).

## 6. Proxmox VE (a228–a232, a235, a236)

Evidències a `evidencias/t5-proxmox/`. Com al grup: un **clúster de 3 nodes**, i els servidors empresarials són VM *dins* dels nodes.
Requisit: `--nested-hw-virt on`, ja aplicat. Per comprovar-ho dins de cada node: `egrep -c vmx /proc/cpuinfo` ha de donar més de 0.

1. **Instal·lació (a228):**
   - PVE1: hostname `pve1.lan13.local`, IP 192.168.13.32/24.
   - PVE2: `pve2.lan13.local`, .33.
   - PVE3: `pve3.lan13.local`, .34.
   - Tots tres amb GW i DNS .1.
   - Després, `pveversion -v`, desactivar el repositori enterprise, activar el `no-subscription` i fer `apt update && apt full-upgrade`.
   - Comprovar que `/etc/hosts` té el nom de cada node amb la seua IP. El grup va tindre problemes amb això (si Proxmox no troba el seu nom, no arrenca la web).
2. **Usuaris (a229):**
   - `root@pam` (sistema).
   - `pveum user add ivan@pve`, `pveum passwd ivan@pve` i `pveum acl modify / -user ivan@pve -role Administrator`.
   - Usuari de consulta: rol `PVEAuditor`.
3. **Xarxa (a230):** `/etc/network/interfaces` amb `vmbr0` sobre `enp0s3` (exemple a [03 §2](03-xarxa.md#2-configuració-de-cada-interfície-a148)). Comprovar `ip a` i `bridge link`.
4. **Clúster (a232):**
   - PVE1: `pvecm create cluster13`. PVE2 i PVE3: `pvecm add 192.168.13.32`.
   - Després, `pvecm status` (`Expected votes: 3`, `Quorate: Yes`) i `pvecm nodes`.
   - **Quòrum amb 3 nodes:** cada node té 1 vot i en calen 2, la majoria. Si en cau un, els altres dos continuen funcionant. Si en cauen dos, el que queda passa `/etc/pve` a només lectura per evitar un *split-brain*.
   - **Prova:** apagar PVE3 → `pvecm status` encara diu `Quorate: Yes`.
   - **Diferències:**
     - *Gestió conjunta*: una sola web i una sola configuració per als 3 nodes.
     - *Migració*: moure a mà una VM o un CT d'un node a un altre.
     - *Alta disponibilitat (HA)*: el clúster reinicia sol les VM d'un node caigut en un altre node. Necessita quòrum i emmagatzematge compartit (o replicació); amb discos locals al meu SSD USB no és viable, i queda com a disseny.
5. **Emmagatzematge compartit:** `pvesm add nfs nas-proxmox --server 192.168.13.20 --export /mnt/copies/proxmox --content backup,iso,vztmpl,images`.
   S'hi guarden la ISO del WS2025 i les plantilles. Així tots els nodes les veuen sense copiar-les.
6. **Servidors dins del clúster:**

   | ID | Nom | Node | Recursos | Disc(s) |
   |---|---|---|---|---|
   | 210 | SRV-WS2025 | PVE1 | 2 vCPU · 4 GB · tipus de CPU `host` · OVMF (UEFI) + EFI disk | 50 GB VirtIO SCSI (controladors *virtio-win*) |
   | 220 | SRV-SERVEIS | PVE2 | 1 vCPU · 1 GB · Debian sense GUI | 10 GB + 2 GB (DRBD) |
   | 230 | SRV-DADES | PVE3 | 1 vCPU · 1 GB · Debian sense GUI | 10 GB + 5×1 GB (RAID) + 2 GB (DRBD) |
   | CT 100 | ct-prova | PVE2 | 1 vCPU · 512 MB | 4 GB |

   - Debian més ràpid: importar `debian-13-genericcloud-amd64.qcow2` amb `qm importdisk` en lloc de la netinst.
   - CT: `pveam download local debian-13-standard_*.tar.zst` i després `pct create 100 local:vztmpl/... --memory 512 --rootfs local-lvm:4 --net0 name=eth0,bridge=vmbr0,ip=192.168.13.41/24,gw=192.168.13.1`.
7. **Migració (a235) i mesures (a236)** — la VM migrada és **SRV-SERVEIS**, una Debian sense entorn gràfic, com demana la rúbrica:

   | Migració | Ordre | Temps | Espai ocupat | Observacions |
   |---|---|---|---|---|
   | CT 100 PVE2→PVE3 | `time pct migrate 100 pve3 --restart` | | `pct df 100` / `du` | Els CT no es poden migrar en calent: es reinicien |
   | VM 220 PVE2→PVE3 (disc local) | `time qm migrate 220 pve3 --online --with-local-disks` | | `qm config 220`, `lvs` | Es copia el disc sencer per la LAN |
   | VM 220 amb el disc al NFS | `time qm migrate 220 pve2 --online` | | | Només es copia la RAM: hauria de ser molt més ràpid |

   **Interpretació i millores:**
   - Amb disc local, el temps depén sobretot de la mida del disc i de l'E/S del SSD USB.
   - Amb emmagatzematge compartit, només depén de la RAM.
   - Millores: emmagatzematge compartit, una xarxa de migració dedicada, imatges més xicotetes (cloud image, CT en lloc de VM) i `migration: type=insecure` a la xarxa de laboratori.
8. **Còpia (a231):**
   - Configuració: `/etc/pve`, `/etc/network/interfaces`, `/etc/hosts` i `/etc/corosync` dels 3 nodes, amb `copia-configs.sh`.
   - Imatges: `vzdump 100 210 220 230 --storage nas-proxmox --mode snapshot --compress zstd`.
   - **Què NO:** el sistema Proxmox, perquè es reinstal·la en 10 min; les ISOs i les plantilles, que es poden tornar a descarregar; i els discos de prova del RAID.
9. **Virtualització: avantatges i inconvenients, i contenidors vs VM** (explicació pròpia per a la defensa):
   - **Avantatges:** aprofitar millor el maquinari, instantànies, migració, aïllament entre serveis i proves sense risc.
   - **Inconvenients:** punt únic de fallada, sobrecàrrega i complexitat. Al meu entorn hi ha **tres nivells** (VirtualBox → Proxmox → VM) i tot depén d'un sol SSD USB.
   - **CT vs VM:** el contenidor comparteix el nucli del node, de manera que és més lleuger, arrenca en segons i ocupa centenars de MB. Va bé per a serveis Linux. La VM porta el seu propi nucli: cal per a Windows, per a altres nuclis o quan es necessita més aïllament.

## 7. Windows Server 2025 (a237–a241)

**VM 210 dins de PVE1** (com al grup, on el Windows Server està dins del clúster). Evidències a `evidencias/t5-ws2025/`.
**Bloqueig: falta la ISO** (avaluació de 180 dies del Microsoft Evaluation Center). Es puja a `nas-proxmox` o a `local` de PVE1,
juntament amb la ISO `virtio-win` (controladors de disc i xarxa VirtIO).

1. **Instal·lació (a237):**
   - VM 210 a PVE1: màquina `q35`, BIOS OVMF, disc VirtIO SCSI i xarxa VirtIO a `vmbr0`.
   - Durant la instal·lació, carregar el controlador `vioscsi` del CD de virtio-win.
   - Edició *Standard Evaluation (Desktop Experience)*.
   - Versió: `winver` i `Get-ComputerInfo | Select OsName, OsVersion, OsBuildNumber`. Després, Windows Update.
2. **Usuaris (a238):** l'`Administrator` local amb contrasenya robusta, més `admin-ivan` al grup Administradors:
   `New-LocalUser admin-ivan; Add-LocalGroupMember Administrators admin-ivan`.
3. **Xarxa (a239):**
   ```powershell
   New-NetIPAddress -InterfaceAlias Ethernet -IPAddress 192.168.13.21 -PrefixLength 24 -DefaultGateway 192.168.13.1
   Set-DnsClientServerAddress -InterfaceAlias Ethernet -ServerAddresses 192.168.13.1
   Rename-Computer SRV-WS2025 -Restart
   ```
4. **Còpia (a240):**
   - **Nivell VM:** `vzdump 210` cap a `nas-proxmox`, que és la imatge completa.
   - **Nivell sistema:** `Install-WindowsFeature Windows-Server-Backup` i després `wbadmin start backup -backupTarget:\\192.168.13.20\windows -allCritical -systemState -quiet`.
   - També `Get-NetIPConfiguration` i `Get-WindowsFeature | ? Installed`, exportats a un fitxer de text.
   - **Què NO:** el fitxer de paginació i la hibernació, les dades temporals i les aplicacions que es reinstal·len.
   - **Què SÍ:** l'estat del sistema. Si el servidor és controlador de domini, conté la base de dades d'Active Directory, que és el més valuós.
5. **Què és un domini i què aporta (a241)** — *redactar-ho amb les meues paraules; guió:*
   - Un domini és un conjunt d'usuaris, equips i recursos que comparteixen una mateixa base de dades d'identitats (Active Directory), gestionada per un o més controladors de domini.
   - **A l'empresa de l'enunciat** (direcció, administració, comercial, producció i informàtica):
     - un usuari s'autentica igual a qualsevol equip;
     - les altes i les baixes es fan en un sol lloc;
     - es poden aplicar polítiques (GPO) per departament;
     - els permisos de les carpetes compartides es donen per grups;
     - i hi ha inventari i auditoria centralitzats.
   - **Inconvenient:** el domini és un servei crític. Calen còpies de l'estat del sistema i, idealment, dos controladors de domini.

## 8. Servidors GNU/Linux d'infraestructura (a242–a246)

**VM 220 `SRV-SERVEIS` (.22, a PVE2) i VM 230 `SRV-DADES` (.23, a PVE3)**, igual que les «VM Debian · serveis» i «VM Debian · dades» del grup.
Evidències a `evidencias/t5-linux-infra/`.

1. **Instal·lació (a242):** Debian 13 **sense entorn gràfic**, des de la netinst (*SSH server* + *standard system utilities*) o des de la cloud image. Comprovar amb `cat /etc/os-release` i fer `apt full-upgrade`.
2. **Usuaris (a243):** `ivan` (sudo) i root sense login SSH. A SRV-SERVEIS, a més, l'usuari de servei `copies` (sense sudo, amb clau SSH).
3. **Xarxa (a244):** estàtica, `ens18` (exemple a [03 §2](03-xarxa.md#2-configuració-de-cada-interfície-a148)). Comprovar amb `ip a`, `ip route` i `cat /etc/resolv.conf`.
4. **Funció i programari (a246):** l'enunciat diu que, de moment, no s'ha d'instal·lar programari addicional. Només el que necessiten les còpies i les proves:
   - SRV-SERVEIS: `rsync` i `openssh`, per orquestrar les còpies.
   - SRV-DADES: `mdadm`, per al RAID.
   - Tots dos: `drbd-utils`, per a la T6.
5. **Còpia (a245):** `/etc` i la llista de paquets (`dpkg --get-selections`), amb `copia-configs.sh`. A més, `vzdump` de la VM sencera.
   - Restaurar: reinstal·lar, fer `dpkg --set-selections` i `apt-get dselect-upgrade`, i descomprimir `/etc`.
   - **Què NO:** `/usr`, `/var/cache` i els discos de prova del RAID (són dades fictícies).

## 9. Clients (a247–a250, a252–a255)

Evidències a `evidencias/t5-clients/`.

| | Windows 11 (`Cliente_windows_1`, existent) | GNU/Linux (`CLI-Debian`) |
|---|---|---|
| Instal·lació i versió (a247/a252) | `winver`, `Get-ComputerInfo`. Requisits: TPM 2.0, UEFI i Secure Boot a la VM ✅. Windows Update | Debian 13 + **XFCE**: és lleuger i serveix de navegador per a les webs de gestió. `cat /etc/os-release` |
| Usuaris (a248/a253) | `admin-ivan` (administrador) i `usuari` (estàndard). Es treballa amb l'estàndard | `ivan` (sudo) i `usuari` (sense sudo) |
| Xarxa (a249/a254) | DHCP del router: `ipconfig /all` ha de mostrar .10x, GW .1 i DNS .1 | DHCP: `ip a`, `ip route`, `nmcli dev show` |
| Còpia (a250/a255) | `robocopy C:\Users\usuari\Documents \\192.168.13.20\clients\w11 /MIR /R:1 /W:1`, més `ipconfig /all` exportat. **No** la imatge sencera: un client es reinstal·la des d'una imatge estàndard. El que és únic són les dades i el perfil de l'usuari | `rsync -a /home/ copies@192.168.13.20:/mnt/copies/clients/cli-debian/` i `/etc`. **No** les aplicacions |
| Domini | ➖ no exigit (a251) | ➖ no exigit (a256) |

## 10. Apte+: còpies automatitzades (a105)

| Equip | Mecanisme | Fitxer | Prova |
|---|---|---|---|
| R1 MikroTik | `/system scheduler` diari + script `copia-nas` (SFTP) | [`r1-scheduler-copia.rsc`](../configs/mikrotik/r1-scheduler-copia.rsc) | `/system script run copia-nas` → el fitxer apareix a `/mnt/copies/routers/r1` |
| R2, R3, Proxmox, Linux | `copia-configs.sh`, executat per un **timer de systemd** a SRV-SERVEIS, amb claus SSH | [`scripts/copies/`](../scripts/copies/) | `systemctl list-timers`, `journalctl -u copia-configs` i `ls -l` al dataset |
| Proxmox (imatges) | Datacenter → Backup: job setmanal `vzdump` cap a `nas-proxmox` | — | Tasks → registre del job |

**Prova d'automatització:** deixar que el timer s'execute sol (o avançar `OnCalendar` a 2 minuts després) i
comprovar al NAS que el fitxer porta la data i l'hora correctes.

---

## Pla de contingència individual: temps observats

| Escenari | Funció afectada | Recurs de recuperació | RTO objectiu | RTO observat | Dades perdudes |
|---|---|---|---|---|---|
| R1 sense NAT ni IP LAN | Internet de la LAN | `r1-backup.backup` del NAS | 15 min | **42 s** | cap (la còpia era de pocs minuts abans) |
| R2 restablert de fàbrica | Internet + DHCP | `config.xml` | 15 min | | |
| R3 sense regles | Internet + filtre | `/etc/nftables.conf` / NAS | 10 min | | |
| Disc RAID fallit | Volum de dades | RAID 1/5 + reconstrucció | 0 (servei continu) | | |
| Node DRBD A caigut | Carpeta replicada | Node B → primari | 5 min | | |
| Configuració de Linux trencada | Servidor | `/etc` del NAS | 20 min | | |
