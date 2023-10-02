ARG COMPOSER_VERSION=2.5.8

FROM composer:$COMPOSER_VERSION as composer

FROM golang:alpine as builder

# envsubst from gettext can not replace env vars with default values
# this package is not available for ARM32 and we have to build it from source code
# flag -ldflags "-s -w" produces a smaller executable
RUN go install -ldflags "-s -w" -v github.com/a8m/envsubst/cmd/envsubst@v1.3.0

FROM alpine:3.18

COPY --from=builder /go/bin/envsubst /usr/bin/envsubst

ARG WALLABAG_VERSION=2.6.7

RUN set -ex \
 && apk add --no-cache \
      curl \
      libwebp \
      nginx \
      pcre \
      php81 \
      php81-bcmath \
      php81-ctype \
      php81-curl \
      php81-dom \
      php81-fpm \
      php81-gd \
      php81-gettext \
      php81-iconv \
      php81-json \
      php81-mbstring \
      php81-openssl \
      php81-pecl-amqp \
      php81-pdo_mysql \
      php81-pdo_pgsql \
      php81-pdo_sqlite \
      php81-phar \
      php81-session \
      php81-simplexml \
      php81-tokenizer \
      php81-xml \
      php81-zlib \
      php81-sockets \
      php81-xmlreader \
      php81-tidy \
      php81-intl \
      php81-sodium \
      mariadb-client \
      postgresql14-client \
      rabbitmq-c \
      s6 \
      tar \
      tzdata \
 && ln -sf /usr/bin/php81 /usr/bin/php \
 && ln -sf /usr/sbin/php-fpm81 /usr/sbin/php-fpm \
 && rm -rf /var/cache/apk/* \
 && ln -sf /dev/stdout /var/log/nginx/access.log \
 && ln -sf /dev/stderr /var/log/nginx/error.log

COPY --from=composer /usr/bin/composer /usr/local/bin/composer

COPY root /

RUN set -ex \
 && curl -L -o /tmp/wallabag.tar.gz https://github.com/wallabag/wallabag/archive/$WALLABAG_VERSION.tar.gz \
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

EXPOSE 80
ENTRYPOINT ["/entrypoint.sh"]
CMD ["wallabag"]
