import json
from pathlib import Path
import subprocess
import uuid

import pytest


@pytest.mark.parametrize("variables, expected", [
    ({}, "my-super-user"),
    ({"POSTGRES_DB": "admin_database"}, "admin_database"),
    ({"POSTGRES_DB": ""}, "my-super-user"),
    ({"PGDATABASE": "legacy_database"}, "legacy_database"),
    ({"PGDATABASE": "legacy_database", "POSTGRES_DB": "admin_database"}, "legacy_database"),
    ({"PGDATABASE": "", "POSTGRES_DB": "admin_database"}, "admin_database"),
])
def test_postgresql_admin_database(pytestconfig, tmp_path, variables, expected):
    database = pytestconfig.getoption("database")
    compose = Path(__file__).parent / f"docker-compose.{database}.yml"
    config = subprocess.check_output(
        ["docker", "compose", "-f", str(compose), "config", "--format", "json"], text=True,
    )
    image = json.loads(config)["services"]["wallabag"]["image"]

    # Run the real entrypoint, but do not contact a database or start application services.
    commands = {name: "exit 0\n" for name in ("nc", "su", "s6-svscan")}
    commands["psql"] = 'printf "PSQL_DATABASE=%s\\n" "${PGDATABASE:-$POSTGRES_USER}" >&2\n'
    for name, body in commands.items():
        path = tmp_path / name
        path.write_text("#!/bin/sh\n" + body)
        path.chmod(0o755)

    env = {
        "PATH": "/run/test-bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
        "POSTGRES_USER": "my-super-user",
        "POSTGRES_PASSWORD": "test-password",
        "SYMFONY__ENV__DATABASE_DRIVER": "pdo_pgsql",
        "SYMFONY__ENV__DATABASE_HOST": "db",
        "SYMFONY__ENV__DATABASE_PORT": "5432",
        "SYMFONY__ENV__DATABASE_NAME": "wallabag",
        "SYMFONY__ENV__DATABASE_USER": "wallabag",
        "SYMFONY__ENV__DATABASE_PASSWORD": "wallapass",
        **variables,
    }
    name = "wallabag-postgresql-test-" + uuid.uuid4().hex
    command = ["docker", "run", "--rm", "--name", name, "-v", f"{tmp_path}:/run/test-bin:ro"]
    for name, value in env.items():
        command += ["-e", f"{name}={value}"]
    try:
        result = subprocess.run(command + [image], capture_output=True, text=True, timeout=30)
    finally:
        subprocess.run(["docker", "rm", "-f", name], capture_output=True, timeout=30)
    assert result.returncode == 0, result.stdout + result.stderr
    databases = [line.removeprefix("PSQL_DATABASE=") for line in result.stderr.splitlines()
                 if line.startswith("PSQL_DATABASE=")]
    assert databases == [expected] * 4
