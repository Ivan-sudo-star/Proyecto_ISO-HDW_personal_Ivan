# r1-config.rsc — R1-MikroTik (RouterOS 7.25.1 x86; instal·lat amb la 7.24.5) — lloc 31
# ether1 = WAN (NAT VirtualBox, DHCP)   ether2 = port del bridge-lan31 (LAN31, 192.168.31.1/24 al bridge)
# Importar: /import file-name=r1-config.rsc   (pujar-lo abans per WinBox/SFTP o enganxar-lo al terminal)
# La contrasenya NO va al fitxer: es posa a mà amb /user set admin-ivan password=...

/system identity set name=R1-MikroTik-31

# --- Usuaris d'administració (a204) ---
/user group add name=lectura policy=read,test,winbox,web,ssh,!write,!policy,!sensitive
# Les contrasenyes (password=<lab>) s'afigen en el moment d'aplicar el fitxer, no es guarden al repositori
/user add name=admin-ivan group=full comment="Administrador principal"
/user add name=suport group=lectura comment="Consulta / diagnostic"
# Després de comprovar l'accés amb admin-ivan: /user disable admin

# --- Interfícies (a205) ---
/interface ethernet set [find default-name=ether1] comment=WAN
/interface ethernet set [find default-name=ether2] comment=LAN31
/ip dhcp-client add interface=ether1 disabled=no comment="WAN per DHCP (NAT VirtualBox)"

# --- Bridge de la LAN (12/11/2026) ---
# La IP, el DHCP i el filtre van al bridge, no al port: si s'afig un port (o una VLAN) a la LAN, només cal posar-lo al bridge.
/interface bridge add name=bridge-lan31 protocol-mode=rstp comment="LAN31: la IP, el DHCP i el filtre van al bridge"
/interface bridge port add bridge=bridge-lan31 interface=ether2 comment=LAN31
/ip address add address=192.168.31.1/24 interface=bridge-lan31 comment=LAN31

# --- Llistes d'interfícies: les regles diuen LAN/WAN, no noms de port ---
/interface list add name=WAN comment="Internet (NAT VirtualBox)"
/interface list add name=LAN comment="Xarxa interna LAN31"
/interface list member add list=WAN interface=ether1
/interface list member add list=LAN interface=bridge-lan31
# Descobriment de veïns i accés per MAC (MAC-Telnet/MAC-WinBox) només des de la LAN, mai per la WAN
/ip neighbor discovery-settings set discover-interface-list=LAN
/tool mac-server set allowed-interface-list=LAN
/tool mac-server mac-winbox set allowed-interface-list=LAN

# --- DHCP i DNS per a la LAN ---
/ip pool add name=pool-lan31 ranges=192.168.31.100-192.168.31.200
/ip dhcp-server add name=dhcp-lan31 interface=bridge-lan31 address-pool=pool-lan31 lease-time=12h disabled=no
/ip dhcp-server network add address=192.168.31.0/24 gateway=192.168.31.1 dns-server=192.168.31.1 domain=lan31.local
/ip dns set allow-remote-requests=yes servers=1.1.1.1,9.9.9.9
# Domini AD (16/11): les consultes de ivan-cambra-31.lan (i subdominis, p. ex. _msdcs) van al controlador de domini SRV-WS2025
/ip dns static add name=ivan-cambra-31.lan type=FWD forward-to=192.168.31.21 match-subdomain=yes comment="domini AD -> SRV-WS2025"

# --- NAT: eixida a Internet de la LAN (a206) ---
/ip firewall nat add chain=srcnat src-address=192.168.31.0/24 out-interface-list=WAN action=masquerade comment="LAN31 -> Internet"

# --- Filtre (a207): una connexió permesa i una bloquejada, totes dues amb registre ---
/ip firewall filter
add chain=input connection-state=established,related action=accept comment="input: establertes"
add chain=input connection-state=invalid action=drop
add chain=input in-interface-list=LAN action=accept comment="input: gestio des de la LAN"
add chain=input protocol=icmp action=accept
add chain=input in-interface-list=WAN src-address=10.0.2.2 protocol=tcp dst-port=22 action=accept comment="input: gestio SSH des de l'amfitrio (port-forward NAT VirtualBox 127.0.0.1:2201)"
add chain=input in-interface-list=WAN action=drop log=yes log-prefix="R1-IN-DROP" comment="input: resta de la WAN"
add chain=forward connection-state=established,related action=accept
add chain=forward connection-state=invalid action=drop
add chain=forward in-interface-list=LAN out-interface-list=WAN protocol=tcp dst-port=22 action=drop log=yes log-prefix="R1-BLOQ-SSH" comment="PROVA: SSH a Internet bloquejat"
add chain=forward in-interface-list=LAN out-interface-list=WAN connection-state=new action=accept log=yes log-prefix="R1-FWD-OK" comment="PROVA: eixida permesa"
add chain=forward action=drop log=yes log-prefix="R1-FWD-DROP"

# --- Serveis: només els necessaris ---
/ip service disable telnet,ftp,api,api-ssl
/ip service set ssh address=192.168.31.0/24,10.0.2.2/32
/ip service set winbox address=192.168.31.0/24
/ip service set www address=192.168.31.0/24

# --- Registre i hora ---
/system clock set time-zone-name=Europe/Madrid
/system ntp client set enabled=yes servers=pool.ntp.org

# --- Còpia (a208): fitxers locals + pujada al NAS per SFTP ---
# /system backup save name=r1-backup dont-encrypt=no password=<xifrat>
# /export file=r1-export
# /tool fetch upload=yes mode=sftp address=192.168.31.20 user=copies password=<...> src-path=r1-export.rsc dst-path=/mnt/copies/routers/r1/r1-export.rsc
