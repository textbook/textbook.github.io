Title: Python TDD Ohm (redux)
Date: 2026-06-17 22:10
Tags: python, tdd, xp
Authors: Jonathan Sharpe
Summary: Test-driven Python development done right - part 2, again

> **Note**: this was originally published as [Python TDD Ohm], using [pipenv], but has been rewritten to use [uv]. The principles and process are exactly the same.

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
- Python (FastAPI requires at least 3.8 - this is written using 3.14, so you may need to write slightly different code in earlier versions, but all of the examples in the FastAPI docs allow you to pick your version) and [uv]; and
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

Let's get started by creating a new [uv] package to hold our API:

```bash
$ mkdir resistance
$ cd $_
$ uv init --package
Initialized project `resistance`
$ git commit --allow-empty --message 'Initial commit'
[main (root-commit) 7c30cd9] Initial commit
$ uv sync
uv sync
Using CPython 3.14.5+freethreaded
Creating virtual environment at: .venv
Resolved 1 package in 13ms
      Built resistance @ file:///path/to/resista
Prepared 1 package in 9ms
Installed 1 package in 3ms
 + resistance==0.1.0 (from file:///path/to/resistance)
$ git add .
$ git commit --message 'Create uv project'
[main 9772970] Create uv project
 6 files changed, 38 insertions(+)
 create mode 100644 .gitignore
 create mode 100644 .python-version
 create mode 100644 README.md
 create mode 100644 pyproject.toml
 create mode 100644 src/resistance/__init__.py
 create mode 100644 uv.lock
```
This will create a `pyproject.toml`, containing something like:
```toml
[project]
name = "resistance"
version = "0.1.0"
description = "Add your description here"
readme = "README.md"
authors = [
    { name = "Jonathan Sharpe", email = "mail@jonrshar.pe" }
]
requires-python = ">=3.14"
dependencies = []

[project.scripts]
resistance = "resistance:main"

[build-system]
requires = ["uv_build>=0.11.21,<0.12.0"]
build-backend = "uv_build"
```
along with a `uv.lock` which will be largely empty (until we start adding dependencies):

```toml
version = 1
revision = 3
requires-python = ">=3.14"

[[package]]
name = "resistance"
version = "0.1.0"
source = { editable = "." }

```

Next, install [FastAPI], which we'll use to write and test our API endpoints, then [pytest] as the test runner:

```bash
$ uv add 'fastapi[standard]'
Resolved 45 packages in 316ms
      Built resistance @ file://path/to/resista
Prepared 23 packages in 595ms
Uninstalled 1 package in 0.93ms
Installed 44 packages in 41ms
 + annotated-doc==0.0.4
# ...and a bunch of other packages...
 + websockets==16.0
```
```bash
$ uv add --dev pytest
Resolved 49 packages in 125ms
      Built resistance @ file://path/to/resista
Prepared 2 packages in 58ms
Uninstalled 1 package in 0.71ms
Installed 5 packages in 3ms
 + iniconfig==2.3.0
 + packaging==26.2
 + pluggy==1.6.0
 + pytest==9.1.0
 ~ resistance==0.1.0 (from file://path/to/resistance)
```
This will add those packages to your `pyproject.toml`:
```diff
-dependencies = []
+dependencies = [
+    "fastapi[standard]>=0.137.1",
+]
```

```diff
+
+[dependency-groups]
+dev = [
+    "pytest>=9.1.0",
+]
```
and update the lock file accordingly, as well as installing the packages for use locally.
Let's commit that:

```bash
$ git add .
$ git commit --message 'Install dependencies'
[main b3c2f56] Install dependencies
 2 files changed, 799 insertions(+), 1 deletion(-)
```

Now `uv run pytest` will invoke pytest.
**Call the shot**, then run that command.

---

```bash
$ uv run pytest
================================== test session starts ===================================
platform darwin -- Python 3.14.5, pytest-9.1.0, pluggy-1.6.0
rootdir: path/to/resistance
configfile: pyproject.toml
plugins: anyio-4.14.0
collected 0 items

================================= no tests ran in 0.00s ==================================
```

Hopefully this is what you predicted - the test script ran, pytest is correctly installed, but no tests were found.
So let's create one, starting with the **simplest possible case**: the 0Ω resistor, a single black band. 
Put an empty `__init__.py` in a `tests` directory, then add the following to `tests/api_test.py`:

```python
from http import HTTPStatus

from fastapi.testclient import TestClient

from resistance import app


def test_single_black_band_returns_0R():
    response = TestClient(app).get("/resistance", params=dict(bands=["black"]))
    assert response.status_code == HTTPStatus.OK
    assert response.json() == {"shorthand": "0R"}
```

**Call the shot**, run the test.

---

```bash
$ uv run pytest
================================== test session starts ===================================
platform darwin -- Python 3.14.5, pytest-9.1.0, pluggy-1.6.0
rootdir: path/to/resistance
configfile: pyproject.toml
plugins: anyio-4.14.0
collected 0 items / 1 error

========================================= ERRORS =========================================
___________________________ ERROR collecting tests/api_test.py ___________________________
ImportError while importing test module 'path/to/resistance/tests/api_test.py'.
Hint: make sure your test modules/packages have valid Python names.
Traceback:
../../.local/share/uv/python/cpython-3.14.5+freethreaded-macos-aarch64-none/lib/python3.14t/importlib/__init__.py:88: in import_module
    return _bootstrap._gcd_import(name[level:], package, level)
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
tests/api_test.py:5: in <module>
    from resistance import app
E   ImportError: cannot import name 'app' from 'resistance' (path/to/resistance/src/resistance/__init__.py)
==================================== warnings summary ====================================
.venv/lib/python3.14t/site-packages/fastapi/testclient.py:1
  path/to/resistance/.venv/lib/python3.14t/site-packages/fastapi/testclient.py:1: StarletteDeprecationWarning: Using `httpx` with `starlette.testclient` is deprecated; install `httpx2` instead.
    from starlette.testclient import TestClient as TestClient  # noqa

-- Docs: https://docs.pytest.org/en/stable/how-to/capture-warnings.html
================================ short test summary info =================================
ERROR tests/api_test.py
!!!!!!!!!!!!!!!!!!!!!!!!! Interrupted: 1 error during collection !!!!!!!!!!!!!!!!!!!!!!!!!
============================== 1 warning, 1 error in 0.14s ===============================
```

