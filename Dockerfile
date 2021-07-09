FROM php:7.4.14-fpm-alpine

ARG BASE=2.4.2

WORKDIR /var/www/html

ENV LD_PRELOAD /usr/lib/preloadable_libiconv.so php
ENV SYMFONY_ENV=prod

RUN set -ex; \
    \
    apk add --no-cache --virtual .run-deps \
        gnu-libiconv=1.15-r3 \
        imagemagick6-libs \
        tzdata \
    ; \
    apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS \
        freetype-dev \
        gettext-dev \
        icu-dev \
        imagemagick6-dev \
        libjpeg-turbo-dev \
        libpng-dev \
        libxml2-dev \
        libzip-dev \
        oniguruma-dev \
        postgresql-dev \
        sqlite-dev \
        tidyhtml-dev \
    ; \
    docker-php-ext-configure gd --with-freetype --with-jpeg; \
    docker-php-ext-install -j "$(nproc)" \
       bcmath \
       gd \
       gettext \
       iconv \
       intl \
       mbstring \
       opcache \
       pdo \
       pdo_mysql \
       pdo_pgsql \
       pdo_sqlite \
       sockets \
       tidy \
       zip \
    ; \
    pecl install redis; \
    pecl install imagick; \
    docker-php-ext-enable \
       redis \
       imagick \
    ; \
    runDeps="$( \
        scanelf --needed --nobanner --format '%n#p' --recursive /usr/local/lib/php/extensions \
            | tr ',' '\n' \
            | sort -u \
            | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
    )"; \
    apk add --virtual .wallabag-phpext-rundeps $runDeps; \
    apk del .build-deps \
    ; \
    apk add --virtual .composer-runtime-deps git patch; \
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin/ --filename=composer; \
    rm -rf /usr/src/* /tmp/pear/*

RUN wget -O /usr/local/bin/envsubst https://github.com/a8m/envsubst/releases/download/v1.1.0/envsubst-`uname -s`-`uname -m`; \
    chmod +x /usr/local/bin/envsubst

RUN wget -O /tmp/wallabag.tar.gz https://github.com/wallabag/wallabag/archive/$BASE.tar.gz; \
    mkdir /tmp/extract; \
    tar xf /tmp/wallabag.tar.gz -C /tmp/extract; \
    rmdir /var/www/html; \
    mv /tmp/extract/wallabag-*/ /var/www/html; \
    cd /var/www/html; \
    composer install --no-dev --no-interaction -o --prefer-dist; \
    chown -R www-data: /var/www/html; \
    rm -rf /tmp/wallabag.tar.gz /tmp/extract /root/.composer /var/www/html/var/cache/prod;

COPY entrypoint.sh /entrypoint.sh
COPY config/ /opt/wallabag/config/
COPY patches/ /opt/wallabag/patches/
COPY apply-patches.sh /opt/wallabag/apply-patches.sh
RUN set -ex; \
    /opt/wallabag/apply-patches.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["php-fpm"]
