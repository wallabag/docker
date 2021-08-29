#!/bin/sh

provisioner () {
    echo "Setting up Wallabag..."

    cd /var/www/wallabag
    /usr/local/bin/envsubst < app/config/parameters.template > app/config/parameters.yml
    SYMFONY_ENV=prod composer install --no-dev -o --prefer-dist --no-progress --quiet
    chown -R nobody:nobody /var/www/wallabag/var

    echo "Ready"
}

if [ "$1" = "wallabag" ];then
    provisioner
    exec s6-svscan /etc/s6/
fi

if [ "$1" = "import" ];then
    provisioner
    exec su -c "bin/console wallabag:import:redis-worker --env=prod $2 -vv" -s /bin/sh nobody
fi

if [ "$1" = "migrate" ];then
    provisioner
    exec su -c "bin/console doctrine:migrations:migrate --env=prod --no-interaction" -s /bin/sh nobody
fi

exec "$@"
