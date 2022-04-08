#!/bin/bash

nft add table nat
nft 'add chain nat postrouting { type nat hook postrouting priority 100 ; }'
nft add rule nat postrouting meta oifname "eth0" masquerade

apt update && apt install snort -y

echo "include /etc/snort/rules/icmp2.rules" > /etc/snort/mysnort.conf

echo 'alert icmp any any -> any any (msg:"ICMP Packet"; sid:4000001; rev:3;)' > /etc/snort/rules/icmp2.rules

echo "alert tcp any any -> any any (msg:\"Concerne l'HEIG-VD\"; content:\"HEIG-VD\"; sid:1000001; rev:1;)" > /root/myrules.rules
