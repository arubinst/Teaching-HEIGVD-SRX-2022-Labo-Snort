#!/bin/bash

####################################################################################
# Initial setup
# Nb: You may remove other routes than default one to ensure to transit through IDS

docker exec -i Client /bin/bash <<- EOF
ip route del default
ip route add default via 192.168.220.2
ip route
EOF

docker exec -i firefox /bin/bash <<- EOF
ip route del default
ip route add default via 192.168.220.2
ip route
EOF

docker exec -i IDS /bin/bash <<- EOF
nft add table nat
nft 'add chain nat postrouting { type nat hook postrouting priority 100 ; }'
nft add rule nat postrouting meta oifname "eth0" masquerade
nft list ruleset
EOF

docker exec -i IDS /bin/bash <<- EOF
apt update && apt install -y snort
snort --help
EOF

#####################################################################################
## Essayer Snort


docker exec -i IDS /bin/bash <<- EOF
snort -v -i eth0
EOF


docker exec -i IDS /bin/bash <<- EOF
echo 'include /etc/snort/rules/icmp2.rules' > '/etc/snort/mysnort.conf'
echo 'alert icmp any any -> any any (msg:"ICMP Packet"; sid:4000001; rev:3;)' > '/etc/snort/rules/icmp2.rules'
EOF

docker exec -i IDS /bin/bash <<- EOF
snort -v -c /etc/snort/mysnort.conf
EOF

# From another terminal
# docker exec -i Client ping IDS



# docker exec -i IDS /bin/bash & <<- EOF
# timeout -k 5 30 snort -c /etc/snort/mysnort.conf
# EOF
# sleep 2
# docker exec -i Client ping -c 5 IDS

docker exec -i IDS cat /var/log/snort/alert

# Nb: avec content:"Facebook" ça ne marchait pas mais maintenant oui
docker exec -i IDS /bin/bash <<- EOF
echo 'alert tcp any any -> any any (msg:"Fishing"; content:"neverssl"; sid:4000019; rev:1;)' > "/root/myrules.rules"
EOF

# Nb: mieux de lancer le shell bash et de faire le stop dedans pour voir l'output
docker exec -i IDS /bin/bash <<- EOF
snort -c /root/myrules.rules -i eth0
EOF

# From another terminal
# docker exec -i Client wget -O- http://neverssl.com
# docker exec -i Client sh -c 'while true; do wget -O- http://neverssl.com > /dev/null; done;'
# docker exec -i Client sh -c 'while true; do wget -O- http://neverssl.com 2>1 | grep Facebook; done;'

# Q8
docker exec -i IDS /bin/bash <<- EOF
echo 'log tcp 192.168.220.3 any -> 91.198.174.192 [80,443] (msg: "Client accessed Wikipedia.org"; sid:4000023; rev:1;)' > "/root/wikipedia.rules"
echo 'log tcp 192.168.220.4 any -> 91.198.174.192 [80,443] (msg: "Firefox accessed Wikipedia.org"; sid:4000024; rev:1;)' >> "/root/wikipedia.rules"
EOF

# Q9 a Q12
docker exec -i IDS /bin/bash <<- EOF
echo 'pass icmp 192.168.220.2 any -> 192.168.220.2 any (sid:4000034; rev:1;)' > "/root/alert_ping.rules"
echo 'alert icmp any any -> 192.168.220.2 any (itype: 8; msg: "Someone pinged IDS"; sid:4000035; rev:1;)' >> "/root/alert_ping.rules"
EOF

# Q13
docker exec -i IDS /bin/bash <<- EOF
echo 'pass icmp 192.168.220.2 any -> 192.168.220.3 any (sid:4000033; rev:1;)' > "/root/alert_ping2.rules"
echo 'pass icmp 192.168.220.3 any -> 192.168.220.2 any (sid:4000035; rev:1;)' >> "/root/alert_ping2.rules"
echo 'alert icmp any any -> 192.168.220.3 any (msg: "Someone pinged Client"; sid:4000034; rev:1;)' >> "/root/alert_ping2.rules"
echo 'alert icmp 192.168.220.3 any -> any any (msg: "Client answered"; sid:4000036; rev:1;)' >> "/root/alert_ping2.rules"
EOF

# Q14
docker exec -i IDS /bin/bash <<- EOF
echo 'alert tcp 192.168.220.3 any -> 192.168.220.2 22 (msg:"Client tried to connect to IDS using ssh"; sid:4000040; rev:1;)' > "/root/ssh.rules"
EOF

# Q20
docker exec -i IDS /bin/bash <<- EOF
echo 'alert tcp any any -> 192.168.220.2 22 (msg:"SCAN SYN"; flags:S; sid:4000050; rev:1;)' > "/root/nmap_syn.rules"
EOF

# Q24
docker exec -i IDS /bin/bash <<- EOF
echo 'preprocessor frag3_global: max_frags 65536' >> "/root/nmap_syn2.rules"
echo 'preprocessor frag3_engine: policy windows detect_anomalies overlap_limit 10 min_fragment_length 100 timeout 180' >> "/root/nmap_syn2.rules"
echo 'alert tcp any any -> 192.168.220.2 22 (msg:"SCAN SYN"; flags:S; sid:4000050; rev:1;)' >> "/root/nmap_syn2.rules"
EOF
