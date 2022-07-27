FROM alpine:3.16

LABEL maintainer "Marvin Steadfast <marvin@xsteadfastx.org>"

ARG WALLABAG_VERSION=2.5.1

# Install dependencies
RUN set -ex \
 && apk update \
 && apk add \
      curl \
      libwebp \
      nginx \
      pcre \
      php8 \
    #   php8-amqp \
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
      py3-mysqlclient \
      py3-psycopg2 \
      py-simplejson \
      rabbitmq-c \
      s6 \
      tzdata \
     #  make \
     #  bash \
 && ln -sf /usr/bin/php8 /usr/bin/php \
 && ln -sf /usr/sbin/php-fpm8 /usr/sbin/php-fpm \
 && rm -rf /var/cache/apk/* \
 && ln -sf /dev/stdout /var/log/nginx/access.log \
 && ln -sf /dev/stderr /var/log/nginx/error.log

# Install composer (requires composer < 2.3)
# RUN set -ex \
#  && curl -s https://getcomposer.org/installer | php \
#  && mv composer.phar /usr/local/bin/composer
RUN set -ex \
  && curl -L -o /usr/local/bin/composer https://getcomposer.org/download/2.2.12/composer.phar \
  && chmod +x /usr/local/bin/composer

# Install envsubst
RUN set -ex \
 && curl -L -o /usr/local/bin/envsubst https://github.com/a8m/envsubst/releases/download/v1.1.0/envsubst-`uname -s`-`uname -m` \
 && chmod +x /usr/local/bin/envsubst

# Download Wallabag
RUN set -ex \
 && curl -L -o /tmp/wallabag.tar.gz https://github.com/wallabag/wallabag/archive/$WALLABAG_VERSION.tar.gz \
 && tar xvf /tmp/wallabag.tar.gz -C /tmp \
 && mv /tmp/wallabag-*/ /var/www/wallabag \
 && rm -rf /tmp/wallabag*

# Copy resources
COPY root /

# Install Wallabag
RUN set -ex \
 && cd /var/www/wallabag \
 && SYMFONY_ENV=prod composer install --no-dev -o --prefer-dist --no-progress \
 && rm -rf /root/.composer/* /var/www/wallabag/var/cache/* /var/www/wallabag/var/logs/* /var/www/wallabag/var/sessions/*

EXPOSE 80
ENTRYPOINT ["/entrypoint.sh"]
CMD ["wallabag"]

# docker build -t wallabag:custom .
