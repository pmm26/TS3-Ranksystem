# syntax=docker/dockerfile:1.19
FROM php:8.6-apache@sha256:0b06b358a7d59cca80e0528aad0e49b43208c3a74754ffcd8a12d7727058511e AS base

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
    printf '%s\n' 'RemoteIPHeader X-Forwarded-For' 'ServerTokens Prod' 'ServerSignature Off' \
        'TraceEnable off' 'FileETag MTime Size' 'ErrorLog /dev/null' 'CustomLog /dev/null combined' \
        >> /etc/apache2/apache2.conf; \
    mkdir -p /var/www/html /var/www/tsicons; \
    chown www-data:www-data /var/www/html /var/www/tsicons

COPY docker-entrypoint.sh /docker-entrypoint.sh
COPY --exclude=.git --exclude=.github --exclude=**/.github --exclude=.gitattributes --exclude=.dockerignore \
    --exclude=Dockerfile --exclude=docker-compose.yml --exclude=docker-entrypoint.sh --exclude=README.md . /var/www/ranksystem/

USER www-data
WORKDIR /
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/bin/sh", "/docker-entrypoint.sh"]
