# Linux System Setup

## Make sudo passwordless

```
$ sudo visudo
# change lines to include NOPASSWD:

  # Allow members of group sudo to execute any command
  %sudo	ALL=(ALL:ALL) NOPASSWD: ALL
```

## Docker

```
$ sudo apt-get remove docker docker-engine docker.io
$ sudo apt-get update
$ sudo apt-get install pt-transport-https ca-certificates curl software-properties-common
$ curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
$ sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
$ sudo apt-get update
$ sudo apt-get install docker-ce
$ sudo usermod -aG docker $USER
```

## Useful packages

```
$ sudo -H apt install emacs25-nox mosh bc htop
$ sudo -H curl -L https://github.com/docker/compose/releases/download/1.18.0/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
$ sudo -H chmod +x /usr/local/bin/docker-compose
```

## HAProxy with LetsEncrypt

### Domains

#### /etc/haproxy/domains

This file contains the list of domain we want Let's Encrypt certificates for.

*We will need to add DNS TXT records when LE creates certicates.*

```
neil.jarvis.name
*.neil.jarvis.name
*.internal.neil.jarvis.name
*.portal.neil.jarvis.name
```

### Install haproxy

```
$ sudo apt-get install haproxy
$ sudo systemctl restart rsyslog
$ sudo systemctl restart hqproxy  # To get logging working
$ sudo mkdir /etc/haproxy/certs
```

### Install Let's Encrypt

https://www.digitalocean.com/community/tutorials/how-to-secure-haproxy-with-let-s-encrypt-on-ubuntu-14-04

```
$ sudo add-apt-repository ppa:certbot/certbot
$ sudo apt-get update
$ sudo apt-get install certbot
```

#### /etc/haproxy/le-update

This script creates or updates certificates for domains read from `/etc/haproxy/domains`

```
#!/bin/bash

DOMAIN_FILE=${1:-/etc/haproxy/domains}

DOMAINS=$(awk '{printf "-d %s ", $0}' $DOMAIN_FILE)

certbot certonly --manual --agree-tos --manual-public-ip-logging-ok --preferred-challenges dns --server https://acme-v02.api.letsencrypt.org/directory $DOMAINS --pre-hook "systemctl stop haproxy docker-unifi" --post-hook "systemctl start docker-unifi haproxy" --deploy-hook "cat \$RENEWED_LINEAGE/fullchain.pem \$RENEWED_LINEAGE/privkey.pem > /etc/haproxy/certs/\$(echo \$RENEWED_DOMAINS | awk '{print \$1}').pem; cp \$RENEWED_LINEAGE/fullchain.pem $USER/unifi/cert/chain.pem; cp \$RENEWED_LINEAGE/privkey.pem $USER/unifi/cert/; cp \$RENEWED_LINEAGE/cert.pem $USER/unifi/cert/"
```

It does this by requesting TXT records for the listed domains, and expecting you to have added the random data string it states.

#### /etc/haproxy/le-renew

This script renews any certificates we have created; it can be called from a crontab entry.

```
#!/bin/bash

certbot renew --pre-hook "systemctl stop haproxy docker-unifi" --post-hook "systemctl start docker-unifi haproxy" --deploy-hook "cat \$RENEWED_LINEAGE/fullchain.pem \$RENEWED_LINEAGE/privkey.pem > /etc/haproxy/certs/\$(echo \$RENEWED_DOMAINS | awk '{print \$1}').pem; cp \$RENEWED_LINEAGE/fullchain.pem $USER/unifi/cert/chain.pem; cp \$RENEWED_LINEAGE/privkey.pem $USER/unifi/cert/; cp \$RENEWED_LINEAGE/cert.pem $USER/unifi/cert/"
```

User root crontab entry

```
30 2 * * * /etc/haproxy/le-renew >> /var/log/le-renew-haproxy.log
```

### Setup haproxy

#### /etc/haproxy/haproxy.cfg

