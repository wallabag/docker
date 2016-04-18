# What is wallabag?

[wallabag](https://www.wallabag.org/) is a self hostable application for saving web pages. Unlike other services, wallabag is free (as in freedom) and open source.

With this application you will not miss content anymore. Click, save, read it when you want. It saves the content you select so that you can read it when you have time.

# How to use this image

Default login is `wallabag:wallabag`.

## Environment variables

- `-e MYSQL_ROOT_PASSWORD=...` (needed for the mariadb container to initialise and for the entrypoint in the wallabag container to create a database and user if its not there)
- `-e SYMFONY__ENV__DATABASE_DRIVER=...` (defaults to "pdo_sqlite", this sets the database driver to use)
- `-e SYMFONY__ENV__DATABASE_HOST=...` (defaults to "127.0.0.1", if use mysql this should be the name of the mariadb container)
- `-e SYMFONY__ENV__DATABASE_PORT=...` (port of the database host)
- `-e SYMFONY__ENV__DATABASE_NAME=...`(defaults to "symfony", this is the name of the database to use)
- `-e SYMFONY__ENV__DATABASE_USER=...` (defaults to "root", this is the name of the database user to use)
- `-e SYMFONY__ENV__DATABASE_PASSWORD=...` (defaults to "~", this is the password of the database user to use)
- `-e SYMFONY__ENV__SECRET=...` (defaults to "ovmpmAWXRCabNlMgzlzFXDYmCFfzGv")

## sqlite

The easiest way to start wallabag is to use the sqlite backend. You can spin that up with

```
$ docker run -p 80:80 xsteadfastx/wallabag
```

and point your browser to `http://localhost:80`. For persistent storage you should start the container with the a volume:

```
$ docker run -v /opt/wallabag:/var/www/wallabag/data -p 80:80 xsteadfastx/wallabag
```

## mariadb / mysql

For using mariadb or mysql you have to define some environment variables with the container. Example:

```
$ docker run docker run --name wallabag-db -e "MYSQL_ROOT_PASSWORD=my-secret-pw" -d mariadb
$ docker run --name wallabag --link wallabag-db:wallabag-db -e "MYSQL_ROOT_PASSWORD=my-secret-pw" -e "SYMFONY__ENV__DATABASE_DRIVER=pdo_mysql" -e "SYMFONY__ENV__DATABASE_HOST=wallabag-db" -e "SYMFONY__ENV__DATABASE_PORT=3306" -e "SYMFONY__ENV__DATABASE_NAME=wallabag" -e "SYMFONY__ENV__DATABASE_USER=wallabag" -e "SYMFONY__ENV__DATABASE_PASSWORD=wallapass" -p 80:80 xsteadfastx/wallabag
```

## docker-compose

Its a good way to use [docker-compose](https://docs.docker.com/compose/). Example:

```
version: '2'
services:
  wallabag:
    build:
      context: wallabag/
    environment:
      - MYSQL_ROOT_PASSWORD=wallaroot
      - SYMFONY__ENV__DATABASE_DRIVER=pdo_mysql
      - SYMFONY__ENV__DATABASE_HOST=db
      - SYMFONY__ENV__DATABASE_PORT=3306
      - SYMFONY__ENV__DATABASE_NAME=wallabag
      - SYMFONY__ENV__DATABASE_USER=wallabag
      - SYMFONY__ENV__DATABASE_PASSWORD=wallapass
    ports:
      - "80"
  db:
    image: mariadb
    environment:
      - MYSQL_ROOT_PASSWORD=wallaroot
    volumes:
      - /opt/wallabag:/var/lib/mysql
```

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
