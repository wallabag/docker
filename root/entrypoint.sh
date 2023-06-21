#!/bin/sh
# Exit when any command fails
set -e

COMMAND_ARG1="$1"
COMMAND_ARG2="$2"

cd /var/www/wallabag || exit

wait_for_database() {
    timeout 60s /bin/sh -c "$(cat << EOF
        until echo 'Waiting for database ...' \
            && nc -z ${SYMFONY__ENV__DATABASE_HOST} ${SYMFONY__ENV__DATABASE_PORT} < /dev/null > /dev/null 2>&1 ; \
        do sleep 1 ; done
EOF
)"
}

install_wallabag() {
    su -c "php bin/console wallabag:install --env=prod -n" -s /bin/sh nobody
}

provisioner() {
    SYMFONY__ENV__DATABASE_DRIVER=${SYMFONY__ENV__DATABASE_DRIVER:-pdo_sqlite}
    POPULATE_DATABASE=${POPULATE_DATABASE:-True}

    # Replace environment variables
    envsubst < /etc/wallabag/parameters.template.yml > app/config/parameters.yml

    # Wait for external database
    if [ "$SYMFONY__ENV__DATABASE_DRIVER" = "pdo_mysql" ] || [ "$SYMFONY__ENV__DATABASE_DRIVER" = "pdo_pgsql" ] ; then
        wait_for_database
    fi

    # Configure SQLite database
    SQLITE_FILE_SIZE=$(wc -c "/var/www/wallabag/data/db/wallabag.sqlite" | awk '{print $1}')
    if [ "$SYMFONY__ENV__DATABASE_DRIVER" = "pdo_sqlite" ] && ([ ! -f "/var/www/wallabag/data/db/wallabag.sqlite" ] || [ "$SQLITE_FILE_SIZE" = 0 ]) ; then
        echo "Configuring the SQLite database ..."
        install_wallabag
    fi

    # Configure MySQL / MariaDB database
    if [ "$SYMFONY__ENV__DATABASE_DRIVER" = "pdo_mysql" ] && [ "$POPULATE_DATABASE" = "True" ] && [ "$MYSQL_ROOT_PASSWORD" != "" ] ; then
        DATABASE_EXISTS="$(mysql -h "${SYMFONY__ENV__DATABASE_HOST}" --port "${SYMFONY__ENV__DATABASE_PORT}" -uroot -p"${MYSQL_ROOT_PASSWORD}" \
            -sse "SELECT EXISTS(SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = '$SYMFONY__ENV__DATABASE_NAME')")"
        if [ "$DATABASE_EXISTS" != "1" ]; then
            echo "Configuring the MySQL database ..."
            mysql -h "${SYMFONY__ENV__DATABASE_HOST}" --port "${SYMFONY__ENV__DATABASE_PORT}" -uroot -p"${MYSQL_ROOT_PASSWORD}" \
                -e "CREATE DATABASE IF NOT EXISTS ${SYMFONY__ENV__DATABASE_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
            USER_EXISTS="$(mysql -h "${SYMFONY__ENV__DATABASE_HOST}" --port "${SYMFONY__ENV__DATABASE_PORT}" -uroot -p"${MYSQL_ROOT_PASSWORD}" \
                -sse "SELECT EXISTS(SELECT 1 FROM mysql.user WHERE user = '$SYMFONY__ENV__DATABASE_USER')")"
            if [ "$USER_EXISTS" != "1" ]; then
                mysql -h "${SYMFONY__ENV__DATABASE_HOST}" --port "${SYMFONY__ENV__DATABASE_PORT}" -uroot -p"${MYSQL_ROOT_PASSWORD}" \
                    -e "CREATE USER IF NOT EXISTS '${SYMFONY__ENV__DATABASE_USER}'@'%' IDENTIFIED BY '${SYMFONY__ENV__DATABASE_PASSWORD}';"
                mysql -h "${SYMFONY__ENV__DATABASE_HOST}" --port "${SYMFONY__ENV__DATABASE_PORT}" -uroot -p"${MYSQL_ROOT_PASSWORD}" \
                    -e "GRANT ALL PRIVILEGES ON ${SYMFONY__ENV__DATABASE_NAME}.* TO '${SYMFONY__ENV__DATABASE_USER}'@'%';"
            fi
            install_wallabag
        else
            echo "WARN: MySQL database is already configured. Remove the environment variable with root password."
        fi
    fi

    # Configure Postgres database
    if [ "$SYMFONY__ENV__DATABASE_DRIVER" = "pdo_pgsql" ] && [ "$POPULATE_DATABASE" = "True" ] && [ "$POSTGRES_PASSWORD" != "" ] ; then
        export PGPASSWORD="${POSTGRES_PASSWORD}"
        DATABASE_EXISTS="$(psql -qAt -h "${SYMFONY__ENV__DATABASE_HOST}" -p "${SYMFONY__ENV__DATABASE_PORT}" -U "${POSTGRES_USER}" \
            -c "SELECT 1 FROM pg_catalog.pg_database WHERE datname = '${SYMFONY__ENV__DATABASE_NAME}';")"
        if [ "$DATABASE_EXISTS" != "1" ]; then
            echo "Configuring the Postgres database ..."
            psql -q -h "${SYMFONY__ENV__DATABASE_HOST}" -p "${SYMFONY__ENV__DATABASE_PORT}" -U "${POSTGRES_USER}" \
                -c "CREATE DATABASE ${SYMFONY__ENV__DATABASE_NAME};"
            USER_EXISTS="$(psql -qAt -h "${SYMFONY__ENV__DATABASE_HOST}" -p "${SYMFONY__ENV__DATABASE_PORT}" -U "${POSTGRES_USER}" \
                -c "SELECT 1 FROM pg_roles WHERE rolname = '${SYMFONY__ENV__DATABASE_USER}';")"
            if [ "$USER_EXISTS" != "1" ]; then
                psql -q -h "${SYMFONY__ENV__DATABASE_HOST}" -p "${SYMFONY__ENV__DATABASE_PORT}" -U "${POSTGRES_USER}" \
                    -c "CREATE ROLE ${SYMFONY__ENV__DATABASE_USER} with PASSWORD '${SYMFONY__ENV__DATABASE_PASSWORD}' LOGIN;"
            fi
            install_wallabag
        else
            echo "WARN: Postgres database is already configured. Remove the environment variable with root password."
        fi
    fi

    # Remove cache and install Wallabag
    rm -f -r /var/www/wallabag/var/cache
    su -c "SYMFONY_ENV=prod composer install --no-dev -o --prefer-dist" -s /bin/sh nobody
}

if [ "$COMMAND_ARG1" = "wallabag" ]; then
    echo "Starting wallabag ..."
    provisioner
    echo "wallabag is ready!"
    exec s6-svscan /etc/s6/
fi

if [ "$COMMAND_ARG1" = "import" ]; then
    provisioner
    exec su -c "bin/console wallabag:import:redis-worker --env=prod $COMMAND_ARG2 -vv" -s /bin/sh nobody
fi

if [ "$COMMAND_ARG1" = "migrate" ]; then
    provisioner
    exec su -c "bin/console doctrine:migrations:migrate --env=prod --no-interaction" -s /bin/sh nobody
fi

exec "$@"
