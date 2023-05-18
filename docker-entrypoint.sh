#!/bin/bash

# Wait for other container
/wait

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

	# disable ssl3 tls1.0 tls1.1
	tls-priorities = "NORMAL:%SERVER_PRECEDENCE:%COMPAT:-RSA:-VERS-SSL3.0:-VERS-TLS1.0:-VERS-TLS1.1"

	device = vpns

	ipv4-network = 192.168.100.0/24
	ipv4-netmask = 255.255.255.0

	route = default
	route = 192.168.0.0/24
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
	dns = 8.8.8.8

	# config file must as same as username or groupname
	config-per-user = /etc/ocserv/config-per-user/
	config-per-group = /etc/ocserv/config-per-group/
	predictable-ips = true

	# let ocserv to obtain information on the incoming session from loadbalancer
	keepalive = 300

	# uncomment below if you are using haproxy
	# listen-proxy-proto = true

	ping-leases = false
	match-tls-dtls-ciphers = true
	# if you want to support older version cisco clients, uncomment the following line
	# dtls-legacy = true
	# cisco-client-compat = true

	use-occtl = true
	log-level = 1
	EOCONF

fi

# Create certs if no local or letsencrypt certs
if [ ! -f /etc/ocserv/server.cert ] && [ ! -f /etc/letsencrypt/live/$DOMAIN/fullchain.pem ]; then

	if [ -z DOMAIN ]; then

		# Create self signed certificate
		CN="vpn.example.com"
		ORG="Organization"
		DAYS=3650
		IP=$(curl -s ipinfo.io/ip)

		certtool --generate-privkey --outfile ca-key.pem
		cat > ca.tmpl <<-EOCA
		cn = "$CN"
		organization = "$ORG"
		serial = 1
		expiration_days = $DAYS
		ca
		signing_key
		cert_signing_key
		crl_signing_key
		EOCA
		certtool --generate-self-signed --load-privkey ca-key.pem --template ca.tmpl --outfile ca.pem
		certtool --generate-privkey --outfile server-key.pem
		cat > server.tmpl <<-EOSRV
		cn = "$CN"
		organization = "$ORG"
    serial = 2
		expiration_days = $DAYS
		signing_key
		encryption_key
		tls_www_server
		# dns_name = "<your-hostname>"
		ip_address = "$IP"
		EOSRV
		certtool --generate-certificate --load-privkey server-key.pem --load-ca-certificate ca.pem --load-ca-privkey ca-key.pem --template server.tmpl --outfile server-cert.pem
		echo "server-cert = /etc/ocserv/server-cert.pem" >> ocserv.conf
		echo "server-key = /etc/ocserv/server-key.pem" >> ocserv.conf

	else

		if [ -z EMAIL ]; then
			EMAIL="foo@example.com"
		fi

		# Create letsencrypt certificate
		if [ -f /etc/ocserv/cloudflare.ini ]; then
			certbot certonly --dns-cloudflare \
			--dns-cloudflare-credentials /etc/ocserv/cloudflare.ini --email $EMAIL -d $DOMAIN \
			--non-interactive --agree-tos
		else
			certbot certonly --non-interactive --agree-tos \
			--standalone --preferred-challenges http --agree-tos --email $EMAIL -d $DOMAIN
		fi

		cron_file="/var/spool/cron/crontabs/root"
		cron_config='15 00 * * * certbot renew --quiet && systemctl restart ocserv'
		if ! grep -Fxq "$cron_config" $cron_file; then
			echo "$cron_config" >> $cron_file
		fi
		ocserv_config_file="/etc/ocserv/ocserv.conf"
		cert_config="server-cert = /etc/letsencrypt/live/$DOMAIN/fullchain.pem"
		key_config="server-key = /etc/letsencrypt/live/$DOMAIN/privkey.pem"
		if ! grep -Fxq "$cert_config" $ocserv_config_file; then
			echo "$cert_config" >> $ocserv_config_file
			echo "$key_config" >> $ocserv_config_file
		fi
		service cron restart

	fi

fi

# Create init user for PAM authentication
if [ ! -f /etc/ocserv/ocpasswd ]; then

	if [ -z USERNAME ] && [ -z USERPASS ]; then
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
	echo '---------------------------------------------------'

fi

# Open ipv4 ip forward
sysctl -w net.ipv4.ip_forward=1

# Enable NAT forwarding
# if you want to specific translate ip, uncomment the following line, -j MASQUERADE is dynamic way
# iptables -t nat -A POSTROUTING -s 192.168.100.0/24 -j SNAT --to-source $(hostname -I)
iptables -t nat -A POSTROUTING -j MASQUERADE
iptables -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu

# Enable TUN device
mkdir -p /dev/net
mknod /dev/net/tun c 10 200
chmod 600 /dev/net/tun

# Run OpennConnect Server
exec "$@"
