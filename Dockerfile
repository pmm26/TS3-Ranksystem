# syntax=docker/dockerfile:1.19
FROM php:8.6-apache AS base

RUN apt-get update && apt-get upgrade -y && rm -rf /var/lib/apt/lists/*

FROM base AS extensions
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends libonig-dev libssh2-1-dev libzip-dev; \
    docker-php-ext-install -j4 mbstring pdo_mysql zip; \
    curl -fsSL https://pecl.php.net/get/ssh2-1.6.1.tgz -o /tmp/ssh2.tgz; \
    echo '2212d8266df54654b282ca681ee9b82f312a776e801b667b288d80f3541741ed  /tmp/ssh2.tgz' | sha256sum -c -; \
    tar -xzf /tmp/ssh2.tgz -C /tmp; \
    cd /tmp/ssh2-1.6.1; phpize; ./configure --with-ssh2; make -j4; make install; \
    docker-php-ext-enable ssh2

FROM base
COPY --from=extensions /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=extensions /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends libcap2-bin libonig5 libssh2-1t64 libzip5 procps tini; \
    setcap cap_net_bind_service=+ep /usr/sbin/apache2; \
    apt-mark auto $PHPIZE_DEPS libc6-dev libcap2-bin; \
    apt-get autoremove -y --purge; \
    rm -rf /var/lib/apt/lists/* /usr/src/php.tar.*; \
    mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"; \
    a2enmod remoteip; \
    mkdir -p /var/www/html /var/www/tsicons && \
    mkdir -p /var/www/ranksystem/avatars /var/www/ranksystem/logs /var/www/ranksystem/update && \
    chown www-data:www-data /var/www/html /var/www/tsicons

COPY docker/httpd.conf /etc/apache2/sites-available/000-default.conf
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
