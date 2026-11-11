import html, sys
cells=[]; nid=[1]
def box(x,y,w,h,label,style):
    nid[0]+=1; i=f"n{nid[0]}"
    cells.append(f'<mxCell id="{i}" value="{html.escape(label)}" style="{style}" vertex="1" parent="1"><mxGeometry x="{x}" y="{y}" width="{w}" height="{h}" as="geometry"/></mxCell>')
    return i
def edge(a,b,label="",style="endArrow=none;html=1;strokeWidth=2;"):
    nid[0]+=1
    cells.append(f'<mxCell id="e{nid[0]}" value="{html.escape(label)}" style="{style}fontSize=10;" edge="1" parent="1" source="{a}" target="{b}"><mxGeometry relative="1" as="geometry"/></mxCell>')
R="rounded=1;whiteSpace=wrap;html=1;fontSize=11;"
PHY=R+"fillColor=#f5f5f5;strokeColor=#666666;"
WAN=R+"fillColor=#fff2cc;strokeColor=#d6b656;"
RT=R+"fillColor=#f8cecc;strokeColor=#b85450;"
SW="shape=mxgraph.cisco.switches.workgroup_switch;html=1;fillColor=#036897;strokeColor=#ffffff;verticalLabelPosition=bottom;verticalAlign=top;fontSize=11;"
SRV=R+"fillColor=#dae8fc;strokeColor=#6c8ebf;"
CLI=R+"fillColor=#d5e8d4;strokeColor=#82b366;"
NOTE="text;html=1;align=left;verticalAlign=top;fontSize=10;whiteSpace=wrap;"
box(20,10,1260,30,"<b>Entorn individual de proves · Lloc 13 · LAN 192.168.13.0/24</b> (VirtualBox 7.2 · grup /ISO_HWD · disc SSD USB portable)","text;html=1;align=center;fontSize=15;")
W=1300
inet=box(570,50,160,60,"Internet","ellipse;shape=cloud;whiteSpace=wrap;html=1;fillColor=#ffffff;")
host=box(430,135,440,60,"<b>Equip físic (amfitrió)</b><br>Classe: ASUS B3605 · eno1 1 Gb/s · 172.16.222.40/24<br>Casa: MSI B760M · enp7s0 100 Mb/s · 192.168.1.86/24",PHY)
nat=box(430,220,440,50,"<b>WAN</b> · NAT de VirtualBox (una per VM) · 10.0.2.15/24 per DHCP<br>GW 10.0.2.2 · DNS 10.0.2.3",WAN)
rs=[]
for k,(n,d) in enumerate([("R1-MikroTik","(RouterOS 7.24.5)<br>ether1 WAN DHCP · ether2 <b>192.168.13.1/24</b>"),("R2-OPNsense","(26.7)<br>em0 WAN DHCP · em1 <b>192.168.13.2/24</b>"),("R3-Debian_NFtables","(Debian 13)<br>enp0s3 WAN DHCP · enp0s8 <b>192.168.13.3/24</b>")]):
    rs.append((box(250+k*285,310,230,65,f"<b>{n}</b> {d}",RT),250+k*285+115))
BX,BY,BW=20,440,1260
bus=box(BX,BY,BW,26,"<b>LAN13</b> · xarxa interna VirtualBox · 192.168.13.0/24 · màscara 255.255.255.0 · GW 192.168.13.1 · DNS 192.168.13.1 · DHCP .100–.200 (només dins la LAN)",R+"fillColor=#036897;fontColor=#ffffff;strokeColor=#036897;")
def vedge(src,cx,up):
    ex=(cx-BX)/BW
    st=f"endArrow=none;html=1;strokeWidth=2;exitX=0.5;exitY={1 if up else 0};entryX={ex:.4f};entryY={0 if up else 1};"
    edge(src,bus,style=st)
VM="rounded=1;whiteSpace=wrap;html=1;fontSize=9;fillColor=#ffffff;strokeColor=#6c8ebf;dashed=1;"
cols=[("NAS-TrueNAS","TrueNAS SCALE 25.10.7<br>192.168.13.20/24 estàtica<br>boot 20 GB + <b>copies 50 GB</b>",SRV,[]),
      ("PVE1-Proxmox","Proxmox VE 9.2 · node 1<br>vmbr0 192.168.13.32/24<br>6 GB · 4 vCPU",SRV,[("SRV-WS2025","VM · Windows Server 2025<br>192.168.13.21/24")]),
      ("PVE2-Proxmox","Proxmox VE 9.2 · node 2<br>vmbr0 192.168.13.33/24<br>3 GB · 2 vCPU",SRV,[("SRV-SERVEIS","VM · Debian 13 sense GUI<br>.22 · còpies · DRBD A"),("CT 100","LXC Debian · 192.168.13.41")]),
      ("PVE3-Proxmox","Proxmox VE 9.2 · node 3<br>vmbr0 192.168.13.34/24<br>3 GB · 2 vCPU",SRV,[("SRV-DADES","VM · Debian 13 sense GUI<br>.23 · RAID · DRBD B")]),
      ("CLI-Debian","Client GNU/Linux<br>DHCP (.100–.200)<br>GW .1 · DNS .1",CLI,[]),
      ("Cliente_windows_1","Client Windows 11<br>DHCP (.100–.200)<br>TPM 2.0 · UEFI · SB",CLI,[])]
bw=200; gap=(BW-6*bw)/5
for k,(n,d,st,inner) in enumerate(cols):
    x=BX+k*(bw+gap); h=70+48*len(inner)+(10 if inner else 0)
    i=box(x,520,bw,h,f"<b>{n}</b><br>{d}",st+"fontSize=10;verticalAlign=top;")
    for j,(vn,vd) in enumerate(inner):
        box(x+10,520+72+j*48,bw-20,42,f"<b>{vn}</b><br>{vd}",VM)
    vedge(i,x+bw/2,False)
box(BX,700,BW,20,"Caixes discontínues = VM i contenidors <b>dins</b> dels nodes Proxmox (clúster <b>cluster13</b>, 3 vots, quòrum = 2). Els servidors empresarials no són VM de VirtualBox, igual que al grup.","text;html=1;align=center;fontSize=10;fontStyle=2;")
edge(inet,host); edge(host,nat)
for r,cx in rs:
    edge(nat,r,style="endArrow=none;html=1;strokeWidth=1;dashed=1;")
    vedge(r,cx,True)
box(20,730,1260,50,"<b>Camí del trànsit:</b> client (192.168.13.10x) → LAN13 → router (R1 .1 · R2 .2 · R3 .3: filtre + NAT masquerade) → WAN 10.0.2.15 → NAT VirtualBox 10.0.2.2 → NIC física de l'amfitrió → Internet.<br><b>Llegenda:</b> vermell = comunicacions · blau = servidors · verd = clients · groc = WAN · gris = maquinari físic. Línia discontínua = tres alternatives de servidor de comunicacions (com al grup): R1 és la porta d'enllaç principal (.1); es proven d'una en una i només una té el DHCP actiu.",NOTE)
xml='<mxfile host="drawio"><diagram name="Xarxa individual lloc 13"><mxGraphModel dx="1100" dy="820" grid="1" gridSize="10" page="1" pageWidth="1300" pageHeight="790"><root><mxCell id="0"/><mxCell id="1" parent="0"/>'+"".join(cells)+'</root></mxGraphModel></diagram></mxfile>'
open(sys.argv[1],'w').write(xml)
