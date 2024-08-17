Title: Python TDD Ohm
Date: 2024-08-17 11:31
Tags: python, tdd, xp
Authors: Jonathan Sharpe
Summary: Test-driven Python development done right - part 2

> **Note**: this was originally published as [JS TDD Ohm], using JavaScript with Express and Jest, but I've recently been working with a client using [Python] with [pytest] and [FastAPI], so this article is an updated version of the same example using the latter tech stack.

In [the previous article] in this series, I introduced some of the basics of test-driven development (TDD):

- the process:

    > 1. Red - write a failing test that describes the behaviour you want;
    > 2. Green - write the simplest possible code to make the test pass; and
    > 3. Refactor - clean up your code without breaking the tests.

- the three main parts of a test:

    > - **Arrange** (sometimes known as _"given"_) - set up the preconditions for our test...
    > - **Act** (or _"when"_) - do some work... This is what we're actually testing.
    > - **Assert** (or _"then"_) - make sure that the work was done correctly.

- some of the benefits of test-driving implementations:

    - _"...we can try out how we should interact with our code (its "interface") before we've even written any. We can have that discussion... while it's just a matter of changing our minds rather than the code."_;
    
    - _"...it tells you when you're done. Once the tests are passing, the implementation meets the current requirements."_; and
    
    - _"...we know that the code still does exactly what it's supposed to even [when] we've just changed the implementation. This allows us to confidently refactor towards cleaner code and higher quality."_