```
global
	log /dev/log	local0
	log /dev/log	local1 notice
	chroot /var/lib/haproxy
	stats socket /run/haproxy/admin.sock mode 660 level admin
	stats timeout 30s
	user haproxy
	group haproxy
	maxconn 2048
	daemon

	# Default SSL material locations
	ca-base /etc/ssl/certs
	crt-base /etc/ssl/private

	# Default ciphers to use on SSL-enabled listening sockets.
	# For more information, see ciphers(1SSL). This list is from:
	#  https://hynek.me/articles/hardening-your-web-servers-ssl-ciphers/
	ssl-default-bind-ciphers ECDH+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:RSA+AESGCM:RSA+AES:!aNULL:!MD5:!DSS:!3DES
	ssl-default-bind-options no-sslv3
	tune.ssl.default-dh-param 2048

userlist admin
	 # python3 -c 'import crypt; print(crypt.crypt("XXXXXXXX", crypt.mksalt(crypt.METHOD_SHA512)))'
 	 user njarvis password ***
	 
defaults
	log	global
	mode	http
	option	httplog
	option	dontlognull
	option  forwardfor
	option  http-server-close
        timeout connect 5000
        timeout client  50000
        timeout server  50000
	errorfile 400 /etc/haproxy/errors/400.http
	errorfile 403 /etc/haproxy/errors/403.http
	errorfile 408 /etc/haproxy/errors/408.http
	errorfile 500 /etc/haproxy/errors/500.http
	errorfile 502 /etc/haproxy/errors/502.http
	errorfile 503 /etc/haproxy/errors/503.http
	errorfile 504 /etc/haproxy/errors/504.http

frontend www-frontend
	 bind ipv6@:80 v4v6
	 bind ipv6@:443 v4v6 ssl crt /etc/haproxy/certs/neil.jarvis.name.pem

	 reqadd X-Forwarded-Proto:\ http if !{ ssl_fc }
	 reqadd X-Forwarded-Proto:\ https if { ssl_fc }

	 acl smokeping-acl path_beg /smokeping/
	 acl grafana-acl path_beg /grafana
	 acl uptimerobot-acl path /uptimerobot.html
	 acl gw-acl hdr_beg(host) -i gw.internal.
	 acl unifi-acl hdr_beg(host) -i unifi.internal.
	 acl unifi-video-acl hdr_beg(host) -i unifi-video.internal.
	 acl openvpn-acl hdr_beg(host) -i openvpn.internal.
	 acl qnapa-acl hdr_beg(host) -i qnapa.internal.
	 acl homebridge-acl hdr_beg(host) -i homebridge.internal.
	 acl wp-acl hdr_beg(host) -i www.

	 use_backend smokeping-backend if smokeping-acl
	 use_backend grafana-backend if grafana-acl
	 use_backend uptimerobot-backend if uptimerobot-acl
	 use_backend gw-backend if gw-acl { ssl_fc }
	 use_backend unifi-backend if unifi-acl { ssl_fc }
	 use_backend unifi-video-backend if unifi-video-acl { ssl_fc }
	 use_backend openvpn-backend if openvpn-acl { ssl_fc }
	 use_backend qnapa-backend if qnapa-acl { ssl_fc }
	 use_backend homebridge-backend if homebridge-acl { ssl_fc }
	 use_backend wp-backend if wp-acl { ssl_fc }
 	 default_backend www-backend

listen stats
       bind :9876
       mode http
       stats enable
       stats uri /haproxy?stats
       stats auth admin:***password-for-stats***
       stats refresh 5s

backend www-backend
	
backend smokeping-backend
	redirect scheme https if !{ ssl_fc }
	server www-smokeping 127.0.0.1:8888 check

backend grafana-backend
	redirect scheme https if !{ ssl_fc }
	reqrep ^([^\ ]*\ /)grafana[/]?(.*) \1\2
	server www-grafana 127.0.0.3:3000 check

backend uptimerobot-backend
	mode http
	errorfile 503 /etc/haproxy/errors/uptimerobot.http

backend gw-backend
	acl auth_admin_ok http_auth(admin)
	http-request auth realm NeilJarvisName if !auth_admin_ok

	server www-gw 10.10.10.1:80 check

backend unifi-backend
	server www-unifi 127.0.0.1:8443 check ssl verify required ca-file ca-certificates.crt

backend unifi-video-backend
	server www-unifi-video 127.0.0.1:7080 check

backend openvpn-backend
	acl auth_admin_ok http_auth(admin)
	http-request auth realm NeilJarvisName if !auth_admin_ok

	server www-openvpn 10.10.10.5:943 check ssl verify none

backend qnapa-backend
	acl auth_admin_ok http_auth(admin)
	http-request auth realm NeilJarvisName if !auth_admin_ok

	server www-qnapa 10.10.10.11:443 check ssl verify none

backend wp-backend
	acl auth_admin_ok http_auth(admin)
	http-request auth realm NeilJarvisName if !auth_admin_ok

	server www-wp 127.0.0.2:8889 check

backend homebridge-backend
	acl auth_admin_ok http_auth(admin)
	acl is_websocket hdr(Upgrade) -i WebSocket
  
	http-request auth realm NeilJarvisName if !auth_admin_ok !is_websocket

	server www-homebridge 127.0.0.1:8901 check
```