Hopefully you predicted that: `app` wasn't defined in `resistance`, the test crashed before even getting the chance to fail.
So let's give it an app to test!
Edit `src/resistance/__init__.py` to contain the following:

```python
from fastapi import FastAPI

app = FastAPI()
```
What will happen when we re-run the test now?
**Call the shot**, then run it again.

---

```bash
$ uv run pytest
================================== test session starts ===================================
platform darwin -- Python 3.14.5, pytest-9.1.0, pluggy-1.6.0
rootdir: path/to/resistance
configfile: pyproject.toml
plugins: anyio-4.14.0
collected 1 item

tests/api_test.py F                                                                [100%]

======================================== FAILURES ========================================
___________________________ test_single_black_band_returns_0R ____________________________

    def test_single_black_band_returns_0R():
        response = TestClient(app).get("/resistance", params=dict(bands=["black"]))
>       assert response.status_code == HTTPStatus.OK
E       assert 404 == <HTTPStatus.OK: 200>
E        +  where 404 = <Response [404 Not Found]>.status_code
E        +  and   <HTTPStatus.OK: 200> = HTTPStatus.OK

tests/api_test.py:10: AssertionError
==================================== warnings summary ====================================
.venv/lib/python3.14t/site-packages/fastapi/testclient.py:1
  path/to/resistance/.venv/lib/python3.14t/site-packages/fastapi/testclient.py:1: StarletteDeprecationWarning: Using `httpx` with `starlette.testclient` is deprecated; install `httpx2` instead.
    from starlette.testclient import TestClient as TestClient  # noqa

-- Docs: https://docs.pytest.org/en/stable/how-to/capture-warnings.html
================================ short test summary info =================================
FAILED tests/api_test.py::test_single_black_band_returns_0R - assert 404 == <HTTPStatus.OK: 200>
============================== 1 failed, 1 warning in 0.13s ==============================
```

That's a bit more like it, the test is now _failing_ (rather than _crashing_) and we're getting feedback at the HTTP API level (404 Not Found status code instead of the expected 200 OK).
Let's handle that endpoint and move the failure a bit further along; add the code to `src/resistance/__init__.py` to handle the GET request and immediately return 200 OK:

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
$ uv run pytest
================================== test session starts ===================================
platform darwin -- Python 3.14.5, pytest-9.1.0, pluggy-1.6.0
rootdir: path/to/resistance
configfile: pyproject.toml
plugins: anyio-4.14.0
collected 1 item

tests/api_test.py F                                                                [100%]

======================================== FAILURES ========================================
___________________________ test_single_black_band_returns_0R ____________________________

    def test_single_black_band_returns_0R():
        response = TestClient(app).get("/resistance", params=dict(bands=["black"]))
        assert response.status_code == HTTPStatus.OK
>       assert response.json() == {"shorthand": "0R"}
E       AssertionError: assert None == {'shorthand': '0R'}
E        +  where None = json()
E        +    where json = <Response [200 OK]>.json

tests/api_test.py:11: AssertionError
==================================== warnings summary ====================================
.venv/lib/python3.14t/site-packages/fastapi/testclient.py:1
  path/to/resistance/.venv/lib/python3.14t/site-packages/fastapi/testclient.py:1: StarletteDeprecationWarning: Using `httpx` with `starlette.testclient` is deprecated; install `httpx2` instead.
    from starlette.testclient import TestClient as TestClient  # noqa

-- Docs: https://docs.pytest.org/en/stable/how-to/capture-warnings.html
================================ short test summary info =================================
FAILED tests/api_test.py::test_single_black_band_returns_0R - AssertionError: assert None == {'shorthand': '0R'}
============================== 1 failed, 1 warning in 0.12s ==============================
```

Now we see a failure for the body of the response, rather than the status code.
If not, you may be handling the wrong path or method; double-check that the code in `src/resistance/__init__.py` matches up with the request defined in `tests/api_test.py`.

This makes sense - our _"path operation function"_ returns `None`, so the response content JSON will be `null`.
One of FastAPI's features is the use of [models][fastapi-models] to document (in the code itself and in generated [OpenAPI] documentation) request and response bodies.
Add a model describing the type of response body we're expecting to `src/resistance/__init__.py`:

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
$ uv run pytest
================================== test session starts ===================================
platform darwin -- Python 3.14.5, pytest-9.1.0, pluggy-1.6.0
rootdir: path/to/resistance
configfile: pyproject.toml
plugins: anyio-4.14.0
collected 1 item

tests/api_test.py F                                                                [100%]

======================================== FAILURES ========================================
___________________________ test_single_black_band_returns_0R ____________________________

    def test_single_black_band_returns_0R():
>       response = TestClient(app).get("/resistance", params=dict(bands=["black"]))
                   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

tests/api_test.py:9:
_ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _
# ...
            if errors:
                ctx = endpoint_ctx or EndpointContext()
>               raise ResponseValidationError(
                    errors=errors,
                    body=response_content,
                    endpoint_ctx=ctx,
                )
E               fastapi.exceptions.ResponseValidationError: 1 validation error:
E                 {'type': 'model_attributes_type', 'loc': ('response',), 'msg': 'Input should be a valid dictionary or object to extract fields from', 'input': None}
E
E                 File "path/to/resistance/src/resistance/__init__.py", line 11, in _
E                   GET /resistance

.venv/lib/python3.14t/site-packages/fastapi/routing.py:309: ResponseValidationError
==================================== warnings summary ====================================
.venv/lib/python3.14t/site-packages/fastapi/testclient.py:1
  path/to/resistance/.venv/lib/python3.14t/site-packages/fastapi/testclient.py:1: StarletteDeprecationWarning: Using `httpx` with `starlette.testclient` is deprecated; install `httpx2` instead.
    from starlette.testclient import TestClient as TestClient  # noqa

-- Docs: https://docs.pytest.org/en/stable/how-to/capture-warnings.html
================================ short test summary info =================================
FAILED tests/api_test.py::test_single_black_band_returns_0R - fastapi.exceptions.ResponseValidationError: 1 validation error:
============================== 1 failed, 1 warning in 0.27s ==============================
```

