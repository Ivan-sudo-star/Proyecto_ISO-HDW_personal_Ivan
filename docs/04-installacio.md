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
| OPNsense 26.7 | `OPNsense-26.7-dvd-amd64.iso` | amd64 | pkg.opnsense.org/releases/26.7/OPNsense-26.7-checksums-amd64.sha256 | `1efd5dc9…48d5dcd` | ✅ **Sí** (12/11): el fabricant publica el hash del `.iso.bz2`. Es va tornar a baixar el `.bz2` (hash oficial correcte) i, descomprimit, dona el mateix hash que la ISO instal·lada |
| MikroTik RouterOS 7.24.5 | `mikrotik-7.24.5.iso` | x86 | download.mikrotik.com/routeros/7.24.5/mikrotik-7.24.5.iso.sha256 | `4bff16b8…75aaec02` | ✅ **Sí** (12/11). La **7.25.1** (`c639a897…c2b27480`), usada per actualitzar R1, també coincideix amb el seu `.iso.sha256` oficial |
| Windows 11 | `w11.iso` | x64 | microsoft.com/software-download/windows11 | `5210deed…89119dc8` | ➖ **No verificable**: ISO multiedició es-ES de la 23H2 (compilació base 22621). Microsoft només publica els hashes de la versió actual, i aquest no apareix en cap font pública. Alternativa: l'XML d'`install.wim` és coherent i el sistema instal·lat és 23H2 (22631). Per a una instal·lació nova: baixar la ISO actual i verificar-la |
| Windows Server 2025 | *(falta)* | x64 | Microsoft Evaluation Center | — | ⬜ falta la ISO |

