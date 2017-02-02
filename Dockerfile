FROM alpine:3.5
MAINTAINER Marvin Steadfast <marvin@xsteadfastx.org>

ARG WALLABAG_VERSION=2.2.1
ARG POSTGRES_USER=postgres

RUN set -ex \
 && echo "@testing http://dl-4.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories \
 && apk add --update \
      ansible \
      curl \
      git \
      libwebp \
      mariadb-client \
      nginx \
      pcre \
      php7 \
      php7-amqp \
      php7-amqp@testing \
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
      php7-xml \
      php7-zlib \
      php7\
      py-mysqldb \
      py-psycopg2 \
      py-simplejson \
      s6 \
      tar \
 && rm -rf /var/cache/apk/*

RUN ln -s /usr/bin/php7 /usr/bin/php \
 && ln -sf /dev/stdout /var/log/nginx/access.log \
 && ln -sf /dev/stderr /var/log/nginx/error.log

RUN curl -s http://getcomposer.org/installer | php \
 && mv composer.phar /usr/local/bin/composer

RUN git clone --branch $WALLABAG_VERSION --depth 1 https://github.com/wallabag/wallabag.git /var/www/wallabag

COPY root /

RUN cd /var/www/wallabag \
 && SYMFONY_ENV=prod composer install --no-dev -o --prefer-dist

RUN chown -R nobody:nobody /var/www/wallabag

EXPOSE 80
ENTRYPOINT ["/entrypoint.sh"]
CMD ["wallabag"]