This one might be a bit surprising.
Rather than seeing some kind of response at the HTTP API level, the test is actually receiving a `ResponseValidationError` at the Python level.
Is this what would happen in real life, would our server crash and error without responding?
The `pyproject.toml` already includes a script, calling `resistance:main`:
```toml
[project.scripts]
resistance = "resistance:main"
```
We can configure that to allow us to start up the application and investigate what actually happens.
Add the following imports to `src/resistance/__init__.py`:

```diff
+import os
+
 from fastapi import FastAPI
 from pydantic import BaseModel
+from uvicorn import Config, Server
```
then define the `main` function at the end:
```python
def main() -> None:
    port = int(os.getenv("PORT", "8000"))
    server = Server(Config(app=app, port=port))
    server.run()
```
Now run the script and the app should start up:
```bash
$ uv run resistance
INFO:     Started server process [19558]
INFO:     Waiting for application startup.
INFO:     Application startup complete.
INFO:     Uvicorn running on http://127.0.0.1:8080 (Press CTRL+C to quit)
```

In another terminal session, run:

```bash
$ curl -v 'http://127.0.0.1:8000/resistance?bands=black'
*   Trying 127.0.0.1:8000...
* Connected to 127.0.0.1 (127.0.0.1) port 8000
> GET /resistance?bands=black HTTP/1.1
> Host: 127.0.0.1:8000
> User-Agent: curl/8.7.1
> Accept: */*
>
* Request completely sent off
< HTTP/1.1 500 Internal Server Error
< date: Wed, 17 Jun 2026 20:37:58 GMT
< server: uvicorn
< content-length: 21
< content-type: text/plain; charset=utf-8
<
* Connection #0 to host 127.0.0.1 left intact
Internal Server Error
```

Alternatively, visit http://localhost:8000/docs and use the Swagger UI to send a request and view the response.

This is the expected behaviour - the server still sends a response, but with a 5xx (server-side) error.
Back in the Uvicorn logs, we see the details:

```bash
INFO:     127.0.0.1:49571 - "GET /resistance?bands=black HTTP/1.1" 500 Internal Server Error
ERROR:    Exception in ASGI application
Traceback (most recent call last):
  # ...
fastapi.exceptions.ResponseValidationError: 1 validation error:
  {'type': 'model_attributes_type', 'loc': ('response',), 'msg': 'Input should be a valid dictionary or object to extract fields from', 'input': None}

  File "path/to/resistance/src/resistance/__init__.py", line 14, in _
    GET /resistance
```

We do have a failing test, and could continue to get it passing, but the _diagnostics_ are important.
We want to be able to test behaviour (HTTP requests and responses) not implementation details (Python errors).
So let's use a powerful pytest feature, [fixtures][pytest-fixtures], to solve the problem without filling our tests with details of what's happening.
Create a `tests/conftest.py` containing the following:

```python
from __future__ import annotations

from collections.abc import Generator
from socket import socket
from threading import Thread

import pytest
from fastapi import FastAPI
from httpx import Client
from uvicorn import Config, Server

from resistance import app


@pytest.fixture(scope="module")
def client() -> Generator[Client, None, None]:
    with TestServer.random_port(app) as server:
        with Client(base_url=server.url) as client:
            yield client


class TestServer:

    @classmethod
    def random_port(cls, application: FastAPI) -> TestServer:
        socket_ = socket()
        socket_.bind(("", 0))
        return cls(application, socket_)

    def __init__(self, application: FastAPI, socket_: socket):
        self._server = Server(Config(app=application))
        self._socket = socket_
        self._thread = Thread(
            target=self._server.run,
            kwargs=dict(sockets=[self._socket]),
        )

    def __enter__(self) -> TestServer:
        self._thread.start()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self._server.should_exit = True
        self._thread.join()

    @property
    def url(self) -> str:
        host, port = self._socket.getsockname()
        return f"http://{host}:{port}"
```

If you want the detailed explanation of what's happening here, see the [bonus section](#bonus).
In brief, though, it's starting the app as a web server in the background, then providing a client the tests can use to make requests to it.

Update `tests/api_test.py` to use the fixture, instead of making its own FastAPI `TestClient`:

```diff
  from http import HTTPStatus

- from fastapi.testclient import TestClient
+ from httpx import Client
- 
- from resistance import app
  
  
- def test_single_black_band_returns_0R():
-     response = TestClient(app).get("/resistance", params=dict(bands=["black"]))
+ def test_single_black_band_returns_0R(client: Client):
+     response = client.get("/resistance", params=dict(bands=["black"]))
      assert response.status_code == HTTPStatus.OK
      assert response.json() == {"shorthand": "0R"}
```

