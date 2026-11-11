# R3 · Debian 13 + nftables — fitxers de configuració

| Fitxer al repo | Destí a la VM | Funció |
|---|---|---|
| `nftables.conf` | `/etc/nftables.conf` | Filtre + NAT (masquerade) |
| `interfaces` | `/etc/network/interfaces` | WAN per DHCP, LAN estàtica 192.168.13.3/24 |
| `99-router.conf` | `/etc/sysctl.d/99-router.conf` | Activa l'encaminament IPv4 |
| `dnsmasq-lan13.conf` | `/etc/dnsmasq.d/lan13.conf` | DHCP (.100–.200) i DNS per a la LAN |

## Aplicació (dins de la VM, com a root)
```bash
apt update && apt install -y nftables dnsmasq
cp interfaces /etc/network/interfaces && systemctl restart networking
cp 99-router.conf /etc/sysctl.d/ && sysctl --system | grep ip_forward
cp dnsmasq-lan13.conf /etc/dnsmasq.d/lan13.conf && systemctl restart dnsmasq
nft -c -f nftables.conf            # comprova la sintaxi ABANS d'aplicar
cp /etc/nftables.conf /root/nftables.conf.bak-$(date +%F)   # punt de retorn
cp nftables.conf /etc/nftables.conf && systemctl enable --now nftables
nft list ruleset
```

## Prova permesa / bloquejada (a221)
Des de `CLI-Debian`:
```bash
curl -sI https://www.debian.org | head -1     # PERMESA  -> HTTP/2 200
nc -zv -w5 github.com 22                      # BLOQUEJADA -> timeout
```
Al router: `journalctl -k -f | grep NFT-` mostra:
- `NFT-FWD-OK IN=enp0s8 OUT=enp0s3 SRC=192.168.13.10x DST=... PROTO=TCP DPT=443` → regla d'eixida permesa.
- `NFT-FWD-BLOQ-SSH IN=enp0s8 OUT=enp0s3 SRC=192.168.13.10x DST=140.82.x.x PROTO=TCP DPT=22 SYN` → descartada per la regla de bloqueig.

## Retorn si una regla falla
`nft -f /root/nftables.conf.bak-AAAA-MM-DD` o restaurar la instantània de VirtualBox `R3-config-ok`.
