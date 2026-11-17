# 03 · Tasca 4 — Esquema de xarxa individual (ISO RA1 · a128, a148, a129, a149)

**Lloc a l'aula: 31 → LAN `192.168.31.0/24`.** La WAN dels routers rep la IP per DHCP del NAT de VirtualBox.
L'adreçament segueix el del [grup 3](https://github.com/varo010/asix-aula-grup-03-ISO/blob/main/docs/04-disseny.md)
(xarxa 192.168.30.0/24): mateixos rangs i mateixos últims octets, però amb el meu tercer octet, **31**.

![Esquema](../diagrames/xarxa-individual-lloc31.png)

Font editable: [`diagrames/xarxa-individual-lloc31.drawio`](../diagrames/xarxa-individual-lloc31.drawio) (draw.io).
Es regenera amb [`scripts/vbox/genera-diagrama.py`](../scripts/vbox/genera-diagrama.py).

## 1. Rangs i decisions de disseny

| Rang | Ús (igual que al grup) |
|---|---|
| .1 – .15 | Servidors de comunicacions (R1 .1 · R2 .2 · R3 .3) |
| .16 – .99 | Servidors i serveis amb IP fixa (NAS .20 · WS2025 .21 · serveis .22 · dades .23 · nodes .32–.34 · CT .41) |
| .100 – .200 | Clients per DHCP |
| .201 – .254 | Reserva |

