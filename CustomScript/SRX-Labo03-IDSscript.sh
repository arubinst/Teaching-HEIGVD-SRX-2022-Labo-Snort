# Script to configure the IDS machine when starting the lab
# Copy this script from your host to your IDS root directory with :
# sudo docker cp SRX-Labo03-IDSscript.sh IDS:/root/

#!/bin/sh

# Add NAT to nftables

nft add table nat
nft 'add chain nat postrouting { type nat hook postrouting priority 100 ; }'
nft add rule nat postrouting meta oifname "eth0" masquerade

# Install packages
apt update
apt install vim tmux snort -y
