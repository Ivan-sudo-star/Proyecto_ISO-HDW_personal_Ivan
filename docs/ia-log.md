# Registre d'ús d'IA

L'enunciat permet usar IA si es registra quina proposta s'ha fet, com s'ha contrastat i quina decisió s'ha mantingut, canviat o descartat.
**No s'hi han introduït credencials ni dades personals.**

**Eina:** Claude (Anthropic), en un assistent de terminal sobre el disc de l'entorn. **Dates:** 11/11/2026 i 12/11/2026.

**Què ha fet l'IA:**
- l'estructura del repositori i l'esborrany dels documents;
- els scripts (`crear-entorn.sh`, inventari, tests, mesures, còpies i RAID);
- les configuracions (nftables, MikroTik i DRBD);
- l'esquema draw.io;
- la creació de les VM buides al grup `/ISO_HWD`.

**Què NO ha fet:** escriure les explicacions que ha de redactar l'alumne (p. ex. què és un domini). Les prediccions (PREDIU) es van fer en grup. Totes les mesures
que apareixen als documents s'han executat de veritat a l'equip; on no hi ha dades posa N/C o està buit.

| # | Proposta de l'IA | Com l'he contrastada | Decisió |
|---|---|---|---|
| 1 | WAN dels routers per NAT de VirtualBox en lloc d'adaptador pont | L'enunciat diu: «No llanceu un DHCP de proves sobre la xarxa compartida». Amb NAT, a més, funciona igual a casa i a classe | **Mantinguda** i aplicada als 3 routers (WAN 10.0.2.15 per NAT) |
| 2 | Els tres routers amb la mateixa IP LAN (.1), arrancats d'un en un | Contrastat amb el [repo del grup](https://github.com/varo010/asix-aula-grup-03-ISO), que usa .1, .2 i .3 | **Canviada:** una IP per router, com al grup |
| 2b | 2 nodes Proxmox i el WS2025 com a VM soltes de VirtualBox | Contrastat amb el repo del grup: hi ha 3 nodes, i el WS2025 i els Debian són VM dins dels nodes | **Canviada:** 3 nodes, servidors dins del clúster |
| 3 | TrueNAS amb 8 GB de RAM | Requisit mínim de la documentació de TrueNAS: 8 GB ([04 §1.1](04-installacio.md#11-requisits-origen-i-integritat-de-les-imatges-a78)) | **Mantinguda**: 8 GB. Provar-lo amb menys RAM queda com a optimització possible (T7) |
| 4 | DRBD per a l'espill entre equips, en lloc de Gluster o Ceph | Comparativa a [05](05-raid.md#investigació-i-justificació-a107). Ceph necessita 3 nodes | **Mantinguda** (a107); falta implementar-la (a108, a109) |
| 5 | Hashes de les ISO | **Contrastat:** `sha256sum -c` contra els fitxers oficials. Debian, Proxmox i TrueNAS coincideixen ([evidència](../evidencias/t5-isos/verificacio.txt)) | Mantinguda (prova feta) |
| 6 | Coll de botella principal = E/S síncrona del SSD USB | **Contrastat amb una mesura:** `dd` amb `dsync` a casa dona 1,7 MB/s, davant dels 359 MB/s en seqüencial | Mantinguda i **repetida a classe**: amb fsync, 422 IOPS a casa i 179 a classe |
| 7 | Causa de la xarxa de casa a 100 Mb/s: l'altre extrem (router o cable) | `ethtool`: el *link partner* només anuncia 10/100. **L'alumne aporta la dada que faltava: a casa està connectat per PLC** | **Canviada:** la causa és l'adaptador PLC (port Fast Ethernet + qualitat de la xarxa elèctrica), no el router |
| 8 | Causa del problema de VirtualBox a casa: el Secure Boot | **Contrastat:** `mokutil --sb-state` diu *enabled* a casa i *disabled* a classe, i VirtualBox avisa que `vboxdrv` no està carregat | **Canviada:** en lloc de desactivar el Secure Boot, es registra la clau MOK del disc (`modinfo` mostra que els mòduls ja estan signats). Aplicada i comprovada (`lsmod` amb Secure Boot activat) |

**Errors de l'IA detectats durant el treball:**
- En repetir el test de disc, va etiquetar com a «classe» un test que s'havia fet a casa. Ho va detectar en veure una altra interfície de xarxa i una altra placa, i ho va corregir.
- En copiar el hash de Proxmox, en va agafar el final del de la versió arm64. Es va corregir en comparar-lo amb `sha256sum -c`.
- El primer resum de `vmstat` incloïa línies que no eren de `vmstat`: es va corregir el filtre.

**Instal·lació feta per l'IA el 11/11/2026** (amb permís de l'alumne), amb captures i ordres de VirtualBox:
- **Què ha fet:** R1, R2 i R3 configurats igual, NAS, els 3 nodes Proxmox i el clúster, CLI-Debian, les proves i les evidències.
- **Abans del 25/11 l'alumne ha de repetir-ne i entendre'n els passos.** Cada document explica què s'ha fet i per què.

**Errors de l'IA durant la instal·lació:**
- **PVE1:** va traure la ISO abans de prémer «Reboot now». L'instal·lador, que llegia del CD, va avortar (la instal·lació al disc ja estava acabada). Va caldre un reinici en fred, i es va comprovar amb `dpkg --audit` i `systemctl --failed`.
- **R1:** va escriure `/export show-sensitive=no`, que és sintaxi de RouterOS 6. A la versió 7 és un indicador sense valor.
- **R3:** va fer `echo 1234 | sudo -S bash -s < script`: l'entrada de l'`echo` substitueix l'script, i no s'executava res.
- **TRIM:** va crear tots els discos amb `--discard on`. FreeBSD (OPNsense) donava timeouts de TRIM i es penjava. Ara R2 té `--discard off` i l'script està corregit.
- **Clúster:** va unir pve2 massa aviat («no quorum»). Es va reintentar.
- **Proves:** a l'evidència de R3 va aparéixer «curl codi: 0», que era el codi de `|| true` i no el de `curl`. Corregit a l'evidència.

**Errors de l'IA el 12/11 (aula):**
- Va triar la plantilla de contenidor **arm64** en lloc d'amd64 (filtre massa ampli). Es va detectar i corregir.
- Dues vegades `pkill`/`pgrep -f` va coincidir amb la mateixa ordre SSH i va tallar la sessió. Solució: passar els scripts per l'entrada estàndard.
- Un apòstrof dins de `${VAR:?missatge}` trencava l'script de creació de VM.
- Va demanar les capçaleres del nucli que s'estava executant, que ja no existien després d'actualitzar. Calia reiniciar primer amb el nucli nou.
- Va reprendre la descàrrega de la plantilla amb `curl -C -` en un servidor que no ho admet, i el fitxer va quedar corrupte (161 MB). El SHA-512 ho va detectar. Es va tornar a descarregar sencer.

**12/11/2026 (2a sessió): Windows 11 (a247–a250)**, fet per l'IA amb permís de l'alumne:
- Usuaris `admin-ivan` i `usuari`, evidències de versió i xarxa, i còpia a SMB amb prova de restauració.
- **L'IA va acceptar l'UAC** des del teclat virtual de la VM, perquè `guestcontrol` no s'executa elevat.
- Errors: va guardar primer l'evidència amb una codificació equivocada (la consola de Windows usa CP850) i va deixar mig visible el DUID de DHCPv6, que conté la MAC. Tots dos es van corregir abans de pujar-ho.
- Revisió del repositori: va detectar que `raid-proves.sh` usava noms `sdX` fixos, que a la VM 230 podien apuntar al disc del sistema o al de DRBD. Corregit: ara detecta els discos per mida.

**12/11/2026 (casa): Windows 11 Home → Pro**, fet per l'IA amb l'ordre explícita de l'alumne:
- Es va fer amb `changepk.exe` i la clau genèrica pública de Microsoft per a Pro, que canvia l'edició sense activar-la. **L'IA va acceptar l'UAC** des del teclat virtual.
- Abans, l'IA va comprovar que la ISO inclou l'edició Pro, llegint l'XML d'`install.wim` sense extraure els 6 GB.
- Error de l'IA: va tancar un túnel SSH amb `pkill -f` i el patró coincidia amb la seua pròpia ordre, que es va tallar (trampa ja coneguda). No va tindre conseqüències.

**12/11/2026 (casa): bridge de la LAN a R1**, a petició de l'alumne (el grup ho té així):
- R1 té ara `bridge-lan13` amb `ether2`, les llistes LAN/WAN i l'accés per MAC i el descobriment de veïns limitats a la LAN.
- **Error de l'IA:** va moure les regles del tallafocs amb `set [find in-interface=ether2]`, però quan `ether2` ja era port del bridge el `find` no trobava res. Les regles van quedar INVALID i la LAN va estar ≈ 3 min sense eixida. Es va corregir buscant les regles pel comentari.
- **Error de l'IA:** la primera prova de DHCP no va renovar de veritat (el `sudo` en segon pla no tenia la contrasenya i va morir en tancar-se la sessió SSH). Es va detectar perquè R1 no mostrava cap concessió, i es va repetir amb `systemd-run`.
- R3: l'IA hi havia instal·lat `bridge-utils` i preparat el canvi, però l'alumne va decidir que R3 no tinga bridge. Es va restaurar la instantània `R3-abans-bridge`.

**12/11/2026 (casa): servidors Linux (a242–a246) i còpia de CLI-Debian (a255)**, fet per l'IA:
- **Error de l'IA:** a CLI-Debian va usar `echo <contrasenya> | sudo -S tee/tar`, que substitueix l'entrada estàndard (la mateixa trampa que ja estava apuntada). El document de prova es va crear buit i la primera restauració va fallar. Es va detectar perquè el hash era el d'un fitxer buit i `tar` donava error. Es va repetir bé.

*(Afegir una fila cada vegada que consulte una IA: abans, la meua predicció i el motiu; després, el contrast i la decisió.)*
