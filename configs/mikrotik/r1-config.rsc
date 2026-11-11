# r1-config.rsc — R1-MikroTik (RouterOS 7.24.5 x86) — lloc 13
# ether1 = WAN (NAT VirtualBox, DHCP)   ether2 = LAN13 (192.168.13.1/24)
# Importar: /import file-name=r1-config.rsc   (pujar-lo abans per WinBox/SFTP o enganxar-lo al terminal)
# La contrasenya NO va al fitxer: es posa a mà amb /user set admin-ivan password=...

/system identity set name=R1-MikroTik-13

# --- Usuaris d'administració (a204) ---
/user group add name=lectura policy=read,test,winbox,web,ssh,!write,!policy,!sensitive
/user add name=admin-ivan group=full comment="Administrador principal"
/user add name=suport group=lectura comment="Consulta / diagnòstic"
# Després de comprovar l'accés amb admin-ivan: /user disable admin

# --- Interfícies (a205) ---
/interface ethernet set [find default-name=ether1] comment=WAN
/interface ethernet set [find default-name=ether2] comment=LAN13
/ip dhcp-client add interface=ether1 disabled=no comment="WAN per DHCP (NAT VirtualBox)"
/ip address add address=192.168.13.1/24 interface=ether2 comment=LAN13

# --- DHCP i DNS per a la LAN ---
/ip pool add name=pool-lan13 ranges=192.168.13.100-192.168.13.200
/ip dhcp-server add name=dhcp-lan13 interface=ether2 address-pool=pool-lan13 lease-time=12h disabled=no
/ip dhcp-server network add address=192.168.13.0/24 gateway=192.168.13.1 dns-server=192.168.13.1 domain=lan13.local
/ip dns set allow-remote-requests=yes servers=1.1.1.1,9.9.9.9

# --- NAT: eixida a Internet de la LAN (a206) ---
/ip firewall nat add chain=srcnat src-address=192.168.13.0/24 out-interface=ether1 action=masquerade comment="LAN13 -> Internet"

# --- Filtre (a207): una connexió permesa i una bloquejada, totes dues amb registre ---
/ip firewall filter
add chain=input connection-state=established,related action=accept comment="input: establertes"
add chain=input connection-state=invalid action=drop
add chain=input in-interface=ether2 action=accept comment="input: gestió des de la LAN"
add chain=input protocol=icmp action=accept
add chain=input in-interface=ether1 action=drop log=yes log-prefix="R1-IN-DROP" comment="input: resta de la WAN"
add chain=forward connection-state=established,related action=accept
add chain=forward connection-state=invalid action=drop
add chain=forward in-interface=ether2 out-interface=ether1 protocol=tcp dst-port=22 action=drop log=yes log-prefix="R1-BLOQ-SSH" comment="PROVA: SSH a Internet bloquejat"
add chain=forward in-interface=ether2 out-interface=ether1 connection-state=new action=accept log=yes log-prefix="R1-FWD-OK" comment="PROVA: eixida permesa"
add chain=forward action=drop log=yes log-prefix="R1-FWD-DROP"

# --- Serveis: només els necessaris ---
/ip service disable telnet,ftp,api,api-ssl
/ip service set ssh address=192.168.13.0/24
/ip service set winbox address=192.168.13.0/24
/ip service set www address=192.168.13.0/24

# --- Registre i hora ---
/system clock set time-zone-name=Europe/Madrid
/system ntp client set enabled=yes servers=pool.ntp.org

# --- Còpia (a208): fitxers locals + pujada al NAS per SFTP ---
# /system backup save name=r1-backup dont-encrypt=no password=<xifrat>
# /export show-sensitive=no file=r1-export
# /tool fetch upload=yes mode=sftp address=192.168.13.20 user=copies password=<...> src-path=r1-export.rsc dst-path=/mnt/copies/routers/r1/r1-export.rsc
