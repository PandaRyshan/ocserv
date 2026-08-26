FROM alpine:latest AS builder
LABEL maintainer="Hu Xiaohong <xiaohong@pandas.run>"

ENV URL="https://www.infradead.org/ocserv/download/"
ENV BUILD_DEPS="\
  gcc coreutils build-base \
  xz gawk pkgconfig nettle-dev gnutls-dev \
  libev-dev readline-dev lz4-dev libseccomp-dev \
  oath-toolkit-dev libnl3-dev talloc-dev http-parser-dev \
  radcli-dev linux-pam-dev krb5-dev protobuf-c-dev \
  meson ninja"

RUN apk add --no-cache bash curl ${BUILD_DEPS}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN set -x \
  && curl -sL "$URL" | \
    grep -oE 'ocserv-([0-9]{1,}\.)+[0-9]{1,}\.tar\.xz' | \
    sort -V | tail -n1 | \
    xargs -I {} curl -sLo ocserv.tar.xz "$URL{}" \
  && tar -xf ocserv.tar.xz && cd ocserv-* \
  && meson setup build \
  && meson compile -C build \
  && meson install -C build \
  && cd .. && rm -rf ocserv-* ocserv.tar.xz

# Final runtime stage
FROM alpine:latest
LABEL maintainer="Hu Xiaohong <xiaohong@pandas.run>"

# Runtime deps only
RUN apk add --no-cache \
  bash curl gnutls nettle libev talloc \
  linux-pam krb5 oath-toolkit-liboath libnl3 \
  libseccomp radcli certbot certbot-dns-cloudflare \
  iptables ipcalc protobuf-c lz4

WORKDIR /etc/ocserv

COPY --from=builder /usr/local/sbin/ocserv /usr/local/sbin/ocserv
COPY --from=builder /usr/local/sbin/ocserv-worker /usr/local/sbin/ocserv-worker
COPY --from=builder /usr/local/bin/occtl /usr/local/sbin/occtl
COPY --from=builder /usr/local/bin/ocpasswd /usr/local/sbin/ocpasswd
COPY --from=ghcr.io/ufoscout/docker-compose-wait:latest /wait /wait
COPY docker-entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 443
CMD ["ocserv", "-c", "/etc/ocserv/ocserv.conf", "-f"]
