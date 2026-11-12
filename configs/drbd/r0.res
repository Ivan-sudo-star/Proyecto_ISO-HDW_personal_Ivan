# /etc/drbd.d/r0.res — Espill RAID 1 per xarxa entre dos equips (Tasca 6.3 · a107-a109)
# Nodes: srv-serveis (192.168.13.22) i srv-dades (192.168.13.23), cadascun amb un disc de 2 GB.
# COMPTE: /dev/sdb i /dev/sdg són provisionals. Substituir-los pel camí /dev/disk/by-path/... del disc de 2 GiB
# (vegeu el README): a la VM 230 els noms sdX no segueixen l'ordre scsiN.
# Protocol C = síncron: l'escriptura no es confirma fins que és als DOS discos (zero pèrdua si cau un node).
resource r0 {
  protocol C;
  net {
    cram-hmac-alg sha256;
    shared-secret "CANVIAR-FORA-DEL-REPO";   # es posa a mà a les dues VM, no es puja amb el valor real
    after-sb-0pri discard-zero-changes;
    after-sb-1pri discard-secondary;
    after-sb-2pri disconnect;               # split-brain amb dos primaris: no es decideix sol
  }
  on srv-serveis {
    device    /dev/drbd0;
    disk      /dev/sdb;
    address   192.168.13.22:7789;
    meta-disk internal;
  }
  on srv-dades {
    device    /dev/drbd0;
    disk      /dev/sdg;
    address   192.168.13.23:7789;
    meta-disk internal;
  }
}
