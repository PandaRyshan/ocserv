#!/bin/bash

# Create init config
if [ ! -f /etc/ocserv/ocserv.conf ]; then
	cat > ocserv.conf <<- EOCONF
	auth = "plain[passwd=/etc/ocserv/ocpasswd]"
	tcp-port = 443
	udp-port = 443
	run-as-user = nobody
	run-as-group = daemon
	socket-file = /var/run/ocserv-socket
	max-clients = 50
	max-same-clients = 0
	try-mtu-discovery = true
	device = vpns
	ipv4-network = 192.168.99.0/24
	ipv4-netmask = 255.255.255.0
	dns = 1.1.1.1
	dns = 114.114.114.114
	dns = 8.8.8.8
	dns = 208.67.222.222
	cisco-client-compat = true
	ping-leases = false
	dtls-legacy = true
	EOCONF

	# Create certificate offline
	if [ -z "$DOMAIN" ]; then
		CA_CN="vpn.example.com"
		CA_ORG="CA_Organization"
		CA_DAYS=9999
		SRV_CN="vpn.example.com"
		SRV_ORG="My_Organization"
		SRV_DAYS=9999

		# No certification found, generate one
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
	else
		# Create letsencrypt certificate
		if [ -z "$EMAIL" ]; then
      EMAIL="foo@example.com"
		fi
		if [ -f /etc/letsencrypt/cloudflare.ini ]; then
      certbot certonly --dns-cloudflare \
      --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.ini \
      --email $EMAIL -d $DOMAIN \
      --non-interactive --agree-tos
		else
      certbot certonly --non-interactive --agree-tos \
      --standalone --preferred-challenges http --agree-tos --email $EMAIL -d $DOMAIN
		fi

		echo "server-cert = /etc/letsencrypt/live/$DOMAIN/fullchain.pem" >> /etc/ocserv/ocserv.conf
		echo "server-key = /etc/letsencrypt/live/$DOMAIN/privkey.pem" >> /etc/ocserv/ocserv.conf

		# Start crond
		echo '15 00 * * * certbot renew --quiet && systemctl restart ocserv' > /var/spool/cron/crontabs/$USER
		service cron restart
	fi
	echo 'Certificate is generated.'
fi

# Create specific user
if [ ! -z "$USERNAME" ] && [ ! -z "$USERPASS" ]; then
	echo "$USERPASS" | echo "$USERPASS" | ocpasswd "$USERNAME"
fi

# Create init test user
if [ ! -f /etc/ocserv/ocpasswd ]; then
	openssl rand -base64 14 > /home/$USERNAME/pass.txt
	cat /home/$USERNAME/pass.txt | cat /home/$USERNAME/pass.txt | ocpasswd "test"
	echo '----------------- Test User Generated ------------------'
	echo 'User: test'
	echo "Pass: $(cat /home/$USERNAME/pass.txt)"
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
