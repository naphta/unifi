# syntax=docker/dockerfile:experimental
FROM --platform=$TARGETPLATFORM ubuntu:18.04

LABEL maintainer="Jake Hill <jake@naphta.uk>"

ARG DEBIAN_FRONTEND=noninteractive

ARG UNIFI_VERSION=5.12.22
ARG PKGURL=https://dl.ubnt.com/unifi/5.12.22/unifi_sysvinit_all.deb

ENV BASEDIR=/usr/lib/unifi \
    DATADIR=/unifi/data \
    LOGDIR=/unifi/log \
    CERTDIR=/unifi/cert \
    RUNDIR=/var/run/unifi \
    ODATADIR=/var/lib/unifi \
    OLOGDIR=/var/log/unifi \
    CERTNAME=cert.pem \
    CERT_PRIVATE_NAME=privkey.pem \
    CERT_IS_CHAIN=false \
    GOSU_VERSION=1.10 \
    BIND_PRIV=true \
    RUNAS_UID0=true \
    UNIFI_GID=999 \
    UNIFI_UID=999

RUN set -ex \
 && fetchDeps='\
        ca-certificates \
        dirmngr \
        gpg \
        wget \
        gosu' \
 && apt-get update \
 && apt-get install -y --no-install-recommends $fetchDeps \
 && apt-get purge -y --auto-remove $fetchDeps \
 && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /usr/unifi \
    /usr/local/unifi/init.d \
    /usr/unifi/init.d
COPY docker-entrypoint.sh /usr/local/bin/
COPY docker-healthcheck.sh /usr/local/bin/
COPY docker-build.sh /usr/local/bin/
COPY functions /usr/unifi/functions
COPY import_cert /usr/unifi/init.d/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh \
 && chmod +x /usr/unifi/init.d/import_cert \
 && chmod +x /usr/local/bin/docker-healthcheck.sh \
 && chmod +x /usr/local/bin/docker-build.sh

# Push installing openjdk-8-jre first, so that the unifi package doesn't pull in openjdk-7-jre as a dependency? Else uncomment and just go with openjdk-7.
RUN set -ex \
 && mkdir -p /usr/share/man/man1/ \
 && groupadd -r unifi -g $UNIFI_GID \
 && useradd --no-log-init -r -u $UNIFI_UID -g $UNIFI_GID unifi \
 && /usr/local/bin/docker-build.sh "${PKGURL}"

VOLUME ["/unifi", "${RUNDIR}"]

EXPOSE 6789/tcp 8080/tcp 8443/tcp 8880/tcp 8843/tcp 3478/udp

WORKDIR /unifi

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

CMD ["unifi"]
