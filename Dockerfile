# syntax=docker/dockerfile:1.19
FROM cgr.dev/chainguard/wolfi-base:latest

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
    mkdir -p /var/www/ranksystem/avatars /var/www/ranksystem/logs /var/www/ranksystem/update && \
    chown www-data:www-data /var/www/html /var/www/tsicons /run/apache2

COPY docker/httpd.conf /etc/apache2/httpd.conf
COPY docker-entrypoint.sh /docker-entrypoint.sh
COPY LICENSE /usr/share/licenses/ts3-ranksystem/LICENSE
COPY index.php install.php worker.php /var/www/ranksystem/
COPY api/*.php /var/www/ranksystem/api/
COPY jobs/*.php /var/www/ranksystem/jobs/
COPY languages/*.php /var/www/ranksystem/languages/
COPY libs/ /var/www/ranksystem/libs/
COPY other/*.php /var/www/ranksystem/other/
COPY stats/*.php /var/www/ranksystem/stats/
COPY styles/ /var/www/ranksystem/styles/
COPY tsicons/*.png /var/www/ranksystem/tsicons/
COPY webinterface/*.php /var/www/ranksystem/webinterface/

USER www-data
EXPOSE 80
WORKDIR /
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/bin/sh", "/docker-entrypoint.sh"]
