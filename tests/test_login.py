import pytest
import re
import requests


URL = 'http://127.0.0.1:80'


def test_accessing_login_page():
    r = requests.get(URL, allow_redirects=True)

    assert r.status_code == 200
    assert 'Log in' in r.text
    assert 'Password' in r.text
    assert 'Register' in r.text
    assert 'Username' in r.text


def test_logging_in():
    client = requests.session()
    r = client.get(URL, allow_redirects=True)
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

    r = client.post(URL + '/login_check', cookies=jar, data=data)
    assert r.status_code == 200
    assert '/unread/list' in r.text
    assert '/starred/list' in r.text
    assert '/archive/list' in r.text
    assert '/all/list' in r.text
