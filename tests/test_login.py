import pytest
import re
import requests
import os

from requests.exceptions import ConnectionError

@pytest.fixture(scope="session")
def database(pytestconfig):
    return pytestconfig.getoption("database")

def is_responsive(url):
    try:
        response = requests.get(url)
        if response.status_code == 200:
            return True
    except ConnectionError:
        return False

@pytest.fixture(scope="session")
def docker_compose_project_name(database):
    return "wallabag_{}".format(database)

@pytest.fixture(scope="session")
def docker_cleanup():
    """Disable docker cleanup at the end of tests to get logs outside of pytest"""
    return False

@pytest.fixture(scope="session")
def docker_compose_command() -> str:
    return "docker-compose"

@pytest.fixture(scope="session")
def docker_compose_file(pytestconfig, database):
    return os.path.join(str(pytestconfig.rootdir), "tests/", "docker-compose.{}.yml".format(database))

@pytest.fixture(scope="session")
def wallabag_service(docker_ip, docker_services):
    """Ensure that wallabag service is up and responsive"""

    # `port_for` takes a container port and returns the corresponding host port
    port = docker_services.port_for("wallabag", 80)
    url = "http://{}:{}".format(docker_ip, port)
    docker_services.wait_until_responsive(
            timeout=60.0, pause=0.5, check=lambda: is_responsive(url)
    )
    return url

def test_accessing_login_page(wallabag_service):
    r = requests.get(wallabag_service, allow_redirects=True)

    assert r.status_code == 200
    assert 'Log in' in r.text
    assert 'Password' in r.text
    assert 'Username' in r.text


def test_logging_in(wallabag_service):
    client = requests.session()
    r = client.get(wallabag_service, allow_redirects=True)
    jar = r.cookies

    # get csrf token
    csrf_match = re.search(
        '<input type="hidden" name="_csrf_token" value="(.*)" />',
        r.text
    )

    if csrf_match:
        csrf = csrf_match.group(1)
    else:
        # if there is no csrf token the test will fail
        pytest.fail('csrf not matched')

    data = {
        '_username': 'wallabag',
        '_password': 'wallabag',
        '_csrf_token': csrf
    }

    r = client.post(wallabag_service + '/login_check', cookies=jar, data=data)
    assert r.status_code == 200
    assert '/unread/list' in r.text
    assert '/starred/list' in r.text
    assert '/archive/list' in r.text
    assert '/all/list' in r.text
