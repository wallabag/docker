<?php

// JSON strings are valid YAML scalars; do not let credentials become YAML syntax.
foreach ([
    'SYMFONY__ENV__DATABASE_PASSWORD',
    'SYMFONY__ENV__SECRET',
    'SYMFONY__ENV__MAILER_DSN',
    'SYMFONY__ENV__RABBITMQ_PASSWORD',
    'SYMFONY__ENV__REDIS_PASSWORD',
    'SYMFONY__ENV__SENTRY_DSN',
] as $name) {
    $value = getenv($name);
    if ($value !== false && $value !== '') {
        // Symfony treats %name% as a parameter reference, even inside YAML strings.
        $value = str_replace('%', '%%', $value);
        putenv($name . '=' . json_encode($value, JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE));
    }
}

passthru('envsubst < ' . escapeshellarg(__DIR__ . '/parameters.template.yml'), $status);
exit($status);
