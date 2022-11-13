FROM golang:alpine3.16 as builder

# envsubst from gettext can not replace env vars with default values
# this package is not available for ARM32 and we have to build it from source code
# flag -ldflags "-s -w" produces a smaller executable
RUN go install -ldflags "-s -w" -v github.com/a8m/envsubst/cmd/envsubst@v1.3.0

FROM alpine:3.16

COPY --from=builder /go/bin/envsubst /usr/bin/envsubst

ARG WALLABAG_VERSION=2.5.2

RUN set -ex \
 && apk add --no-cache \
      curl \
      libwebp \
      nginx \
      pcre \
      php8 \
      php8-bcmath \
      php8-ctype \
      php8-curl \
      php8-dom \
      php8-fpm \
      php8-gd \
      php8-gettext \
      php8-iconv \
      php8-json \
      php8-mbstring \
      php8-openssl \
      php8-pecl-amqp \
      php8-pdo_mysql \
      php8-pdo_pgsql \
      php8-pdo_sqlite \
      php8-phar \
      php8-session \
      php8-simplexml \
      php8-tokenizer \
      php8-xml \
      php8-zlib \
      php8-sockets \
      php8-xmlreader \
      php8-tidy \
      php8-intl \
      mariadb-client \
      postgresql14-client \
      rabbitmq-c \
      s6 \
      tar \
      tzdata \
 && ln -sf /usr/bin/php8 /usr/bin/php \
 && ln -sf /usr/sbin/php-fpm8 /usr/sbin/php-fpm \
 && rm -rf /var/cache/apk/* \
 && ln -sf /dev/stdout /var/log/nginx/access.log \
 && ln -sf /dev/stderr /var/log/nginx/error.log \
 && curl -s https://getcomposer.org/installer | php \
 && mv composer.phar /usr/local/bin/composer \
 && composer selfupdate 2.2.18 \
 && rm -rf /root/.composer/*

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

EXPOSE 80
ENTRYPOINT ["/entrypoint.sh"]
CMD ["wallabag"]
