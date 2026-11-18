# Tasca 5 · Instal·lació i configuració dels sistemes

**ISO RA1 / RA3 / RA6** · Estat: ✅

Els mateixos sistemes que el grup, amb la mateixa plantilla per a cada un: **versió → usuaris → xarxa → còpia al NAS**. Els routers, a més: NAT, prova permesa/bloquejada i fallada amb recuperació.

| # | Sistema | Accions | Estat |
|---|---|---|---|
| 0 | [Comprovacions generals](0-Comprovacions/) (ISO, actualitzacions, arrencada) | a78, a79, a258 | ✅ |
| 1 | [R1 · MikroTik](1-R1-MikroTik/) | a203–a209 | ✅ |
| 2 | [R2 · OPNsense](2-R2-OPNsense/) | a210–a216 | ✅ |
| 3 | [R3 · Debian + nftables](3-R3-nftables/) | a217–a223 | ✅ |
| 4 | [NAS · TrueNAS](4-NAS-TrueNAS/) | a224–a227 | ✅ |
| 5 | [Proxmox · clúster `cluster31`](5-Proxmox/) | a228–a232, a235, a236 | ✅ |
| 6 | [Windows Server 2025 i domini](6-WS2025-Domini/) | a237–a241 | ✅ |
| 7 | [Servidors Linux](7-Servidors-Linux/) | a242–a246 | ✅ |
| 8 | [Clients W11 i Debian](8-Clients/) | a247–a250, a252–a255 | ✅ |
| 9 | [Còpies de seguretat](9-Copies/) | a259, a105 (Apte+) | ✅ (a105: 2 eines provades, instantànies de TrueNAS i backup de Proxmox) |

**Credencials:** no apareixen al repositori. Els scripts les demanen o les reben en executar-se.
