# syntax=docker/dockerfile:1.19
FROM cgr.dev/chainguard/wolfi-base@sha256:be019c1c74fe69204a42c4e10bc4d886a49bf5403ffa74374ef7baa408fc9a26

# Keep the UID and GID used by existing tsicons volumes.
RUN addgroup -g 33 www-data && adduser -S -D -H -u 33 -G www-data www-data && \
    apk --no-cache upgrade && \
    apk add --no-cache apache2 ca-certificates-bundle procps tini tzdata \
        php-8.6 php-8.6-apache php-8.6-ctype php-8.6-curl php-8.6-dom \
        php-8.6-fileinfo php-8.6-iconv php-8.6-mbstring php-8.6-mysqlnd \
        php-8.6-openssl php-8.6-pdo php-8.6-pdo_mysql \
        php-8.6-pdo_sqlite php-8.6-phar php-8.6-posix php-8.6-simplexml \
        php-8.6-sodium php-8.6-ssh2 php-8.6-xml php-8.6-xmlreader \
        php-8.6-xmlwriter php-8.6-zip && \
    apk add --no-cache --virtual .setcap libcap-utils && \
    setcap cap_net_bind_service=+ep /usr/bin/httpd && apk del .setcap && \
    mkdir -p /var/www/html /var/www/tsicons /run/apache2 && \
    chown www-data:www-data /var/www/html /var/www/tsicons /run/apache2

COPY docker/httpd.conf /etc/apache2/httpd.conf
COPY docker-entrypoint.sh /docker-entrypoint.sh
COPY --exclude=docker --exclude=docker-entrypoint.sh \
    --exclude=.git --exclude=.github --exclude=**/.github --exclude=.gitattributes --exclude=.dockerignore \
    --exclude=Dockerfile --exclude=docker-compose.yml --exclude=README.md . /var/www/ranksystem/

USER www-data
EXPOSE 80
WORKDIR /
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/bin/sh", "/docker-entrypoint.sh"]
