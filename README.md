# What is wallabag?

[![Build Status](https://travis-ci.org/wallabag/docker.svg?branch=master)](https://travis-ci.org/wallabag/docker)
[![Docker Stars](https://img.shields.io/docker/stars/wallabag/wallabag.svg?maxAge=2592000)](https://hub.docker.com/r/wallabag/wallabag/)
[![Docker Pulls](https://img.shields.io/docker/pulls/wallabag/wallabag.svg?maxAge=2592000)](https://hub.docker.com/r/wallabag/wallabag/)

[wallabag](https://www.wallabag.org/) is a self hostable application for saving web pages. Unlike other services, wallabag is free (as in freedom) and open source.

With this application you will not miss content anymore. Click, save, read it when you want. It saves the content you select so that you can read it when you have time.

# How to use this image

Default login is `wallabag:wallabag`.

## Environment variables

- `-e MYSQL_ROOT_PASSWORD=...` (needed for the mariadb container to initialise and for the entrypoint in the wallabag container to create a database and user if its not there)
- `-e POSTGRES_PASSWORD=...` (needed for the posgres container to initialise and for the entrypoint in the wallabag container to create a database and user if not there)
- `-e POSTGRES_USER=...` (needed for the posgres container to initialise and for the entrypoint in the wallabag container to create a database and user if not there)
- `-e SYMFONY__ENV__DATABASE_DRIVER=...` (defaults to "pdo_sqlite", this sets the database driver to use)
- `-e SYMFONY__ENV__DATABASE_HOST=...` (defaults to "127.0.0.1", if use mysql this should be the name of the mariadb container)
- `-e SYMFONY__ENV__DATABASE_PORT=...` (port of the database host)
- `-e SYMFONY__ENV__DATABASE_NAME=...`(defaults to "symfony", this is the name of the database to use)
- `-e SYMFONY__ENV__DATABASE_USER=...` (defaults to "root", this is the name of the database user to use)
- `-e SYMFONY__ENV__DATABASE_PASSWORD=...` (defaults to "~", this is the password of the database user to use)
- `-e SYMFONY__ENV__SECRET=...` (defaults to "ovmpmAWXRCabNlMgzlzFXDYmCFfzGv")
- `-e SYMFONY__ENV__MAILER_HOST=...`  defaults to "127.0.0.1", the SMTP host)
- `-e SYMFONY__ENV__MAILER_USER=...` (defaults to "~", the SMTP user)
- `-e SYMFONY__ENV__MAILER_PASSWORD=...`(defaults to "~", the SMTP password)
- `-e SYMFONY__ENV__FROM_EMAIL=...`(defaults to "wallabag@example.com", the address wallabag uses for outgoing emails)
- `-e SYMFONY__ENV__FOSUSER_REGISTRATION=...`(defaults to "true", enable or disable public user registration)
- `-e POPULATE_DATABASE=...`(defaults to "True". Does the DB has to be populated or is it an existing one)

## SQLite

The easiest way to start wallabag is to use the SQLite backend. You can spin that up with

```
$ docker run -p 80:80 wallabag/wallabag
```

and point your browser to `http://localhost:80`. For persistent storage you should start the container with a volume:

```
$ docker run -v /opt/wallabag:/var/www/wallabag/data -p 80:80 wallabag/wallabag
```

## MariaDB / MySQL

For using MariaDB or MySQL you have to define some environment variables with the container. Example:

```
$ docker run --name wallabag-db -e "MYSQL_ROOT_PASSWORD=my-secret-pw" -d mariadb
$ docker run --name wallabag --link wallabag-db:wallabag-db -e "MYSQL_ROOT_PASSWORD=my-secret-pw" -e "SYMFONY__ENV__DATABASE_DRIVER=pdo_mysql" -e "SYMFONY__ENV__DATABASE_HOST=wallabag-db" -e "SYMFONY__ENV__DATABASE_PORT=3306" -e "SYMFONY__ENV__DATABASE_NAME=wallabag" -e "SYMFONY__ENV__DATABASE_USER=wallabag" -e "SYMFONY__ENV__DATABASE_PASSWORD=wallapass" -p 80:80 wallabag/wallabag
```

## PostgreSQL

For using PostgreSQL you have to define some environment variables with the container. Example:

```
$ docker run --name wallabag-db -e "POSTGRES_PASSWORD=my-secret-pw" -e "POSTGRES_USER=my-super-user" -d postgres
$ docker run --name wallabag --link wallabag-db:wallabag-db -e "POSTGRES_PASSWORD=my-secret-pw" -e "POSTGRES_USER=my-super-user" -e "SYMFONY__ENV__DATABASE_DRIVER=pdo_pgsql" -e "SYMFONY__ENV__DATABASE_HOST=wallabag-db" -e "SYMFONY__ENV__DATABASE_PORT=5432" -e "SYMFONY__ENV__DATABASE_NAME=wallabag" -e "SYMFONY__ENV__DATABASE_USER=wallabag" -e "SYMFONY__ENV__DATABASE_PASSWORD=wallapass" -p 80:80 wallabag/wallabag
```

## Redis

To use redis support a linked redis container with the name `redis` is needed.

 ```
$ docker run -p 6379:6379 --name redis redis:alpine
$ docker run -p 80:80 --link redis:redis wallabag/wallabag
```

## DB migration

If there is a version upgrade that needs a database migration, you should start the container with the new image and run the migration command.

```
$ docker exec -t wallabag /var/www/wallabag/bin/console doctrine:migrations:migrate --env=prod --no-interaction
```

## docker-compose

It's a good way to use [docker-compose](https://docs.docker.com/compose/). Example:

```
version: '2'
services:
  wallabag:
    image: wallabag/wallabag
    environment:
      - MYSQL_ROOT_PASSWORD=wallaroot
      - SYMFONY__ENV__DATABASE_DRIVER=pdo_mysql
      - SYMFONY__ENV__DATABASE_HOST=db
      - SYMFONY__ENV__DATABASE_PORT=3306
      - SYMFONY__ENV__DATABASE_NAME=wallabag
      - SYMFONY__ENV__DATABASE_USER=wallabag
      - SYMFONY__ENV__DATABASE_PASSWORD=wallapass
      - SYMFONY__ENV__MAILER_HOST=127.0.0.1
      - SYMFONY__ENV__MAILER_USER=~
      - SYMFONY__ENV__MAILER_PASSWORD=~
      - SYMFONY__ENV__FROM_EMAIL=wallabag@example.com
    ports:
      - "80"
  db:
    image: mariadb
    environment:
      - MYSQL_ROOT_PASSWORD=wallaroot
    volumes:
      - /opt/wallabag:/var/lib/mysql
  redis:
    image: redis:alpine
```

Note that you must fill out the mail related variables according to your mail config.

## nginx

I use nginx to make wallabag public available. This is a example how to use it:

```
server {
        listen 443;
        server_name wallabag.foo.bar;

	ssl on;
        ssl_certificate /etc/letsencrypt/live/wallabag.foo.bar/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/wallabag.foo.bar/privkey.pem;

	location / {
		proxy_pass http://wallabag;
		proxy_set_header X-Forwarded-Host $server_name;
                proxy_set_header X-Forwarded-Proto https;
                proxy_set_header X-Forwarded-For $remote_addr;
	}

}
```

## Import worker

To run the [async redis import worker](http://doc.wallabag.org/en/master/developer/asynchronous.html#install-redis-for-asynchronous-tasks) use the following command:
```
$ docker run --name wallabag --link wallabag-db:wallabag-db --link redis:redis -e <... your config variables here ...>  wallabag/wallabag import <type>
```
Where `<type>` is one of pocket, readability, instapaper, wallabag_v1, wallabag_v2, firefox or chrome.
