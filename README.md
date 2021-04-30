# wgman.sh

## manage wireguard user and server configs, on top of wg-quick@wg0

### INITIALIZE:

`wgman.sh init external_ip:port vpn_subnet/mask extra_iface_masquarade 'extra_network/mask, extra_network2/mask'`

eg.  `wgman.sh init example.com:51820  10.50.0.1/24         eth1            '172.16.20.0/24'`

If extra_iface_masquarade is provided, traffic will be allowed from/to this interface to VPN clients, so it could be used to open internal company network to VPN clients; subnet of that network shall be passed as extra_networks/masks, so it will be included in the peer configs.

### CREATE USER:

`wgman.sh create username <IP>/32`

### DELETE USER:

`wgman.sh delete username`

### SHOW USER CONFIG:

`wgman.sh show username`

### SHOW QR CODE OF USER CONFIG:

`wgman.sh qr username`

### REGENENERATE SERVER CONFIG, JOINING PARTIAL PEERS CONFIG (DONE AUTOMATICALLY AFTER USER CREATE/DELETE):

`wgman.sh regen`

### PURGE (remove all users and server configs, but not backups)

`wgman.sh purge`

### Misc info

BTW: after each action, in ./.backup/ directory, all configs are backed up.

### License

(c) 2021 Rafal Rozestwinski, rafal@rozestwinski.com, license: GPLv3