- how to _"call the shot"_ when running your tests:

    > ...make a prediction of what the test result will be, pass or fail. 
    > If you think the test will fail, **why**; will the expectation be 
    > unmet (and what value do you think you'll get instead) or will 
    > something else go wrong?

In this article we're going to dive into test-driving HTTP APIs and talk a bit more about how we can use testing to support us in designing the code we're working on.

### Requirements

I've aimed this content at more junior developers, so there are more explanations than all readers will need, but anyone new to testing and TDD should find something to take from it. We'll need:

- \*nix command line: already provided on macOS and Linux; if you're using Windows try WSL or Git BASH;
- Python (FastAPI requires at least 3.8 - this is written using 3.12, so you may need to write slightly different code in earlier versions, but all of the examples in the FastAPI docs allow you to pick your version) and [pipenv]; and
- Familiarity with Python syntax (including type annotations, which FastAPI uses to automatically generate API documentation).

In addition, given the domain for this post, you'll need:

- Familiarity with HTTP requests and responses.

Again please carefully _read everything_, and for newer developers I'd recommend _typing the code_ rather than copy-pasting.

## Setting the scene [1/9]

Our customer, **JonFX**, sells guitar pedal kits that you construct yourself at home.
These kits contain set of instructions and a bunch of electrical components, including resistors: 

![Picture of some resistors][resistors]

There are three representations of resistance (measured in Ohms, Ω) in use within this ecosystem.
For example, given a 22,000Ω resistor, it can be represented as:

- A number, `22_000`;
- A shorthand string, `"22K"`; or
- A set of bands on the physical component, e.g. **<span style="color: red">red</span>**, **<span style="color: red">red</span>**, **<span style="color: orange; background-color: black">&nbsp;orange&nbsp;</span>**.

Our customer has noted that people sometimes have difficulty converting between these representations, and asked us to build something to help solve the problem.

---

How do we prioritise which representations we should focus on to start with?
We want to deliver the most valuable thing first, so let's do some analysis.
There are three _personas_ who work with these representations:

- Debbie the designer: Debbie designs the circuits, and generally works with the _number_ representation. Once a design is complete the values are recorded in a manifest using the _shorthand_ notation;
- Colin the customer: Colin wants to buy and build one of the kits, which will include the manifest and the components with their _bands_; and
- Parul the packer: When Colin orders a kit, Parul is responsible for selecting the components based on the manifest, boxing them up and shipping them out.

Parul and Debbie both work with resistors and other electrical components on a very regular basis, so they probably don't need reminding what the bands mean, and if not there are various non-software interventions we could use to make their lives easier (for example, the boxes Parul is selecting components from could have a picture of the relevant bands and the shorthand printed in large letters to aid selection and refilling).
But it might be a while since Colin built his last kit (or he may even be a first-time customer), so that's the persona most likely to need help and therefore the highest value software would focus on the conversion between bands and shorthand, especially when you consider that the company will have far more Colins (thousands) than Paruls (ten) or Debbies (one).

---

Let's capture that as a _user story_ that we can refer back to if we need reminding what we're working towards:

> **As a** customer
> 
> **I want** to convert a set of bands to a shorthand string
> 
> **So that** I can match a given resistor to the diagram

For this exercise, we're going to be building the backend for a web UI; an acceptance criterion based on the above examples might be:

> - **Given** an input of the bands red, red, orange
>
>      **When** the client makes a request
> 
>      **Then** the response contains the shorthand `"22K"`

**Note**: for the sake of simplicity we will be working on an implementation that can convert values from 10Ω (or 100Ω for three value bands) up to but not including 1,000,000,000Ω.

## Welcome to the resistance [2/9]

As shown above, physical resistors have coloured bands which indicate their resistance.
The "rules of resistors" that we'll be following are:

1. A resistor must have two or three _value_ bands, unless it's a 0Ω resistor (which must have only a single black value band);
1. The first value band must not be black, unless it's a 0Ω resistor; and
1. A resistor must have a single _multiplier_ band.

The band colours indicate numbers via the following mapping:

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 |
|---|---|---|---|---|---|---|---|---|---|
| **<span style="color: black">black</span>** | **<span style="color: brown">brown</span>** | **<span style="color: red">red</span>** | **<span style="color: orange; background-color: black">&nbsp;orange&nbsp;</span>** | **<span style="color: yellow; background-color: black">&nbsp;yellow&nbsp;</span>** | **<span style="color: green">green</span>** | **<span style="color: blue">blue</span>** | **<span style="color: purple">violet</span>** | **<span style="color: dimgrey">grey</span>** | **<span style="color: white; background-color: black">&nbsp;white&nbsp;</span>** |

The numerical resistance is determined by taking the two or three value bands as the first two or three digits, then adding the number of zeros specified by the multiplier band to the end, e.g.:

- Value: **<span style="color: blue">blue</span>** - 6
- Value: **<span style="color: dimgrey">grey</span>** - 8
- Multiplier: **<span style="color: green">green</span>** - 5

becomes 6,800,000Ω (6 then 8 then 5 zeros). You could also calculate this as `((6 * 10) + 8) * (10 ** 5)`.

The shorthand form is created by replacing the left-most comma with M (for "mega", meaning a factor of one million) and dropping all trailing zeros<sup>1</sup>; in this case `"6M8"`.
For values between 1,000Ω and 999,999Ω the comma is replaced with K (for "kilo", meaning a factor of one thousand) instead, hence the 22,000Ω above becomes `"22K"`.
For values less than 1,000Ω the decimal point is replaced with R, so e.g. 150Ω (bands **<span style="color: brown">brown</span>**, **<span style="color: green">green</span>**, **<span style="color: brown">brown</span>**) would be represented as `"150R"`.

Here are a few more examples, or for more details you can read about this [electronic colour code] on Wikipedia:

| Numeric (Ω) | Shorthand | Bands |
|---|---|---|
| 22 | `"22R"` | **<span style="color: red">red</span>**, **<span style="color: red">red</span>**, **<span style="color: black">black</span>** |
| 12,700 | `"12K7"` | **<span style="color: brown">brown</span>**, **<span style="color: red">red</span>**, **<span style="color: purple">violet</span>**, **<span style="color: red">red</span>** |
| 330,000 | `"330K"` | **<span style="color: orange; background-color: black">&nbsp;orange&nbsp;</span>**, **<span style="color: orange; background-color: black">&nbsp;orange&nbsp;</span>**, **<span style="color: black">black</span>**, **<span style="color: orange; background-color: black">&nbsp;orange&nbsp;</span>** |
| 8,200,000 | `"8M2"` | **<span style="color: dimgrey">grey</span>**, **<span style="color: red">red</span>**, **<span style="color: green">green</span>** |

How can we represent this at the API level?
There are a few options, but for the purposes of working through this exercise let's say:

- The request method will be `GET`;
- The request path will be `/resistance`;
- The bands will be provided as a query parameter named `bands`;
- The response status code on success will be `200` ("OK"); and
- The response body on success will be a JSON object containing the shorthand representation.

Using [cURL], this might look like (assuming an environment variable `URL` has been set pointing to our API server):

```bash
$ curl "$URL/resistance?bands=brown&bands=red&bands=violet&bands=red"
{"shorthand":"12K7"}
```

## None more black [3/9]

Let's get started by creating a new [pipenv] package to hold our API:

```bash
$ mkdir resistance
$ cd $_
$ git init
Reinitialized existing Git repository in path/to/resistance/.git/
$ git commit --allow-empty --message 'Initial commit'
[main (root-commit) 7c30cd9] Initial commit
$ pipenv install
Creating a Pipfile for this project...
Pipfile.lock not found, creating...
Locking [packages] dependencies...
Locking [dev-packages] dependencies...
Updated Pipfile.lock (702ad05de9bc9de99a4807c8dde1686f31e0041d7b5f6f6b74861195a52110f5)!
To activate this project's virtualenv, run pipenv shell.
Alternatively, run a command inside the virtualenv with pipenv run.
To activate this project's virtualenv, run pipenv shell.
Alternatively, run a command inside the virtualenv with pipenv run.
Installing dependencies from Pipfile.lock (2110f5)...
$ git add .
$ git commit --message 'Create pipenv project'
[main c56f9f2] Create pipenv project
 2 files changed, 1 insertion(+), 3 deletions(-)
```
This will create a `Pipfile`, containing something like:
```toml
[[source]]
url = "https://pypi.org/simple"
verify_ssl = true
name = "pypi"

[packages]

[dev-packages]

[requires]
python_version = "3.12"
```
along with a `Pipfile.lock` which will be largely empty (until we start adding dependencies):

```json
{
    "_meta": {
        "hash": {
            "sha256": "702ad05de9bc9de99a4807c8dde1686f31e0041d7b5f6f6b74861195a52110f5"
        },
        "pipfile-spec": 6,
        "requires": {
            "python_version": "3.12"
        },
        "sources": [
            {
                "name": "pypi",
                "url": "https://pypi.org/simple",
                "verify_ssl": true
            }
        ]
    },
    "default": {},
    "develop": {}
}
```

Next, install [FastAPI], which we'll use to write and test our API endpoints, then [pytest] as the test runner:

```bash
$ pipenv install 'fastapi[standard]'
Installing fastapi...
Resolving fastapi[standard]...
Added fastapi to Pipfile's [packages] ...
✔ Installation Succeeded
Pipfile.lock (2110f5) out of date: run `pipfile lock` to update to (1a42bb)...
Running $ pipenv lock then $ pipenv sync.
Locking [packages] dependencies...
Building requirements...
Resolving dependencies...
✔ Success!
Locking [dev-packages] dependencies...
Updated Pipfile.lock (32f3a7325583c6d7bc3d4a81bbe168b8f4e158e2f313d4e85675c20d3d1a42bb)!
To activate this project's virtualenv, run pipenv shell.
Alternatively, run a command inside the virtualenv with pipenv run.
Installing dependencies from Pipfile.lock (1a42bb)...
All dependencies are now up-to-date!
To activate this project's virtualenv, run pipenv shell.
Alternatively, run a command inside the virtualenv with pipenv run.
Installing dependencies from Pipfile.lock (1a42bb)...
```
```bash
$ pipenv install --dev pytest
Installing pytest...
Resolving pytest...
Added pytest to Pipfile's [dev-packages] ...
✔ Installation Succeeded
Pipfile.lock (1a42bb) out of date: run `pipfile lock` to update to (cef74e)...
Running $ pipenv lock then $ pipenv sync.
Locking [packages] dependencies...
Building requirements...
Resolving dependencies...
✔ Success!
Locking [dev-packages] dependencies...
Building requirements...
Resolving dependencies...
✔ Success!
Updated Pipfile.lock (9207f36ec8d8c7e488e13ad84852aa51d32c08e7f3ead19ec0c91e8930cef74e)!
To activate this project's virtualenv, run pipenv shell.
Alternatively, run a command inside the virtualenv with pipenv run.
Installing dependencies from Pipfile.lock (cef74e)...
All dependencies are now up-to-date!
To activate this project's virtualenv, run pipenv shell.
Alternatively, run a command inside the virtualenv with pipenv run.
Installing dependencies from Pipfile.lock (cef74e)...
Installing dependencies from Pipfile.lock (cef74e)...
```
This will add those packages to your `Pipfile`:
```diff
  [packages]
+ fastapi = {extras = ["standard"], version = "*"}
  
  [dev-packages]
+ pytest = "*"
```
and update the lock file accordingly, as well as installing the packages for use locally.
Let's commit that:

```bash
$ git commit --message 'Install dependencies'
[main a3e239e] Install dependencies
 2 files changed, 715 insertions(+), 3 deletions(-)
```

To make it easy to run the tests, add the following to the end of the `Pipfile`:
```diff
+ 
+ [scripts]
+ test = "pytest"
  
```


Now `pipenv run test` will invoke pytest.
**Call the shot**, then run that command.

---

```bash
$ pipenv run test
================================== test session starts ===================================
platform darwin -- Python 3.12.0, pytest-8.3.2, pluggy-1.5.0
rootdir: path/to/resistance
plugins: anyio-4.4.0
collected 0 items

================================= no tests ran in 0.00s ==================================
```

Hopefully this is what you predicted - the test script ran, pytest is correctly installed, but no tests were found.
So let's create one, starting with the **simplest possible case**: the 0Ω resistor, a single black band. 
Put an empty `__init__.py` in a `tests` directory, then add the following to `tests/api_test.py`:

```python
from http import HTTPStatus

from fastapi.testclient import TestClient

from app import app


def test_single_black_band_returns_0R():
    response = TestClient(app).get("/resistance", params=dict(bands=["black"]))
    assert response.status_code == HTTPStatus.OK
    assert response.json() == {"shorthand": "0R"}
```

**Call the shot**, run the test.

---

```bash
$ pipenv run test
======================================= test session starts ========================================
platform darwin -- Python 3.12.0, pytest-8.3.2, pluggy-1.5.0
rootdir: path/to/resistance
plugins: anyio-4.4.0
collected 0 items / 1 error

============================================== ERRORS ==============================================
________________________________ ERROR collecting tests/api_test.py ________________________________
ImportError while importing test module 'path/to/resistance/tests/api_test.py'.
Hint: make sure your test modules/packages have valid Python names.
Traceback:
/Library/Frameworks/Python.framework/Versions/3.12/lib/python3.12/importlib/__init__.py:90: in import_module
    return _bootstrap._gcd_import(name[level:], package, level)
tests/api_test.py:3: in <module>
    from app import app
E   ModuleNotFoundError: No module named 'app'
===================================== short test summary info ======================================
ERROR tests/api_test.py
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! Interrupted: 1 error during collection !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
========================================= 1 error in 0.35s =========================================
```

Hopefully you predicted that: `app` wasn't defined, the test crashed before even getting the chance to fail.
So let's give it an app to test!
Create `app/__init__.py` containing the following:

```python
from fastapi import FastAPI

app = FastAPI()
```
What will happen when we re-run the test now?
**Call the shot**, then run it again.

---

```bash
$ pipenv run test
======================================= test session starts ========================================
platform darwin -- Python 3.12.0, pytest-8.3.2, pluggy-1.5.0
rootdir: path/to/resistance
plugins: anyio-4.4.0
collected 1 item

tests/api_test.py F                                                                          [100%]

============================================= FAILURES =============================================
________________________________ test_single_black_band_returns_0R _________________________________

    def test_single_black_band_returns_0R():
        response = TestClient(app).get("/resistance", params=dict(bands=["black"]))
>       assert response.status_code == HTTPStatus.OK
E       assert 404 == <HTTPStatus.OK: 200>
E        +  where 404 = <Response [404 Not Found]>.status_code
E        +  and   <HTTPStatus.OK: 200> = HTTPStatus.OK

tests/api_test.py:10: AssertionError
===================================== short test summary info ======================================
FAILED tests/api_test.py::test_single_black_band_returns_0R - assert 404 == <HTTPStatus.OK: 200>
======================================== 1 failed in 0.37s =========================================
```

That's a bit more like it, the test is now _failing_ (rather than _crashing_) and we're getting feedback at the HTTP API level (404 Not Found status code instead of the expected 200 OK).
Let's handle that endpoint and move the failure a bit further along; add the code to `app/__init__.py` to handle the GET request and immediately return 200 OK:

```diff
  from fastapi import FastAPI
  
  app = FastAPI()
+ 
+ 
+ @app.get("/resistance")
+ def _():
+     pass
```
**Call the shot**, then run the test.

---

```bash
$ pipenv run test
======================================= test session starts ========================================
platform darwin -- Python 3.12.0, pytest-8.3.2, pluggy-1.5.0
rootdir: path/to/resistance
plugins: anyio-4.4.0
collected 1 item

tests/api_test.py F                                                                          [100%]

============================================= FAILURES =============================================
________________________________ test_single_black_band_returns_0R _________________________________

    def test_single_black_band_returns_0R():
        response = TestClient(app).get("/resistance", params=dict(bands=["black"]))
        assert response.status_code == HTTPStatus.OK
>       assert response.json() == {"shorthand": "0R"}
E       AssertionError: assert None == {'shorthand': '0R'}
E        +  where None = json()
E        +    where json = <Response [200 OK]>.json

tests/api_test.py:9: AssertionError
===================================== short test summary info ======================================
FAILED tests/api_test.py::test_single_black_band_returns_0R - AssertionError: assert None == {'shorthand': '0R'}
======================================== 1 failed in 0.36s =========================================
```

Now we see a failure for the body of the response, rather than the status code.
If not, you may be handling the wrong path or method; double-check that the code in `app/__init__.py` matches up with the request defined in `tests/api_test.py`.

This makes sense - our _"path operation function"_ returns `None`, so the response content JSON will be `null`.
One of FastAPI's features is the use of [models][fastapi-models] to document (in the code itself and in generated [OpenAPI] documentation) request and response bodies.
Add a model describing the type of response body we're expecting to `app/__init__.py`:

```diff
  from fastapi import FastAPI
+ from pydantic import BaseModel
  
  app = FastAPI()
+ 
+ 
+ class ResistanceModel(BaseModel):
+     shorthand: str
  
  
  @app.get("/resistance")
- def _():
+ def _() -> ResistanceModel:
      pass
```

**Call the shot**, then run the test.

---

```bash
$ pipenv run test
======================================= test session starts ========================================
platform darwin -- Python 3.12.0, pytest-8.3.2, pluggy-1.5.0
rootdir: path/to/resistance
plugins: anyio-4.4.0
collected 1 item

tests/api_test.py F                                                                          [100%]

============================================= FAILURES =============================================
________________________________ test_single_black_band_returns_0R _________________________________

    def test_single_black_band_returns_0R():
>       response = TestClient(app).get("/resistance", params=dict(bands=["black"]))

tests/api_test.py:9:
_ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _
# ...
            if errors:
>               raise ResponseValidationError(
                    errors=_normalize_errors(errors), body=response_content
                )
E               fastapi.exceptions.ResponseValidationError: 1 validation errors:
E                 {'type': 'model_attributes_type', 'loc': ('response',), 'msg': 'Input should be a valid dictionary or object to extract fields from', 'input': None}

../../../../.local/share/virtualenvs/resistance-UW3A4gHD/lib/python3.12/site-packages/fastapi/routing.py:155: ResponseValidationError
===================================== short test summary info ======================================
FAILED tests/api_test.py::test_single_black_band_returns_0R - fastapi.exceptions.ResponseValidationError: 1 validation errors:
======================================== 1 failed in 0.18s =========================================
```

This one might be a bit surprising.
Rather than seeing some kind of response at the HTTP API level, the test is actually receiving a `ResponseValidationError` at the Python level.
Is this what would happen in real life, would our server crash and error without responding? 
Let's add a new script in the `Pipfile`, to allow us to start up the application, and investigate what actually happens:

```diff
  [scripts]
+ dev = "fastapi dev app"
  test = "pytest"
```
```bash
$ pipenv run dev
INFO     Using path app
INFO     Resolved absolute path path/to/resistance/app
INFO     Searching for package file structure from directories with __init__.py files
INFO     Importing from path/to/resistance

 ╭─ Python package file structure ─╮
 │                                 │
 │  📁 app                         │
 │  └── 🐍 __init__.py             │
 │                                 │
 ╰─────────────────────────────────╯

INFO     Importing module app
INFO     Found importable FastAPI app

 ╭─ Importable FastAPI app ─╮
 │                          │
 │  from app import app     │
 │                          │
 ╰──────────────────────────╯

INFO     Using import string app:app

 ╭────────── FastAPI CLI - Development mode ───────────╮
 │                                                     │
 │  Serving at: http://127.0.0.1:8000                  │
 │                                                     │
 │  API docs: http://127.0.0.1:8000/docs               │
 │                                                     │
 │  Running in development mode, for production use:   │
 │                                                     │
 │  fastapi run                                        │
 │                                                     │
 ╰─────────────────────────────────────────────────────╯

INFO:     Will watch for changes in these directories: ['path/to/resistance']
INFO:     Uvicorn running on http://127.0.0.1:8000 (Press CTRL+C to quit)
INFO:     Started reloader process [64850] using WatchFiles
INFO:     Started server process [64863]
INFO:     Waiting for application startup.
INFO:     Application startup complete.
```

In another terminal session, run:

```bash
$ curl -v http://127.0.0.1:8000/resistance?bands=black
*   Trying 127.0.0.1:8000...
* Connected to 127.0.0.1 (127.0.0.1) port 8000
> GET /resistance?bands=black HTTP/1.1
> Host: 127.0.0.1:8000
> User-Agent: curl/8.7.1
> Accept: */*
>
* Request completely sent off
< HTTP/1.1 500 Internal Server Error
< date: Thu, 15 Aug 2024 17:00:40 GMT
< server: uvicorn
< content-length: 21
< content-type: text/plain; charset=utf-8
<
* Connection #0 to host 127.0.0.1 left intact
Internal Server Error
```

This is the expected behaviour - the server still sends a response, but with a 5xx (server-side) error.
Back in the FastAPI logs, we see the details:

```bash
INFO:     127.0.0.1:56075 - "GET /resistance?bands=black HTTP/1.1" 500 Internal Server Error
ERROR:    Exception in ASGI application
Traceback (most recent call last):
  # ...
fastapi.exceptions.ResponseValidationError: 1 validation errors:
  {'type': 'model_attributes_type', 'loc': ('response',), 'msg': 'Input should be a valid dictionary or object to extract fields from', 'input': None}
```

We do have a failing test, and could continue to get it passing, but the _diagnostics_ are important.
We want to be able to test behaviour (HTTP requests and responses) not implementation details (Python errors).
So let's use a powerful pytest feature, [fixtures][pytest-fixtures], to solve the problem without filling our tests with details of what's happening.
Create a `tests/conftest.py` containing the following:

```python
from collections.abc import Generator
from socket import socket
from threading import Thread

import pytest
from httpx import Client
from uvicorn import Config, Server

from app import app


@pytest.fixture(scope="module")
def client() -> Generator[Client, None, None]:
    free_socket = _create_socket()
    host, port = free_socket.getsockname()
    server = Server(Config(app=app))
    thread = Thread(target=server.run, kwargs=dict(sockets=[free_socket]))
    thread.start()
    with Client(base_url=f"http://{host}:{port}") as client:
        yield client
    server.should_exit = True
    thread.join()


def _create_socket(host: str = "", port: int = 0) -> socket:
    socket_ = socket()
    socket_.bind((host, port))
    return socket_
```

If you want the detailed explanation of what's happening here, see the [bonus section](#bonus).
In brief, though, it's starting the app as a web server in the background, then providing a client the tests can use to make requests to it.

Update `tests/api_test.py` to use the fixture, instead of making its own FastAPI `TestClient`:

```diff
  from http import HTTPStatus

- from fastapi.testclient import TestClient
+ from httpx import Client
- 
- from app import app
  
  
- def test_single_black_band_returns_0R():
-     response = TestClient(app).get("/resistance", params=dict(bands=["black"]))
+ def test_single_black_band_returns_0R(client: Client):
+     response = client.get("/resistance", params=dict(bands=["black"]))
      assert response.status_code == HTTPStatus.OK
      assert response.json() == {"shorthand": "0R"}
```

Now run the test again:

```bash
$ pipenv run test
======================================= test session starts ========================================
platform darwin -- Python 3.12.0, pytest-8.3.2, pluggy-1.5.0
rootdir: path/to/resistance
plugins: anyio-4.4.0
collected 1 item

tests/api_test.py F                                                                          [100%]

============================================= FAILURES =============================================
________________________________ test_single_black_band_returns_0R _________________________________

client = <httpx.Client object at 0x104f4e570>

    def test_single_black_band_returns_0R(client: Client):
        response = client.get("/resistance", params=dict(bands=["black"]))
>       assert response.status_code == HTTPStatus.OK
E       assert 500 == <HTTPStatus.OK: 200>
E        +  where 500 = <Response [500 Internal Server Error]>.status_code
E        +  and   <HTTPStatus.OK: 200> = HTTPStatus.OK

tests/api_test.py:8: AssertionError
-------------------------------------- Captured stderr setup ---------------------------------------
INFO:     Started server process [72231]
INFO:     Waiting for application startup.
INFO:     Application startup complete.
--------------------------------------- Captured stdout call ---------------------------------------
INFO:     127.0.0.1:57542 - "GET /resistance?bands=black HTTP/1.1" 500 Internal Server Error
--------------------------------------- Captured stderr call ---------------------------------------
ERROR:    Exception in ASGI application
Traceback (most recent call last):
# ...
    raise ResponseValidationError(
fastapi.exceptions.ResponseValidationError: 1 validation errors:
  {'type': 'model_attributes_type', 'loc': ('response',), 'msg': 'Input should be a valid dictionary or object to extract fields from', 'input': None}

------------------------------------- Captured stderr teardown -------------------------------------
INFO:     Shutting down
INFO:     Waiting for application shutdown.
INFO:     Application shutdown complete.
INFO:     Finished server process [72231]
===================================== short test summary info ======================================
FAILED tests/api_test.py::test_single_black_band_returns_0R - assert 500 == <HTTPStatus.OK: 200>
======================================== 1 failed in 0.27s =========================================
```

You can still see the details of _why_ the server responded 500, but now the actual failure is the status code mismatch rather than a low-level error.
This is exactly what we're looking for, so update the implementation to get the test passing, then make a commit:

```bash
$ pipenv run test
======================================= test session starts ========================================
platform darwin -- Python 3.12.0, pytest-8.3.2, pluggy-1.5.0
rootdir: path/to/resistance
plugins: anyio-4.4.0
collected 1 item

tests/api_test.py .                                                                          [100%]

======================================== 1 passed in 0.36s =========================================
$ git commit --message 'Implement 0 Ohm resistor'
[main e062a7b] Implement 0 Ohm resistor
 5 files changed, 55 insertions(+)
 create mode 100644 app/__init__.py
 create mode 100644 tests/__init__.py
 create mode 100644 tests/api_test.py
 create mode 100644 tests/conftest.py
```

## Unhappy path to design \[4/9]

At this point you might be tempted to jump straight to an example like the 22kΩ resistor in the introduction, writing something like:

```python
def test_red_red_orange_returns_22K(client: Client):
    response = client.get("/resistance", params=dict(bands=["red", "red", "orange"]))
    assert response.status_code == HTTPStatus.OK
    assert response.json() == {"shorthand": "22K"}
```

But bear in mind that this is an HTTP API.
Anyone can make a request to it, and they might not send one that's well-formed.
In this case, where it's expecting a request like `/resistance?bands=black`, what if there _isn't_ a query parameter?
I've found this [status code flowchart] really useful for figuring out a semantically appropriate response; working through that I get down to `400 Bad Request`.
So let's write _that_ test:

```python
def test_no_bands_responds_400(client: Client):
    response = client.get("/resistance")
    assert response.status_code == HTTPStatus.BAD_REQUEST
```

Follow the TDD process:

1. Call the shot;
2. Run the test;
3. Ensure it fails usefully (edit the test and repeat steps 1 and 2 as needed);
4. Get it passing (edit the implementation); and
5. Make a commit.

**Remember**: never rely on your clients to make valid requests.
Even if you only intend for the API to be consumed by e.g. a React app you're maintaining, always check that input validation and authentication is applied correctly; it's trivial to make a request _without_ using the UI.

---

Next, what if there is a `bands` query parameter but its value isn't `black`?
That's a _structurally_ valid request, it has the query parameter, but e.g. `/resistance?bands=blue` is _semantically_ invalid; there's no real resistor with a single blue band.
From the above flowchart, I get to `422 Unprocessable Entity`.
So let's write a test for that:

```python
def test_single_blue_band_responds_422(client: Client):
    response = client.get("/resistance", params=dict(bands=["blue"]))
    assert response.status_code == HTTPStatus.UNPROCESSABLE_ENTITY
```

**Call the shot**, run the test.

---

```bash
$pipenv run test
================================== test session starts ===================================
platform darwin -- Python 3.12.0, pytest-8.3.2, pluggy-1.5.0
rootdir: path/to/resistance
plugins: anyio-4.4.0
collected 3 items

tests/api_test.py ..F                                                              [100%]

======================================== FAILURES ========================================
___________________________ test_single_blue_band_responds_422 ___________________________

client = <httpx.Client object at 0x11165aa50>

    def test_single_blue_band_responds_422(client: Client):
        response = client.get("/resistance", params=dict(bands=["blue"]))
>       assert response.status_code == HTTPStatus.UNPROCESSABLE_ENTITY
E       assert 200 == <HTTPStatus.UNPROCESSABLE_ENTITY: 422>
E        +  where 200 = <Response [200 OK]>.status_code
E        +  and   <HTTPStatus.UNPROCESSABLE_ENTITY: 422> = HTTPStatus.UNPROCESSABLE_ENTITY

tests/api_test.py:19: AssertionError
---------------------------------- Captured stdout call ----------------------------------
INFO:     127.0.0.1:62543 - "GET /resistance?bands=blue HTTP/1.1" 200 OK
-------------------------------- Captured stderr teardown --------------------------------
INFO:     Shutting down
INFO:     Waiting for application shutdown.
INFO:     Application shutdown complete.
INFO:     Finished server process [12134]
================================ short test summary info =================================
FAILED tests/api_test.py::test_single_blue_band_responds_422 - assert 200 == <HTTPStatus.UNPROCESSABLE_ENTITY: 422>
============================== 1 failed, 2 passed in 0.27s ===============================
```

Depending on which way you implemented the previous step, you might see either 200 != 422 or 400 != 422.
Either way, that's not the status code we're expecting.
The temptation here might be to do something like this:

```python
@app.get("/resistance")
def _(bands: Annotated[list[str], Query()] = None) -> ResistanceModel:
    if bands is None:
        raise HTTPException(status_code=HTTPStatus.BAD_REQUEST)
    if bands != ["black"]:
        raise HTTPException(status_code=HTTPStatus.UNPROCESSABLE_ENTITY)
    return ResistanceModel(shorthand="0R")
```

However, this is mixing up two very important concepts.
We have two _domains_ here: **transport** (HTTP requests and responses, things like paths, query parameters and status codes); and **business** (resistors and their resistance values).
Splitting this out into those two domains might look like:

| Request | Transport | Business |
|---|---|---|
| `GET /resistance` | _"A request with no `bands` query parameter is bad."_ -> `400` | N/A |
| `GET /resistance?bands=blue` | _"An invalid resistor isn't processable."_ -> `422` | _"A resistor with a single blue band isn't valid."_ |

Here you can see the split described above - the left-hand side is about HTTP APIs, the right-hand side is about resistors.
While handling a _structurally_ invalid request can be done entirely at the transport level, handling a _semantically_ invalid request is a business level question.

So let's take this opportunity to split out a _service_ in `app/service.py` to handle the business domain:

```python
def resistance(bands: list[str]) -> str:
    return "0R"
```

and use that in the `app/__init__.py` to create the `shorthand` attribute in the `ResistanceModel`.

This is a simple _refactor_, the `200` and `400` tests should still pass, and the `422` test should still fail (you can comment it out or [skip it][pytest-skip] to double-check).
It also gives us a new _boundary_ to test at, we can exercise the service code directly in `tests/service_test.py`:

```python
from app import resistance


def test_single_black_band_returns_0R():
    assert resistance(["black"]) == "0R"
```

At this point everything should be passing except the new API test:

```bash
$ pipenv run test
================================== test session starts ===================================
platform darwin -- Python 3.12.0, pytest-8.3.2, pluggy-1.5.0
rootdir: path/to/resistance
plugins: anyio-4.4.0
collected 4 items

tests/api_test.py ..s                                                              [ 75%]
tests/service_test.py .                                                            [100%]

============================== 3 passed, 1 skipped in 0.39s ==============================
```

You can run the low-level tests on their own by passing a test matching expression to pytest, e.g. `pipenv run test -k service`.
So how should we handle an invalid band?
Again this gives us a chance to do some design, think through how the function should behave by writing the test _before_ the implementation.
For example:

- We could return `None` for cases where the bands aren't valid, `assert resistance(["red"]) is None`,  but if _all_ we get back from the function in the failing case is `None` that doesn't tell us much about what the problem was;
- We could return a string describing the problem, but that would make it very difficult for the controller to distinguish between valid and invalid cases to send the appropriate responses;
- We could return some kind of object, `assert resistance(["red"]) == {"error": "..."}`, but that doesn't exactly scream _"your input made no sense"_.

I would say the right thing to do here is to **throw an error**, which can have a message explaining what the problem was.
Remember that you have to use a _context manager_ when you expect an error to be thrown, to ensure the test can handle the error:

```python
def test_single_non_black_band_raises_error():
    with pytest.raises(ValueError):
        resistance(["blue"])
```

**Call the shot**, run the test, check the diagnostics.

---

```bash
$ pipenv run test -k service
================================== test session starts ===================================
platform darwin -- Python 3.12.0, pytest-8.3.2, pluggy-1.5.0
rootdir: path/to/resistance
plugins: anyio-4.4.0
collected 5 items / 3 deselected / 2 selected

tests/service_test.py .F                                                           [100%]

======================================== FAILURES ========================================
________________________ test_single_non_black_band_raises_error _________________________

    def test_single_non_black_band_raises_error():
>       with pytest.raises(ValueError):
E       Failed: DID NOT RAISE <class 'ValueError'>

tests/service_test.py:11: Failed
================================ short test summary info =================================
FAILED tests/service_test.py::test_single_non_black_band_raises_error - Failed: DID NOT RAISE <class 'ValueError'>
======================= 1 failed, 1 passed, 3 deselected in 0.06s ========================
```
Get that test passing at the service level, then run all of the tests to bring the integration tests back in (remember to **call the shot**).

---

```bash
$ pipenv run test
================================== test session starts ===================================
platform darwin -- Python 3.12.0, pytest-8.3.2, pluggy-1.5.0
rootdir: path/to/resistance
plugins: anyio-4.4.0
collected 5 items

tests/api_test.py ..F                                                              [ 60%]
tests/service_test.py ..                                                           [100%]

======================================== FAILURES ========================================
___________________________ test_single_blue_band_responds_422 ___________________________

client = <httpx.Client object at 0x1034c3020>

    def test_single_blue_band_responds_422(client: Client):
        response = client.get("/resistance", params=dict(bands=["blue"]))
>       assert response.status_code == HTTPStatus.UNPROCESSABLE_ENTITY
E       assert 500 == <HTTPStatus.UNPROCESSABLE_ENTITY: 422>
E        +  where 500 = <Response [500 Internal Server Error]>.status_code
E        +  and   <HTTPStatus.UNPROCESSABLE_ENTITY: 422> = HTTPStatus.UNPROCESSABLE_ENTITY

tests/api_test.py:19: AssertionError
---------------------------------- Captured stdout call ----------------------------------
INFO:     127.0.0.1:64165 - "GET /resistance?bands=blue HTTP/1.1" 500 Internal Server Error
---------------------------------- Captured stderr call ----------------------------------
ERROR:    Exception in ASGI application
Traceback (most recent call last):
  # ...
  File "path/to/resistance/app/__init__.py", line 20, in _
    return ResistanceModel(shorthand=resistance(bands))
                                     ^^^^^^^^^^^^^^^^^
  File "path/to/resistance/app/service.py", line 3, in resistance
    raise ValueError
ValueError
-------------------------------- Captured stderr teardown --------------------------------
INFO:     Shutting down
INFO:     Waiting for application shutdown.
INFO:     Application shutdown complete.
INFO:     Finished server process [19140]
================================ short test summary info =================================
FAILED tests/api_test.py::test_single_blue_band_responds_422 - assert 500 == <HTTPStatus.UNPROCESSABLE_ENTITY: 422>
============================== 1 failed, 4 passed in 0.28s ===============================
```

We only have one failing test and can see the error at the _business_ level, so we just need to catch it in the path operation function and respond appropriately to the request to get the tests passing.
Once you're there, make a commit.

```bash
$ pipenv run test
================================== test session starts ===================================
platform darwin -- Python 3.12.0, pytest-8.3.2, pluggy-1.5.0
rootdir: path/to/resistance
plugins: anyio-4.4.0
collected 5 items

tests/api_test.py ...                                                              [ 60%]
tests/service_test.py ..                                                           [100%]

=================================== 5 passed in 0.24s ====================================
$ git add .
$ git commit -m 'Handle single non-black band'
[main 3cebb2c] Handle single non-black band
 4 files changed, 28 insertions(+), 1 deletion(-)
 create mode 100644 app/service.py
 create mode 100644 tests/service_test.py
```

## Double trouble [5/9]

An obvious next step at this point is to test what happens with _two_ bands, which is also invalid according to our rules.
Let's add a low-level test case for two bands:

```python
def test_two_bands_raises_error():
    with pytest.raises(ValueError):
        resistance(["black", "blue"])
```

It's worth noting that I've chosen to have `"black"` as the first of two bands _specifically_; this _was_ a valid first band for a 0Ω resistor, but isn't otherwise.
Any two-band "resistor" is invalid, but using this test case rules out the possibility that we _only_ check whether the first band is black (and not e.g. how many there are).

Call the shot, run the test.
If it fails (it may not, depending on how you've implemented the service so far!) then get it passing.
We already know that the API will respond 422 if the service throws an error, so we're done; make a commit:

```bash
$ pipenv run test
================================== test session starts ===================================
platform darwin -- Python 3.12.0, pytest-8.3.2, pluggy-1.5.0
rootdir: path/to/resistance
plugins: anyio-4.4.0
collected 6 items

tests/api_test.py ...                                                              [ 50%]
tests/service_test.py ...                                                          [100%]

=================================== 6 passed in 0.36s ====================================
$ git add .
$ git commit --message 'Error for two bands'
[main 6dae036] Error for two bands
 1 file changed, 5 insertions(+)
```

## Plotting a course [6/9]

Now we're in a nice position - we've designed and implemented an API, factored our app into _transport_ and _business_ domains, and are testing the integration across three cases:

- No bands - _structurally_ invalid, service doesn't get called, 400 response;
- One black band - service gets called, 200 response with its return value; and
- One non-black band or two bands - _semantically_ invalid, service gets called, 422 response on error.

Sure, we're only dealing with a single, trivial valid case: a 0Ω resistor, with a single black band (which is basically just a wire in the packaging of a resistor!)
Our code isn't going to help our end users much at this stage, but we've set the foundations to be able to confidently and rapidly iterate on the core functionality.
And if the user _does_ have a resistor with a single black band it gives them the correct answer!

Now, how to approach the more useful cases and actually return some non-zero answers?

In general, when I'm trying to work my way through a problem like this, I try to think about what the next _simplest_ step is - not just in the implementation to get the test passing, but in the _logic_ to write a failing test.
Let's keep using the 22,000Ω/`"22K"` case we started with.
Thinking about the three bands we are using, I'd propose that:

- The **second** band is the simplest to deal with, as it can represent any value 0-9 (`"20K"`, `"21K"`, ...); then
- The first band is the next simplest, as it can represent 1-9 (`"12K"`, `"22K"`, ...) but not 0 (throws an error leading to 422 response status); and finally
- The third is the most complex, as both the character and its _position_ can change (`"22R"`, `"220R"`, ...).

To keep us on track as we work towards the result, start with an integration-level test for a _different_ example, one we're not actually going to reach until all three bands are handled.
E.g. if the unit-level cases are based around the 22,000Ω example, use the 6,800,000Ω example for the integration-level case.
That stops us getting overexcited and shipping once we've handled both value bands but not yet the multiplier.
The alternative would be to ensure that cases that aren't yet supported explicitly throw an error, returning a 422 status, which means adding extra tests early on then deleting them as they become irrelevant (this is also an acceptable part of TDD).

So work through the cases in that order, writing [_parameterised tests_][pytest-parametrize] for each group.
By the time you're finished the suite at the service level should look something like this:

```python
import pytest

from app import resistance


def test_single_black_band_returns_0R():
    ...


def test_single_non_black_band_raises_error():
    ...


def test_two_bands_raises_error():
    ...


@pytest.mark.parametrize("second_band,shorthand", [
    ("black", "20K"),
    # ...
])
def test_three_bands_second_band_returns_correct_result(second_band, shorthand):
    assert resistance(["red", second_band, "orange"]) == shorthand


def test_three_bands_black_first_band_raises_error():
    ...


@pytest.mark.parametrize("first_band,shorthand", [
    # ...
])
def test_three_bands_first_band_returns_correct_result(first_band, shorthand):
    ...


@pytest.mark.parametrize("third_band,shorthand", [
    # ...
])
def test_three_bands_third_band_returns_correct_result(third_band, shorthand):
    ...
```

Giving test outputs like:

```bash
$ pipenv run test --verbose
================================== test session starts ===================================
platform darwin -- Python 3.12.0, pytest-8.3.2, pluggy-1.5.0 -- path/to/virtualenvs/resistance-UW3A4gHD/bin/python
cachedir: .pytest_cache
rootdir: path/to/resistance
plugins: anyio-4.4.0
collected 33 items

tests/api_test.py::test_single_black_band_returns_0R PASSED                        [  3%]
tests/api_test.py::test_no_bands_responds_400 PASSED                               [  6%]
tests/api_test.py::test_single_blue_band_responds_422 PASSED                       [  9%]
tests/api_test.py::test_blue_grey_red_returns_6M8 PASSED                           [ 12%]
tests/service_test.py::test_single_black_band_returns_0R PASSED                    [ 15%]
tests/service_test.py::test_single_non_black_band_raises_error PASSED              [ 18%]
tests/service_test.py::test_two_bands_raises_error PASSED                          [ 21%]
tests/service_test.py::test_three_bands_second_band_returns_correct_result[black-20K] PASSED [ 24%]
tests/service_test.py::test_three_bands_second_band_returns_correct_result[brown-21K] PASSED [ 27%]
tests/service_test.py::test_three_bands_second_band_returns_correct_result[red-22K] PASSED [ 30%]
tests/service_test.py::test_three_bands_second_band_returns_correct_result[orange-23K] PASSED [ 33%]
tests/service_test.py::test_three_bands_second_band_returns_correct_result[yellow-24K] PASSED [ 36%]
tests/service_test.py::test_three_bands_second_band_returns_correct_result[green-25K] PASSED [ 39%]
tests/service_test.py::test_three_bands_second_band_returns_correct_result[blue-26K] PASSED [ 42%]
tests/service_test.py::test_three_bands_second_band_returns_correct_result[violet-27K] PASSED [ 45%]
tests/service_test.py::test_three_bands_second_band_returns_correct_result[grey-28K] PASSED [ 48%]
tests/service_test.py::test_three_bands_second_band_returns_correct_result[white-29K] PASSED [ 51%]
tests/service_test.py::test_three_bands_black_first_band_raises_error PASSED       [ 54%]
tests/service_test.py::test_three_bands_first_band_returns_correct_result[brown-12K] PASSED [ 57%]
tests/service_test.py::test_three_bands_first_band_returns_correct_result[orange-32K] PASSED [ 60%]
tests/service_test.py::test_three_bands_first_band_returns_correct_result[yellow-42K] PASSED [ 63%]
tests/service_test.py::test_three_bands_first_band_returns_correct_result[green-52K] PASSED [ 66%]
tests/service_test.py::test_three_bands_first_band_returns_correct_result[blue-62K] PASSED [ 69%]
tests/service_test.py::test_three_bands_first_band_returns_correct_result[violet-72K] PASSED [ 72%]
tests/service_test.py::test_three_bands_first_band_returns_correct_result[grey-82K] PASSED [ 75%]
tests/service_test.py::test_three_bands_first_band_returns_correct_result[white-92K] PASSED [ 78%]
tests/service_test.py::test_three_bands_third_band_returns_correct_result[black-22R] PASSED [ 81%]
tests/service_test.py::test_three_bands_third_band_returns_correct_result[brown-220R] PASSED [ 84%]
tests/service_test.py::test_three_bands_third_band_returns_correct_result[red-2K2] PASSED [ 87%]
tests/service_test.py::test_three_bands_third_band_returns_correct_result[yellow-220K] PASSED [ 90%]
tests/service_test.py::test_three_bands_third_band_returns_correct_result[green-2M2] PASSED [ 93%]
tests/service_test.py::test_three_bands_third_band_returns_correct_result[blue-22M] PASSED [ 96%]
tests/service_test.py::test_three_bands_third_band_returns_correct_result[violet-220M] PASSED [100%]

=================================== 33 passed in 0.25s ===================================
```

Once everything's passing, make a commit.

## Four bands [7/9]

We can handle all valid one- and three-band resistors at this point, plus some invalid one- and two-band cases.
So let's handle resistors with _three_ value bands, adding an extra significant figure to the value.

Again it's important to think about the cases we're going to choose to ensure our code works correctly.
I would suggest at least three, based on the _structure_ of the output:

- Where the multiplier is a multiple of 3 (0, 3, 6, 9), i.e. the band is black, orange, blue or white, we already showed three digits, e.g. `"120R"`;
- Otherwise, we only showed two digits before, e.g. `"12K"` or `"1M2"`, so we're adding a third digit;
- Unless the third value band is black, in which case we still shouldn't show a trailing zero.

Here the cases we've selected have a meaning, so the name should clarify that meaning to the reader rather than just e.g. `"returns 123K for brown, red, orange, orange"`:

```python
def test_four_bands_adds_third_digit_in_the_middle():
    assert resistance(["brown", "red", "orange", "orange"]) == "123K"


def test_four_bands_adds_third_digit_at_the_end():
    assert resistance(["brown", "yellow", "violet", "brown"]) == "1K47"


def test_four_bands_does_not_add_trailing_zero():
    assert resistance(["blue", "grey", "black", "green"]) == "68M"
```

Introduce these tests (along with an API integration case, if you like), get everything passing and make a commit.

## Paradox of tolerance [8/9]

Now we're going to add a fourth rule of resistors:

<ol start="4">
  <li>A resistor may have a <em>tolerance</em> band (otherwise its tolerance is ±20%), unless it's a 0Ω resistor.
</ol>

We'll cover five possible cases here, which include two new band colours and reuse two of the existing colours:

| ±20% | ±10% | ±5% | ±2% | ±1% | 
|---|---|---|---|---|
| _No band_ | **<span style="color: gold; background-color: black">&nbsp;gold&nbsp;</span>** | **<span style="color: silver; background-color: black">&nbsp;silver&nbsp;</span>** | **<span style="color: red">red</span>** | **<span style="color: brown">brown</span>** |

This is, as you may just have realised, a bit of a problem.
If the tolerance band is optional, then what is e.g. **<span style="color: brown">brown</span>**, **<span style="color: green">green</span>**, **<span style="color: yellow; background-color: black">&nbsp;yellow&nbsp;</span>**, **<span style="color: red">red</span>** describing:

- 15,400Ω ±20%; or
- 150,000Ω ±2%?

Obviously that's quite a big difference; the circuit probably isn't going to work correctly if you use the wrong one!
On the physical packaging this is indicated by a gap - the value and multiplier bands are at one end of the resisistor, the tolerance band is at the other.
Perhaps we could do something similar, adding a separate parameter at the service level and a separate query parameter to the HTTP API?
For example, maybe something like:

```bash
$ curl 'http://localhost:3000/resistance?bands=brown&bands=green&bands=yellow&bands=red'
{"shorthand":"15K4","tolerance":0.2}
$ curl 'http://localhost:3000/resistance?bands=brown&bands=green&bands=yellow&tolerance=red'
{"shorthand":"150K","tolerance":0.02}
```

Here we're changing the responses for existing requests - now rather than `{"shorthand":"15K4"}`, we get `{"shorthand":"15K4","tolerance":0.2}`.
I'd suggest making this change first, as a separate commit, then moving on to include the actual tolerance bands.

Design the API and test-drive the implementation of your choice, starting with an integration test then driving out the full functionality through some unit tests.

Once you're happy, make a final commit - we're done!

## Exercises [9/9]

Here are some follow-up tasks for further practice (remember to **test-drive** anything you work on):

1. Predict and then check happens if you make a request where the bands aren't recognised colours (e.g. `GET /resistance?bands=fuchsia&bands=goldenrod&bands=octarine`) and/or there are multiple tolerance bands. Did you predict correctly? Do you think it's the _right_ behaviour - do you consider that request to be _semantically_ or _structurally_ invalid, and does the current implementation reflect that? If you think it should behave differently, update accordingly.
1. Return to step 4 and try out some different orders for introducing the three-band cases - did I suggest the right route, how much difference does it make?
1. Design and develop a different HTTP API (i.e. changing any or all of the request method, request path, use of query parameters or structure of the response body).
1. As well as the _value_, _multiplier_ and _tolerance_ bands, resistors may have a _temperature coefficient_ band - implement support for this.
1. There's a set of [preferred numbers] that resistors are generally designed to (e.g. for the default ±20% tolerance you'd get resistors only in multiples of 1.0, 1.5, 2.2, 3.3, 4.7 or 6.8) - introduce a "strict" mode in which non-preferred resistors are invalid inputs.
1. Write a CLI to expose the core functionality on the command line (you can use Python's built-in [`argparse`][python-argparse] to help you out) e.g. `pipenv run cli red green blue --tolerance silver`).

I'd recommend creating a new git branch for each one you try (e.g. use `git checkout -b <name>`) and making commits as appropriate.

## The fix(ture) is in [Bonus] {#bonus}

The content of `conftest.py` may look a little complicated, and uses some moderately advanced Python language features, but it allows:

1. our tests to make requests to a real server instance, avoiding the issue of some errors not being turned into responses by the `TestClient` setup; and
2. the setup and teardown to be handled outside of each individual test.

```python
from collections.abc import Generator
from socket import socket
from threading import Thread

import pytest
from httpx import Client
from uvicorn import Config, Server

from app import app


@pytest.fixture(scope="module")
def client() -> Generator[Client, None, None]:
    free_socket = _create_socket()
    host, port = free_socket.getsockname()
    server = Server(Config(app=app))
    thread = Thread(target=server.run, kwargs=dict(sockets=[free_socket]))
    thread.start()
    with Client(base_url=f"http://{host}:{port}") as client:
        yield client
    server.should_exit = True
    thread.join()


def _create_socket(host: str = "", port: int = 0) -> socket:
    socket_ = socket()
    socket_.bind((host, port))
    return socket_
```

In a bit more detail, focusing on the fixture function itself, here's what's happening:

- The first line:

        :::python
        @pytest.fixture(scope="module")

    is a _decorator_ registering the function as a pytest fixture, i.e. that its going to provide a value to be used in individual test cases.
    The module scope means that the fixture will only be called once for any given module that it's used in, and all of the tests in the same module will receive the same value (in our case, all of the tests in `tests/api_test.py` will make requests to the same server thread).

- On the next line:

        :::python
        def client() -> Generator[Client, None, None]:

    the fixture name is declared as `client` and the return type is declared as a [generator][python-generator], i.e. this is a function that's going to _yield_ one or more values, stopping its own execution until control is returned to it.
    In pytest, generators (or ["yield fixtures"][pytest-yield-fixtures]) are used to allow a fixture to be re-entered _after_ the test cases have run to do any necessary cleanup and teardown.

    In this case we only care about the type of value that's yielded, not what can be sent back to the generator or is eventually returned, so the other generics are just filled with `None`.

- Next we get a free socket and determine its host and port:

        :::python
        free_socket = _create_socket()
        host, port = free_socket.getsockname()

    This will bind a random port, so we can run the tests while the dev server is running without seeing any conflicts.

- Then we create a new [Uvicorn] server wrapping the FastAPI application:

        :::python
        server = Server(Config(app=app))

    This is the same server FastAPI uses for its `dev` and `run` CLI commands.

- Next we create the [thread][python-threading] that allows the server to run in the background while our tests are executed:

        :::python
        thread = Thread(target=server.run, kwargs=dict(sockets=[free_socket]))
        thread.start()

    The `target` argument is the callable that should be executed in the new thread.
    The `kwargs` argument defines additional keyword arguments that should be passed to the target callable when it's invoked.
    So when the thread starts, it will effectively run:

        :::python
        server.run(sockets=[free_socket])

- The final step before the fixture value is ready to be injected into the tests is creating an [`httpx` client][httpx-client]:

        :::python
        with Client(base_url=f"http://{host}:{port}") as client:

    This uses a _context manager_, per the documentation:

    > The recommended way to use a `Client` is as a context manager.
    > This will ensure that connections are properly cleaned up when leaving the `with` block

    The base URL is set to the host and port our server is listening on, allowing the tests to make _relative_ requests like `client.get("/resistance")`.

- Now the client object is yielded, providing the value of the fixture for the tests:

        :::python
        yield client

    The fixture function pauses execution at this point, waiting while pytest runs the tests that require the value.
    Once all of the tests in the module have finished running, pytest _re-enters_ the fixture function, allowing execution to continue from the next line.

- This leaves the context manager block, so `httpx` clears up any leftover connections, then runs:

        :::python
        server.should_exit = True

    This tells the Uvicorn server to stop accepting any new requests and prepare for shutdown.

- Finally:

        :::python
        thread.join()

    Joining the thread means the fixture function will now wait for that thread (and hence the server process) to exit before allowing the test suite to complete.

Fixtures are a powerful way to abstract setup and teardown out of your tests to keep them readable; here's an example of using them to test actual spacecraft 🚀:

<iframe width="560" height="315" src="https://www.youtube.com/embed/spCOYV4KyPA?si=accWVqeMBQn85oM7" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

---

<sup>1</sup> Actually, the proper [RKM code] uses trailing zeros to indicate a tighter tolerance, we will ignore that distinction for now.

[curl]: https://en.wikipedia.org/wiki/CURL
[electronic colour code]: https://en.wikipedia.org/wiki/Electronic_color_code
[JS TDD Ohm]: {filename}/development/js-tdd-ohm.md
[fastapi]: https://fastapi.tiangolo.com/
[fastapi-models]: https://fastapi.tiangolo.com/tutorial/response-model/
[httpx-client]: https://www.python-httpx.org/advanced/clients/
[openapi]: https://www.openapis.org/
[pipenv]: https://pipenv.pypa.io/en/latest/
[preferred numbers]: https://en.wikipedia.org/wiki/E_series_of_preferred_numbers
[pytest]: https://docs.pytest.org/en/stable/
[pytest-fixtures]: https://docs.pytest.org/en/stable/explanation/fixtures.html
[pytest-parametrize]: https://docs.pytest.org/en/stable/example/parametrize.html
[pytest-skip]: https://docs.pytest.org/en/stable/how-to/skipping.html
[pytest-yield-fixtures]: https://docs.pytest.org/en/stable/how-to/fixtures.html#yield-fixtures-recommended
[python]: https://www.python.org/
[python-argparse]: https://docs.python.org/3/library/argparse.html
[python-generator]: https://wiki.python.org/moin/Generators
[python-threading]: https://docs.python.org/3/library/threading.html
[resistors]: {static}/images/Electronic-Axial-Lead-Resistors-Array.png
[rkm code]: https://en.wikipedia.org/wiki/RKM_code
[status code flowchart]: https://www.codetinkerer.com/2015/12/04/choosing-an-http-status-code.html
[the previous article]: {filename}/development/python-tdd-ftw.md
[uvicorn]: https://www.uvicorn.org/
