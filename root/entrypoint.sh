#!/bin/sh

provisioner () {
    echo "Starting provisioner..."
    if ! out=`ansible-playbook -i /etc/ansible/hosts /etc/ansible/entrypoint.yml -c local "$@"`;then
        echo $out;
    fi
    echo "Provisioner finished."
}

migrate () {
    cd /var/www/wallabag/
    exec su -c "bin/console doctrine:migrations:migrate --env=prod --no-interaction" -s /bin/sh nobody
}

if [ "$1" = "wallabag" ];then
    provisioner
    exec s6-svscan /etc/s6/
    echo "Checking if DB migrations are needed..."
    migrate
fi

if [ "$1" = "import" ];then
    provisioner --skip-tags=firstrun
    cd /var/www/wallabag/
    exec su -c "bin/console wallabag:import:redis-worker -e=prod $2 -vv" -s /bin/sh nobody
fi

if [ "$1" = "migrate" ];then
    provisioner
    echo "Forcing DB migration..."
    migrate
    echo "Migration finished.
fi

exec "$@"
