# R3 · Debian 13 + nftables (router alternatiu)

**a217–a223** · Estat: ✅ · Configuració: [`config/`](config/) (`nftables.conf`, `interfaces`, `dnsmasq`)

| | |
|---|---|
| Versió | Debian **13.7**, nucli 6.12.116, nftables · sense escriptori i amb 1 GB (optimització de la [Tasca 7](../../Tasca7-Rendiment/)) |
| Xarxa | WAN `enp0s3` per DHCP · LAN `enp0s8` **192.168.31.3/24** · `ip_forward=1` · `dnsmasq` preparat però desactivat |
| Usuaris | `admin-ivan` (sudo) · `suport` · root sense SSH per contrasenya |

| Acció | Resultat | Evidència |
|---|---|---|
| a217–a219 versió, usuaris, xarxa | ✅ | [`a217-a219-versio-usuaris-xarxa.txt`](evidencies/a217-a219-versio-usuaris-xarxa.txt) |
| a220–a221 Internet, permesa / bloquejada | ✅ `NFT-FWD-OK` (443) i `NFT-FWD-BLOQ-SSH` (22) amb comptadors | [`a220-a221-prova-permesa-bloquejada.txt`](evidencies/a220-a221-prova-permesa-bloquejada.txt) |
| a222 còpia al NAS | ✅ `tgz` de la configuració + ruleset a `routers/r3` | [`a222-copia-al-nas.txt`](evidencies/a222-copia-al-nas.txt) |
| a223 fallada i recuperació | ✅ `nft flush` + `ip_forward=0` → restauració des del NAS: **22 s** | [`a223-fallada-recuperacio.txt`](evidencies/a223-fallada-recuperacio.txt) |

## Els 3 routers, configurats igual

| | R1 MikroTik | R2 OPNsense | R3 nftables |
|---|---|---|---|
| LAN | .1 (bridge) | .2 | .3 |
| NAT | masquerade | Outbound NAT | masquerade |
| Bloqueig | tcp/22 + registre | tcp/22 + registre | tcp/22 + registre + comptador |
| Eixida | permesa + registre | permesa + registre | permesa + registre + comptador |
| DHCP | actiu | preparat | preparat |
| Còpia | export + backup | `config.xml` | `tgz` + ruleset |
| Recuperació | **42 s** | **48 s** | **22 s** |