Hashes complets a les evidències ([`verificacio.txt`](../evidencias/t5-isos/verificacio.txt)). **Resum: 5 de 6 ISO verificades contra el fabricant**; la de Windows 11 està justificada i la de Windows Server 2025 es verificarà quan es descarregue.

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
| MikroTik | `/system resource print` | `/system package update check-for-updates` → `install` | ✅ **7.24.5 → 7.25.1** (12/11). Des de RouterOS no es podia (*«Missing license, please buy license to upgrade»*: la llicència x86 de prova no permet actualitzar). Solució: còpia binària `/system backup save` + `/export` (al NAS) → instantània → **reinstal·lació des de la ISO 7.25.1 verificada** (l'instal·lador de la v7 no conserva la configuració) → contrasenya temporal i client DHCP a la WAN per la consola → `scp` de la còpia → `/system backup load`. Resultat: mateixa configuració (bridge, llistes, usuaris, tallafocs), `admin` desactivat i **llicència de prova renovada** (24 h noves). Temps sense servei ≈ 8 min → [`a79-actualitzacions.txt`](../evidencias/t5-isos/a79-actualitzacions.txt) | ✅ client: DHCP, HTTPS 200, SSH bloquejat (`R1-BLOQ-SSH`) |
| OPNsense | Panell | `opnsense-update` o System → Firmware → Updates | ✅ **26.7 → 26.7.9** (12/11): 96 paquets, 298,8 MiB, `base` i `kernel` nous, 4 avisos de seguretat; reinici de 68 s. Instantània prèvia `R2-abans-26.7.9`. Després: «no updates available» → [captures](../evidencias/CAPTURES.md#t5--r2-opnsense-evidències) | ✅ web de gestió; per R2: HTTPS 200 i SSH bloquejat (R2-BLOQ-SSH) |
| Debian (R3, INFRA, RAID, CLI) | `cat /etc/debian_version; uname -r` | `apt update && apt full-upgrade` | ✅ **R3** (12/11): 94 paquets + nucli **6.12.107 → 6.12.116**, instantània prèvia `R3-abans-update`; a més, `vboxadd` fallava (faltaven les capçaleres del nucli i `make`): instal·lats `linux-headers-amd64`, `make` i `gcc`, Guest Additions recompilades → 0 serveis fallits · **VM 220/230**: al dia (0 pendents) · **CLI-Debian**: nucli 6.12.43 → **6.12.116** ([abans](../evidencias/t5-clients/a252-a253-cli-debian.txt), [després](../evidencias/t5-clients/guest-additions.txt)) | `systemctl --failed` buit; R3: HTTPS per la .3 = 200, SSH bloquejat (`NFT-FWD-BLOQ-SSH`) |
| TrueNAS | Dashboard | System → Update | ✅ 25.10.7, **al dia** (`/update/status`: `new_version: null`, tren Goldeye) | pool ONLINE, recurs accessible |
| Proxmox | `pveversion -v` | repositori *no-subscription* + `apt update && apt full-upgrade` | `pve-manager` 9.2.2 → **9.2.26**, nucli → 7.0.14-28 ✅ ([evidència](../evidencias/t5-proxmox/a79-actualitzacio-nodes.txt)) | `pvecm status`, CT arrenca |
| Windows (WS / W11) | `winver` | Windows Update | 🟡 W11 Pro 23H2 (22631.2861): Windows Update ofereix les firmes de Defender i la **25H2**; la 23H2 Pro ja no té suport. **En curs** el 12/11 ([`w11-update.ps1`](../scripts/clients/w11-update.ps1)); instantània prèvia `W11-Pro-23H2` | `Test-NetConnection 192.168.13.1` |

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
✅ **Feta el 12/11:** del prompt `grub>` a sistema funcionant en ≈ **1,5 min** amb `configfile`; després `update-grub` i reinici normal en 35 s. Evidència amb captures: [`incidencia-grub.md`](../evidencias/t5-linux-infra/incidencia-grub.md).

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

Captures (WebFig: bridge, llistes LAN/WAN i tallafocs): [índex de captures](../evidencias/CAPTURES.md#t5--r1-mikrotik-evidències).

| Acció | Estat | Evidència |
|---|---|---|
| a203 instal·lació i versió | ✅ RouterOS **7.24.5 (stable)** x86_64, paquet `system`. **Llicència: sense clau, 24 h de funcionament** (el comptador només avança amb la VM encesa: s'apaga quan no s'usa) | `t5-mikrotik/captures/01-installador-paquets.png`, `02-installacio-completada.png`, `03-llicencia-x86-24h.png`, `a203-versio.txt` |
| a204 usuaris | ✅ `admin-ivan` (grup full) i `suport` (grup `lectura`, només lectura). `admin` **deshabilitat** després de comprovar l'accés amb `admin-ivan` | `a204-usuaris.txt` |
| a205 xarxa | ✅ ether1 WAN 10.0.2.15/24 per DHCP (GW 10.0.2.2), LAN 192.168.13.1/24 (des del 12/11, al **bridge-lan13**, vegeu sota) | `a205-xarxa.txt`, `bridge-r1.txt` |
| a206 Internet per a la LAN | ✅ masquerade + DHCP .100–.200. CLI-Debian i TrueNAS s'han instal·lat descarregant paquets a través de R1 (leases .199 i .200). El NAS fa ping a 1.1.1.1 | `a206-nat-dhcp.txt` |
| a207 permesa/bloquejada | ✅ des de CLI-Debian: `curl https://www.debian.org` → `HTTP/2 200` (registre `R1-FWD-OK ... ->130.89.148.77:443`). `nc github.com 22` → timeout (registre `R1-BLOQ-SSH`: 5 SYN, el primer i 4 retransmissions; comptador de la regla = 5 paquets). Interpretació a l'evidència | `a207-filtre.txt`, `a207-prova-permesa-bloquejada.txt` |
| a208 còpia al NAS | ✅ `/export` (text, sense dades sensibles) + `/system backup save` (binari xifrat) pujats per SFTP a `/mnt/copies/routers/r1/` | `a208-copia-al-nas.txt` |
| a209 fallada i recuperació | ✅ s'esborren la IP de la LAN, el NAT i la còpia local → els clients perden la porta d'enllaç. Recuperació: es torna a posar la IP de la LAN, es baixa `r1-backup.backup` del NAS per SFTP i es fa `/system backup load`. Prova final: CLI-Debian torna a obtindre `HTTP/2 200`. **Temps d'inactivitat: 42 s** | `a209-fallada-recuperacio.txt` |

**Bridge de la LAN (12/11/2026).** Al principi la IP de la LAN, el DHCP i les regles estaven directament al port `ether2`. El grup ho té en un bridge (`bridge_grupo3` amb `ether2`–`ether5`), i és la pràctica recomanada a RouterOS, així que R1 ara té:
- **`bridge-lan13`** amb el port `ether2`. La IP 192.168.13.1/24 i el servidor DHCP són al bridge, no al port.
- **Llistes d'interfícies `LAN` (bridge-lan13) i `WAN` (ether1).** El filtre i el NAT usen les llistes, no noms de port.
- **Descobriment de veïns i accés per MAC (MAC-Telnet/MAC-WinBox) només des de la LAN.**

Per què és millor, encara que a la VM hi haja un sol port de LAN:
- **Seguretat i ordre:** les regles diuen «LAN» i «WAN». Un port nou que s'afegisca al bridge queda protegit per les mateixes regles sense tocar-les, i no queda cap port de la LAN fora del filtre per error.
- **No s'exposa res a la WAN:** l'accés per MAC i el descobriment de veïns ja no responen per `ether1`.
- **Escalable:** més ports o VLAN (`vlan-filtering`) es posen al bridge i hereten la IP i el DHCP. Al hEX físic del grup és el que fa que `ether2`–`ether5` funcionen com un commutador.
- **Mateix disseny que el grup.**

Comprovat: el client renova el DHCP a través del bridge, navega (`R1-FWD-OK ... in:bridge-lan13`) i l'SSH cap a Internet continua bloquejat (`R1-BLOQ-SSH`). Còpia nova al NAS: `routers/r1/export-bridge-*.rsc`. **Incidència:** les regles que apuntaven a `ether2` van quedar *INVALID* en convertir-lo en port del bridge, i la LAN va estar ≈ 3 min sense eixida fins que es van passar a les llistes. Evidència: [`bridge-r1.txt`](../evidencias/t5-mikrotik/bridge-r1.txt). Punt de retorn: instantània `R1-abans-bridge`.

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


### ✅ Resultat R2 (11/11/2026)

Captures (panell, regles de la LAN i registre en viu): [índex de captures](../evidencias/CAPTURES.md#t5--r2-opnsense-evidències).

| Acció | Estat | Evidència |
|---|---|---|
| a210 instal·lació i versió | ✅ OPNsense **26.7** amd64 en UFS (ZFS consumeix massa RAM amb 2 GB). L'instal·lador recomana 3 GB des de la imatge *live*, però amb 2 GB ha funcionat | `t5-opnsense/a210-a214-opnsense.txt` |
| a211 usuaris | ✅ `root` · **`admin-ivan`** (grup admins; s'ha comprovat que pot iniciar sessió a la web) · `suport` (sense privilegis d'administrador). Els mateixos que R1 i R3 | ídem |
| a212 xarxa | ✅ WAN `em0` 10.0.2.15 per DHCP · LAN `em1` **192.168.13.2/24** · sense DHCP propi (el dona el router actiu) | ídem |
| a213 Internet per a la LAN | ✅ Outbound NAT automàtic. `traceroute` del client → 192.168.13.2 → 10.0.2.2 → router de casa · `curl` → `HTTP/2 200` | ídem |
| a214 permesa/bloquejada | ✅ Regles **iguals que a R1 i R3**: seq. 10 *block* tcp/22 amb registre i seq. 20 *pass* amb registre. La regla de fàbrica «Default allow LAN to any» queda desactivada. Registre: `pass em1 ... ->130.89.148.77:443` i `block em1 ... ->20.250.119.67:22` (SYN + retransmissions) | ídem |
| a215 còpia al NAS | ✅ `config.xml` (41 KB, tota la configuració) descarregat per l'API i desat a `/mnt/copies/routers/r2/`. Conté els hash de les contrasenyes: només al NAS | `a215-copia-al-nas.txt` |
| a216 fallada i recuperació | ✅ s'esborren les regles de la LAN → el *default deny* talla tota l'eixida. Es restaura el `config.xml` del NAS (System → Configuration → Backups) → **48 s** fins que el client torna a navegar; després del reinici les regles hi són | `a216-fallada-recuperacio.txt` |

**Problemes trobats:**
1. A l'arrencada *live* va assignar les interfícies al revés (LAN = em0, WAN = em1). Corregit amb l'opció 1 de la consola.
2. Després de canviar la LAN a estàtica, `em1` va continuar amb la IP de DHCP (.197) perquè el client DHCP de quan era WAN seguia en marxa. Resolt amb un reinici (la configuració, `config.xml`, ja tenia la .2).
3. **Timeouts de TRIM** al disc (`DSM TRIM ... Command timeout`, `DELETE ... error = 5`): FreeBSD i el TRIM del controlador AHCI de VirtualBox no s'entenen, i el sistema es penja esperant el disc (la web no responia). Solució: `--discard off` al disc de R2 (aplicat i corregit a `crear-entorn.sh`).

**Requisit del treball: els 3 routers han d'estar configurats igual.** La mateixa política a R1, R2 i R3:
- usuaris d'administració;
- WAN per DHCP i LAN estàtica (.1 / .2 / .3);
- NAT masquerade;
- DHCP .100–.200 només al router actiu;
- DNS reenviat;
- bloqueig de tcp/22 cap a Internet amb registre, i la resta d'eixida permesa amb registre;
- còpia a `/mnt/copies/routers/rN` i prova de fallada.

## 4. R3 · Debian 13 + nftables (a217–a223)

**Configuració:** [`configs/nftables/`](../configs/nftables/) (vegeu-ne el README) · evidències a `evidencias/t5-nftables/`

1. **Instal·lació i versió (a217):** VM `Debian_NFtables` existent. `cat /etc/debian_version`, `uname -r`, `nft --version`, `apt update && apt full-upgrade`.
2. **Usuaris (a218):** `admin-ivan` (sudo) i `suport` (sense privilegis), com a R1 i R2. A `/etc/ssh/sshd_config`: `PermitRootLogin no`. Accés per clau des de SRV-SERVEIS (usuari `copies`, només per a les còpies).
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


### ✅ Resultat R3 (11/11/2026)

| Acció | Estat | Evidència |
|---|---|---|
| a217 instal·lació i versió | ✅ VM existent: Debian **13.7**, nucli 6.12.107, nftables. Tenia **escriptori GNOME**: el router no el necessita (optimització 1 de la T7) | `t5-nftables/a217-a219-versio-usuaris-xarxa.txt` |
| a218 usuaris | ✅ `ivancambra` no era al grup `sudo`: s'hi ha afegit des de la consola com a root (`su -`). SSH instal·lat (`openssh-server`); root sense login SSH per contrasenya (`PermitRootLogin prohibit-password`, valor per defecte) | ídem |
| a219 xarxa | ✅ enp0s3 WAN 10.0.2.15 per DHCP · enp0s8 LAN **192.168.13.3/24** amb ifupdown (NetworkManager deixa de gestionar-la) · `ip_forward=1` | ídem |
| a220 Internet per a la LAN | ✅ CLI-Debian amb porta d'enllaç .3: `traceroute` → 192.168.13.3 → 10.0.2.2 → router de casa; `curl` → `HTTP/2 200` | `a220-a221-prova-permesa-bloquejada.txt` |
| a221 permesa/bloquejada | ✅ `NFT-FWD-OK ... DPT=443` i `NFT-FWD-BLOQ-SSH ... DPT=22` a `journalctl -k`, amb comptadors per regla | ídem |
| a222 còpia al NAS | ✅ `etc-AAAA-MM-DD_HHMM.tgz` (nftables, network, sysctl, dnsmasq) + `ruleset-*.txt` a `/mnt/copies/routers/r3/` | `a222-copia-al-nas.txt` |
| a223 fallada i recuperació | ✅ `nft flush ruleset` + `ip_forward=0` + s'esborra `/etc/nftables.conf` → el client no té Internet. Es restaura des del tgz del NAS, amb `nft -c` abans d'aplicar-lo. **Temps d'inactivitat: 22 s** | `a223-fallada-recuperacio.txt` |

**Problemes trobats:**
1. La WAN (enp0s3) no tenia IP: NetworkManager només tenia perfil per a enp0s8. Resolt passant les dues interfícies a `/etc/network/interfaces`.
2. Des de la consola de VirtualBox, el teclat espanyol de la VM converteix la `/` en `-` i la `|` en `Ç`. Es van escriure les ordres tenint-ho en compte només fins que SSH va funcionar.
3. El DHCP de R3 (`dnsmasq`) queda **instal·lat però desactivat**, perquè el DHCP de la LAN el dona R1. S'activa (`systemctl start dnsmasq`) només en provar R3 amb R1 apagat.


## Comparativa: els 3 servidors de comunicacions configurats igual

| Element | R1 MikroTik | R2 OPNsense | R3 Debian + nftables |
|---|---|---|---|
| Versió | RouterOS **7.25.1** | OPNsense **26.7.9** | Debian 13.7 + nftables (nucli 6.12.116) |
| Administrador / consulta | `admin-ivan` / `suport` (`admin` desactivat) | `admin-ivan` / `suport` (+ `root`) | `admin-ivan` (sudo) / `suport` (+ `ivancambra`) |
| WAN | ether1 · DHCP 10.0.2.15 | em0 · DHCP 10.0.2.15 | enp0s3 · DHCP 10.0.2.15 |
| LAN | **bridge-lan13** (port ether2) · **192.168.13.1/24** | em1 · **192.168.13.2/24** | enp0s8 · **192.168.13.3/24** |
| Bridge a la LAN | ✅ `bridge-lan13` + llistes LAN/WAN | ➖ no (decisió de l'alumne): la LAN es queda a `em1` | ➖ no (decisió de l'alumne): la LAN es queda a `enp0s8` |
| NAT | masquerade srcnat | Outbound NAT automàtic | `masquerade` (taula ip nat) |
| DHCP LAN .100–.200 | ✅ actiu (router principal) | preparat, desactivat | `dnsmasq` preparat, desactivat |
| DNS per a la LAN | `allow-remote-requests` | Unbound | `dnsmasq` |
| Regla de bloqueig | tcp/22 cap a Internet → drop + log | tcp/22 → block + log | tcp/22 → drop + log + counter |
| Eixida permesa | accept + log | pass + log | accept + log + counter |
| Còpia al NAS | `export` + `backup` → `routers/r1` | `config.xml` → `routers/r2` | `etc-*.tgz` + ruleset → `routers/r3` |
| Fallada provocada | s'esborren la IP de LAN, el NAT i la còpia local | s'esborren les regles de LAN | `nft flush` + `ip_forward=0` + s'esborra la config |
| Recuperació (temps) | `backup load` des del NAS (**42 s**) | restauració de `config.xml` (**48 s**) | `tar` des del NAS + `nft -f` (**22 s**) |

Diferències que el disseny accepta: la IP de LAN (.1/.2/.3, com al grup), que el DHCP només està actiu al router principal i que **el bridge de la LAN només és a R1**, que és el router principal (com el MikroTik del grup).

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
   - Datasets: `routers`, `linux`, `proxmox` (NFS per a 192.168.13.0/24, el munten els nodes Proxmox), `windows` i `clients` (SMB).
   - Serveis: SSH (amb SFTP), NFS i SMB.
5. **Equips crítics** que es copien: els 3 routers (sense ells no hi ha xarxa), els nodes Proxmox, el WS2025 (identitats) i el mateix NAS.
6. **Còpia del propi NAS:** System → General → *Manage configuration* → *Download file*, amb el secret seed. Es guarda **fora** del NAS i **fora** del Git.


### ✅ Resultat NAS (11/11/2026)

Captures (panell, pool, datasets, recursos SMB/NFS i usuaris): [índex de captures](../evidencias/CAPTURES.md#t5--nas-truenas-evidències).

| Acció | Estat | Evidència |
|---|---|---|
| a224 instal·lació i versió | ✅ TrueNAS SCALE **25.10.7**, instal·lat **només** al disc de 20 GiB (`boot-pool` a `sda`) | `t5-truenas/captures/01-disc-installacio-sda.png`, `02-installacio-completada.png`, `a224-a227-truenas.txt` |
| a225 usuaris | ✅ `truenas_admin` (administrador, creat a l'instal·lador; el login de root amb contrasenya queda desactivat) i `copies` (uid 3000, **sense** privilegis d'administrador, home `/mnt/copies/usuaris/copies`) | `t5-truenas/a224-a227-truenas.txt` |
| a226 xarxa | ✅ enp0s3 **192.168.13.20/24** estàtica (sense DHCP), GW i DNS 192.168.13.1, nom `nas13.lan13.local`. Canvi aplicat amb *commit* i *checkin* (si no es confirma en 120 s, TrueNAS torna sol a la configuració anterior) | ídem |
| a227 disc addicional | ✅ pool **`copies`** (stripe, 48 GB útils) sobre el disc de 50 GiB · datasets `routers` (r1, r2, r3), `linux`, `proxmox` (NFS per a 192.168.13.0/24), `windows` i `clients` (SMB) · propietari `copies`, permisos 770 · serveis SSH/SFTP, NFS i SMB actius | ídem (exportat per l'API el 12/11) |
| Web de gestió només per HTTPS (12/11) | ✅ En fer les captures es va veure que el panell s'usava per **HTTP** (sense xifrar: la contrasenya de `truenas_admin` viatjava en clar per la LAN). S'ha activat **«Web Interface HTTP → HTTPS Redirect»** (`ui_httpsredirect: true` per l'API + reinici de la web): ara `http://192.168.13.20` respon **307 → https**. TLS 1.2 i 1.3; certificat autofermat `truenas_default` | `t5-truenas/captures/08-gui-https-redireccio.png` |

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
   - `ivan@pam` (usuari Linux del node, perquè el *realm* `pve` exigeix 8 caràcters): `pveum user add ivan@pam` i `pveum acl modify / -user ivan@pam -role Administrator`.
   - Usuari de consulta: rol `PVEAuditor`.
3. **Xarxa (a230):** `/etc/network/interfaces` amb `vmbr0` sobre `nic0` (exemple a [03 §2](03-xarxa.md#2-configuració-de-cada-interfície-a148)). Comprovar `ip a` i `bridge link`.
4. **Clúster (a232):**
   - PVE1: `pvecm create cluster13`. PVE2 i PVE3 s'uneixen per l'API, sense haver d'escriure la contrasenya de manera interactiva:
     `pvesh create /cluster/config/join --hostname 192.168.13.32 --fingerprint <empremta de pve-ssl.pem> --password <...>`
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

   - Debian més ràpid: importar `debian-13-generic-amd64.qcow2` amb `qm importdisk` en lloc de la netinst (la variant `genericcloud` ja no existeix: 404).
   - CT: `pveam download local debian-13-standard_*.tar.zst` i després `pct create 100 local:vztmpl/... --memory 512 --rootfs local-lvm:4 --net0 name=eth0,bridge=vmbr0,ip=192.168.13.41/24,gw=192.168.13.1`.
7. **Migració (a235) i mesures (a236)** — la VM migrada és **SRV-SERVEIS**, una Debian sense entorn gràfic, com demana la rúbrica:

   | Migració | Ordre | Temps | Espai ocupat | Observacions |
   |---|---|---|---|---|
   | CT 100 PVE2⇄PVE3 | `time pct migrate 100 pve3 --restart` | **87,6 s** i 113,6 s | `pct df 100` / `du` | Els CT no es poden migrar en calent: es reinicien |
   | VM 220 PVE2→PVE3 (disc local) | `time qm migrate 220 pve3 --online --with-local-disks` | ❌ falla als 5 min 47 s | `qm config 220`, `lvs` | Es copia el disc sencer i omple el thin pool de destí |
   | VM 220 amb el disc al NFS | `time qm migrate 220 pve3 --online` | **8,5 s**, 50 ms de tall | 581 MiB de RAM | Només es copia la RAM |

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


### ✅ Resultat Proxmox (11/11/2026)

Captures (clúster amb 3 nodes, VM i CT, còpia programada, NFS i còpies `vzdump`): [índex de captures](../evidencias/CAPTURES.md#t5--proxmox-evidències).

| Acció | Estat | Evidència |
|---|---|---|
| a228 instal·lació i versió | ✅ 3 nodes amb l'instal·lador en mode text: ext4/LVM-thin, Europe/Madrid, teclat US. `pve-manager` 9.2.2 → **9.2.26** després d'actualitzar | `t5-proxmox/captures/01..03-*-resum-installacio.png`, `a79-actualitzacio-nodes.txt` |
| a229 usuaris | ✅ `root@pam` · **`ivan@pam`** (rol Administrator a `/`) · `consulta@pve` (rol PVEAuditor). El *realm* `pve` exigeix 8 caràcters com a mínim, per això l'administrador és un usuari PAM (Linux) | `t5-proxmox/a229-usuaris.txt` |
| a230 xarxa | ✅ `vmbr0` amb IP fixa sobre **`nic0`** (Proxmox 9 «fixa» els noms de les targetes), GW i DNS .1, `/etc/hosts` correcte als 3 nodes | `t4-xarxa/ifaces-rutes-pve{1,2,3}.txt` |
| a232 clúster | ✅ **`cluster13`**: 3 nodes, 3 vots, quòrum 2, `Quorate: Yes` | `a232-cluster.txt` |
| a79 actualització | ✅ repositori *enterprise* desactivat i *no-subscription* activat; 211 paquets actualitzats; nucli 7.0.2-6 → **7.0.14-28**; 0 serveis fallits després de reiniciar | `a79-actualitzacio-nodes.txt` |
| Emmagatzematge compartit | ✅ `nas-proxmox` (NFS del NAS, `/mnt/copies/proxmox`, 47 GB) visible als 3 nodes. Contingut: imatges, plantilles, còpies i *import* | — |
| VM 220 i 230 | ✅ creades amb [`scripts/proxmox/crea-vm-debian.sh`](../scripts/proxmox/crea-vm-debian.sh) a partir de la imatge oficial `debian-13-generic-amd64.qcow2` (**SHA-512 verificat** amb `SHA512SUMS`) + cloud-init (usuari `ivancambra`, IP fixa, clau SSH, actualització al primer arrencada). SRV-SERVEIS a PVE2 (.22, 10 + 2 GB) i SRV-DADES a PVE3 (.23, 10 + 5×1 + 2 GB) | `a232-quorum-amb-un-node-apagat.txt` |
| CT 100 | ✅ `ct-prova` (Debian 13.6, sense privilegis, 512 MB, 4 GB) a PVE2, IP .41. Plantilla oficial verificada amb SHA-512 | — |
| a235 migració | ✅ **CT 100** PVE2⇄PVE3 (mode restart: 87,6 s i 113,6 s) · **VM 220** (Debian sense GUI) PVE2⇄PVE3 **en calent** | `a235-a236-migracio.txt` |
| a236 temps i espai | ✅ amb discs locals la migració de la VM **falla**: el mirror escriu els 10 GB sencers i omple el thin pool de destí (11,4 GB). Amb el disc a l'**NFS compartit**: **8,5 s i 50 ms de tall**, i només es copien 581 MiB de RAM. El disc ocupa 631 MB reals de 10 GB. Millores documentades | ídem |
| a231 còpies | ✅ `vzdump` de CT 100 (204 MB), VM 220 (444 MB) i VM 230 (437 MB) al NAS, més la configuració dels nodes (`/etc/pve`, xarxa, hosts, corosync). Justificació de què es copia i què no. El CT sense privilegis necessita `--tmpdir` local en NFS | `a231-copies-proxmox.txt` |

**Problemes trobats:**
0. **12/11, a l'aula:** les descàrregues es quedaven penjades (connexió HTTP establerta sense dades) i la imatge `genericcloud` ja no existeix (404): s'usa `generic`. Solució: `wget -c` i `apt` amb `Acquire::http::Timeout=30` i reintents.
1. **Contrasenya de root de 8 caràcters com a mínim** a l'instal·lador. S'instal·la amb una de 8 i després es canvia amb `chpasswd`.
2. **Teclat espanyol** a l'instal·lador i teclat virtual US de VirtualBox: es tria «U.S. English».
3. **Error meu a PVE1:** vaig traure la ISO abans de prémer «Reboot now» i l'entorn de l'instal·lador, que llegia del CD, va avortar amb errors d'E/S. La instal·lació al disc ja havia acabat: un reinici en fred i les comprovacions (`dpkg --audit`, `systemctl --failed`) ho confirmen. A PVE2 i PVE3: reiniciar amb la ISO posada, apagar i després traure-la.
4. **pve2 no es podia unir al clúster** («cluster not ready - no quorum?») perquè es va intentar just en crear-lo. Reintentat quan el clúster ja tenia quòrum: ✅.

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
2. **Usuaris (a243):** `ivancambra` (creat per cloud-init, sudo, només amb clau SSH) i, com a la resta d'equips, `admin-ivan` (sudo) i `suport`. Root sense login SSH. A SRV-SERVEIS, a més, l'usuari de servei `copies` (sense sudo, amb clau SSH).
3. **Xarxa (a244):** estàtica, `eth0` amb la imatge cloud, configurada per cloud-init (exemple a [03 §2](03-xarxa.md#2-configuració-de-cada-interfície-a148)). Comprovar amb `ip a`, `ip route` i `cat /etc/resolv.conf`.
4. **Funció i programari (a246):** l'enunciat diu que, de moment, no s'ha d'instal·lar programari addicional. Només el que necessiten les còpies i les proves:
   - SRV-SERVEIS: `rsync` i `openssh`, per orquestrar les còpies.
   - SRV-DADES: `mdadm`, per al RAID.
   - Tots dos: `drbd-utils`, per a la T6.
5. **Còpia (a245):** `/etc` i la llista de paquets (`dpkg --get-selections`), amb `copia-configs.sh`. A més, `vzdump` de la VM sencera.
   - Restaurar: reinstal·lar, fer `dpkg --set-selections` i `apt-get dselect-upgrade`, i descomprimir `/etc`.
   - **Què NO:** `/usr`, `/var/cache` i els discos de prova del RAID (són dades fictícies).

### ✅ Resultat servidors GNU/Linux (12/11/2026, equip de casa)

Configuració aplicada amb [`scripts/proxmox/infra-config.sh`](../scripts/proxmox/infra-config.sh) a les dues VM.

| Acció | Estat | Evidència |
|---|---|---|
| a242 instal·lació i versió | ✅ Debian **13.7**, nucli 6.12.116, des de la imatge cloud oficial (SHA-512 verificat). 0 paquets pendents, 0 serveis fallits, Internet per R1 | `t5-linux-infra/a242-a246-srv-serveis.txt`, `a242-a246-srv-dades.txt` |
| a243 usuaris | ✅ `ivancambra` (cloud-init), **`admin-ivan`** (sudo) i **`suport`** (sense sudo), igual que als routers. SSH **només amb clau**: root i contrasenyes rebutjats (`/etc/ssh/sshd_config.d/10-lloc13.conf`, comprovat des de fora) | ídem |
| a244 xarxa | ✅ `eth0` amb IP fixa (.22 / .23) per cloud-init (netplan), GW i DNS .1, sufix `lan13.local` | ídem |
| a246 programari | ✅ Cap servei addicional, com diu l'enunciat. Només `qemu-guest-agent`, perquè Proxmox apague bé la VM, en veja la IP i congele el disc a les còpies (`qm agent ping` = OK). `mdadm` i `drbd-utils` s'instal·len a la T6 | ídem |
| a245 còpia | ✅ `/etc` + llista de paquets de cada servidor a `NAS:/mnt/copies/linux/<servidor>/` (verificat amb `sha256sum -c`), més el `vzdump` de la VM (a231). **Prova:** s'esborra la configuració SSH de srv-dades (root tornava a entrar) i es recupera del NAS en **2,8 s**, amb el mateix hash | `t5-linux-infra/a245-copies-linux.txt` |

## 9. Clients (a247–a250, a252–a255)

Evidències a `evidencias/t5-clients/`. Captures: [índex de captures](../evidencias/CAPTURES.md#t5--clients-evidències).

| | Windows 11 (`Cliente_windows_1`, existent) | GNU/Linux (`CLI-Debian`) |
|---|---|---|
| Instal·lació i versió (a247/a252) | ✅ **Windows 11 Pro 23H2** (era Home; canviada a Pro el 12/11, vegeu sota), compilació 22631, 64 bits. UEFI, **Secure Boot actiu** i **TPM 2.0 preparat** (llegits des d'un PowerShell elevat). Serveis automàtics aturats: només `edgeupdate`, `MapsBroker` i `sppsvc` (és normal que estiguen parats). Internet: HTTPS 200 | ✅ Debian 13 (trixie) + **GNOME** 48: fa d'equip de gestió amb Firefox per a les webs de la LAN13 ([03 §5](03-xarxa.md#5-accés-de-gestió-a-les-webs-de-la-lan13)). 0 serveis fallits, Internet HTTP/2 200 |
| Usuaris (a248/a253) | ✅ `admin-ivan` (Administradors, el mateix nom que als routers) i `usuari` (Usuaris, estàndard: és el compte de treball diari). `Ivan` és el compte de la instal·lació i també és administrador. L'`Administrador` integrat i `Invitado` estan desactivats. UAC actiu (`EnableLUA=1`). Script: `scripts/clients/w11-usuaris.ps1` | ✅ `ivancambra` i **`admin-ivan`** (grup `sudo`) · **`usuari`** (sense sudo, compte de treball) · `root` amb contrasenya (només `su`) |
| Xarxa (a249/a254) | ✅ Per DHCP de R1: **192.168.13.199/24**, GW .1, DNS .1, sufix `lan13.local`. Ping a la GW correcte, el DNS resol, port 445 del NAS obert | ✅ DHCP de R1 ([evidència](../evidencias/t4-xarxa/ifaces-rutes-cli-debian.txt)) |
| Còpia (a250/a255) | ✅ `scripts/copies/copia-w11.ps1`: `robocopy /MIR` cap a `\\192.168.13.20\clients\w11` amb l'usuari `copies`. **Es copien:** `config\` (ipconfig, configuració IP, usuaris, aplicacions instal·lades i versió, per poder reconstruir el client) i `dades\<usuari>\Documents` i `Desktop` (el que és únic de cada usuari). **No es copien:** la imatge sencera, `C:\Windows`, `Program Files` ni `AppData\Local` (memòria cau). Un client es reinstal·la des d'una imatge estàndard i les aplicacions es tornen a instal·lar a partir de la llista. **Prova de restauració:** s'esborra `prova-copia-w11.txt`, es recupera del NAS i el SHA-256 coincideix. També s'ha comprovat amb `ls -lR` al NAS | ✅ `/home` (sense memòries cau), `/etc` i la llista de paquets a `NAS:/mnt/copies/clients/cli-debian/` (25 MB). **No:** el sistema ni les aplicacions, que es reinstal·len. **Prova:** es recupera un document esborrat de `usuari` amb el mateix hash i propietari (4,8 s) → [`a255-cli-debian-copia.txt`](../evidencias/t5-clients/a255-cli-debian-copia.txt) |
| Domini | ➖ a251 desactivada a la rúbrica. L'enunciat deixa la implantació del domini per a RA4/RA5 d'ISO; el disseny del grup preveu unir els clients al domini amb **Windows 11 Pro**. Home no es pot unir a un domini: per això s'ha passat a **Pro** | ➖ a256 desactivada; al disseny, unió a AD amb SSSD/realmd en fases posteriors |

**Windows 11 Home → Pro (fet el 12/11/2026).** La ISO és multiedició i inclou Pro, així que no cal reinstal·lar.
Es fa el canvi d'edició *in situ* amb la clau genèrica de Microsoft per a Pro (`changepk.exe /ProductKey <clau genèrica>`):
només canvia l'edició, no activa el sistema (per activar-lo caldria una llicència, p. ex. la del centre). Es conserven els usuaris, la xarxa i les dades.
Punt de retorn: instantània de VirtualBox `W11-Home-a250-ok`.

**Resultat:** després del reinici automàtic, `Microsoft Windows 11 Pro` 23H2 (22631), `slmgr /dli` → *Professional edition*, estat «notificació» (sense activar). Els usuaris, la xarxa (.199, GW i DNS .1), l'accés SMB al NAS i Internet continuen igual → [`a247-w11-pro.txt`](../evidencias/t5-clients/a247-w11-pro.txt). Per activar-lo caldria una llicència de Pro; el sistema funciona igual sense activar (només mostra l'avís).

**Evidències W11 (12/11):** `a247-a249-w11.txt` i `a250-w11-copia.txt`. `guestcontrol` s'executa sense elevar (UAC), de manera que les accions d'administrador (usuaris, Secure Boot, TPM) es van fer obrint un PowerShell elevat a la consola i acceptant l'UAC.

**Guest Additions als clients (12/11):** CLI-Debian amb les 7.2.18 compilades per al nucli nou (cal reiniciar amb el nucli nou abans d'instal·lar les capçaleres). Windows 11 ja les tenia (7.2.18). Totes dues VM tenen el porta-retalls i l'arrossegar i deixar anar bidireccionals → `evidencias/t5-clients/guest-additions.txt`.

## 10. Apte+: còpies automatitzades (a105)

| Equip | Mecanisme | Fitxer | Prova |
|---|---|---|---|
| R1 MikroTik | `/system scheduler` diari + script `copia-nas` (SFTP) | [`r1-scheduler-copia.rsc`](../configs/mikrotik/r1-scheduler-copia.rsc) | `/system script run copia-nas` → el fitxer apareix a `/mnt/copies/routers/r1` |
| R2, R3, Proxmox, Linux | `copia-configs.sh`, executat per un **timer de systemd** a SRV-SERVEIS, amb claus SSH | [`scripts/copies/`](../scripts/copies/) | `systemctl list-timers`, `journalctl -u copia-configs` i `ls -l` al dataset |
| Proxmox (imatges) | Datacenter → Backup: job setmanal `vzdump` cap a `nas-proxmox` | — | Tasks → registre del job |

**Prova d'automatització:** deixar que el timer s'execute sol (o avançar `OnCalendar` a 2 minuts després) i
comprovar al NAS que el fitxer porta la data i l'hora correctes.

### ✅ Resultat a105 (12/11/2026)

| Part | Estat | Evidència |
|---|---|---|
| **Imatges de les VM i el CT** | ✅ **Automàtica.** Tasca de clúster `copia-setmanal` (Datacenter → Backup): diumenge 03:00, VM 220, VM 230 i CT 100 → `nas-proxmox`, mode snapshot, zstd, **es guarden les 3 últimes** (`keep-last=3`). Prova: horari avançat a les 16:19 → el planificador la va llançar sol als dos nodes i va acabar bé (CT 203 MB, VM 220 492 MB, VM 230 537 MB). Després es va tornar a posar el diumenge | [`a105-copia-automatica-vzdump.txt`](../evidencias/t5-proxmox/a105-copia-automatica-vzdump.txt) |
| **Configuracions (orquestrador)** | 🟡 **Instal·lat però sense activar.** `copia-configs.sh` + `copia-configs.service/.timer` instal·lats a SRV-SERVEIS amb l'usuari de servei `copies` (clau SSH pròpia). **Falta repartir la clau pública** als equips (nodes, servidors, R1 i NAS): el repartiment de claus amb accés permanent s'ha de fer amb l'autorització de l'alumne | — |

**Correcció de seguretat a l'script (12/11):** la rotació antiga feia `find /mnt/copies/proxmox -mtime +14 -delete`. En aquest directori hi ha **els discos de les VM** (`images/220`) i els `vzdump`, així que podia esborrar el disc d'una VM aturada. Ara només esborra fitxers `*-auto-*` creats pel mateix script, i només a `routers/` i `linux/`; la configuració dels nodes Proxmox va a `linux/<node>/`. A R1 l'script entra amb un usuari `copies` de **només lectura** (grup `lectura`, limitat a la IP de SRV-SERVEIS) en lloc d'`admin-ivan`.

---

## Pla de contingència individual: temps observats

| Escenari | Funció afectada | Recurs de recuperació | RTO objectiu | RTO observat | Dades perdudes |
|---|---|---|---|---|---|
| R1 sense NAT ni IP LAN | Internet de la LAN | `r1-backup.backup` del NAS | 15 min | **42 s** | cap (la còpia era de pocs minuts abans) |
| R2 sense regles de LAN | Internet | `config.xml` del NAS | 15 min | **48 s** | cap |
| R3 sense regles | Internet + filtre | `etc-*.tgz` del NAS | 10 min | **22 s** | cap |
| Disc RAID fallit | Volum de dades | RAID 1/5 + reconstrucció | 0 (servei continu) | **0 s** (reconstrucció 8–12 s) | cap |
| Node DRBD A caigut | Carpeta replicada | Node B → primari | 5 min | **7,3 s** | cap (protocol C) |
| Configuració de Linux trencada | Servidor | `/etc` del NAS | 20 min | **2,8 s** (un fitxer) | cap |
