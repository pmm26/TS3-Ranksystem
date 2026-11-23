# syntax=docker/dockerfile:1.19
FROM cgr.dev/chainguard/wolfi-base@sha256:be019c1c74fe69204a42c4e10bc4d886a49bf5403ffa74374ef7baa408fc9a26 AS runtime

# Keep the UID and GID used by existing tsicons volumes.
RUN addgroup -g 33 www-data && adduser -S -D -H -u 33 -G www-data www-data && \
    apk --no-cache upgrade && \
    apk add --no-cache apache2 ca-certificates-bundle procps tini tzdata \
        php-8.4 php-8.4-apache php-8.4-ctype php-8.4-curl php-8.4-dom \
        php-8.4-fileinfo php-8.4-iconv php-8.4-mbstring php-8.4-mysqlnd \
        php-8.4-opcache php-8.4-openssl php-8.4-pdo php-8.4-pdo_mysql \
        php-8.4-pdo_sqlite php-8.4-phar php-8.4-posix php-8.4-simplexml \
        php-8.4-sodium php-8.4-ssh2 php-8.4-xml php-8.4-xmlreader \
        php-8.4-xmlwriter php-8.4-zip && \
    apk add --no-cache --virtual .setcap libcap-utils && \
    setcap cap_net_bind_service=+ep /usr/bin/httpd && apk del .setcap && \
    mkdir -p /var/www/html /var/www/tsicons /run/apache2 && \
    chown www-data:www-data /var/www/html /var/www/tsicons /run/apache2

FROM runtime AS tls-build
RUN apk add --no-cache build-base binutils brotli-dev linux-headers nfpm patch perl zlib-dev zstd-dev && mkdir /out
COPY docker/backport-libssl.sh docker/*.patch /backport/

FROM tls-build AS tls3
RUN sh /backport/backport-libssl.sh openssl-3.6-libssl openssl 3
FROM tls-build AS tls4
RUN sh /backport/backport-libssl.sh openssl-4.0-libssl openssl-4.0 4

FROM runtime
# The APKs are built above from authenticated packages and the upstream fix.
RUN --mount=type=bind,from=tls3,source=/out,target=/tls3 \
    --mount=type=bind,from=tls4,source=/out,target=/tls4 \
    for package in /tls3/*.apk /tls4/*.apk; do \
        if [ -f "$package" ]; then apk add --no-network --allow-untrusted "$package" || exit 1; fi; \
    done

COPY docker/httpd.conf /etc/apache2/httpd.conf
COPY docker-entrypoint.sh /docker-entrypoint.sh
COPY --exclude=docker --exclude=docker-entrypoint.sh . /var/www/ranksystem/

USER www-data
EXPOSE 80
WORKDIR /
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/bin/sh", "/docker-entrypoint.sh"]
