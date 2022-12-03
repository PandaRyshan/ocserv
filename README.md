## Customize ocserv server Dockerfile

---

Combines [ocserv](https://ocserv.gitlab.io/www/recipes.html) and [certbot](https://eff-certbot.readthedocs.io/en/stable/using.html#) to use secure connections via letsencrypt certificates, with the certbot-dns-cloudflare plugin installed by default.

[ENV file](https://github.com/aold619/ocserv/blob/main/.env) is used to request a Letsencrypt certificate. If no ENV is provided, the ocserv service will be started with a locally generated certificate.

You can also mount your own configuration, certs or passwd to use them out of the box.

References:
  - [Recipes for Openconnect VPN - Official](https://ocserv.gitlab.io/www/recipes.html)
  - [Openconnect VPN Manual - Official](https://ocserv.gitlab.io/www/manual.html)
  - [Ocserv Advanced](https://www.linuxbabe.com/linux-server/ocserv-openconnect-vpn-advanced)
  - [Block Visitors by Country Using Firewall](https://www.ip2location.com/free/visitor-blocker)
