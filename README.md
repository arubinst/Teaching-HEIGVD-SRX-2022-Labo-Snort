# Teaching-HEIGVD-SRX-2022-Laboratoire-Snort

**Ce travail de laboratoire est à faire en équipes de 2 personnes**

**ATTENTION : Commencez par créer un Fork de ce repo et travaillez sur votre fork.**

Clonez le repo sur votre machine. Vous pouvez répondre aux questions en modifiant directement votre clone du README.md ou avec un fichier pdf que vous pourrez uploader sur votre fork.

**Le rendu consiste simplement à répondre à toutes les questions clairement identifiées dans le text avec la mention "Question" et à les accompagner avec des captures. Le rendu doit se faire par une "pull request". Envoyer également le hash du dernier commit et votre username GitHub par email au professeur et à l'assistant**

## Table de matières

[Introduction](#introduction)

[Echéance](#echéance)

[Démarrage de l'environnement virtuel](#démarrage-de-lenvironnement-virtuel)

[Communication avec les conteneurs](#communication-avec-les-conteneurs)

[Configuration de la machine IDS et installation de Snort](#configuration-de-la-machine-ids-et-installation-de-snort)

[Essayer Snort](#essayer-snort)

[Utilisation comme IDS](#utilisation-comme-un-ids)

[Ecriture de règles](#ecriture-de-règles)

[Travail à effectuer](#exercises)

[Cleanup](#cleanup)


## Echéance 

Ce travail devra être rendu au plus tard, **le 29 avril 2022 à 08h30.**


## Introduction

Dans ce travail de laboratoire, vous allez explorer un système de détection contre les intrusions (IDS) dont l'utilisation es très répandue grâce au fait qu'il est gratuit et open source. Il s'appelle [Snort](https://www.snort.org). Il existe des versions de Snort pour Linux et pour Windows.

### Les systèmes de détection d'intrusion

Un IDS peut "écouter" tout le traffic de la partie du réseau où il est installé. Sur la base d'une liste de règles, il déclenche des actions sur des paquets qui correspondent à la description de la règle.

Un exemple de règle pourrait être, en langage commun : "donner une alerte pour tous les paquets envoyés par le port http à un serveur web dans le réseau, qui contiennent le string 'cmd.exe'". En on peut trouver des règles très similaires dans les règles par défaut de Snort. Elles permettent de détecter, par exemple, si un attaquant essaie d'éxecuter un shell de commandes sur un serveur Web tournant sur Windows. On verra plus tard à quoi ressemblent ces règles.

Snort est un IDS très puissant. Il est gratuit pour l'utilisation personnelle et en entreprise, où il est très utilisé aussi pour la simple raison qu'il est l'un des systèmes IDS des plus efficaces.

Snort peut être exécuté comme un logiciel indépendant sur une machine ou comme un service qui tourne après chaque démarrage. Si vous voulez qu'il protège votre réseau, fonctionnant comme un IPS, il faudra l'installer "in-line" avec votre connexion Internet. 

Par exemple, pour une petite entreprise avec un accès Internet avec un modem simple et un switch interconnectant une dizaine d'ordinateurs de bureau, il faudra utiliser une nouvelle machine éxecutant Snort et placée entre le modem et le switch. 


## Matériel

Vous avez besoin de votre ordinateur avec Docker et docker-compose. Vous trouverez tous les fichiers nécessaires pour générer l'environnement pour virtualiser ce labo dans le projet que vous avez cloné.


## Démarrage de l'environnement virtuel

Ce laboratoire utilise docker-compose, un outil pour la gestion d'applications utilisant multiples conteneurs. Il va se charger de créer un réseaux virtuel `snortlan`, la machine IDS, un client avec un navigateur Firefox, une machine "Client" et un conteneur Wireshark directement connecté à la même interface réseau que la machine IDS. Le réseau LAN interconnecte les autres 3 machines (voir schéma ci-dessous).

![Plan d'adressage](images/docker-snort.png)

Nous allons commencer par lancer docker-compose. Il suffit de taper la commande suivante dans le répertoire racine du labo, celui qui contient le fichier [docker-compose.yml](docker-compose.yml). Optionnelement vous pouvez lancer le script [up.sh](scripts/up.sh) qui se trouve dans le répertoire [scripts](scripts), ainsi que d'autres scripts utiles pour vous :

```bash
docker-compose up --detach
```

Le téléchargement et génération des images prend peu de temps. 

Les images utilisées pour les conteneurs client et la machine IDS sont basées sur l'image officielle Kali. Le fichier [Dockerfile](Dockerfile) que vous avez téléchargé contient les informations nécessaires pour la génération de l'image de base. [docker-compose.yml](docker-compose.yml) l'utilise comme un modèle pour générer ces conteneurs. Les autres deux conteneurs utilisent des images du groupe LinuxServer.io. Vous pouvez vérifier que les quatre conteneurs sont crées et qu'ils fonctionnent à l'aide de la commande suivante.

```bash
docker ps
```

## Communication avec les conteneurs

Afin de simplifier vos manipulations, les conteneurs ont été configurées avec les noms suivants :

- IDS
- Client
- wireshark
- firefox

Pour accéder au terminal de l’une des machines, il suffit de taper :

```bash
docker exec -it <nom_de_la_machine> /bin/bash
```

Par exemple, pour ouvrir un terminal sur votre IDS :

```bash
docker exec -it IDS /bin/bash
```

Optionnelement, vous pouvez utiliser les scripts [openids.sh](scripts/openids.sh), [openfirefox.sh](scripts/openfirefox.sh) et [openclient.sh](scripts/openclient.sh) pour contacter les conteneurs.

Vous pouvez bien évidemment lancer des terminaux communiquant avec toutes les machines en même temps ou même lancer plusieurs terminaux sur la même machine. ***Il est en fait conseillé pour ce laboratoire de garder au moins deux terminaux ouverts sur la machine IDS en tout moment***.


### Configuration de la machine Client et de firefox

Dans un terminal de votre machine Client et de la machine firefox, taper les commandes suivantes :

```bash
ip route del default 
ip route add default via 192.168.220.2
```

Ceci configure la machine IDS comme la passerelle par défaut pour les deux autres machines.


## Configuration de la machine IDS et installation de Snort

Pour permettre à votre machine Client de contacter l'Internet à travers la machine IDS, il faut juste une petite règle NAT par intermédiaire de nftables :

```bash
nft add table nat
nft 'add chain nat postrouting { type nat hook postrouting priority 100 ; }'
nft add rule nat postrouting meta oifname "eth0" masquerade
```

Cette commande `iptables` définit une règle dans le tableau NAT qui permet la redirection de ports et donc, l'accès à l'Internet pour la machine Client.

On va maintenant installer Snort sur le conteneur IDS.

La manière la plus simple c'est d'installer Snort en ligne de commandes. Il suffit d'utiliser la commande suivante :

```
apt update && apt install snort
```

Ceci télécharge et installe la version la plus récente de Snort.

Il est possible que vers la fin de l'installation, on vous demande de fournir deux informations :

- Le nom de l'interface sur laquelle snort doit surveiller - il faudra répondre ```eth0```
- L'adresse de votre réseau HOME. Il s'agit du réseau que vous voulez protéger. Cela sert à configurer certaines variables pour Snort. Vous pouvez répondre ```192.168.220.0/24```.


## Essayer Snort

Une fois installé, vous pouvez lancer Snort comme un simple "sniffer". Pourtant, ceci capture tous les paquets, ce qui peut produire des fichiers de capture énormes si vous demandez de les journaliser. Il est beaucoup plus efficace d'utiliser des règles pour définir quel type de trafic est intéressant et laisser Snort ignorer le reste.

Snort se comporte de différentes manières en fonction des options que vous passez en ligne de commande au démarrage. Vous pouvez voir la grande liste d'options avec la commande suivante :

```
snort --help
```

On va commencer par observer tout simplement les entêtes des paquets IP utilisant la commande :

```
snort -v -i eth0
```

**ATTENTION : le choix de l'interface devient important si vous avez une machine avec plusieurs interfaces réseau. Dans notre cas, vous pouvez ignorer entièrement l'option ```-i eth0```et cela devrait quand-même fonctionner correctement.**

Snort s'éxecute donc et montre sur l'écran tous les entêtes des paquets IP qui traversent l'interface eth0. Cette interface reçoit tout le trafic en provenance de la machine "Client" puisque nous avons configuré le IDS comme la passerelle par défaut.

Pour arrêter Snort, il suffit d'utiliser `CTRL-C` (**attention** : en ligne générale, ceci fonctionne si vous patientez un moment... Snort est occupé en train de gérer le contenu du tampon de communication et cela qui peut durer quelques secondes. Cependant, il peut arriver de temps à autres que Snort ne réponde plus correctement au signal d'arrêt. Dans ce cas-là, il faudra utiliser `kill` depuis un deuxième terminal pour arrêter le process).


## Utilisation comme un IDS

Pour enregistrer seulement les alertes et pas tout le trafic, on execute Snort en mode IDS. Il faudra donc spécifier un fichier contenant des règles. 

Il faut noter que `/etc/snort/snort.config` contient déjà des références aux fichiers de règles disponibles avec l'installation par défaut. Si on veut tester Snort avec des règles simples, on peut créer un fichier de config personnalisé (par exemple `mysnort.conf`) et importer un seul fichier de règles utilisant la directive "include".

Les fichiers de règles sont normalement stockes dans le répertoire `/etc/snort/rules/`, mais en fait un fichier de config et les fichiers de règles peuvent se trouver dans n'importe quel répertoire de la machine. 

Par exemple, créez un fichier de config `mysnort.conf` dans le repertoire `/etc/snort` avec le contenu suivant :

```
include /etc/snort/rules/icmp2.rules
```

Ensuite, créez le fichier de règles `icmp2.rules` dans le repertoire `/etc/snort/rules/` et rajoutez dans ce fichier le contenu suivant :

`alert icmp any any -> any any (msg:"ICMP Packet"; sid:4000001; rev:3;)`

On peut maintenant éxecuter la commande :

```
snort -c /etc/snort/mysnort.conf
```

Vous pouvez maintenant faire quelques pings depuis votre "Client" et regarder les résultas dans le fichier d'alertes contenu dans le repertoire `/var/log/snort/`.


## Ecriture de règles

Snort permet l'écriture de règles qui décrivent des tentatives de exploitation de vulnérabilités bien connues. Les règles Snort prennent en charge à la fois, l'analyse de protocoles et la recherche et identification de contenu.

Il y a deux principes de base à respecter :

* Une règle doit être entièrement contenue dans une seule ligne
* Les règles sont divisées en deux sections logiques : (1) l'entête et (2) les options.

L'entête de la règle contient l'action de la règle, le protocole, les adresses source et destination, et les ports source et destination.

L'option contient des messages d'alerte et de l'information concernant les parties du paquet dont le contenu doit être analysé. Par exemple:

```
alert tcp any any -> 192.168.220.0/24 111 (content:"|00 01 86 a5|"; msg: "mountd access";)
```

Cette règle décrit une alerte générée quand Snort trouve un paquet avec tous les attributs suivants :

* C'est un paquet TCP
* Emis depuis n'importe quelle adresse et depuis n'importe quel port
* A destination du réseau identifié par l'adresse 192.168.220.0/24 sur le port 111

Le text jusqu'au premier parenthèse est l'entête de la règle. 

```
alert tcp any any -> 192.168.220.0/24 111
```

Les parties entre parenthèses sont les options de la règle:

```
(content:"|00 01 86 a5|"; msg: "mountd access";)
```

Les options peuvent apparaître une ou plusieurs fois. Par exemple :

```
alert tcp any any -> any 21 (content:"site exec"; content:"%"; msg:"site
exec buffer overflow attempt";)
```

La clé "content" apparait deux fois parce que les deux strings qui doivent être détectés n'apparaissent pas concaténés dans le paquet mais a des endroits différents. Pour que la règle soit déclenchée, il faut que le paquet contienne **les deux strings** "site exec" et "%". 

Les éléments dans les options d'une règle sont traités comme un AND logique. La liste complète de règles sont traitées comme une succession de OR.

## Informations de base pour le règles

### Actions :

```
alert tcp any any -> any any (msg:"My Name!"; content:"Skon"; sid:1000001; rev:1;)
```

L'entête contient l'information qui décrit le "qui", le "où" et le "quoi" du paquet. Ça décrit aussi ce qui doit arriver quand un paquet correspond à tous les contenus dans la règle.

Le premier champ dans le règle c'est l'action. L'action dit à Snort ce qui doit être fait quand il trouve un paquet qui correspond à la règle. Il y a six actions :

* alert - générer une alerte et écrire le paquet dans le journal
* log - écrire le paquet dans le journal
* pass - ignorer le paquet
* drop - bloquer le paquet et l'ajouter au journal
* reject - bloquer le paquet, l'ajouter au journal et envoyer un `TCP reset` si le protocole est TCP ou un `ICMP port unreachable` si le protocole est UDP
* sdrop - bloquer le paquet sans écriture dans le journal

### Protocoles :

Le champ suivant c'est le protocole. Il y a trois protocoles IP qui peuvent être analysés par Snort : TCP, UDP et ICMP.


### Adresses IP :

La section suivante traite les adresses IP et les numéros de port. Le mot `any` peut être utilisé pour définir "n'import quelle adresse". On peut utiliser l'adresse d'une seule machine ou un block avec la notation CIDR. 

Un opérateur de négation peut être appliqué aux adresses IP. Cet opérateur indique à Snort d'identifier toutes les adresses IP sauf celle indiquée. L'opérateur de négation est le `!`.

Par exemple, la règle du premier exemple peut être modifiée pour alerter pour le trafic dont l'origine est à l'extérieur du réseau :

```
alert tcp !192.168.220.0/24 any -> 192.168.220.0/24 111
(content: "|00 01 86 a5|"; msg: "external mountd access";)
```

### Numéros de Port :

Les ports peuvent être spécifiés de différentes manières, y-compris `any`, une définition numérique unique, une plage de ports ou une négation.

Les plages de ports utilisent l'opérateur `:`, qui peut être utilisé de différentes manières aussi :

```
log udp any any -> 192.168.220.0/24 1:1024
```

Journaliser le traffic UDP venant d'un port compris entre 1 et 1024.

--

```
log tcp any any -> 192.168.220.0/24 :6000
```

Journaliser le traffic TCP venant d'un port plus bas ou égal à 6000.

--

```
log tcp any :1024 -> 192.168.220.0/24 500:
```

Journaliser le traffic TCP venant d'un port privilégié (bien connu) plus grand ou égal à 500 mais jusqu'au port 1024.


### Opérateur de direction

L'opérateur de direction `->`indique l'orientation ou la "direction" du trafique. 

Il y a aussi un opérateur bidirectionnel, indiqué avec le symbole `<>`, utile pour analyser les deux côtés de la conversation. Par exemple un échange telnet :

```
log 192.168.220.0/24 any <> 192.168.220.0/24 23
```

## Alertes et logs Snort

Si Snort détecte un paquet qui correspond à une règle, il envoie un message d'alerte ou il journalise le message. Les alertes peuvent être envoyées au syslog, journalisées dans un fichier text d'alertes ou affichées directement à l'écran.

Le système envoie **les alertes vers le syslog** et il peut en option envoyer **les paquets "offensifs" vers une structure de repertoires**.

Les alertes sont journalisées via syslog dans le fichier `/var/log/snort/alerts`. Toute alerte se trouvant dans ce fichier aura son paquet correspondant dans le même repertoire, mais sous le fichier `snort.log.xxxxxxxxxx` où `xxxxxxxxxx` est l'heure Unix du commencement du journal.

Avec la règle suivante :

```
alert tcp any any -> 192.168.220.0/24 111
(content:"|00 01 86 a5|"; msg: "mountd access";)
```

un message d'alerte est envoyé à syslog avec l'information "mountd access". Ce message est enregistré dans `/var/log/snort/alerts` et le vrai paquet responsable de l'alerte se trouvera dans un fichier dont le nom sera `/var/log/snort/snort.log.xxxxxxxxxx`.

Les fichiers log sont des fichiers binaires enregistrés en format pcap. Vous pouvez les ouvrir avec Wireshark ou les diriger directement sur la console avec la commande suivante :

```
tcpdump -r /var/log/snort/snort.log.xxxxxxxxxx
```

Vous pouvez aussi utiliser des captures Wireshark ou des fichiers snort.log.xxxxxxxxx comme source d'analyse por Snort.

## Exercises

**Réaliser des captures d'écran des exercices suivants et les ajouter à vos réponses.**

### Essayer de répondre à ces questions en quelques mots, en réalisant des recherches sur Internet quand nécessaire :

**Question 1: Qu'est ce que signifie les "preprocesseurs" dans le contexte de Snort ?**

---

**Réponse :** 
Les preprocesseurs dans le context de Snort sont les composants qui traitent les
paquets avant qu'ils ne soient traités par les règles.
Il y a par exemple un preprocesseur qui permet de détecter et réassembler 
les paquets fragmentés qui tentent d'éviter une détection. Ce preprocesseur 
s'appelle Frag2.

Le préprocesseurs est utile car certaines attaques ne peuvent pas être traitées
par le moteur de règles avant d'avoir étés transformées au préalables. C'est le
cas par exemple avec le traffic fragmenté.

---

**Question 2: Pourquoi êtes vous confronté au WARNING suivant `"No preprocessors configured for policy 0"` lorsque vous exécutez la commande `snort` avec un fichier de règles ou de configuration "fait-maison" ?**

---

**Réponse :**  

Car contrairement au fichier snort.conf, le fichier mysnort.conf ne charge aucun
preprocesseur. Snort nous indique donc qu'aucun preprocesseur n'est chargé pour 
la policy 0, mais fonctionne quand même sans traiter les paquets avant le set de 
règles que nous avons renseignées.

---

--

### Trouver du contenu :

Considérer la règle simple suivante:

alert tcp any any -> any any (msg:"Mon nom!"; content:"Rubinstein"; sid:4000015; rev:1;)

**Question 3: Qu'est-ce qu'elle fait la règle et comment ça fonctionne ?**

---

**Réponse :**  

La règle indique à snort de logger le message "Mon nom!" dans le fichier d'alert tous les paquets
tcp provenant de n'importe quelle ip source et port source vers n'importe quelle
ip de destination et port de destination si la payload contient la string 
"Rubinstein". 
La règle indique également que son sid est "4000015" et que c'est sa première version.

---

Utiliser nano pour créer un fichier `myrules.rules` sur votre répertoire home (```/root```). Rajouter une règle comme celle montrée avant mais avec votre text, phrase ou mot clé que vous aimeriez détecter. Lancer Snort avec la commande suivante :

```
sudo snort -c myrules.rules -i eth0
```

**Question 4: Que voyez-vous quand le logiciel est lancé ? Qu'est-ce que tous ces messages affichés veulent dire ?**

---

**Réponse :**  

Ce sont tous les éléments de configuration qui sont appliqués. On voit que la
plupart des éléments indiquent "none". La configuration s'initialise en fonction 
de ce qui est nécessaire pour pouvoir appliquer la règles que nous appliquons 
via notre fichier myrules.rules.

---

Aller à un site web contenant dans son text la phrase ou le mot clé que vous avez choisi (il faudra chercher un peu pour trouver un site en http... Si vous n'y arrivez pas, vous pouvez utiliser [http://neverssl.com](http://neverssl.com) et modifier votre votre règle pour détecter un morceau de text contenu dans le site).

Pour accéder à Firefox dans son conteneur, ouvrez votre navigateur web sur votre machine hôte et dirigez-le vers [http://localhost:4000](http://localhost:4000). Optionnellement, vous pouvez utiliser wget sur la machine client pour lancer la requête http ou le navigateur Web lynx - il suffit de taper ```lynx neverssl.com```. Le navigateur lynx est un navigateur basé sur text, sans interface graphique.

**Question 5: Que voyez-vous sur votre terminal quand vous chargez le site depuis Firefox ou la machine Client? **

---

**Réponse :**  

WARNING: No preprocessors configured for policy 0.
---

Arrêter Snort avec `CTRL-C`.

**Question 6: Que voyez-vous quand vous arrêtez snort ? Décrivez en détail toutes les informations qu'il vous fournit.**

---

**Réponse :**  

Snort fournit un compte rendu de ce qui a été détecté avec des statistiques et
chiffres.

```
===============================================================================
Run time for packet processing was 83.14207 seconds
Snort processed 271 packets.
Snort ran for 0 days 0 hours 1 minutes 23 seconds
   Pkts/min:          271
   Pkts/sec:            3
===============================================================================
Memory usage summary:
  Total non-mmapped bytes (arena):       4100096
  Bytes in mapped regions (hblkhd):      30265344
  Total allocated space (uordblks):      3349104
  Total free space (fordblks):           750992
  Topmost releasable block (keepcost):   593552
===============================================================================
Packet I/O Totals:
   Received:          282
   Analyzed:          271 ( 96.099%)
    Dropped:            0 (  0.000%)
   Filtered:            0 (  0.000%)
Outstanding:           11 (  3.901%)
   Injected:            0
===============================================================================
Breakdown by protocol (includes rebuilt packets):
        Eth:          271 (100.000%)
       VLAN:            0 (  0.000%)
        IP4:          265 ( 97.786%)
       Frag:            0 (  0.000%)
       ICMP:            0 (  0.000%)
        UDP:           58 ( 21.402%)
        TCP:          205 ( 75.646%)
        IP6:            0 (  0.000%)
    IP6 Ext:            0 (  0.000%)
   IP6 Opts:            0 (  0.000%)
      Frag6:            0 (  0.000%)
      ICMP6:            0 (  0.000%)
       UDP6:            0 (  0.000%)
       TCP6:            0 (  0.000%)
     Teredo:            0 (  0.000%)
    ICMP-IP:            0 (  0.000%)
    IP4/IP4:            0 (  0.000%)
    IP4/IP6:            0 (  0.000%)
    IP6/IP4:            0 (  0.000%)
    IP6/IP6:            0 (  0.000%)
        GRE:            0 (  0.000%)
    GRE Eth:            0 (  0.000%)
   GRE VLAN:            0 (  0.000%)
    GRE IP4:            0 (  0.000%)
    GRE IP6:            0 (  0.000%)
GRE IP6 Ext:            0 (  0.000%)
   GRE PPTP:            0 (  0.000%)
    GRE ARP:            0 (  0.000%)
    GRE IPX:            0 (  0.000%)
   GRE Loop:            0 (  0.000%)
       MPLS:            0 (  0.000%)
        ARP:            6 (  2.214%)
        IPX:            0 (  0.000%)
   Eth Loop:            0 (  0.000%)
   Eth Disc:            0 (  0.000%)
   IP4 Disc:            2 (  0.738%)
   IP6 Disc:            0 (  0.000%)
   TCP Disc:            0 (  0.000%)
   UDP Disc:            0 (  0.000%)
  ICMP Disc:            0 (  0.000%)
All Discard:            2 (  0.738%)
      Other:            0 (  0.000%)
Bad Chk Sum:          139 ( 51.292%)
    Bad TTL:            0 (  0.000%)
     S5 G 1:            0 (  0.000%)
     S5 G 2:            0 (  0.000%)
      Total:          271
===============================================================================
Action Stats:
     Alerts:            2 (  0.738%)
     Logged:            2 (  0.738%)
     Passed:            0 (  0.000%)
Limits:
      Match:            0
      Queue:            0
        Log:            0
      Event:            0
      Alert:            0
Verdicts:
      Allow:          271 ( 96.099%)
      Block:            0 (  0.000%)
    Replace:            0 (  0.000%)
  Whitelist:            0 (  0.000%)
  Blacklist:            0 (  0.000%)
     Ignore:            0 (  0.000%)
      Retry:            0 (  0.000%)
===============================================================================
Snort exiting

```
---


Aller au répertoire /var/log/snort. Ouvrir le fichier `alert`. Vérifier qu'il y ait des alertes pour votre text choisi.

**Question 7: A quoi ressemble l'alerte ? Qu'est-ce que chaque élément de l'alerte veut dire ? Décrivez-la en détail !**

---

**Réponse :**  

```
[**] [1:4000015:1] Mon Alert! [**]
[Priority: 0]
04/01-09:58:35.141221 188.184.21.108:80 -> 192.168.220.4:37524
TCP TTL:47 TOS:0x0 ID:7269 IpLen:20 DgmLen:930 DF
***AP*** Seq: 0x8F80B664  Ack: 0x4B6D1B37  Win: 0xEB  TcpLen: 32
TCP Options (3) => NOP NOP TS: 199862785 766923961

```
---
*[**] [1:4000015:1] Mon Alert! [**]*: Cette ligne indique le message d'alert ("Mon Alert!")
ainsi que la signature de l'intrusion ([1:4000015:1] ).

*[Priority: 0]*: Indique la priorité de l'attaque (0 indique un risque faible).

*04/01-09:58:35.141221*: Indique la date et l'heure de l'événement.

*188.184.21.108:80 -> 192.168.220.4:37524*: Indique les ip et ports sources / destination.

Le reste du message donne des indications sur le paquet qui a été observé
(comme le time-to-live par exemple).

--

### Detecter une visite à Wikipedia

Ecrire deux règles qui journalisent (sans alerter) chacune un message à chaque fois que Wikipedia est visité **SPECIFIQUEMENT DEPUIS VOTRE MACHINE CLIENT OU DEPUIS FIREFOX**. Chaque règle doit identifier quelle machine à réalisé la visite. Ne pas utiliser une règle qui détecte un string ou du contenu. Il faudra se baser sur d'autres paramètres.

**Question 8: Quelle est votre règle ? Où le message a-t'il été journalisé ? Qu'est-ce qui a été journalisé ?**

---

**Réponse :**  

En utilisant l'adresse IP d'un des serveur de Wikipedia: 

Règles Snort:

```
log tcp 192.168.220.4 any -> 91.198.174.194 any (msg:"Visite Wikipedia"; sid:40000020;)
log tcp 192.168.220.3 any -> 91.198.174.194 any (msg:"Visite Wikipedia"; sid:40000021;)
```


```
18:11:22.602624 IP ncredir-lb.esams.wikimedia.org.http > firefox.snortlan.57420: Flags [S.], seq 2827772920, ack 3857134510, win 43440, options [mss 1380,sackOK,TS val 2312190699 ecr 632067788,nop,wscale 9], length 0
18:11:22.622756 IP ncredir-lb.esams.wikimedia.org.http > firefox.snortlan.57420: Flags [.], ack 81, win 85, options [nop,nop,TS val 2312190720 ecr 632067810], length 0
18:11:22.622884 IP ncredir-lb.esams.wikimedia.org.http > firefox.snortlan.57420: Flags [P.], seq 1:382, ack 81, win 85, options [nop,nop,TS val 2312190721 ecr 632067810], length 381: HTTP: HTTP/1.1 301 Moved Permanently
18:11:22.623017 IP ncredir-lb.esams.wikimedia.org.http > firefox.snortlan.57420: Flags [F.], seq 382, ack 81, win 85, options [nop,nop,TS val 2312190721 ecr 632067810], length 0
18:11:22.642462 IP ncredir-lb.esams.wikimedia.org.http > firefox.snortlan.57420: Flags [.], ack 82, win 85, options [nop,nop,TS val 2312190740 ecr 632067830], length 0
18:11:22.649391 IP ncredir-lb.esams.wikimedia.org.https > firefox.snortlan.34522: Flags [S.], seq 3868483984, ack 620835916, win 43440, options [mss 1380,sackOK,TS val 1988530205 ecr 632067837,nop,wscale 9], length 0
18:11:22.681884 IP ncredir-lb.esams.wikimedia.org.https > firefox.snortlan.34522: Flags [.], ack 405, win 85, options [nop,nop,TS val 1988530236 ecr 632067868], length 0
18:11:22.682413 IP ncredir-lb.esams.wikimedia.org.https > firefox.snortlan.34522: Flags [.], seq 1:1369, ack 405, win 85, options [nop,nop,TS val 1988530237 ecr 632067868], length 1368
18:11:22.682601 IP ncredir-lb.esams.wikimedia.org.https > firefox.snortlan.34522: Flags [.], seq 1369:2737, ack 405, win 85, options [nop,nop,TS val 1988530237 ecr 632067868], length 1368
18:11:22.682636 IP ncredir-lb.esams.wikimedia.org.https > firefox.snortlan.34522: Flags [P.], seq 2737:4097, ack 405, win 85, options [nop,nop,TS val 1988530237 ecr 632067868], length 1360
18:11:22.682660 IP ncredir-lb.esams.wikimedia.org.https > firefox.snortlan.34522: Flags [P.], seq 4097:5163, ack 405, win 85, options [nop,nop,TS val 1988530238 ecr 632067868], length 1066
18:11:22.703095 IP ncredir-lb.esams.wikimedia.org.https > firefox.snortlan.34522: Flags [P.], seq 5163:5450, ack 485, win 85, options [nop,nop,TS val 1988530258 ecr 632067890], length 287
18:11:22.703297 IP ncredir-lb.esams.wikimedia.org.https > firefox.snortlan.34522: Flags [P.], seq 5450:5737, ack 485, win 85, options [nop,nop,TS val 1988530258 ecr 632067890], length 287
18:11:22.722510 IP ncredir-lb.esams.wikimedia.org.https > firefox.snortlan.34522: Flags [P.], seq 5737:6214, ack 587, win 85, options [nop,nop,TS val 1988530278 ecr 632067910], length 477
18:11:22.722760 IP ncredir-lb.esams.wikimedia.org.https > firefox.snortlan.34522: Flags [P.], seq 6214:6238, ack 587, win 85, options [nop,nop,TS val 1988530278 ecr 632067910], length 24
18:11:22.723062 IP ncredir-lb.esams.wikimedia.org.https > firefox.snortlan.34522: Flags [F.], seq 6238, ack 587, win 85, options [nop,nop,TS val 1988530278 ecr 632067910], length 0
18:11:22.743538 IP ncredir-lb.esams.wikimedia.org.https > firefox.snortlan.34522: Flags [R], seq 3868490223, win 0, length 0
```

Comme alternative nous avions utilisé les requêtes DNS avant d'utiliser
l'adresse IP de Wikipedia :
```
log udp 192.168.220.4 any -> any any (msg:"Visite Wikipedia"; content:"|09|wikipedia|03|org|00|"; nocase; sid: 4000020;)                                                                                    
log udp 192.168.220.3 any -> any any (msg:"Visite Wikipedia"; content:"|09|wikipedia|03|org|00|"; nocase; sid: 4000021;)
```

Contenu log /var/log/snort/snort.log.1649002876 :
(Ouvert avec tcpdump -r snort.log.xxxxx)

```
reading from file snort.log.1649002876, link-type EN10MB (Ethernet), snapshot
length 1514
16:21:19.278661 IP 192.168.220.4.34011 > 192.168.0.254.53: 28092+ A?  de.wikipedia.org. (34)
16:21:19.279651 IP 192.168.220.4.53315 > 192.168.0.254.53: 51316+ A?  de.wikipedia.org. (34)
16:21:19.524195 IP 192.168.220.4.54088 > 192.168.0.254.53: 3000+ A?  de.wikipedia.org. (34)
16:21:19.527678 IP 192.168.220.4.36888 > 192.168.0.254.53: 62228+ A?  de.wikipedia.org. (34)
16:21:19.565185 IP 192.168.220.4.52880 > 192.168.0.254.53: 18219+ A?  de.wikipedia.org. (34)
16:21:19.571523 IP 192.168.220.4.44068 > 192.168.0.254.53: 10498+ A?  de.wikipedia.org. (34)
16:21:19.575469 IP 192.168.220.4.43372 > 192.168.0.254.53: 43451+ A?  de.wikipedia.org. (34)
16:21:19.625311 IP 192.168.220.4.51885 > 192.168.0.254.53: 41987+ A?  de.wikipedia.org. (34)
16:21:19.665905 IP 192.168.220.4.56434 > 192.168.0.254.53: 45190+ A?  de.wikipedia.org. (34)
16:21:19.745752 IP 192.168.220.4.45628 > 192.168.0.254.53: 33157+ A?  de.wikipedia.org. (34)
```

On peut constater que le log contient:

- un timestamp de l'événement
- l'adresse IP source et destination
- le port source et destionation
- la requête DNS qui a été faite

---

--

### Détecter un ping d'un autre système

Ecrire une règle qui alerte à chaque fois que votre machine IDS **reçoit** un ping depuis une autre machine (n'import laquelle des autres machines de votre réseau). Assurez-vous que **ça n'alerte pas** quand c'est vous qui **envoyez** le ping depuis l'IDS vers un autre système !

**Question 9: Quelle est votre règle ?**

---

**Réponse :**  


```
alert icmp 192.168.220.0/24 any -> 192.168.220.2 any (msg:"Alerte ping recu"; sid: 4000022;)

ou

alert icmp any any -> 192.168.220.2 any (msg:"Alerte ping recu"; sid: 4000023;)

```

Résultat du fichier alert:

```

[**] [1:4000022:0] Alerte ping recu [**]
[Priority: 0]                                        
04/03-16:54:29.270623 192.168.220.3 -> 192.168.220.2                                                  
ICMP TTL:64 TOS:0x0 ID:39077 IpLen:20 DgmLen:84 DF
Type:8  Code:0  ID:59576   Seq:4  ECHO

[**] [1:4000022:0] Alerte ping recu [**]
[Priority: 0] 
04/03-16:54:46.198408 192.168.220.4 -> 192.168.220.2
ICMP TTL:64 TOS:0x0 ID:12740 IpLen:20 DgmLen:84 DF
Type:8  Code:0  ID:8628   Seq:0  ECHO
```

---


**Question 10: Comment avez-vous fait pour que ça identifie seulement les pings entrants ?**

---

**Réponse :**  

En précisent comme destination l'ip de l'IDS, soit 192.168.220.2 ainsi qu'avec
une flèche allant dans le sens source -> destination, oû la destination est l'IP de l'IDS.

---

**Question 11: Où le message a-t-il été journalisé ?**

---

**Réponse :**  

Dans /var/log/snort/alert

---

Les journaux sont générés en format pcap. Vous pouvez donc les lire avec Wireshark. Vous pouvez utiliser le conteneur wireshark en dirigeant le navigateur Web de votre hôte sur vers [http://localhost:3000](http://localhost:3000). Optionnellement, vous pouvez lire les fichiers log utilisant la commande `tshark -r nom_fichier_log` depuis votre IDS.

**Question 12: Qu'est-ce qui a été journalisé ? **

---

**Réponse :**  
On peut voir dans le log ci-dessous que les adresses ip sources et destination,
le protocol et le type de requetes sont loguées.

Contenu du fichier log:

```
1   0.000000 192.168.220.3 ? 192.168.220.2 ICMP 98 Echo (ping) request  id=0xe8b8, seq=1/256, ttl=64
2   1.008930 192.168.220.3 ? 192.168.220.2 ICMP 98 Echo (ping) request  id=0xe8b8, seq=2/512, ttl=64
3   2.033023 192.168.220.3 ? 192.168.220.2 ICMP 98 Echo (ping) request  id=0xe8b8, seq=3/768, ttl=64
4   3.057157 192.168.220.3 ? 192.168.220.2 ICMP 98 Echo (ping) request  id=0xe8b8, seq=4/1024, ttl=64
5  19.984942 192.168.220.4 ? 192.168.220.2 ICMP 98 Echo (ping) request  id=0x21b4, seq=0/0, ttl=64
6  20.985172 192.168.220.4 ? 192.168.220.2 ICMP 98 Echo (ping) request  id=0x21b4, seq=1/256, ttl=64
7  21.985403 192.168.220.4 ? 192.168.220.2 ICMP 98 Echo (ping) request  id=0x21b4, seq=2/512, ttl=64
```
---

--

### Detecter les ping dans les deux sens

Faites le nécessaire pour que les pings soient détectés dans les deux sens.

**Question 13: Qu'est-ce que vous avez fait pour détecter maintenant le trafic dans les deux sens ?**

---

**Réponse :**  

```
alert icmp 192.168.220.0/24 any -> 192.168.220.2 any (msg:"Ping vers IDS"; sid: 4000025;)
alert icmp 192.168.220.2 any -> 192.168.220.0/24 any (msg:"Ping depuis IDS"; sid: 4000026;)
```

Note: il est aussi possible d'utiliser l'opérateur bidirectionnel

---


--

### Detecter une tentative de login SSH

Essayer d'écrire une règle qui Alerte qu'une tentative de session SSH a été faite depuis la machine Client sur l'IDS.

**Question 14: Quelle est votre règle ? Montrer la règle et expliquer en détail comment elle fonctionne.**

---

**Réponse :**  

```
alert tcp 192.168.220.3 any -> 192.168.220.2 22 (msg: "Alerte SSH Client->IDS";sid :4000024;)
```

---


**Question 15: Montrer le message enregistré dans le fichier d'alertes.** 

---

**Réponse :**  

```

[**] [1:4000024:0] Alerte SSH Client->IDS [**]
[Priority: 0] 
04/07-04:53:45.221512 192.168.220.3:44850 -> 192.168.220.2:22
TCP TTL:64 TOS:0x10 ID:44837 IpLen:20 DgmLen:60 DF
******S* Seq: 0x56A9B316  Ack: 0x0  Win: 0xFAF0  TcpLen: 40
TCP Options (5) => MSS: 1460 SackOK TS: 3596258622 0 NOP WS: 7 
```

---

--

### Analyse de logs

Depuis l'IDS, servez-vous de l'outil ```tshark```pour capturer du trafic dans un fichier. ```tshark``` est une version en ligne de commandes de ```Wireshark```, sans interface graphique.

Pour lancer une capture dans un fichier, utiliser la commande suivante :

```
tshark -w nom_fichier.pcap
```

Générez du trafic depuis le deuxième terminal qui corresponde à l'une des règles que vous avez ajoutées à votre fichier de configuration personnel. Arrêtez la capture avec ```Ctrl-C```.

**Question 16: Quelle est l'option de Snort qui permet d'analyser un fichier pcap ou un fichier log ?**

---

**Réponse :**  

snort -r nom_fichier.pcap

---

Utiliser l'option correcte de Snort pour analyser le fichier de capture Wireshark que vous venez de générer.

**Question 17: Quelle est le comportement de Snort avec un fichier de capture ? Y-a-t'il une différence par rapport à l'analyse en temps réel ?**

---

**Réponse :**  

Snort affiche les logs puis un résumé du type du trafic et du nombre de
paquets. Le comportant est identique à celui en temps réel.

---

**Question 18: Est-ce que des alertes sont aussi enregistrées dans le fichier d'alertes?**

---

**Réponse :**  

Non étant donné que ce n'est pas Snort qui a été lancé pour faire la capture,
mais Tshark.

---

--

### Contournement de la détection

Faire des recherches à propos des outils `fragroute` et `fragrouter`.

**Question 19: A quoi servent ces deux outils ?**

---

**Réponse :**  

Ces outils servent à échapper aux systèmes de détection d'intrusion en
modifiant les paquets à destination d'une cible. Les paquets peuvent être
dupliqués, fragmentés, réordonnés, etc.

---


**Question 20: Quel est le principe de fonctionnement ?**

---

**Réponse :**  

Il est possible de configurer une machine pour qu'elle route son trafic au
travers de Fragrouter. On peut ensuite configurer Fragrouter pour que le trafic
à destination d'une certaine machine soit modifié de manière à correspondre à
une attaque dont le but est d'échapper aux systèmes de détection d'intrusion. Un
exemple d'attaque est de fragmenter les paquets en plusieurs petits paquets. Le
système d'intrusion analyse ainsi du trafic qui ne correspond pas exactement à
ce que la cible va recevoir, et n'est pas en mesure de détecter des attaques
sans au préalable ré assembler les paquets, s'il est capable de le faire et
s'il est configuré pour le faire.

---


**Question 21: Qu'est-ce que le `Frag3 Preprocessor` ? A quoi ça sert et comment ça fonctionne ?**

---

**Réponse :**  

Frag3 a pour but de défragmenter du trafic étant arrivé fragmenté et ce pour
contrer les techniques d'évasion de systèmes d'intrustion. Il fonctionne en
ré-assemblant les paquets qui ont été fragmentés. Cela permet ensuite d'appliquer
les règles du systèmes de détection d'intrusion sur le trafic défragmenté.

---


L'utilisation des outils ```Fragroute``` et ```Fragrouter``` nécessite une infrastructure un peu plus complexe. On va donc utiliser autre chose pour essayer de contourner la détection.

L'outil nmap propose une option qui fragmente les messages afin d'essayer de contourner la détection des IDS. Générez une règle qui détecte un SYN scan sur le port 22 de votre IDS.


**Question 22: A quoi ressemble la règle que vous avez configurée ?**

---

**Réponse :**  

En détectant le flag SYN:

```
alert tcp any any -> 192.168.220.2 22 (msg:"SYN Scan"; flags:S;sid:1000004;)

```

Note: il y a aussi le preprocesseur SFPORTSCAN qui permet de détecter des scans.

---


Ensuite, servez-vous du logiciel nmap pour lancer un SYN scan sur le port 22 depuis la machine Client :

```
nmap -sS -p 22 192.168.220.2
```
Vérifiez que votre règle fonctionne correctement pour détecter cette tentative. 

Ensuite, modifiez votre commande nmap pour fragmenter l'attaque :

```
nmap -sS -f -p 22 --send-eth 192.168.220.2
```

**Question 23: Quel est le résultat de votre tentative ?**

---

**Réponse :**  


En utilisant la fragmentation avec Nmap, Snort ne détecte plus le scan.

---


Modifier le fichier `myrules.rules` pour que snort utiliser le `Frag3 Preprocessor` et refaire la tentative.


**Question 24: Quel est le résultat ?**

---

**Réponse :**  


Snort est maintenant capable d'identifier le SYN scan de Nmap. Il indique aussi
dans son rapport les statistiques de Frag3 et les paquets qui ont été réassemblés.

---


**Question 25: A quoi sert le `SSL/TLS Preprocessor` ?**

---

**Réponse :**  


Ce préprocesseur sert à traiter le trafic afin de déterminer s'il s'agit de
trafic avec protocole SSL/TLS. Ce trafic étant chiffré, il n'y a pas de raison
que Snort l'inspecte car il ne pourra rien en tirer, en plus de consommer des
ressources inutilement.

---


**Question 26: A quoi sert le `Sensitive Data Preprocessor` ?**

---

**Réponse :**  


Ce préprocesseur sert à détecter des fuites de données sensibles, telles que des
numéros de carte de crédit ou des numéros de sécurité sociale, afin de les modifier, 
par exemple en remplaçant les premiers digits d'un numéro de carte de crédit par
des XXXX. Cela permet d'éviter que ces données sensibles sortent du réseau en
clair, par exemple en les ayant copié accidentellement dans un document.
Certaines données sont inclues de base et il est possible d'en rajouter des
règles personnalisées.

---

### Conclusions


**Question 27: Donnez-nous vos conclusions et votre opinion à propos de snort**

---

**Réponse :**  
 

Snort est un outil puissant de détection d'intrusion. C'est devenu le standard
de facto. Adoptant la philosophie Unix, il est possible de tout configurer et
customiser, ce qui en fait un outil très flexible. Les règles et la syntaxes de
base sont relativement simple à comprendre mais elles deviennent vite complexe
lorsqu'il faut créer des règles plus élaborée. La documentation n'est pas
évidente à comprendre et il manque souvent des exemples. Une des grandes forces
est la communauté qui fournis de nombreuses règles prêtes à l'emploi. Tout cela
fait qu'il est donc possible d'installer Snort sur un réseau avec une
configuration de base assez solide et tout cela à bas prix.

---

### Cleanup

Pour nettoyer votre système et effacer les fichiers générés par Docker, vous pouvez exécuter le script [cleanup.sh](scripts/cleanup.sh). **ATTENTION : l'effet de cette commande est irréversible***.


<sub>This guide draws heavily on http://cs.mvnu.edu/twiki/bin/view/Main/CisLab82014</sub>