#### /etc/haproxy/errors/uptimerobot.http

A fake web page served to requests made by uptimerobot.com

```
HTTP/1.0 200 Found
Cache-Control: no-cache
Connection: close
Content-Type: text/html

<html>
<head>
<title>Up</title>
</head>
<body>
<p>Up</p>
</body>
</html>
```

## Smokeping docker

```
$ mkdir -p $HOME/smokeping/data $HOME/smokeping/config
$ docker create --name smokeping -p 8888:80 -e PUID=1000 -e PGID=1000 -e TZ=Europe/London -v $HOME/smokeping/data:/data -v $HOME/smokeping/config:/config linuxserver/smokeping
$ sudo cp ~/.user-setup/systemd/docker-smnokeping.service /lib/systemd/system
$ sudo systemctl enable docker-smokeping
$ sudo systemctl start docker-smokeping
```

## UniFi docker (jacobalberty/unifi)

### Create

```
$ mkdir -p $HOME/unifi
$ docker create --name=unifi --net=host -v $HOME/unifi:/unifi -p 8080:8080 -p 8443:8443 -p 3478:3478/udp -p 10001:10001/udp -p 8843:8843 -p 8880:8880 -p 6789:6789/tcp -e TZ='Europe/London' -e RUNAS_UID0=false -e UNIFI_UID=1000 -e UNIFI_GID=1000 jacobalberty/unifi:stable
$ sudo cp ~/.user-setup/systemd/docker-unifi.service /lib/systemd/system
$ sudo systemctl enable docker-unifi-video
$ sudo systemctl start docker-unifi-video
```

### Update

```
sudo systemctl stop docker-unifi.service
docker pull jacobalberty/unifi:stable
docker rm unifi
docker create --name=unifi --net=host -v $HOME/unifi:/unifi -p 8080:8080 -p 8443:8443 -p 3478:3478/udp -p 10001:10001/udp -p 8843:8843 -p 8880:8880 -p 6789:6789/tcp -e TZ='Europe/London' -e RUNAS_UID0=false -e UNIFI_UID=1000 -e UNIFI_GID=1000 jacobalberty/unifi:stable
sudo systemctl start docker-unifi.service
sudo systemctl restart haproxy
```

## OLD: UniFi docker (linuxserver/unifi)

```
$ mkdir -p $HOME/unifi
$ docker create --name=unifi -v $HOME/unifi:/config -e PGID=1000 -e PUID=1000 -p 3478:3478/udp -p 10001:10001/udp -p 8080:8080 -p 8081:8081 -p 8443:8443 -p 8843:8843 -p 8880:8880 linuxserver/unifi
$ sudo cp ~/.user-setup/systemd/docker-unifi.service /lib/systemd/system
$ sudo systemctl enable docker-unifi
$ sudo systemctl start docker-unifi
```

## UniFi video docker

### Create

