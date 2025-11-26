ARG COMPOSER_VERSION=2.2

FROM composer:$COMPOSER_VERSION AS composer

FROM golang:alpine AS builder

# envsubst from gettext can not replace env vars with default values
# this package is not available for ARM32 and we have to build it from source code
# flag -ldflags "-s -w" produces a smaller executable
RUN go install -ldflags "-s -w" -v github.com/a8m/envsubst/cmd/envsubst@v1.4.3

FROM alpine:3.22

COPY --from=builder /go/bin/envsubst /usr/bin/envsubst

ARG WALLABAG_VERSION=2.6.14

RUN set -ex \
 && apk add --no-cache \
      curl \
      libwebp \
      nginx \
      pcre \
      php84 \
      php84-bcmath \
      php84-ctype \
      php84-curl \
      php84-dom \
      php84-fpm \
      php84-gd \
      php84-gettext \
      php84-iconv \
      php84-json \
      php84-mbstring \
      php84-opcache \
      php84-openssl \
      php84-pecl-amqp \
      php84-pecl-imagick \
      php84-pdo_mysql \
      php84-pdo_pgsql \
      php84-pdo_sqlite \
      php84-phar \
      php84-session \
      php84-simplexml \
      php84-tokenizer \
      php84-xml \
      php84-zlib \
      php84-sockets \
      php84-xmlreader \
      php84-tidy \
      php84-intl \
      php84-sodium \
      mariadb-client \
      postgresql17-client \
      rabbitmq-c \
      s6 \
      tar \
      tzdata \
 && ln -sf /usr/bin/php84 /usr/bin/php \
 && ln -sf /usr/sbin/php-fpm84 /usr/sbin/php-fpm \
 && rm -rf /var/cache/apk/* \
 && ln -sf /dev/stdout /var/log/nginx/access.log \
 && ln -sf /dev/stderr /var/log/nginx/error.log

COPY --from=composer /usr/bin/composer /usr/local/bin/composer

COPY root /

RUN set -ex \
 && curl -L -o /tmp/wallabag.tar.gz https://github.com/wallabag/wallabag/releases/download/$WALLABAG_VERSION/wallabag-$WALLABAG_VERSION.tar.gz \
 && tar xvf /tmp/wallabag.tar.gz -C /tmp \
 && mkdir /var/www/wallabag \
 && mv /tmp/wallabag-*/* /var/www/wallabag/ \
 && rm -rf /tmp/wallabag* \
 && cd /var/www/wallabag \
 && mkdir data/assets \
 && envsubst < /etc/wallabag/parameters.template.yml > app/config/parameters.yml \
 && SYMFONY_ENV=prod composer install --no-dev -o --prefer-dist --no-progress \
 && rm -rf /root/.composer/* /var/www/wallabag/var/cache/* /var/www/wallabag/var/logs/* /var/www/wallabag/var/sessions/* \
 && chown -R nobody:nobody /var/www/wallabag

ENV PATH="${PATH}:/var/www/wallabag/bin"

# Set console entry path
WORKDIR /var/www/wallabag

HEALTHCHECK CMD curl --fail --silent --show-error --user-agent healthcheck http://localhost/api/info || exit 1

EXPOSE 80
ENTRYPOINT ["/entrypoint.sh"]
CMD ["wallabag"]