Now run the test again:

```bash
$ uv run pytest
================================== test session starts ===================================
platform darwin -- Python 3.14.5, pytest-9.1.0, pluggy-1.6.0
rootdir: path/to/resistance
configfile: pyproject.toml
plugins: anyio-4.14.0
collected 1 item

tests/api_test.py F                                                                [100%]

======================================== FAILURES ========================================
___________________________ test_single_black_band_returns_0R ____________________________

client = <httpx.Client object at 0x5d6d7f80610>

    def test_single_black_band_returns_0R(client: Client):
        response = client.get("/resistance", params=dict(bands=["black"]))
>       assert response.status_code == HTTPStatus.OK
E       assert 500 == <HTTPStatus.OK: 200>
E        +  where 500 = <Response [500 Internal Server Error]>.status_code
E        +  and   <HTTPStatus.OK: 200> = HTTPStatus.OK

tests/api_test.py:8: AssertionError
--------------------------------- Captured stderr setup ----------------------------------
INFO:     Started server process [22632]
INFO:     Waiting for application startup.
INFO:     Application startup complete.
---------------------------------- Captured stdout call ----------------------------------
INFO:     127.0.0.1:49682 - "GET /resistance?bands=black HTTP/1.1" 500 Internal Server Error
---------------------------------- Captured stderr call ----------------------------------
ERROR:    Exception in ASGI application
Traceback (most recent call last):
  # ...
fastapi.exceptions.ResponseValidationError: 1 validation error:
  {'type': 'model_attributes_type', 'loc': ('response',), 'msg': 'Input should be a valid dictionary or object to extract fields from', 'input': None}

  File "path/to/resistance/src/resistance/__init__.py", line 14, in _
    GET /resistance
----------------------------------- Captured log call ------------------------------------
INFO     uvicorn.access:httptools_impl.py:484 127.0.0.1:49682 - "GET /resistance?bands=black HTTP/1.1" 500
ERROR    uvicorn.error:httptools_impl.py:426 Exception in ASGI application
Traceback (most recent call last):
  # ...
fastapi.exceptions.ResponseValidationError: 1 validation error:
  {'type': 'model_attributes_type', 'loc': ('response',), 'msg': 'Input should be a valid dictionary or object to extract fields from', 'input': None}

  File "path/to/resistance/src/resistance/__init__.py", line 14, in _
    GET /resistance
-------------------------------- Captured stderr teardown --------------------------------
INFO:     Shutting down
INFO:     Waiting for application shutdown.
INFO:     Application shutdown complete.
INFO:     Finished server process [22632]
--------------------------------- Captured log teardown ----------------------------------
INFO     uvicorn.error:server.py:272 Shutting down
INFO     uvicorn.error:on.py:67 Waiting for application shutdown.
INFO     uvicorn.error:on.py:76 Application shutdown complete.
INFO     uvicorn.error:server.py:102 Finished server process [22632]
==================================== warnings summary ====================================
tests/api_test.py::test_single_black_band_returns_0R
  path/to/resistance/.venv/lib/python3.14t/site-packages/websockets/legacy/__init__.py:6: DeprecationWarning: websockets.legacy is deprecated; see https://websockets.readthedocs.io/en/stable/howto/upgrade.html for upgrade instructions
    warnings.warn(  # deprecated in 14.0 - 2024-11-09

tests/api_test.py::test_single_black_band_returns_0R
  path/to/resistance/.venv/lib/python3.14t/site-packages/uvicorn/protocols/websockets/websockets_impl.py:17: DeprecationWarning: websockets.server.WebSocketServerProtocol is deprecated
    from websockets.server import WebSocketServerProtocol

-- Docs: https://docs.pytest.org/en/stable/how-to/capture-warnings.html
================================ short test summary info =================================
FAILED tests/api_test.py::test_single_black_band_returns_0R - assert 500 == <HTTPStatus.OK: 200>
============================= 1 failed, 2 warnings in 0.23s ==============================
```

You can still see the details of _why_ the server responded 500, but now the actual failure is the status code mismatch rather than a low-level error.
This is exactly what we're looking for, so update the implementation to get the test passing, then make a commit:

```bash
$ uv run pytest
================================================ test session starts =================================================
platform darwin -- Python 3.14.5, pytest-9.1.0, pluggy-1.6.0
rootdir: path/to/resistance
configfile: pyproject.toml
plugins: anyio-4.14.0
collected 1 item                                                                                                     

tests/api_test.py .                                                                                            [100%]

================================================== warnings summary ==================================================
tests/api_test.py::test_single_black_band_returns_0R
  path/to/resistance/.venv/lib/python3.14t/site-packages/websockets/legacy/__init__.py:6: DeprecationWarning: websockets.legacy is deprecated; see https://websockets.readthedocs.io/en/stable/howto/upgrade.html for upgrade instructions
    warnings.warn(  # deprecated in 14.0 - 2024-11-09

tests/api_test.py::test_single_black_band_returns_0R
  path/to/resistance/.venv/lib/python3.14t/site-packages/uvicorn/protocols/websockets/websockets_impl.py:17: DeprecationWarning: websockets.server.WebSocketServerProtocol is deprecated
    from websockets.server import WebSocketServerProtocol

-- Docs: https://docs.pytest.org/en/stable/how-to/capture-warnings.html
=========================================== 1 passed, 2 warnings in 0.23s ============================================
$ git add .
$ git commit --message 'Implement 0 Ohm resistor'
[main 1f759b0] Implement 0 Ohm resistor
 4 files changed, 79 insertions(+), 1 deletion(-)
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
$ uv run pytest
================================== test session starts ===================================
platform darwin -- Python 3.14.5, pytest-9.1.0, pluggy-1.6.0
rootdir: path/to/resistance
configfile: pyproject.toml
plugins: anyio-4.14.0
collected 3 items

tests/api_test.py ..F                                                              [100%]

======================================== FAILURES ========================================
___________________________ test_single_blue_band_responds_422 ___________________________

client = <httpx.Client object at 0x5e479f70d90>

    def test_single_blue_band_responds_422(client: Client):
        response = client.get("/resistance", params=dict(bands=["blue"]))
>       assert response.status_code == HTTPStatus.UNPROCESSABLE_ENTITY
E       assert 200 == <HTTPStatus.UNPROCESSABLE_CONTENT: 422>
E        +  where 200 = <Response [200 OK]>.status_code
E        +  and   <HTTPStatus.UNPROCESSABLE_CONTENT: 422> = HTTPStatus.UNPROCESSABLE_ENTITY

tests/api_test.py:19: AssertionError
---------------------------------- Captured stdout call ----------------------------------
INFO:     127.0.0.1:49896 - "GET /resistance?bands=blue HTTP/1.1" 200 OK
----------------------------------- Captured log call ------------------------------------
INFO     uvicorn.access:httptools_impl.py:484 127.0.0.1:49896 - "GET /resistance?bands=blue HTTP/1.1" 200
-------------------------------- Captured stderr teardown --------------------------------
INFO:     Shutting down
INFO:     Waiting for application shutdown.
INFO:     Application shutdown complete.
INFO:     Finished server process [28927]
--------------------------------- Captured log teardown ----------------------------------
INFO     uvicorn.error:server.py:272 Shutting down
INFO     uvicorn.error:on.py:67 Waiting for application shutdown.
INFO     uvicorn.error:on.py:76 Application shutdown complete.
INFO     uvicorn.error:server.py:102 Finished server process [28927]
==================================== warnings summary ====================================
tests/api_test.py::test_single_black_band_returns_0R
  path/to/resistance/.venv/lib/python3.14t/site-packages/websockets/legacy/__init__.py:6: DeprecationWarning: websockets.legacy is deprecated; see https://websockets.readthedocs.io/en/stable/howto/upgrade.html for upgrade instructions
    warnings.warn(  # deprecated in 14.0 - 2024-11-09

tests/api_test.py::test_single_black_band_returns_0R
  path/to/resistance/.venv/lib/python3.14t/site-packages/uvicorn/protocols/websockets/websockets_impl.py:17: DeprecationWarning: websockets.server.WebSocketServerProtocol is deprecated
    from websockets.server import WebSocketServerProtocol

-- Docs: https://docs.pytest.org/en/stable/how-to/capture-warnings.html
================================ short test summary info =================================
FAILED tests/api_test.py::test_single_blue_band_responds_422 - assert 200 == <HTTPStatus.UNPROCESSABLE_CONTENT: 422>
======================== 1 failed, 2 passed, 2 warnings in 0.23s =========================
```

Depending on which way you implemented the previous step, you might see either 200 != 422 or 400 != 422.
Either way, that's not the status code we're expecting.
The temptation here might be to do something like this:

```python
@app.get("/resistance")
def _(bands: Annotated[list[str] | None, Query()] = None) -> ResistanceModel:
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

So let's take this opportunity to split out a _service_ in `src/resistance/service.py` to handle the business domain:

```python
def resistance(bands: list[str]) -> str:
    return "0R"
```

and use that in the `src/resistance/__init__.py` to create the `shorthand` attribute in the `ResistanceModel`.

This is a simple _refactor_, the `200` and `400` tests should still pass, and the `422` test should still fail (you can comment it out or [skip it][pytest-skip] to double-check).
It also gives us a new _boundary_ to test at, we can exercise the service code directly in `tests/service_test.py`:

```python
from resistance import resistance


def test_single_black_band_returns_0R():
    assert resistance(["black"]) == "0R"
```

At this point everything should be passing except the new API test:

```bash
$ uv run pytest
================================== test session starts ===================================
platform darwin -- Python 3.14.5, pytest-9.1.0, pluggy-1.6.0
rootdir: path/to/resistance
configfile: pyproject.toml
plugins: anyio-4.14.0
collected 4 items

tests/api_test.py ..F                                                              [ 75%]
tests/service_test.py .                                                            [100%]

======================================== FAILURES ========================================
___________________________ test_single_blue_band_responds_422 ___________________________

client = <httpx.Client object at 0x2cfd5e11090>

    def test_single_blue_band_responds_422(client: Client):
        response = client.get("/resistance", params=dict(bands=["blue"]))
>       assert response.status_code == HTTPStatus.UNPROCESSABLE_ENTITY
E       assert 200 == <HTTPStatus.UNPROCESSABLE_CONTENT: 422>
E        +  where 200 = <Response [200 OK]>.status_code
E        +  and   <HTTPStatus.UNPROCESSABLE_CONTENT: 422> = HTTPStatus.UNPROCESSABLE_ENTITY

