FROM alpine:3.15

LABEL maintainer "Marvin Steadfast <marvin@xsteadfastx.org>"

ARG WALLABAG_VERSION=2.5.2

RUN apk add gnu-libiconv --update-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/community/ --allow-untrusted
ENV LD_PRELOAD /usr/lib/preloadable_libiconv.so php

RUN set -ex \
 && apk update \
 && apk upgrade --available \
 && apk add \
      ansible \
      curl \
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
      make \
      bash \
 && rm -rf /var/cache/apk/* \
 && ln -sf /dev/stdout /var/log/nginx/access.log \
 && ln -sf /dev/stderr /var/log/nginx/error.log \
 && curl -s https://getcomposer.org/installer | php \
 && mv composer.phar /usr/local/bin/composer \
 && composer selfupdate 2.2.12

COPY root /

RUN set -ex \
 && mv /var/www/wallabag/app /tmp/app \
 && curl -L -o /tmp/wallabag.tar.gz https://github.com/wallabag/wallabag/archive/$WALLABAG_VERSION.tar.gz \
 && tar xvf /tmp/wallabag.tar.gz -C /tmp \
 && mv /tmp/wallabag-*/* /var/www/wallabag/ \
 && rm -rf /tmp/wallabag* \
 && mv /tmp/app/config/parameters.yml /var/www/wallabag/app/config/parameters.yml \
 && cd /var/www/wallabag \
 && SYMFONY_ENV=prod composer install --no-dev -o --prefer-dist --no-progress \
 && rm -rf /root/.composer/* /var/www/wallabag/var/cache/* /var/www/wallabag/var/logs/* /var/www/wallabag/var/sessions/* \
 && chown -R nobody:nobody /var/www/wallabag

EXPOSE 80
ENTRYPOINT ["/entrypoint.sh"]
CMD ["wallabag"]
