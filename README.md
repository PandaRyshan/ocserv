# ocserv + certbot 2 in 1 image

---

## Description

This repo combines [ocserv](https://ocserv.gitlab.io/www/recipes.html) VPN server and [certbot](https://eff-certbot.readthedocs.io/en/stable/using.html#) in one image, allowing users to use secure VPN service and request or renew cert automatically.  The certbot-dns-cloudflare plugin is installed by default.

This image provided a default config in `/etc/ocserv/ocserv.conf`. If you don't mount a conf file, it will generate a new one. And [ENV file](https://github.com/PandaRyshan/ocserv/blob/main/.env) is used to request a Letsencrypt certificate and create a default username. If no ENV is provided, the ocserv service will be started with a locally generated certificate.

The latest version is 1.1.7, and dockerhub page is [here](https://hub.docker.com/r/duckduckio/ocserv).

---

Usage:

  - clone this repo
  - replace content in `.env` file with your information, and check the options in `docker-compose.yml`. email address is optional and only for certs expiration remind if certs renew failed
  - (optional) mount your local dir to keep your certificates and config files
    * if you want get certs via cloudflare api token, please mount config file into config/ folder
    * if you want to get certs via http, please make sure 80 port is open
  - run `docker-compose up -d`
  - keep in mind add `listen-proxy-proto = true` in your `ocserv.conf` if you want to put ocserv in the back of proxy, like haproxy. 

---

References:
  - [Recipes for Openconnect VPN - Official](https://ocserv.gitlab.io/www/recipes.html)
  - [Openconnect VPN Manual - Official](https://ocserv.gitlab.io/www/manual.html)
  - [Ocserv Advanced](https://www.linuxbabe.com/linux-server/ocserv-openconnect-vpn-advanced)
  - [Block Visitors by Country Using Firewall](https://www.ip2location.com/free/visitor-blocker)

---

TODO:

* [ ] cannot connect with Cisco secure client on macOS