tests/api_test.py:19: AssertionError
---------------------------------- Captured stdout call ----------------------------------
INFO:     127.0.0.1:49887 - "GET /resistance?bands=blue HTTP/1.1" 200 OK
----------------------------------- Captured log call ------------------------------------
INFO     uvicorn.access:httptools_impl.py:484 127.0.0.1:49887 - "GET /resistance?bands=blue HTTP/1.1" 200
-------------------------------- Captured stderr teardown --------------------------------
INFO:     Shutting down
INFO:     Waiting for application shutdown.
INFO:     Application shutdown complete.
INFO:     Finished server process [28614]
--------------------------------- Captured log teardown ----------------------------------
INFO     uvicorn.error:server.py:272 Shutting down
INFO     uvicorn.error:on.py:67 Waiting for application shutdown.
INFO     uvicorn.error:on.py:76 Application shutdown complete.
INFO     uvicorn.error:server.py:102 Finished server process [28614]
==================================== warnings summary ====================================
tests/api_test.py::test_single_black_band_returns_0R
  path/to/resistance/.venv/lib/python3.14t/site-packages/websockets/legacy/__init__.py:6: DeprecationWarning: websockets.legacy is deprecated; see https://websockets.readthedocs.io/en/stable/howto/upgrade.html for upgrade instructions
    warnings.warn(  # deprecated in 14.0 - 2024-11-09

tests/api_test.py::test_single_black_band_returns_0R
  path/to/resistance/.venv/lib/python3.14t/site-packages/uvicorn/protocols/websockets/websockets_impl.py:17: DeprecationWarning: websockets.server.WebSocketServerProtocol is deprecated
    from websockets.server import WebSocketServerProtocol

-- Docs: https://docs.pytest.org/en/stable/how-to/capture-warnings.html
================================ short test summary info =================================
FAILED tests/api_test.py::test_single_blue_band_responds_422 - assert 200 == <HTTPStatus.UNPROCESSABLE_CONTENT: 422>
======================== 1 failed, 3 passed, 2 warnings in 0.24s =========================
```

You can run the low-level tests on their own by passing a test matching expression to pytest, e.g. `uv run pytest -k service`.
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

**Call the shot**, run the service tests, check the diagnostics.

---

```bash
$ uv run pytest -k service
================================== test session starts ===================================
platform darwin -- Python 3.14.5, pytest-9.1.0, pluggy-1.6.0
rootdir: path/to/resistance
configfile: pyproject.toml
plugins: anyio-4.14.0
collected 5 items / 3 deselected / 2 selected

tests/service_test.py .F                                                           [100%]

======================================== FAILURES ========================================
________________________ test_single_non_black_band_raises_error _________________________

    def test_single_non_black_band_raises_error():
>       with pytest.raises(ValueError):
             ^^^^^^^^^^^^^^^^^^^^^^^^^
E       Failed: DID NOT RAISE ValueError

tests/service_test.py:11: Failed
================================ short test summary info =================================
FAILED tests/service_test.py::test_single_non_black_band_raises_error - Failed: DID NOT RAISE ValueError
======================= 1 failed, 1 passed, 3 deselected in 0.02s ========================
```
Get that test passing at the service level, then run all of the tests to bring the integration tests back in (remember to **call the shot**).

---

```bash
$ uv run pytest
================================== test session starts ===================================
platform darwin -- Python 3.14.5, pytest-9.1.0, pluggy-1.6.0
rootdir: path/to/resistance
configfile: pyproject.toml
plugins: anyio-4.14.0
collected 5 items

tests/api_test.py ..F                                                              [ 60%]
tests/service_test.py ..                                                           [100%]

======================================== FAILURES ========================================
___________________________ test_single_blue_band_responds_422 ___________________________

client = <httpx.Client object at 0x318b9ea1390>

    def test_single_blue_band_responds_422(client: Client):
        response = client.get("/resistance", params=dict(bands=["blue"]))
>       assert response.status_code == HTTPStatus.UNPROCESSABLE_ENTITY
E       assert 500 == <HTTPStatus.UNPROCESSABLE_CONTENT: 422>
E        +  where 500 = <Response [500 Internal Server Error]>.status_code
E        +  and   <HTTPStatus.UNPROCESSABLE_CONTENT: 422> = HTTPStatus.UNPROCESSABLE_ENTITY

tests/api_test.py:19: AssertionError
---------------------------------- Captured stdout call ----------------------------------
INFO:     127.0.0.1:49936 - "GET /resistance?bands=blue HTTP/1.1" 500 Internal Server Error
---------------------------------- Captured stderr call ----------------------------------
ERROR:    Exception in ASGI application
Traceback (most recent call last):
  # ...
  File "path/to/resistance/src/resistance/__init__.py", line 22, in _
    return ResistanceModel(shorthand=resistance(bands))
                                     ~~~~~~~~~~^^^^^^^
  File "path/to/resistance/src/resistance/service.py", line 3, in resistance
    raise ValueError
ValueError
----------------------------------- Captured log call ------------------------------------
INFO     uvicorn.access:httptools_impl.py:484 127.0.0.1:49936 - "GET /resistance?bands=blue HTTP/1.1" 500
ERROR    uvicorn.error:httptools_impl.py:426 Exception in ASGI application
Traceback (most recent call last):
  # ...
  File "path/to/resistance/src/resistance/__init__.py", line 22, in _
    return ResistanceModel(shorthand=resistance(bands))
                                     ~~~~~~~~~~^^^^^^^
  File "path/to/resistance/src/resistance/service.py", line 3, in resistance
    raise ValueError
ValueError
-------------------------------- Captured stderr teardown --------------------------------
INFO:     Shutting down
INFO:     Waiting for application shutdown.
INFO:     Application shutdown complete.
INFO:     Finished server process [30107]
--------------------------------- Captured log teardown ----------------------------------
INFO     uvicorn.error:server.py:272 Shutting down
INFO     uvicorn.error:on.py:67 Waiting for application shutdown.
INFO     uvicorn.error:on.py:76 Application shutdown complete.
INFO     uvicorn.error:server.py:102 Finished server process [30107]
==================================== warnings summary ====================================
tests/api_test.py::test_single_black_band_returns_0R
  path/to/resistance/.venv/lib/python3.14t/site-packages/websockets/legacy/__init__.py:6: DeprecationWarning: websockets.legacy is deprecated; see https://websockets.readthedocs.io/en/stable/howto/upgrade.html for upgrade instructions
    warnings.warn(  # deprecated in 14.0 - 2024-11-09

tests/api_test.py::test_single_black_band_returns_0R
  path/to/resistance/.venv/lib/python3.14t/site-packages/uvicorn/protocols/websockets/websockets_impl.py:17: DeprecationWarning: websockets.server.WebSocketServerProtocol is deprecated
    from websockets.server import WebSocketServerProtocol

-- Docs: https://docs.pytest.org/en/stable/how-to/capture-warnings.html
================================ short test summary info =================================
FAILED tests/api_test.py::test_single_blue_band_responds_422 - assert 500 == <HTTPStatus.UNPROCESSABLE_CONTENT: 422>
======================== 1 failed, 4 passed, 2 warnings in 0.24s =========================
```

We only have one failing test and can see the error at the _business_ level, so we just need to catch it in the path operation function and respond appropriately to the request to get the tests passing.
Once you're there, make a commit.

```bash
$ uv run pytest
================================== test session starts ===================================
platform darwin -- Python 3.14.5, pytest-9.1.0, pluggy-1.6.0
rootdir: path/to/resistance
configfile: pyproject.toml
plugins: anyio-4.14.0
collected 5 items

tests/api_test.py ...                                                              [ 60%]
tests/service_test.py ..                                                           [100%]

==================================== warnings summary ====================================
tests/api_test.py::test_single_black_band_returns_0R
  path/to/resistance/.venv/lib/python3.14t/site-packages/websockets/legacy/__init__.py:6: DeprecationWarning: websockets.legacy is deprecated; see https://websockets.readthedocs.io/en/stable/howto/upgrade.html for upgrade instructions
    warnings.warn(  # deprecated in 14.0 - 2024-11-09

tests/api_test.py::test_single_black_band_returns_0R
  path/to/resistance/.venv/lib/python3.14t/site-packages/uvicorn/protocols/websockets/websockets_impl.py:17: DeprecationWarning: websockets.server.WebSocketServerProtocol is deprecated
    from websockets.server import WebSocketServerProtocol

-- Docs: https://docs.pytest.org/en/stable/how-to/capture-warnings.html
============================= 5 passed, 2 warnings in 0.23s ==============================
$ git add .
$ git commit -m 'Handle single non-black band'
[main 3cebb2c] Handle single non-black band
[main 4f90b92] Handle single non-black band
 4 files changed, 27 insertions(+), 1 deletion(-)
 create mode 100644 src/resistance/service.py
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
$ uv run pytest
================================== test session starts ===================================
platform darwin -- Python 3.14.5, pytest-9.1.0, pluggy-1.6.0
rootdir: path/to/resistance
configfile: pyproject.toml
plugins: anyio-4.14.0
collected 6 items

tests/api_test.py ...                                                              [ 50%]
tests/service_test.py ...                                                          [100%]

==================================== warnings summary ====================================
tests/api_test.py::test_single_black_band_returns_0R
  path/to/resistance/.venv/lib/python3.14t/site-packages/websockets/legacy/__init__.py:6: DeprecationWarning: websockets.legacy is deprecated; see https://websockets.readthedocs.io/en/stable/howto/upgrade.html for upgrade instructions
    warnings.warn(  # deprecated in 14.0 - 2024-11-09

tests/api_test.py::test_single_black_band_returns_0R
  path/to/resistance/.venv/lib/python3.14t/site-packages/uvicorn/protocols/websockets/websockets_impl.py:17: DeprecationWarning: websockets.server.WebSocketServerProtocol is deprecated
    from websockets.server import WebSocketServerProtocol

-- Docs: https://docs.pytest.org/en/stable/how-to/capture-warnings.html
============================= 6 passed, 2 warnings in 0.22s ==============================
$ git add .
$ git commit --message 'Error for two bands'
[main a910bfe] Error for two bands
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
$ uv run pytest --verbose
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
$ curl 'http://localhost:8000/resistance?bands=brown&bands=green&bands=yellow&bands=red'
{"shorthand":"15K4","tolerance":0.2}
$ curl 'http://localhost:8000/resistance?bands=brown&bands=green&bands=yellow&tolerance=red'
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
1. Write a CLI to expose the core functionality on the command line (you can use Python's built-in [`argparse`][python-argparse] to help you out) e.g. `uv run cli red green blue --tolerance silver`).

I'd recommend creating a new git branch for each one you try (e.g. use `git checkout -b <name>`) and making commits as appropriate.

## The fix(ture) is in [Bonus] {#bonus}

The content of `conftest.py` may look a little complicated, and uses some moderately advanced Python language features, but it allows:

1. our tests to make requests to a real server instance, avoiding the issue of some errors not being turned into responses by the `TestClient` setup; and
2. the setup and teardown to be handled outside of each individual test.

**Note** the core logic for running the server on a separate thread was taken from [_"Starting and Stopping `uvicorn` in the Background"_][bugfactory-uvicorn] by Christoph Schiessl.

```python
from __future__ import annotations

from collections.abc import Generator
from socket import socket
from threading import Thread

import pytest
from fastapi import FastAPI
from httpx import Client
from uvicorn import Config, Server

from app import app


@pytest.fixture(scope="module")
def client() -> Generator[Client, None, None]:
    with TestServer.random_port(app) as server:
        with Client(base_url=server.url) as client:
            yield client


class TestServer:

    @classmethod
    def random_port(cls, application: FastAPI) -> TestServer:
        socket_ = socket()
        socket_.bind(("", 0))
        return cls(application, socket_)

    def __init__(self, application: FastAPI, socket_: socket):
        self._server = Server(Config(app=application))
        self._socket = socket_
        self._thread = Thread(
            target=self._server.run,
            kwargs=dict(sockets=[self._socket]),
        )

    def __enter__(self) -> TestServer:
        self._thread.start()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self._server.should_exit = True
        self._thread.join()

    @property
    def url(self) -> str:
        host, port = self._socket.getsockname()
        return f"http://{host}:{port}"
```

In a bit more detail, focusing on the fixture function itself, here's what's happening:

- The first line:

        :::python
        @pytest.fixture(scope="module")

    is a _decorator_ registering the function as a pytest fixture, i.e. that its going to provide a value to be used in individual test cases.
    The module scope means that the fixture will only be called once for any given module that it's used in, and all of the tests in the same module will receive the same value (so in our case, all of the tests in `tests/api_test.py` will make requests to the same server thread).
     Without this, the default scope `"function"` would be used, and a separate server created for each test (if you try this you can see it takes much longer to run the suite).

- On the next line:

        :::python
        def client() -> Generator[Client, None, None]:

    the fixture name is declared as `client` and the return type is declared as a [generator][python-generator], i.e. this is a function that's going to _yield_ one or more values, stopping its own execution until control is returned to it.
    In pytest, generators (or ["yield fixtures"][pytest-yield-fixtures]) are used to allow a fixture to be re-entered _after_ the test cases have run to do any necessary cleanup and teardown.

    In this case we only care about the type of value that's yielded, not what can be sent back to the generator or is eventually returned, so the other generics are just filled with `None`.

- Within the fixture, we first create a server that wraps our FastAPI application, listening on a random port:

        :::python
        with TestServer.random_port(app) as server:

    `TestServer` is a custom class written for this purpose; we'll go into a bit more detail on how this works below.

- The next step before the fixture value is ready to be injected into the tests is creating an [`httpx` client][httpx-client]:

        :::python
        with Client(base_url=server.url) as client:

    This uses a _context manager_, per the documentation:

    > The recommended way to use a `Client` is as a context manager.
    > This will ensure that connections are properly cleaned up when leaving the `with` block

    Setting the base URL allows the tests to make _relative_ requests like `client.get("/resistance")`.

- Now the client object is yielded, providing the value of the fixture for the tests:

        :::python
        yield client

    The fixture function pauses execution at this point, waiting while pytest runs the tests that require the value.
    Once all of the tests in the module have finished running, pytest _re-enters_ the fixture function, allowing execution to continue from the next line.
    This allows the cleanup on exiting the two context managers to be deferred - if this was `return client` instead, the client would be closed and the server shut down _before_ sending the value to the tests, so they'd all fail with:

        RuntimeError: Cannot send a request, as the client has been closed.

So how does the `TestServer` work?

- A _class method_ is used to create a new instance, creating a new socket listening on a random port on the local host then instantiating the class with that socket and the app:

        :::python
        @classmethod
        def random_port(cls, application: FastAPI) -> TestServer:
            socket_ = socket()
            socket_.bind(("", 0))
            return cls(application, socket_)

- When a new instance is created, it creates a Uvicorn server wrapping the application (this is the same server FastAPI uses for its `dev` and `run` CLI commands) and the [thread][python-threading] that allows the server to run in the background while our tests are executed.
    Note the `_` prefix - this indicates to users of the class that these attributes should be considered _private_ and not accessed directly.

        :::python
        def __init__(self, application: FastAPI, socket_: socket):
            self._server = Server(Config(app=application))
            self._socket = socket_
            self._thread = Thread(
                target=self._server.run,
                kwargs=dict(sockets=[self._socket]),
            )

    The `target` argument to the thread is the callable that should be executed in the new thread.
    The `kwargs` argument defines additional keyword arguments that should be passed to the target callable when it's invoked.
    So when the thread starts, it will effectively run:

        :::python
        self._server.run(sockets=[self._socket])

- When the context manager `with` block is _entered_, the `__enter__` method is called, which starts the thread created in `__init__`:

        :::python
        def __enter__(self) -> TestServer:
            self._thread.start()
            return self

    Returning `self` allows the `TestServer` instance to be accessed `as server` inside the `with` block.

- Inside the `with` block, the client is created. This uses the `url` property from the test server, which is determined based on the host and port from the socket the underlying Uvicorn server is using:

        :::python
        @property
        def url(self) -> str:
            host, port = self._socket.getsockname()
            return f"http://{host}:{port}"

- Once the tests have all run and the client has been closed (by exiting its own context manager), the server `with` block is exited, so the `__exit__` method is called:

        :::python
        def __exit__(self, exc_type, exc_val, exc_tb):
            self._server.should_exit = True
            self._thread.join()

    This tells the Uvicorn server to stop accepting any new requests and prepare for shutdown.
    Joining the thread means the fixture function will now wait for that thread (and hence the server process) to exit before allowing the test suite to complete.

Fixtures are a powerful way to abstract setup and teardown out of your tests to keep them readable; here's an example of using them to test actual spacecraft 🚀:

<iframe width="560" height="315" src="https://www.youtube.com/embed/spCOYV4KyPA?si=accWVqeMBQn85oM7" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

---

<sup>1</sup> Actually, the proper [RKM code] uses trailing zeros to indicate a tighter tolerance, we will ignore that distinction for now.

[bugfactory-uvicorn]: https://bugfactory.io/articles/starting-and-stopping-uvicorn-in-the-background/
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
[Python TDD Ohm]: {filename}/development/python-tdd-ohm.md
[resistors]: {static}/images/Electronic-Axial-Lead-Resistors-Array.png
[rkm code]: https://en.wikipedia.org/wiki/RKM_code
[status code flowchart]: https://www.codetinkerer.com/2015/12/04/choosing-an-http-status-code.html
[the previous article]: {filename}/development/python-tdd-ftw.md
[uv]: https://docs.astral.sh/uv/
[uvicorn]: https://www.uvicorn.org/
