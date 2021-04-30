# wgman.sh

## Manage wireguard user and server configs, on top of wg-quick@wg0

Keeps user data in the same directory as the script itself. Preshared key is being used.

### Initialization:

`wgman.sh init external_ip:port vpn_subnet/mask extra_iface_masquarade 'extra_network/mask, extra_network2/mask'`

eg.  `wgman.sh init example.com:51820  10.50.0.1/24         eth1            '172.16.20.0/24'`

If extra_iface_masquarade is provided, traffic will be allowed from/to this interface to VPN clients, so it could be used to open internal company network to VPN clients; subnet of that network shall be passed as extra_networks/masks, so it will be included in the peer configs.

### Create user:

`wgman.sh create username <IP>/32`

### Delete user:

`wgman.sh delete username`

### Show user config:

`wgman.sh show username`

### Show user config in QR code format:

`wgman.sh qr username`

### Regenerate server config 

Joins partial peer configs, not needed as it's performed after each user add/delete operation.

`wgman.sh regen`

### Purge

Removes all users and server configs, but not backups.

`wgman.sh purge`

### Misc info

After each action, in ./.backup/ directory, all configs are backed up.

### License

(c) 2021 Rafal Rozestwinski, rafal@rozestwinski.com, license: GPLv3

