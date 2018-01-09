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
	 acl uptimerobot-acl path /uptimerobot.html

	 use_backend smokeping-backend if smokeping-acl
	 use_backend uptimerobot-backend if uptimerobot-acl
 	 default_backend www-backend

backend www-backend
	redirect scheme https if !{ ssl_fc }
	
backend smokeping-backend
	redirect scheme https if !{ ssl_fc }
	server www-smokeping 127.0.0.1:8888 check

backend uptimerobot-backend
	mode http
	errorfile 503 /etc/haproxy/errors/uptimerobot.http
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
$ docker create --name smokeping -p 8888:80 -e PUID=1000 -e PGID=1000 -e TZ=Europe/London -v `pwd`/smokeping/data:/data -v `pwd`/smokeping/config:/config linuxserver/smokeping
```

Install ~/.user-setup/systemd/docker-smokeping.service

# TO DO

* network setup
  * bind
  * dhcp static
  * smokeping
  * mrtg
  