```
$ mkdir -p $HOME/unifi-video/videos
$ docker create --name unifi-video --security-opt apparmor:unconfined --cap-add SYS_ADMIN --cap-add DAC_READ_SEARCH -p 10001:10001 -p 1935:1935 -p 6666:6666 -p 7080:7080 -p 7442:7442 -p 7443:7443 -p 7444:7444 -p 7445:7445 -p 7446:7446 -p 7447:7447 -v $HOME/unifi-video:/var/lib/unifi-video -v $HOME/unifi-video/videos:/var/lib/unifi-video/videos -e TZ=Europe/London -e PUID=1000 -e PGID=1000 -e DEBUG=1 pducharme/unifi-video-controller
$ sudo cp ~/.user-setup/systemd/docker-unifi-video.service /lib/systemd/system
$ sudo systemctl enable docker-unifi-video
$ sudo systemctl start docker-unifi-video
```

### Update

```
$ sudo systemctl stop docker-unifi-video.service
$ docker pull pducharme/unifi-video-controller
$ docker rm unifi-video
$ docker create --name unifi-video --security-opt apparmor:unconfined --cap-add SYS_ADMIN --cap-add DAC_READ_SEARCH -p 10001:10001 -p 1935:1935 -p 6666:6666 -p 7080:7080 -p 7442:7442 -p 7443:7443 -p 7444:7444 -p 7445:7445 -p 7446:7446 -p 7447:7447 -v $HOME/unifi-video:/var/lib/unifi-video -v $HOME/unifi-video/videos:/var/lib/unifi-video/videos -e TZ=Europe/London -e PUID=1000 -e PGID=1000 -e DEBUG=1 pducharme/unifi-video-controller
$ sudo systemctl start docker-unifi-video.service
```

## OpenVPN Access Server

### Create

```
$ mkdir openvpn
$ docker create --name=openvpn-as -v $HOME/openvpn:/config -e PGID=1000 -e PUID=1000 -e TZ=Europe/London -e INTERFACE=enp1s0 --net=host --privileged linuxserver/openvpn-as
$ sudo cp ~/.user-setup/systemd/docker-openvpn.service /lib/systemd/system
$ sudo systemctl enable docker-openvpn
$ sudo systemctl start docker-openvpn
```

### Update

```
$ sudo systemctl stop docker-openvpn.service
$ docker pull linuxserver/openvpn-as
$ docker rm openvpn-as
$ docker create --name=openvpn-as -v $HOME/openvpn:/config -e PGID=1000 -e PUID=1000 -e TZ=Europe/London -e INTERFACE=enp1s0 --net=host --privileged linuxserver/openvpn-as
$ sudo systemctl start docker-openvpn.service
```

## Prometheus + exporters

```
$ cd ~
$ mkdir -p prometheus/data
$ chmod 777 prometheus/data
```

### $HOME/prometheus/prometheus.yml

```
global:
  scrape_interval:     15s
  evaluation_interval: 15s

rule_files:
  # - "first.rules"
  # - "second.rules"

scrape_configs:
  - job_name: prometheus
    static_configs:
      - targets: ['localhost:9090']

  - job_name: haproxy
    static_configs:
      - targets: ['10.10.10.5:9101']

  - job_name: cAdvisor
    static_configs:
      - targets: ['10.10.10.5:9105']
```

Enable stats in haproxy

### /etc/haproxy/haproxy.cfg

```
listen stats
       bind :9876
       mode http
       stats enable
       stats uri /haproxy?stats
       stats auth admin:***password-for-stats***
       stats refresh 5s
```

Start exporters and prometheus

```
$ sudo docker run --volume=/:/rootfs:ro --volume=/var/run:/var/run:rw --volume=/sys:/sys:ro --volume=/var/lib/docker/:/var/lib/docker:ro --publish=9105:8080 --name=cadvisor --restart=always --detach=true google/cadvisor:latest
$ docker run -p 9101:9101 -d --restart=always --name=haproxy-exporter prom/haproxy-exporter --haproxy.scrape-uri="http://admin:sediment-riyal-abutment-aloud-tyrant-fief@10.10.10.5:9876/haproxy?stats;csv"
$ docker run -d --restart=always --name prometheus -p 9090:9090 -v $HOME/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml -v $HOME/prometheus/data:/prometheus prom/prometheus
```