| Decisió | Opcions | Escollida | Per què |
|---|---|---|---|
| Tipus de xarxa per a la WAN | Pont · NAT · Xarxa NAT | **NAT** | No llance res sobre la xarxa compartida de l'aula (172.16.222.0/24) ni sobre la de casa: no hi ha risc de DHCP fals ni de conflictes d'IP. A més, funciona igual als dos equips, encara que tinguen xarxes diferents |
| Tipus de xarxa per a la LAN | Només amfitrió · Xarxa interna | **Xarxa interna `LAN31`** | Aïllada de l'amfitrió i de la xarxa física: l'única eixida és el router. Així es demostra que el filtre funciona |
| IP dels tres routers | La mateixa · una per router | **Una per router (.1, .2, .3)**, com al grup | Poden conviure encesos sense conflicte d'IP. R1 (MikroTik) és la porta d'enllaç principal dels servidors. Quan es prova R2 o R3, el client rep la porta d'enllaç del router actiu per DHCP |
| DHCP | A tots els routers · només a un | **Només a l'actiu** | Dos DHCP a la mateixa LAN es contradiuen. Abans de provar R2 o R3, s'apaga R1 (o se'n desactiva el DHCP) |
| Assignació | Tot estàtic · tot DHCP | **Servidors estàtics, clients per DHCP** (.100–.200) | Els servidors necessiten adreça fixa per a les còpies i la gestió |
| DNS | Públic directe · router | **El router** reenvia a 1.1.1.1 / 9.9.9.9. **Des del 16/11, les consultes del domini `ivan-cambra-31.lan` R1 les reenvia al DC (.21)** | Un sol punt de configuració. El grup usa el DNS del centre (172.16.222.1), però amb el NAT de VirtualBox no el necessite. Amb el reenviament condicional, els clients troben el domini sense canviar el DHCP i Internet no depén del servidor Windows |

## 2. Configuració de cada interfície (a148)

Màscara a tota la LAN: **255.255.255.0 (/24)**. La xarxa NAT de VirtualBox és 10.0.2.0/24, amb GW 10.0.2.2 i DNS 10.0.2.3.

| Equip | Nivell | Adaptador | Tipus de xarxa | Interfície (SO) | IP / màscara | Porta d'enllaç | DNS | Mètode |
|---|---|---|---|---|---|---|---|---|
| R1-MikroTik | VirtualBox | 1 | NAT | ether1 (WAN) | 10.0.2.15/24 | 10.0.2.2 | 10.0.2.3 | DHCP |
| | | 2 | Interna LAN31 | **bridge-lan31** (port ether2) | **192.168.31.1/24** | — | — | estàtica · servidor DHCP (al bridge) |
| R2-OPNsense | VirtualBox | 1 | NAT | em0 (WAN) | 10.0.2.15/24 | 10.0.2.2 | 10.0.2.3 | DHCP |
| | | 2 | Interna LAN31 | em1 (LAN) | **192.168.31.2/24** | — | — | estàtica |
| R3 Debian_NFtables | VirtualBox | 1 | NAT | enp0s3 (WAN) | 10.0.2.15/24 | 10.0.2.2 | 10.0.2.3 | DHCP |
| | | 2 | Interna LAN31 | enp0s8 (LAN) | **192.168.31.3/24** | — | — | estàtica |
| NAS-TrueNAS | VirtualBox | 1 | Interna LAN31 | enp0s3 | 192.168.31.20/24 | 192.168.31.1 | 192.168.31.1 | estàtica |
| SRV-WS2025 | VirtualBox (des del 16/11; abans VM 210 de PVE1) | 1 (virtio-net) | Interna LAN31 | Ethernet 2 | 192.168.31.21/24 | 192.168.31.1 | **127.0.0.1** i 192.168.31.1 (és el DC de `ivan-cambra-31.lan` des del 16/11) | estàtica |
| PVE1-Proxmox | VirtualBox | 1 (promiscu) | Interna LAN31 | vmbr0 (sobre nic0) | 192.168.31.32/24 | 192.168.31.1 | 192.168.31.1 | estàtica |
| PVE2-Proxmox | VirtualBox | 1 (promiscu) | Interna LAN31 | vmbr0 (sobre nic0) | 192.168.31.33/24 | 192.168.31.1 | 192.168.31.1 | estàtica |
| PVE3-Proxmox | VirtualBox | 1 (promiscu) | Interna LAN31 | vmbr0 (sobre nic0) | 192.168.31.34/24 | 192.168.31.1 | 192.168.31.1 | estàtica |
| ↳ 220 SRV-SERVEIS | Proxmox (PVE2) | net0 (virtio) | vmbr0 | eth0 | 192.168.31.22/24 | 192.168.31.1 | 192.168.31.1 | estàtica |
| ↳ 230 SRV-DADES | Proxmox (PVE3) | net0 (virtio) | vmbr0 | eth0 | 192.168.31.23/24 | 192.168.31.1 | 192.168.31.1 | estàtica |
| ↳ CT 100 | Proxmox (PVE2) | net0 | vmbr0 | eth0 | 192.168.31.41/24 | 192.168.31.1 | 192.168.31.1 | estàtica |
| CLI-Debian | VirtualBox | 1 | Interna LAN31 | enp0s3 | 192.168.31.100–200/24 | la del router actiu (.1 / .2 / .3) | ídem | DHCP |
| Cliente_windows_1 | VirtualBox | 1 | Interna LAN31 | Ethernet | 192.168.31.100–200/24 | la del router actiu | ídem | DHCP |
| Amfitrió (classe) | físic | — | física | eno1 | 172.16.222.40/24 | N/C | N/C | DHCP de l'aula |
| Amfitrió (casa) | físic | — | física | enp7s0 | 192.168.1.86/24 | 192.168.1.1 | N/C | DHCP del router de casa |

Exemple de configuració estàtica Debian. A SRV-SERVEIS i SRV-DADES l'aplica **cloud-init** des de Proxmox (`--ipconfig0`); la imatge cloud anomena la targeta `eth0`:
```
auto eth0
iface eth0 inet static
    address 192.168.31.22/24
    gateway 192.168.31.1
    dns-nameservers 192.168.31.1
```

Configuració real del node PVE2 (`/etc/network/interfaces`). Proxmox 9 «fixa» el nom de la targeta com a `nic0`, igual que al grup ([evidència](../evidencias/t4-xarxa/ifaces-rutes-pve2.txt)):
```
auto lo
iface lo inet loopback
iface nic0 inet manual
auto vmbr0
iface vmbr0 inet static
    address 192.168.31.33/24
    gateway 192.168.31.1
    bridge-ports nic0
    bridge-stp off
    bridge-fd 0
```

## 3. Camí del trànsit

```
SRV-WS2025 (192.168.31.21) ────────────────────────────────► LAN31 ─► R1 192.168.31.1
SRV-SERVEIS / SRV-DADES (.22/.23) ─net0─► vmbr0 del node ─► LAN31 ─► R1 192.168.31.1
CLI-Debian (192.168.31.10x) ──────────────────────────────► LAN31 ─► router actiu (.1 / .2 / .3)
   router: filtre forward (es permet LAN→WAN excepte tcp/22) + NAT masquerade (origen → 10.0.2.15)
   ─WAN 10.0.2.15─► NAT VirtualBox 10.0.2.2 ─► NIC física (eno1 / enp7s0) ─► router de l'aula/casa ─► Internet
```
- Les VM niuades surten per la NIC del node gràcies al bridge `vmbr0` i a la NIC de VirtualBox en mode promiscu.
- El retorn passa per l'estat de connexió (`established,related`).
- Des d'Internet **no** es pot iniciar res cap a la LAN: hi ha doble NAT (router + VirtualBox) i el router descarta l'entrada per la WAN.

## 4. Implementació i comprovació (Apte+ · a129, a149)

Evidències a `evidencias/t4-xarxa/`. Cada fitxer acaba amb una interpretació del que demostra.

| Prova | Ordre | Des de → cap a | Resultat esperat | Estat i fitxer |
|---|---|---|---|---|
| Configuració d'interfícies i taula d'encaminament | `ip a` + `ip route` · `/ip address print` + `/ip route print` · `ipconfig /all` | cada equip | IP, màscara i estat UP; `default via 192.168.31.1` (routers: `via 10.0.2.2`) | ✅ [R1](../evidencias/t4-xarxa/ifaces-rutes-r1.txt) · [NAS](../evidencias/t4-xarxa/ifaces-rutes-nas.txt) · [PVE1](../evidencias/t4-xarxa/ifaces-rutes-pve1.txt) · [PVE2](../evidencias/t4-xarxa/ifaces-rutes-pve2.txt) · [PVE3](../evidencias/t4-xarxa/ifaces-rutes-pve3.txt) · [CLI-Debian](../evidencias/t4-xarxa/ifaces-rutes-cli-debian.txt) · [W11](../evidencias/t5-clients/a247-a249-w11.txt) |
| Ping dins la LAN | `ping -c3` a .1, .20, .32, .33, .34 | CLI-Debian → R1, NAS, nodes | 0 % pèrdua, < 1 ms | ✅ [`ping-lan-i-internet.txt`](../evidencias/t4-xarxa/ping-lan-i-internet.txt) |
| Ping a una VM niuada | `ping -c4 192.168.31.22` (i .23, .21) | CLI-Debian → VM dins dels nodes | resposta: el bridge funciona | ✅ 16/11: des de PVE2, `ping` al WS2025 (.21, ara VM de VirtualBox) 0 % de pèrdua; les VM niuades .22/.23 es gestionen per SSH a través del bridge ([a242–a246](../evidencias/t5-linux-infra/)) |
| Ping a la porta d'enllaç des de Windows | `Test-Connection 192.168.31.1` | W11 → R1 | resposta | ✅ [`a247-a249-w11.txt`](../evidencias/t5-clients/a247-a249-w11.txt) |
| Eixida a Internet | `ping -c3 1.1.1.1` · `curl -I https://debian.org` | CLI-Debian | resposta | ✅ [`ping-lan-i-internet.txt`](../evidencias/t4-xarxa/ping-lan-i-internet.txt) |
| Resolució DNS i traceroute | `dig +short debian.org @192.168.31.1` · `traceroute -n 1.1.1.1` | CLI-Debian | IP resolta pel router · salt 1 = 192.168.31.1, salt 2 = 10.0.2.2 | ✅ [`traceroute-dns-cli-debian.txt`](../evidencias/t4-xarxa/traceroute-dns-cli-debian.txt) |
| **Prova que falla a propòsit** | `nc -zv -w5 github.com 22` | CLI-Debian | timeout + línia `BLOQ-SSH` al registre del router | ✅ [`a207-prova-permesa-bloquejada.txt`](../evidencias/t5-mikrotik/a207-prova-permesa-bloquejada.txt) (també R2 i R3 a 04) |
| Aïllament | `ping -c3 192.168.31.20` i `ip route get 192.168.31.20` | amfitrió → NAS | **falla**: l'amfitrió (i, per tant, l'aula) no té cap ruta cap a LAN31; només s'hi entra a través del router | ✅ [`aillament-amfitrio.txt`](../evidencias/t4-xarxa/aillament-amfitrio.txt) |

