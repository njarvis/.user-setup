# Server Setup

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
$ sudo -H apt emacs24-nox mosh bc htop
$ sudo -H curl -L https://github.com/docker/compose/releases/download/1.18.0/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
$ sudo -H chmod +x /usr/local/bin/docker-compose

```

## HAProxy with LetsEncrypt

https://www.digitalocean.com/community/tutorials/how-to-secure-haproxy-with-let-s-encrypt-on-ubuntu-14-04

```
$ sudo add-apt-repository ppa:certbot/certbot
$ sudo apt-get update
$ sudo apt-get install certbot

$ sudo certbot certonly --standalone --preferred-challenges http --http-01-port 80 -d neil.jarvis.name -d www.neil.jarvis.name -d home.neil.jarvis.name

```

Install haproxy

```
$ sudo apt-get install haproxy
$ sudo systemctl restart rsyslog
$ sudo systemctl restart hqproxy  # To get logging working
```

Setup

```
$ sudo mkdir /etc/haproxy/certs
$ DOMAIN='neil.jarvis.name' sudo -E bash -c 'cat /etc/letsencrypt/live/$DOMAIN/fullchain.pem /etc/letsencrypt/live/$DOMAIN/privkey.pem > /etc/haproxy/certs/$DOMAIN.pem'
$ sudo chmod -R go-rwx /etc/haproxy/certs
```

/etc/haproxy/haproxy.cfg

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
 	 user njarvis password $6$P5nsTB6sTB7Ywj7a$wdGp5WyUkKVfln2FfrutJ2gUldTdxpGCe69FCVJqMx6oUisTK1y0NwsA7zRN3eerIm54JQfxXtI3NS.6kgsgv1
	 
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
	 acl openvpn-acl hdr_beg(host) -i openvpn.internal.
	 acl qnapa-acl hdr_beg(host) -i qnapa.internal.
	 acl homebridge-acl hdr_beg(host) -i homebridge.internal.
	 acl wp-acl hdr_beg(host) -i www.

	 use_backend smokeping-backend if smokeping-acl
	 use_backend grafana-backend if grafana-acl
	 use_backend uptimerobot-backend if uptimerobot-acl
	 use_backend gw-backend if gw-acl { ssl_fc }
	 use_backend unifi-backend if unifi-acl { ssl_fc }
	 use_backend openvpn-backend if openvpn-acl { ssl_fc }
	 use_backend qnapa-backend if qnapa-acl { ssl_fc }
	 use_backend homebridge-backend if homebridge-acl { ssl_fc }
	 use_backend wp-backend if wp-acl { ssl_fc }
 	 default_backend www-backend

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
	acl auth_admin_ok http_auth(admin)
	http-request auth realm NeilJarvisName if !auth_admin_ok

	server www-unifi 127.0.0.1:8443 check ssl verify none

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

/etc/haproxy/errors/uptimerobot.http

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

/etc/haproxy/domains

```
neil.jarvis.name
home.neil.jarvis.name
www.neil.jarvis.name
gw.internal.neil.jarvis.name
unifi.internal.neil.jarvis.name
openvpn.internal.neil.jarvis.name
qnapa.internal.neil.jarvis.name
homebridge.internal.neil.jarvis.name
```

/etc/haproxy/le-update

```
#!/bin/bash

DOMAIN_FILE=${1:-/etc/haproxy/domains}

DOMAINS=$(awk '{printf "-d %s ", $0}' $DOMAIN_FILE)

certbot certonly --standalone --preferred-challenges http --http-01-port 80 $DOMAINS --pre-hook "systemctl stop haproxy" --post-hook "systemctl start haproxy" --deploy-hook "cat \$RENEWED_LINEAGE/fullchain.pem \$RENEWED_LINEAGE/privkey.pem > /etc/haproxy/certs/\$(echo \$RENEWED_DOMAINS | awk '{print \$1}').pem"
```

/etc/haproxy/le-renew

```
#!/bin/bash

certbot renew --pre-hook "systemctl stop haproxy" --post-hook "systemctl start haproxy" --deploy-hook "cat \$RENEWED_LINEAGE/fullchain.pem \$RENEWED_LINEAGE/privkey.pem > /etc/haproxy/certs/\$(echo \$RENEWED_DOMAINS | awk '{print \$1}').pem"
```

Root crontab entry

```
30 2 * * * /etc/haproxy/le-renew >> /var/log/le-renew-haproxy.log
```

## Smokeping docker

```
$ mkdir -p $HOME/smokeping/data $HOME/smokeping/config
$ docker create --name smokeping -p 8888:80 -e PUID=1000 -e PGID=1000 -e TZ=Europe/London -v $HOME/smokeping/data:/data -v $HOME/smokeping/config:/config linuxserver/smokeping
```

Install ~/.user-setup/systemd/docker-smokeping.service

## UniFi docker

```
$ mkdir -p $HOME/unifi
$ docker create --name=unifi -v $HOME/unifi:/config -e PGID=1000 -e PUID=1000 -p 3478:3478/udp -p 10001:10001/udp -p 8080:8080 -p 8081:8081 -p 8443:8443 -p 8843:8843 -p 8880:8880 linuxserver/unifi
```

Install ~/.user-setup/systemd/docker-unifi.service

## OpenVPN Access Server

```
$ mkdir openvpn
$ docker create --name=openvpn-as -v $HOME/openvpn:/config -e PGID=1000 -e PUID=1000 -e TZ=Europe/London -e INTERFACE=enp1s0 --net=host --privileged linuxserver/openvpn-as
```

Install ~/.user-setup/systemd/docker-openvpn.service

## fail2ban

```
$ sudo -H apt install monit python-pyinotify-doc fail2ban
```

### Set more verbose actions

/etc/fail2ban/jail.d/defaults-debian.conf

```
[sshd]
enabled = true
action = %(action_mwl)s
```

### fail2ban for haproxy

/etc/fail2ban/filter.d/haproxy.conf

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

/etc/fail2ban/jail.d/haproxy.conf

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

# TO DO

* network setup
  * bind
  * dhcp static
  * smokeping
  * mrtg

