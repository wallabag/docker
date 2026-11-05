import json
from pathlib import Path
import subprocess
import time
import uuid

import pytest
import requests


@pytest.fixture(scope="session")
def wallabag_image(pytestconfig):
    database = pytestconfig.getoption("database")
    compose = Path(__file__).parent / f"docker-compose.{database}.yml"
    config = subprocess.check_output(
        ["docker", "compose", "-f", str(compose), "config", "--format", "json"], text=True,
    )
    return json.loads(config)["services"]["wallabag"]["image"]


@pytest.fixture
def start_wallabag(wallabag_image):
    containers = []

    def start(*options, command=()):
        name = "wallabag-nginx-" + uuid.uuid4().hex
        containers.append(name)
        subprocess.run(
            ["docker", "run", "-d", "--name", name, "-p", "127.0.0.1::80",
             *options, wallabag_image, *command], check=True, capture_output=True,
        )
        return name

    yield start
    for name in containers:
        subprocess.run(["docker", "rm", "-f", name], capture_output=True, timeout=30)


def nginx_config(name):
    port = subprocess.check_output(["docker", "port", name, "80/tcp"], text=True).strip().rsplit(":", 1)[1]
    for _ in range(120):
        try:
            if requests.get(f"http://127.0.0.1:{port}", timeout=1).status_code == 200:
                return subprocess.check_output(
                    ["docker", "exec", name, "nginx", "-T"], text=True, stderr=subprocess.PIPE,
                )
        except requests.RequestException:
            pass
        time.sleep(0.5)
    logs = subprocess.check_output(["docker", "logs", name], text=True, stderr=subprocess.STDOUT)
    pytest.fail("Wallabag did not become ready:\n" + logs)


@pytest.mark.parametrize("timeout, expected", [
    (None, "300s"), ("", "300s"), ("900s", "900s"),
    ("15m", "15m"), ("500ms", "500ms"), ("1h30m", "1h30m"),
    ("invalid", None), ("1s2h", None),
    ("300s; access_log off; #", None), ("300s\n; access_log off; #", None),
])
def test_nginx_timeout(start_wallabag, timeout, expected):
    options = [] if timeout is None else ["-e", "FASTCGI_READ_TIMEOUT=" + timeout]
    name = start_wallabag(*options, "-e", "uri=must-not-replace-nginx-variables")
    if expected is None:
        status = subprocess.check_output(["docker", "wait", name], text=True, timeout=30)
        logs = subprocess.check_output(["docker", "logs", name], text=True, stderr=subprocess.STDOUT)
        assert status.strip() != "0"
        assert "FASTCGI_READ_TIMEOUT" in logs.upper()
    else:
        config = nginx_config(name)
        assert f"fastcgi_read_timeout {expected};" in config
        assert "try_files $uri /app.php$is_args$args;" in config


def test_custom_nginx_config_is_preserved(start_wallabag, tmp_path):
    config = Path(__file__).resolve().parents[1] / "root/etc/nginx/nginx.conf"
    custom = config.read_text().replace("keepalive_timeout 15;", "keepalive_timeout 42;")
    custom = custom.replace("include /etc/wallabag/fastcgi-read-timeout.conf;", "fastcgi_read_timeout 123s;")
    path = tmp_path / "nginx.conf"
    path.write_text(custom)
    name = start_wallabag("-v", f"{path}:/etc/nginx/nginx.conf:ro", "-e", "FASTCGI_READ_TIMEOUT=15m")
    loaded = nginx_config(name)
    assert "keepalive_timeout 42;" in loaded
    assert "fastcgi_read_timeout 123s;" in loaded
    assert path.read_text() == custom


@pytest.mark.parametrize("command, console_command", [
    (["import", "firefox"], "wallabag:import:redis-worker"),
    (["migrate"], "doctrine:migrations:migrate"),
])
def test_cli_commands_do_not_configure_nginx(start_wallabag, tmp_path, command, console_command):
    # Stub only the application console; exercise the real entrypoint and provisioner.
    console = tmp_path / "console"
    console.write_text('#!/usr/bin/env php\n<?php echo "TEST_CONSOLE: " . implode(" ", $argv) . PHP_EOL;\n')
    console.chmod(0o755)
    config = tmp_path / "nginx.conf"
    config.write_text("invalid nginx configuration\n")
    name = start_wallabag(
        "-e", "FASTCGI_READ_TIMEOUT=invalid",
        "-v", f"{console}:/var/www/wallabag/bin/console:ro",
        "-v", f"{config}:/etc/nginx/nginx.conf:ro", command=command,
    )
    status = subprocess.check_output(["docker", "wait", name], text=True, timeout=60)
    logs = subprocess.check_output(["docker", "logs", name], text=True, stderr=subprocess.STDOUT)
    assert status.strip() == "0", logs
    assert "TEST_CONSOLE: bin/console " + console_command in logs
