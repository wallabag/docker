ARG COMPOSER_VERSION=2.2

FROM composer:$COMPOSER_VERSION AS composer

FROM golang:alpine AS builder

# envsubst from gettext can not replace env vars with default values
# this package is not available for ARM32 and we have to build it from source code
# flag -ldflags "-s -w" produces a smaller executable
RUN go install -ldflags "-s -w" -v github.com/a8m/envsubst/cmd/envsubst@v1.4.3

FROM alpine:3.24

COPY --from=builder /go/bin/envsubst /usr/bin/envsubst

ARG WALLABAG_VERSION=2.6.19

RUN set -ex \
 && apk add --no-cache \
      curl \
      libwebp \
      nginx \
      pcre \
      php83 \
      php83-bcmath \
      php83-ctype \
      php83-curl \
      php83-dom \
      php83-fpm \
      php83-gd \
      php83-gettext \
      php83-iconv \
      php83-json \
      php83-mbstring \
      php83-opcache \
      php83-openssl \
      php83-pecl-amqp \
      php83-pecl-imagick \
      php83-pdo_mysql \
      php83-pdo_pgsql \
      php83-pdo_sqlite \
      php83-phar \
      php83-session \
      php83-simplexml \
      php83-tokenizer \
      php83-xml \
      php83-zlib \
      php83-sockets \
      php83-xmlreader \
      php83-tidy \
      php83-intl \
      php83-sodium \
      mariadb-client \
      postgresql17-client \
      rabbitmq-c \
      s6 \
      tar \
      tzdata \
 && ln -sf /usr/bin/php83 /usr/bin/php \
 && ln -sf /usr/sbin/php-fpm83 /usr/sbin/php-fpm \
 && rm -rf /var/cache/apk/* \
 && ln -sf /dev/stdout /var/log/nginx/access.log \
 && ln -sf /dev/stderr /var/log/nginx/error.log

COPY --from=composer /usr/bin/composer /usr/local/bin/composer

COPY root /

RUN set -ex \
 && envsubst < /etc/wallabag/fastcgi-read-timeout.template.conf > /etc/wallabag/fastcgi-read-timeout.conf \
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
