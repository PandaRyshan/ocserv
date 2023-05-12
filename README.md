## ocserv + certbot in one image

---

Combines [ocserv](https://ocserv.gitlab.io/www/recipes.html) and [certbot](https://eff-certbot.readthedocs.io/en/stable/using.html#) to use secure connections via letsencrypt certificates, with the certbot-dns-cloudflare plugin installed by default.

[ENV file](https://github.com/PandaRyshan/ocserv/blob/main/.env) is used to request a Letsencrypt certificate. If no ENV is provided, the ocserv service will be started with a locally generated certificate.

You can also mount your own configuration, certs or passwd to use them out of the box.

---

Usage:

  - clone this repo
  - replace your domain and email in `.env`
  - (optional) mount your local dir to keep your certificates and config files
    * if you want get certs via cloudflare api token, please mount config file into config/ folder
    * if you want to get certs via http, please make sure 80 port is open
  - `docker-compose up -d` or `docker compose up -d`
  - add `listen-proxy-proto = true` in your `ocserv.conf` if you want to put ocserv in the back of proxy, like haproxy. 

---

References:
  - [Recipes for Openconnect VPN - Official](https://ocserv.gitlab.io/www/recipes.html)
  - [Openconnect VPN Manual - Official](https://ocserv.gitlab.io/www/manual.html)
  - [Ocserv Advanced](https://www.linuxbabe.com/linux-server/ocserv-openconnect-vpn-advanced)
  - [Block Visitors by Country Using Firewall](https://www.ip2location.com/free/visitor-blocker)
