import re
import requests


URL = 'http://127.0.0.1:80'


def test_login_page():
    r = requests.get(URL, allow_redirects=True)

    assert r.status_code == 200
    assert 'Login' in r.text
    assert 'Password' in r.text
    assert 'Register' in r.text
    assert 'Username' in r.text


def test_login():
    csrf = ''
    client = requests.session()
    r = client.get(URL, allow_redirects=True)
    jar = r.cookies
    csrf_match = re.search('<input type="hidden" name="_csrf_token" value="(.*)" />', r.text)
    if csrf_match:
        csrf = csrf_match.group(1)
    else:
        print("csrf not matched")

    data = {
        '_username': 'wallabag',
        '_password': 'wallabag',
        '_csrf_token' : csrf
    }

    r = client.post(URL + '/login_check', cookies=jar, data=data)
    print(r.text)
    assert r.status_code == 200
    assert '/unread/list' in r.text
    assert '/starred/list' in r.text
    assert '/archive/list' in r.text
    assert '/all/list' in r.text
