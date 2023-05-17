FROM ubuntu:rolling
LABEL maintainer="Hu Xiaohong <xiaohong@duckduck.io>"

ENV VERSION 1.1.6

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY docker-entrypoint.sh /entrypoint.sh
COPY --from=ghcr.io/ufoscout/docker-compose-wait:latest /wait /wait

RUN set -x \
  && apt-get update && apt-get install --no-install-recommends -y ocserv \
    certbot python3-certbot-dns-cloudflare cron iptables \
  && apt-get -y autoremove && apt-get -y clean \
  && rm -rf /var/lib/apt/lists/* \
  && rm /etc/ocserv/ocserv.conf \
  && chmod +x /entrypoint.sh

WORKDIR /etc/ocserv

ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 443
CMD ["ocserv", "-c", "/etc/ocserv/ocserv.conf", "-f"]
