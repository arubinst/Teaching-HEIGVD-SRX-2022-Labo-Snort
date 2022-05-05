#!/bin/bash



apt update && apt install snort -y

echo "include /etc/snort/rules/icmp2.rules" > /etc/snort/mysnort.conf

echo 'alert icmp any any -> any any (msg:"ICMP Packet"; sid:4000001; rev:3;)' > /etc/snort/rules/icmp2.rules

echo $'
alert tcp any any -> any any (msg:"Concerne l\'HEIG-VD"; content:"HEIG-VD"; sid:4000001; rev:1;)

portvar HTTP [80,443]
ipvar CLIENT 192.168.220.3
ipvar FIREFOX 192.168.220.4


ipvar WIKIPEDIA 91.198.174.192
log tcp $CLIENT any -> $WIKIPEDIA $HTTP (msg:"Wikipedia visited"; sid:40000002; rev:1;)
log tcp $FIREFOX any -> $WIKIPEDIA $HTTP (msg:"Wikipedia visited"; sid:40000003; rev:1;)

ipvar IDS 192.168.220.2
alert icmp !$IDS any <> $IDS any (msg:"PING ALERT !"; itype:8; sid:40000004; rev:1;)

portvar SSH 22
alert tcp $CLIENT any -> $IDS $SSH (msg:"SSH ALERT !"; sid:40000005; rev:1;)

alert tcp any any -> $IDS $SSH (msg:"SYN packet on SSH port"; flags:S; sid:40000006; rev:1;)

preprocessor frag3_global
preprocessor frag3_engine
' > /root/myrules.rules

nft flush ruleset

nft add table nat
nft 'add chain nat postrouting { type nat hook postrouting priority 100 ; }'
nft add rule nat postrouting meta oifname "eth0" masquerade
