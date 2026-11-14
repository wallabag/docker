<?php

$connection = new PDO(
    'mysql:host=' . getenv('SYMFONY__ENV__DATABASE_HOST')
        . ';port=' . getenv('SYMFONY__ENV__DATABASE_PORT') . ';charset=utf8mb4',
    'root',
    getenv('MYSQL_ROOT_PASSWORD'),
    [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
);

$connection->exec(
    'CREATE USER IF NOT EXISTS ' . $connection->quote(getenv('SYMFONY__ENV__DATABASE_USER'))
        . "@'%' IDENTIFIED BY " . $connection->quote(getenv('SYMFONY__ENV__DATABASE_PASSWORD'))
);
