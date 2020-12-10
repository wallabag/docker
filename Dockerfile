FROM alpine:3.12

LABEL maintainer "Marvin Steadfast <marvin@xsteadfastx.org>"

ARG WALLABAG_VERSION=2.4.0

RUN apk add gnu-libiconv --update-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/community/ --allow-untrusted
ENV LD_PRELOAD /usr/lib/preloadable_libiconv.so php

RUN set -ex \
 && apk update \
 && apk upgrade --available \
 && apk add \
      ansible \
      curl \
      git \
      libwebp \
      mariadb-client \
      nginx \
      pcre \
      php7 \
      php7-amqp \
      php7-bcmath \
      php7-ctype \
      php7-curl \
      php7-dom \
      php7-fpm \
      php7-gd \
      php7-gettext \
      php7-iconv \
      php7-json \
      php7-mbstring \
      php7-openssl \
      php7-pdo_mysql \
      php7-pdo_pgsql \
      php7-pdo_sqlite \
      php7-phar \
      php7-session \
      php7-simplexml \
      php7-tokenizer \
      php7-xml \
      php7-zlib \
      php7-sockets \
      php7-xmlreader \
      php7-tidy \
      php7-intl \
      py3-mysqlclient \
      py3-psycopg2 \
      py-simplejson \
      rabbitmq-c \
      s6 \
      tar \
      tzdata \
 && rm -rf /var/cache/apk/* \
 && ln -sf /dev/stdout /var/log/nginx/access.log \
 && ln -sf /dev/stderr /var/log/nginx/error.log \
 && curl -s https://getcomposer.org/installer | php \
 && mv composer.phar /usr/local/bin/composer \
 && git clone --branch $WALLABAG_VERSION --depth 1 https://github.com/wallabag/wallabag.git /var/www/wallabag

COPY root /

RUN set -ex \
 && cd /var/www/wallabag \
 && SYMFONY_ENV=prod composer install --no-dev -o --prefer-dist --no-progress \
 && chown -R nobody:nobody /var/www/wallabag

EXPOSE 80
ENTRYPOINT ["/entrypoint.sh"]
CMD ["wallabag"]
