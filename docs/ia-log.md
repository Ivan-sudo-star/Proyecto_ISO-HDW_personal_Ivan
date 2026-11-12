# Registre d'ús d'IA

L'enunciat permet usar IA si es registra quina proposta s'ha fet, com s'ha contrastat i quina decisió s'ha mantingut, canviat o descartat.
**No s'hi han introduït credencials ni dades personals.**

**Eina:** Claude (Anthropic), en un assistent de terminal sobre el disc de l'entorn. **Data:** 11/11/2026.

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
| 1 | WAN dels routers per NAT de VirtualBox en lloc d'adaptador pont | L'enunciat diu: «No llanceu un DHCP de proves sobre la xarxa compartida». Amb NAT, a més, funciona igual a casa i a classe | Mantinguda / canviada / descartada: ___ |
| 2 | Els tres routers amb la mateixa IP LAN (.1), arrancats d'un en un | Contrastat amb el [repo del grup](https://github.com/varo010/asix-aula-grup-03-ISO), que usa .1, .2 i .3 | **Canviada:** una IP per router, com al grup |
| 2b | 2 nodes Proxmox i el WS2025 com a VM soltes de VirtualBox | Contrastat amb el repo del grup: hi ha 3 nodes, i el WS2025 i els Debian són VM dins dels nodes | **Canviada:** 3 nodes, servidors dins del clúster |
| 3 | TrueNAS amb 8 GB de RAM | Requisit mínim de la documentació de TrueNAS: N/C, cal consultar-lo i provar-ho | ___ |
| 4 | DRBD per a l'espill entre equips, en lloc de Gluster o Ceph | Comparativa a [05](05-raid.md#investigació-i-justificació-a107). Ceph necessita 3 nodes | ___ |
| 5 | Hashes de les ISO | **Contrastat:** `sha256sum -c` contra els fitxers oficials. Debian, Proxmox i TrueNAS coincideixen ([evidència](../evidencias/t5-isos/verificacio.txt)) | Mantinguda (prova feta) |
| 6 | Coll de botella principal = E/S síncrona del SSD USB | **Contrastat amb una mesura:** `dd` amb `dsync` a casa dona 1,7 MB/s, davant dels 359 MB/s en seqüencial | Mantinguda (falta repetir-ho a classe) |
| 7 | Causa de la xarxa de casa a 100 Mb/s: l'altre extrem | **Contrastat:** `ethtool` mostra que el *link partner* només anuncia 10/100 | Mantinguda. Pendent provar un altre port o cable |
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

*(Afegir una fila cada vegada que consulte una IA: abans, la meua predicció i el motiu; després, el contrast i la decisió.)*