## fail2ban

```
$ sudo -H apt install monit python-pyinotify-doc fail2ban
```

Set more verbose actions

### /etc/fail2ban/jail.d/defaults-debian.conf

```
[sshd]
enabled = true
action = %(action_mwl)s
```

Add haproxy support to fail2ban

### /etc/fail2ban/filter.d/haproxy.conf

```
[INCLUDES]

# Read common prefixes. If any customizations available -- read them from
# apache-common.local
before = common.conf

[Definition]

__daemon = haproxy
failregex = ^%(__prefix_line)s<HOST>.*?\s4[0-9][0-9]\s.*$
	    ^%(__prefix_line)s<HOST>.*?\s5[0-9][0-9]\s.*$

ignoreregex = ^%(__prefix_line)s<HOST>.*?\s5[0-9][0-9].*?"(?:HEAD|GET) /uptimerobot.html HTTP/1.1"\s*$

# Mar 26 09:00:37 atom haproxy[1653]: ::ffff:10.10.10.1:56952 [26/Mar/2018:09:00:37.668] www-frontend~ homebridge-backend/<NOSRV> -1/-1/-1/-1/2 401 258 - - PR-- 0/0/0/0/3 0/0 "GET /apple-touch-icon-precomposed.png HTTP/1.1"
```

### /etc/fail2ban/jail.d/haproxy.conf

```
[haproxy]
enabled = true

bantime  = 1200
findtime = 120
maxretry = 4
logpath  = /var/log/haproxy.log
port     = http,https
ignoreip = 127.0.0.1/8 10.10.10.1/32

action = %(action_mwl)s
```

## Dropbox

```
$ cd ~ && wget -O - "https://www.dropbox.com/download?plat=lnx.x86_64" | tar xzf -
$ wget -O ~/bin/dropbox.py https://www.dropbox.com/download?dl=packages/dropbox.py
$ chmod +x ~/bin/dropbox.py
$ ~/.dropbox-dist/dropboxd
```

Follow URL displayed to link the server to your account.

To enable on reboot:

```
$ crontab -e
# Add the following line
@reboot $HOME/.dropbox-dist/dropboxd
```

## Python versions and pew

```
$ sudo -H apt-get install build-essential zlib1g-dev libbz2-dev libssl-dev libreadline-dev libncurses5-dev libsqlite3-dev libgdbm-dev libdb-dev libexpat-dev libpcap-dev liblzma-dev libpcre3-dev
$ curl -kL https://raw.github.com/saghul/pythonz/master/pythonz-install | bash
$ sudo -H pip install pew
```

Build specific versions of Python, with dynamic library support

```
$ LDFLAGS="-Wl,-rpath,$HOME/.pythonz/pythons/CPython-2.7.14/lib" pythonz install --reinstall --shared 2.7.14
$ LDFLAGS="-Wl,-rpath,$HOME/.pythonz/pythons/CPython-3.5.4/lib" pythonz install --reinstall --shared 3.5.4
$ LDFLAGS="-Wl,-rpath,$HOME/.pythonz/pythons/CPython-3.6.4/lib" pythonz install --shared 3.6.4
```

Create new pew virtualenv for a specific Python version

```
pew new -d -p $(pythonz locate 2.7.14) -i setuptools_scm -i tox -i invoke py27
pew new -d -p $(pythonz locate 3.5.4) -i setuptools_scm -i tox -i invoke py35
pew new -d -p $(pythonz locate 3.6.4) -i setuptools_scm -i tox -i invoke py36
```

## Build tmux from source

```
$ sudo -H apt install automake libevent-dev pkg-config libutempter-dev libncurses-dev
$ git clone https://github.com/tmux/tmux.git
$ cd tmux
$ sh autogen.sh
$ ./configure --enable-utempter && make
$ mkdir -p ~/bin/$(uname -m)
$ cp ./tmux ~/bin/$(uname -m)
```

## FZF

Command line fuzzy finder: https://github.com/junegunn/fzf

```
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
~/.fzf/install
```