## 5. Accés de gestió a les webs de la LAN31

L'amfitrió no veu la LAN31: és una xarxa interna i només s'hi entra a través del router (vegeu la prova d'aïllament).
**Decisió: la gestió es fa des de dins, amb CLI-Debian** com a «equip d'informàtica» de la LAN (escriptori GNOME + Firefox):

| Servei | Adreça des de CLI-Debian | Usuari |
|---|---|---|
| Proxmox (clúster `cluster31`) | `https://192.168.31.32:8006` (o `.33`, `.34`) | `ivan`, *realm* Linux PAM |
| TrueNAS | `https://192.168.31.20` | `truenas_admin` |
| OPNsense (R2) | `https://192.168.31.2` | `admin-ivan` |
| MikroTik (R1, WebFig) | `http://192.168.31.1` | `admin-ivan` |

| Alternativa | Per què no és l'opció principal |
|---|---|
| Túnel SSH per R1 (`ssh -p 2201 -L 8006:192.168.31.32:8006 admin-ivan@127.0.0.1`) | Còmode des de l'amfitrió i no obri res al router. Queda com a via de suport: és la que s'ha fet servir per automatitzar la instal·lació |
| Adaptador «Només amfitrió» a les VM | Trencaria l'aïllament: hi hauria una segona porta a la LAN31 que no passaria pel tallafocs |
| DNAT a R1 + redirecció de port de VirtualBox | Dues traduccions per servei i publicaria les webs de gestió a la WAN |

Condició: **R1 ha d'estar encés**, perquè és la porta d'enllaç i el DHCP de la LAN.

## 6. Canvi de lloc 13 → 31 (17/11/2026)

El número de lloc correcte és el **31**. Fins al 16/11 tot es va muntar amb **192.168.13.0/24**; el 17/11 es va passar tot a **192.168.31.0/24**, mantenint els mateixos últims octets (.1, .2, .3, .20, .21, .22, .23, .32–.34, .41, DHCP .100–.200). Les evidències anteriors al 17/11 mostren l'adreçament antic i no s'han tocat.

**Ordre seguit** (amb instantànies `abans-canvi-31` de les 10 VM abans de començar):

| # | Element | Què es canvia | Comprovació |
|---|---|---|---|
| 1 | VirtualBox | Xarxa interna `LAN13` → **`LAN31`** a les 10 VM (`VBoxManage modifyvm --intnetN LAN31`) | Cap VM queda a `LAN13` |
| 2 | R1 | Bridge `bridge-lan31` amb .31.1/24, pool i DHCP `dhcp-lan31` (.100–.200, domini `lan31.local`), NAT, serveis (`available-from`), identitat `R1-MikroTik-31`. **IP temporal 192.168.13.254** al bridge per arribar a les màquines que encara no s'havien canviat (esborrada al final) | `/export` sense cap 192.168.13 |
| 3 | NAS | API REST: IP .31.20 amb *rollback* (confirmació des de la IP nova en < 90 s), passarel·la i DNS .31.1, nom `nas31`, xarxa del NFS `192.168.31.0/24` | `nas-proxmox` actiu des dels nodes |
| 4 | Proxmox | Amb quòrum: `/etc/pve/corosync.conf` (IP dels 3 nodes, `cluster_name: cluster31`, `config_version` 3 → 4), `storage.cfg` (NFS .31.20), configuracions de la VM 220/230 (cloud-init) i del CT 100. A cada node: `interfaces`, `hosts`, `resolv.conf`. Reinici dels 3 alhora i `pvecm updatecerts --force` | `cluster31`, 3 vots, *Quorate* |
| 5 | VM 220/230, CT 100 | `qm cloudinit update` (IP nova en arrencar), DRBD `r0.res` amb .31.22/.31.23, orquestrador de còpies | DRBD `Established`, `UpToDate` |
| 6 | R2 / R3 | R2: `config.xml` (l'únic lloc amb la IP era la LAN; les regles usen «LAN net»). R3: `interfaces`, `nftables.conf` (`LAN_NET`), `dnsmasq` | Ping des de R1; regles amb .31 |
| 7 | SRV-WS2025 i clients | Servidor: tasca d'inici `lloc31-xarxa` (IP .31.21). Clients per DHCP (.199 i .200). Domini refet: `ivan-cambra-31.lan` (§7 de 04) | Inici de sessió amb `ivan` als dos clients |

**Resultat:** des del CLI-Debian, ping a R1, NAS i DC, DNS (incloent-hi el domini) i HTTPS a Internet correctes; traceroute .31.1 → 10.0.2.2. El ping a Internet no passa perquè la xarxa de l'aula bloqueja l'ICMP (vegeu [02](02-inventari.md)) → [`evidencias/canvi-lloc31/`](../evidencias/canvi-lloc31/).

