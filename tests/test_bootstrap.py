import os
from pathlib import Path
import subprocess

import pytest


@pytest.mark.parametrize("php_ready", [False, True])
def test_nginx_waits_for_php_fpm(tmp_path, php_ready):
    events = tmp_path / "events"
    ready = tmp_path / "ready"
    if php_ready:
        ready.touch()

    commands = {
        "nc": 'echo "nc $*" >> "$EVENTS"\n[ -f "$READY" ]\n',
        "sleep": 'echo "sleep $*" >> "$EVENTS"\ntouch "$READY"\n',
        "nginx": 'echo "nginx $*" >> "$EVENTS"\nexit 23\n',
    }
    for name, body in commands.items():
        command = tmp_path / name
        command.write_text("#!/bin/sh\n" + body)
        command.chmod(0o755)

    result = subprocess.run(
        ["/bin/sh", str(Path(__file__).resolve().parents[1] / "root/etc/s6/nginx/run")],
        env={**os.environ, "PATH": f"{tmp_path}:{os.defpath}",
             "EVENTS": str(events), "READY": str(ready)},
        capture_output=True,
        timeout=5,
    )

    expected = [] if php_ready else ["nc -z 127.0.0.1 9000", "sleep 1"]
    expected += ["nc -z 127.0.0.1 9000", "nginx -c /etc/nginx/nginx.conf"]
    assert events.read_text().splitlines() == expected
    assert result.returncode == 23
