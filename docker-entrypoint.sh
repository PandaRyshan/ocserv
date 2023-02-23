#!/bin/bash

# Setup Timezone
if [ -v TZ ]; then
	echo $TZ > /etc/timezone
	export TZ
fi

# Create init config
if [ ! -f /etc/ocserv/ocserv.conf ]; then
	cat > ocserv.conf <<- EOCONF
	# authentication via linux user
	# auth = pam

	# authentication via passwd file
	auth = "plain[passwd=/etc/ocserv/ocpasswd]"

	tcp-port = 443
	udp-port = 443

	run-as-user = nobody
	run-as-group = daemon
	socket-file = /var/run/ocserv-socket

	max-clients = 100
	max-same-clients = 0
	try-mtu-discovery = true

	device = vpns

	ipv4-network = 192.168.99.0/24
	ipv4-netmask = 255.255.255.0

	route = default
	route = 192.168.99.0/24
	no-route = 10.0.0.0/8
	no-route = 100.64.0.0/10
	no-route = 169.254.0.0/16
	no-route = 192.0.0.0/24
	no-route = 192.168.0.0/16
	no-route = 224.0.0.0/24
	no-route = 240.0.0.0/4
	no-route = 172.16.0.0/12
	no-route = 127.0.0.0/8
	no-route = 255.255.255.255/32

	# tunnel all DNS queries via the VPN
	tunnel-all-dns = true

	dns = 1.1.1.1
	dns = 223.5.5.5
	dns = 8.8.8.8
	dns = 208.67.220.220

	# config file must as same as username or groupname
	# config-per-user = /etc/ocserv/config-per-user/
	# config-per-group = /etc/ocserv/config-per-group/

	cisco-client-compat = true
	ping-leases = false
	dtls-legacy = true

	use-occtl = true
	log-level = 1
	EOCONF

fi

# Create certificate
if [ ! -f /etc/ocserv/server.cert ]; then

	if [ -v EMAIL ] && [ -v DOMAIN ]; then

		# Create letsencrypt certificate
		if [ -f /etc/ocserv/cloudflare.ini ]; then
			certbot certonly --dns-cloudflare \
			--dns-cloudflare-credentials /etc/ocserv/cloudflare.ini --email $EMAIL -d $DOMAIN \
			--non-interactive --agree-tos
		else
			certbot certonly --non-interactive --agree-tos \
			--standalone --preferred-challenges http --agree-tos --email $EMAIL -d $DOMAIN
		fi
		# Start crond
		echo '15 00 * * * certbot renew --quiet && systemctl restart ocserv' > /var/spool/cron/crontabs/root
		service cron restart

	else

		# Create self signed certificate
		CA_CN="vpn.example.com"
		CA_ORG="CA_Organization"
		CA_DAYS=999
		SRV_CN="vpn.example.com"
		SRV_ORG="My_Organization"
		SRV_DAYS=999

		if [ -v DOMAIN ]; then
			CA_CN="$DOMAIN"
			SRV_CN="$DOMAIN"
		fi

		certtool --generate-privkey --outfile ca-key.pem
		cat > ca.tmpl <<-EOCA
		cn = "$CA_CN"
		organization = "$CA_ORG"
		serial = 1
		expiration_days = $CA_DAYS
		ca
		signing_key
		cert_signing_key
		crl_signing_key
		EOCA
		certtool --generate-self-signed --load-privkey ca-key.pem --template ca.tmpl --outfile ca.pem
		certtool --generate-privkey --outfile server-key.pem
		cat > server.tmpl <<-EOSRV
		cn = "$SRV_CN"
		organization = "$SRV_ORG"
		expiration_days = $SRV_DAYS
		signing_key
		encryption_key
		tls_www_server
		EOSRV
		certtool --generate-certificate --load-privkey server-key.pem --load-ca-certificate ca.pem --load-ca-privkey ca-key.pem --template server.tmpl --outfile server-cert.pem
		echo "server-cert = /etc/ocserv/server-cert.pem" >> ocserv.conf
		echo "server-key = /etc/ocserv/server-key.pem" >> ocserv.conf
	fi

	echo "server-cert = /etc/letsencrypt/live/$DOMAIN/fullchain.pem" >> /etc/ocserv/ocserv.conf
	echo "server-key = /etc/letsencrypt/live/$DOMAIN/privkey.pem" >> /etc/ocserv/ocserv.conf

fi

# Create init user
if [ ! -f /etc/ocserv/ocpasswd ]; then

	if [ ! -v USERNAME ] && [ ! -v USERPASS ]; then
		# Create specific user
		USERNAME='test'
		USERPASS=$(openssl rand -base64 14)
	else
		echo $USERPASS | echo $USERPASS | ocpasswd $USERNAME
	fi

	echo $USERPASS > $HOME/initial_pass.txt
	echo '----------------- User Generated ------------------'
	echo "User: $USERNAME"
	echo "Pass: $USERPASS"
	echo '--------------------------------------------------------'

fi

# Open ipv4 ip forward
#sysctl -w net.ipv4.ip_forward=1
echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
sysctl -p

# Enable NAT forwarding
# iptables -t nat -A POSTROUTING -j MASQUERADE
iptables -t nat -A POSTROUTING -s 192.168.99.0/24 -j SNAT --to-source $(hostname -I)
iptables -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu

# Enable TUN device
mkdir -p /dev/net
mknod /dev/net/tun c 10 200
chmod 600 /dev/net/tun

# Run OpennConnect Server
exec "$@"
