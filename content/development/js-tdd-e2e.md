Title: JS TDD E2E
Date: 2020-11-22 15:30
Modified: 2023-06-27 10:30
Tags: javascript, tdd, xp
Authors: Jonathan Sharpe
Summary: Test-driven JavaScript development done right - part 2

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
    > If you think the test will fail, **why**; will the `expect`ation be 
    > unmet (and what value do you think you'll get instead) or will 
    > something else go wrong?

I also covered how to use one of the most popular test frameworks in the JavaScript ecosystem at the moment, [Jest], to start writing unit tests for a simple function:

```javascript
describe("rock, paper, scissors", () => {
  it("should say left wins for rock vs. scissors", () => {
    // Arrange
    const left = "rock";
    const right = "scissors";
    
    // Act
    const outcome = rps(left, right);
    
    // Assert
    expect(outcome).toBe("left");
  });
});
```

Along the way I threw in some *nix CLI commands and practice with using Git. If you haven't read it yet, or any of the above seems unfamiliar, go and check it out!

One thing that seems to frustrate people new to TDD is that many of the examples are, like my previous post, pretty trivial. They're useful for teaching the flow, but don't actually show you how to test most real applications. So to address that I thought for round two I'd meet a pretty common need - end-to-end (E2E, sometimes known as acceptance or functional) testing a React web app built with [Create React App][cra] (CRA). This will still use the TDD flow, but add an extra layer with some [Cypress] browser tests. We'll work our way from the _outside in_, starting with the E2E tests then moving to lower levels.

Note that I'll use the following names to refer to the different levels:

- **End-to-end**: exercises the whole application from the user's point of view;
- **Integration**: exercises multiple components of the application, collaborating to provide some functionality; and
- **Unit**: exercises a single component, with any collaborating components replaced by [test doubles][test double].

### Requirements

The prerequisites here are the same as the previous article:

- *nix command line: already provided on macOS and Linux; if you're using Windows try [WSL] or [Git BASH];
- [Node] \(16+ recommended, Jest 29 [dropped support] for Node 12; run `node -v` to check) and NPM; and
- Familiarity with ES6 JavaScript syntax.

In addition, given the domain for this post, you'll need:

- Familiarity with React development - I'm going to assume you know how to write a basic implementation, guiding you with test cases and a few function component examples.

We're going to expand on the previous article and add a web UI for our Rock Paper Scissors implementation. This article moves quite quickly; the libraries involved ([Cypress], [Jest], [Testing Library]) have quite large APIs, so it's best to read the details in their documentation.

Again please carefully _read everything_, and for newer developers I'd recommend _typing the code_ rather than copy-pasting.

## Setup [1/8]

To begin, let's create a new React app in our workspace using CRA:

```bash
$ npx create-react-app@latest rps-e2e

Creating a new React app in path/to/rps-e2e.

Installing packages. This might take a couple of minutes.
Installing react, react-dom, and react-scripts with cra-template...


added 1427 packages in 32s

226 packages are looking for funding
  run `npm fund` for details

Initialized a git repository.

Installing template dependencies using npm...

added 74 packages, and changed 1 package in 3s

235 packages are looking for funding
  run `npm fund` for details
Removing template package using npm...


removed 1 package, and audited 1501 packages in 2s

235 packages are looking for funding
  run `npm fund` for details

74 vulnerabilities (69 moderate, 5 high)

To address issues that do not require attention, run:
  npm audit fix

To address all issues (including breaking changes), run:
  npm audit fix --force

Run `npm audit` for details.

Created git commit.

Success! Created rps-e2e at path/to/rps-e2e
Inside that directory, you can run several commands:

  npm start
    Starts the development server.

  npm run build
    Bundles the app into static files for production.

  npm test
    Starts the test runner.

  npm run eject
    Removes this tool and copies build dependencies, configuration files
    and scripts into the app directory. If you do this, you can’t go back!

We suggest that you begin by typing:

  cd rps-e2e
  npm start

Happy hacking!
```

There's a _lot_ of output here, but you should see four main stages:

 1. Install `create-react-app` using `npx`;
 2. Install the specified template (we're using the default, `cra-template`) and the main React and `react-scripts` dependencies;
 3. Install the dependencies the template defines (mostly `@testing-library` utilities in this case); and finally
 4. Uninstall the template.

This also takes care of the initial steps like creating a directory, a git repository (with `node_modules/` already ignored for us) and an NPM package. This time, before getting to the unit test level with Jest (which CRA has already set up for us), let's enter the project directory and install Cypress, for our end-to-end tests, as well as the latest version of Testing Library's packages (CRA installs v13 by default) and [their Cypress utilities][Cypress Testing Library]:

```bash
$ cd rps-e2e/

$ npm install cypress @testing-library/{cypress,react,user-event}@latest

added 119 packages, removed 8 packages, changed 2 packages, and audited 1612 packages in 7s

251 packages are looking for funding
  run `npm fund` for details

74 vulnerabilities (69 moderate, 5 high)

To address issues that do not require attention, run:
  npm audit fix

To address all issues (including breaking changes), run:
  npm audit fix --force

Run `npm audit` for details.
```

Don't worry about the vulnerability reports (and definitely **do not** run `npm audit fix --force` without understanding exactly what it does - that can break the dependency tree entirely), more information is available on the CRA issues list [here][npm audit]. Note that CRA installs everything as a regular dependency rather than a development dependency, so I didn't use `--save-dev`.

## Create E2E suite [2/8]

Now we need to set up the basic Cypress configuration. To do this, we'll open up the Cypress UI.

`./node_modules/.bin/` is where NPM puts all of the _executables_ that your installed packages define. For example, if you look in that directory for this project or the previous `rps-tdd/` project, you'll see `jest` in there; that's what gets called when we `npm run test` if the script is `"test": "jest"`. Most often you'll be running these via scripts defined in your package file, but you can also run them directly if needed.

In this case we only need to run `cypress open` once, so let's do it like this:

```bash
$ npx cypress open
It looks like this is your first time using Cypress: 12.16.0

✔  Verified Cypress! path/to/Cypress/12.16.0/Cypress…

Opening Cypress...

DevTools listening on ws://127.0.0.1:50213/devtools/browser/788298a9-c866-4f0a-b212-bcf59b335b60
Couldn't find tsconfig.json. tsconfig-paths will be skipped
```

This should open the Cypress GUI:

![Screenshot of the Cypress GUI]({static}/images/cypress-gui.png)

Click "E2E Testing", which will also create a `cypress.config.js` configuration file (mostly just an empty object, you can see the configuration options [in the docs][cypress config]) and a `cypress/` directory. Quit the UI then get rid of the example fixture:

```bash
$ rm ./cypress/fixtures/example.json
```

Add a script to run the E2E tests (note we're now using `run`, rather than `open` - you can read more about the commands [in the docs][cypress cli]) into the package file:
    
```json
  "scripts": {
    "e2e": "cypress run",
    "start": "react-scripts start",
    "build": "react-scripts build",
    "test": "react-scripts test",
    "eject": "react-scripts eject"
  },
```

and run our (missing!) tests:

```bash
$ npm run e2e

> rps-e2e@0.1.0 e2e
> cypress run


DevTools listening on ws://127.0.0.1:50454/devtools/browser/9877dd09-85f3-4703-b3f4-8849b8f72424
Couldn't find tsconfig.json. tsconfig-paths will be skipped
Can't run because no spec files were found.

We searched for specs matching this glob pattern:

  > path/to/rps-e2e/cypress/e2e/**/*.cy.{js,jsx,ts,tsx}
```

Cypress refuses to run at all if it can't find any test files, so let's create an empty test file using `touch` and re-run our now-present (but still empty) test suite:

```bash
$ mkdir ./cypress/e2e/

$ touch ./cypress/e2e/journey.cy.js

$ npm run e2e

> rps-e2e@0.1.0 e2e
> cypress run


DevTools listening on ws://127.0.0.1:50484/devtools/browser/f3150f98-9a5d-4843-85bf-ad581eacc1ae
Couldn't find tsconfig.json. tsconfig-paths will be skipped

====================================================================================================

  (Run Starting)

  ┌────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Cypress:        12.16.0                                                                        │
  │ Browser:        Electron 106 (headless)                                                        │
  │ Node Version:   v16.20.0 (path/to/node).                                                       │
  │ Specs:          1 found (journey.cy.js)                                                        │
  │ Searched:       cypress/e2e/**/*.cy.{js,jsx,ts,tsx}                                            │
  └────────────────────────────────────────────────────────────────────────────────────────────────┘


────────────────────────────────────────────────────────────────────────────────────────────────────
                                                                                                    
  Running:  journey.cy.js                                                                   (1 of 1)


  0 passing (1ms)

Warning: We failed capturing this video.

This error will not affect or change the exit code.

TimeoutError: operation timed out
    at afterTimeout (path/to/Cypress/12.16.0/Cypress.app/Contents/Resources/app/node_modules/bluebird/js/release/timers.js:46:19)
    at Timeout.timeoutTimeout [as _onTimeout] (path/to/Cypress/12.16.0/Cypress.app/Contents/Resources/app/node_modules/bluebird/js/release/timers.js:76:13)
    at listOnTimeout (node:internal/timers:559:17)
    at process.processTimers (node:internal/timers:502:7)

  (Results)

  ┌────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Tests:        0                                                                                │
  │ Passing:      0                                                                                │
  │ Failing:      0                                                                                │
  │ Pending:      0                                                                                │
  │ Skipped:      0                                                                                │
  │ Screenshots:  0                                                                                │
  │ Video:        false                                                                            │
  │ Duration:     0 seconds                                                                        │
  │ Spec Ran:     journey.cy.js                                                                    │
  └────────────────────────────────────────────────────────────────────────────────────────────────┘


====================================================================================================

  (Run Finished)


       Spec                                              Tests  Passing  Failing  Pending  Skipped  
  ┌────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ ✔  journey.cy.js                              0ms        -        -        -        -        - │
  └────────────────────────────────────────────────────────────────────────────────────────────────┘
    ✔  All specs passed!                          0ms        -        -        -        -        -  

```

Unlike Jest, Cypress doesn't mind if there aren't any tests in the files and considers that a successful run. Note it also tried to create a video of the run; Cypress can create both videos and screenshots to help with debugging tests, as well as storing any files downloaded as part of a test. We don't want to track all of these in git, though, so add the following to `.gitignore`.

```ignore
# cypress
cypress/downloads/
cypress/screenshots/
cypress/videos/
```

Before we write our first test, let's make a commit:

```
$ git add .

$ git status
On branch main
Changes to be committed:
  (use "git restore --staged <file>..." to unstage)
        modified:   .gitignore
        new file:   cypress.config.js
        new file:   cypress/e2e/journey.cy.js
        new file:   cypress/support/commands.js
        new file:   cypress/support/e2e.js
        modified:   package-lock.json
        modified:   package.json

$ git commit --message 'Install and configure Cypress'
[main 7da2ace] Install and configure Cypress
 7 files changed, 2401 insertions(+), 252 deletions(-)
 create mode 100644 cypress.config.js
 create mode 100644 cypress/e2e/journey.cy.js
 create mode 100644 cypress/support/commands.js
 create mode 100644 cypress/support/e2e.js
```

## Writing the E2E test [3/8]

Let's load Cypress Testing Library for the tests by adding the following import to `cypress/support/commands.js`:

```javascript
import '@testing-library/cypress/add-commands';
```

Now we want to actually visit our page. The best practice, [per the docs][cypress base url], is to configure a global base URL and navigate relative to that, so let's add the default CRA URL (along with disabling the video recordings, to simplify the outputs) to `cypress.config.js`:

```diff
 module.exports = defineConfig({
   e2e: {
+    baseUrl: "http://localhost:3000",
     setupNodeEvents(on, config) {
       // implement node event listeners here
     },
+    video: false,
   },
 });
```

Just like with Jest, Cypress provides an `it` function for registering a test, again taking the name of the test as a string and the body of the test as a function:

```javascript
it("should say left wins for rock vs. scissors", () => {
  // Arrange
  cy.visit("/");

  // Act
  cy.findByLabelText("Left").select("rock");
  cy.findByLabelText("Right").select("scissors");
  cy.findByText("Throw").click();

  // Assert
  cy.findByTestId("outcome").should("contain.text", "Left wins!");
});
```

_(If your IDE seems unhappy with `cy`, just ignore it for now, but check out the bonus section on Linting at the end of the article.)_

This is basically the same expectation as the first unit test case we wrote last time, but at the end-to-end level. `cy` is a global object that provides access to various Cypress methods; this is a pretty big API (and we've added more things to it from Testing Library!) so to translate:

- `cy.visit("/");` - visit the root path, based on the base URL we already set. This should take us to the home page of our site;
- `cy.findByLabelText("Left").select("rock");` - find a control with the label "Left" and select the "rock" option;
- `cy.findByLabelText("Right").select("scissors");` - find a control with the label "Right" and select the "scissors" option;
- `cy.findByText("Throw").click();` - find a button that says "Throw" and click it; and
- `cy.findByTestId("outcome").should("contain.text", "Left wins!");` - check that the outcome being being displayed contains the expected text `Left wins!`, using a Chai DOM assertion [exposed by Cypress][cypress assertions].

**Note** that we look for the outcome in an element with the appropriate _test ID_; using stable attribute selectors is another [Cypress best practice][cypress selectors] and Testing Library gives us functions to easily access such elements, assuming the attribute is named `data-testid` (although this is configurable). In this case, we'd expect an element like:

```html
<div data-testid="outcome">Hello, world!</div>
```

As before, _none of this exists yet_, so we can easily talk about how this user interface should work without the friction of having to implement it. Maybe the user should enter free text instead of selecting from a list? Maybe it should automatically show the outcome when the second input is provided, rather than requiring a button click? Maybe there should be names for the users instead of left and right? This is making us think in concrete terms about how the users should interact with the system, early in the process. In this case, we're describing something like: 

![Wireframe of the proposed RPS UI]({static}/images/rps-ui.png)

<small>_Created with [lofiwireframekit.com](https://www.lofiwireframekit.com/)._</small>

Before we continue, think about how you might actually implement that UI in React - what components would you have, how would they interact, where would the state live? Note your ideas down, we'll revisit them later.

Just like with Jest, call the shot then run the tests:

```bash
$ npm run e2e

> rps-e2e@0.1.0 e2e
> cypress run


DevTools listening on ws://127.0.0.1:50699/devtools/browser/0ed01742-886c-4a1b-9abe-eccf1e79372e
Couldn't find tsconfig.json. tsconfig-paths will be skipped
Cypress could not verify that this server is running:

  > http://localhost:3000

We are verifying this server because it has been configured as your baseUrl.

Cypress automatically waits until your server is accessible before running tests.

We will try connecting to it 3 more times...
We will try connecting to it 2 more times...
We will try connecting to it 1 more time...

Cypress failed to verify that your server is running.

Please start this server and then run Cypress again.
```

Cypress is unhappy because we're _not actually running the app_, so it can't find the specified base URL. As a simple fix, open an extra command line, navigate to the working directory and run `npm start`. For more information on CRA's future, see [this issue][cra future].

**Note**: at this point you may see an error like:

```
One of your dependencies, babel-preset-react-app, is importing the
"@babel/plugin-proposal-private-property-in-object" package without
declaring it in its dependencies. This is currently working because
"@babel/plugin-proposal-private-property-in-object" is already in your
node_modules folder for unrelated reasons, but it may break at any time.

babel-preset-react-app is part of the create-react-app project, which
is not maintianed anymore. It is thus unlikely that this bug will
ever be fixed. Add "@babel/plugin-proposal-private-property-in-object" to
your devDependencies to work around this error. This will make this message
go away.
```

if you do, just `npm install @babel/plugin-proposal-private-property-in-object` and continue.

Once the default CRA home screen shows up in your browser, call the shot then run the E2E tests again in your first command line:

```bash
$ npm run e2e

> rps-e2e@0.1.0 e2e
> cypress run


DevTools listening on ws://127.0.0.1:50726/devtools/browser/7ea7c9ee-025d-4b38-b5b6-74bdd9b08adf
Couldn't find tsconfig.json. tsconfig-paths will be skipped

====================================================================================

  (Run Starting)

  ┌────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Cypress:        12.16.0                                                                        │
  │ Browser:        Electron 106 (headless)                                                        │
  │ Node Version:   v16.20.0 (path/to/node).                                                       │
  │ Specs:          1 found (journey.cy.js)                                                        │
  │ Searched:       cypress/e2e/**/*.cy.{js,jsx,ts,tsx}                                            │
  └────────────────────────────────────────────────────────────────────────────────────────────────┘


────────────────────────────────────────────────────────────────────────────────────────────────────
                                                                                                    
  Running:  journey.cy.js                                                                   (1 of 1)


  1) should say left wins for rock vs. scissors

  0 passing (4s)
  1 failing

  1) should say left wins for rock vs. scissors:
     AssertionError: Timed out retrying after 4000ms: Unable to find a label with the text of: Left

Ignored nodes: comments, script, style
<html
  lang="en"
>
  <head>
     
    
    
    <meta
      charset="utf-8"
    />
    
    
    <link
      href="/favicon.ico"
      rel="icon"
    />
    
    
    <meta
      content="width=device-width, initial-scale=1"
      name="viewport"
    />
    
    
    <meta
      content="#000000"
      name="theme-color"
    />
    
    
    <meta
      content="Web site created using create-react-app"
      name="description"
    />
    
    
    <link
      href="/logo192.png"
      rel="apple-touch-icon"
    />
    
    
    
    
    <link
      href="/manifest.json"
      rel="manifest"
    />
    
    
    
    
    <title>
      React App
    </title>
    
  
  </head>
  
  
  <body>
    
    
    <noscript>
      You need to enable JavaScript to run this app.
    </noscript>
    
    
    <div
      id="root"
    >
      <div
        class="App"
      >
        <header
          class="App-header"
        >
          <img
            alt="logo"
            class="App-logo"
            src="/static/media/logo.6ce24c58023cc2f8fd88fe9d219db6c6.svg"
          />
          <p>
            Edit 
            <code>
              src/App.js
            </code>
             and save to reload.
          </p>
          <a
            class="App-link"
            href="https://reactjs.org"
            rel="noopener noreferrer"
            target="_blank"
          >
            Learn React
          </a>
        </header>
      </div>
    </div>
    
    
    
  


  </body>
</html>...
      at Context.eval (webpack:///./cypress/e2e/journey.cy.js:6:5)




  (Results)

  ┌────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Tests:        1                                                                                │
  │ Passing:      0                                                                                │
  │ Failing:      1                                                                                │
  │ Pending:      0                                                                                │
  │ Skipped:      0                                                                                │
  │ Screenshots:  1                                                                                │
  │ Video:        false                                                                            │
  │ Duration:     4 seconds                                                                        │
  │ Spec Ran:     journey.cy.js                                                                    │
  └────────────────────────────────────────────────────────────────────────────────────────────────┘


  (Screenshots)

  -  path/to/rps-e2e/cypress/screenshots/journey.cy.js/should say left wins for rock      (1280x720)
     vs. scissors (failed).png                                     


====================================================================================

  (Run Finished)


       Spec                                              Tests  Passing  Failing  Pending  Skipped  
  ┌────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ ✖  journey.cy.js                            00:04        1        -        1        -        - │
  └────────────────────────────────────────────────────────────────────────────────────────────────┘
    ✖  1 of 1 failed (100%)                     00:04        1        -        1        -        -  

```
OK, we've moved on a step - the test is now failing because it can't find the element on the page. So far we haven't actually added anything to the page, so that makes sense, it's just showing the default CRA info (you can see this in the screenshot Cypress took, check it out!)

This is going to be our guiding star for the rest of the exercise, so let's make a commit to store this state:

```bash
$ git add .
$ git status
On branch main
Changes to be committed:
  (use "git restore --staged <file>..." to unstage)
        modified:   cypress.config.js
        modified:   cypress/e2e/journey.cy.js
        modified:   cypress/support/commands.js
        modified:   package-lock.json
        modified:   package.json

$ git commit --message 'Implement E2E test'
[main ee33a63] Implement E2E test
 5 files changed, 53 insertions(+), 8 deletions(-)
```

## Moving to the integration level [4/8]

We're working our way from the outside in, and we have a failing E2E test, so let's write an _integration_ test in Jest. Replace the content of `./src/App.test.js` with the following:

```jsx
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";

import App from "./App";

describe("App component", () => {
  it("displays right wins when appropriate", async () => {
    // Arrange
    const user = userEvent.setup();
    render(<App />);

    // Act
    await user.selectOptions(screen.getByLabelText("Left"), "paper");
    await user.selectOptions(screen.getByLabelText("Right"), "scissors");
    await user.click(screen.getByText("Throw"));

    // Assert
    expect(screen.getByTestId("outcome")).toHaveTextContent("Right wins!");
  });
});
```

The way we express the steps might be slightly different, but note that the _logic_ is exactly the same as we tested at the end-to-end level:

- `const user = userEvent.setup();` - start a user event session in the document to be tested;
- `render(<App />);` - render the `App` component, equivalent to visiting the page;
- `await user.selectOptions(screen.getByLabelText("Left"), "paper");` - find a control with the label "Left" and select the "paper" option;
- `await user.selectOptions(screen.getByLabelText("Right"), "scissors");` - find a control with the label "Right" and select the "scissors" option;
- `await user.click(screen.getByText("Throw"));` - find a button that says "Throw" and click it; and
- `expect(screen.getByTestId("outcome")).toHaveTextContent("Right wins!");` - check that the outcome being being displayed contains the expected text `Right wins!`.

Call the shot and run the test (note I'm using the environment variable `CI=true` to run the tests once and exit; you can use the default `npm test` to enter watch mode if you'd prefer, or `npm test -- --watchAll false` as an alternative to setting `CI`):

```
$ CI=true npm test

> rps-e2e@0.1.0 test
> react-scripts test

FAIL src/App.test.js
  App component
    ✕ displays right wins when appropriate (18 ms)

  ● App component › displays right wins when appropriate

    TestingLibraryElementError: Unable to find a label with the text of: Left

    Ignored nodes: comments, script, style
    <body>
      <div>
        <div
          class="App"
        >
          <header
            class="App-header"
          >
            <img
              alt="logo"
              class="App-logo"
              src="logo.svg"
            />
            <p>
              Edit 
              <code>
                src/App.js
              </code>
               and save to reload.
            </p>
            <a
              class="App-link"
              href="https://reactjs.org"
              rel="noopener noreferrer"
              target="_blank"
            >
              Learn React
            </a>
          </header>
        </div>
      </div>
    </body>

      11 |
      12 |     // Act
    > 13 |     await user.selectOptions(screen.getByLabelText("Left"), "paper");
         |                                     ^
      14 |     await user.selectOptions(screen.getByLabelText("Right"), "scissors");
      15 |     await user.click(screen.getByText("Throw"));
      16 |

      at Object.getElementError (node_modules/@testing-library/dom/dist/config.js:37:19)
      at getAllByLabelText (node_modules/@testing-library/dom/dist/queries/label-text.js:111:38)
      at node_modules/@testing-library/dom/dist/query-helpers.js:52:17
      at getByLabelText (node_modules/@testing-library/dom/dist/query-helpers.js:95:19)
      at Object.<anonymous> (src/App.test.js:13:37)
      at TestScheduler.scheduleTests (node_modules/@jest/core/build/TestScheduler.js:333:13)
      at runJest (node_modules/@jest/core/build/runJest.js:404:19)
      at _run10000 (node_modules/@jest/core/build/cli/index.js:320:7)
      at runCLI (node_modules/@jest/core/build/cli/index.js:173:3)

Test Suites: 1 failed, 1 total
Tests:       1 failed, 1 total
Snapshots:   0 total
Time:        0.709 s, estimated 1 s
Ran all test suites.
```

Compare the error messages; they're failing on the same problem:

- **E2E**: `AssertionError: Timed out retrying after 4000ms: Unable to find a label with the text of: Left `
- **Integration**: `TestingLibraryElementError: Unable to find a label with the text of: Left`

Instead of a screenshot we get the rendered HTML, but it shows a similar thing - the default CRA content is still being shown. You should also see that running this test was **much faster** than starting up the app and running Cypress. Lower level tests tend to:

 1. be _more coupled to the implementation_ (this one knows our app is using React, which Cypress had no idea about); but
 2. have a _shorter feedback loop_ (by orders of magnitude, the integration test itself took 54ms vs. 4s for the E2E).

Let's save this new state:

```bash
$ git add .
$ git status
On branch main
Changes to be committed:
  (use "git restore --staged <file>..." to unstage)
        modified:   src/App.test.js

$ git commit --message 'Implement integration test'
[main 1585130] Implement integration test
 1 file changed, 18 insertions(+), 6 deletions(-)
```

Before we move in one last level, to the unit tests, let's think about how our app might be structured. Again note that we can have this discussion before actually writing anything, because the need to identify our test boundaries is driving us to think about the architecture. We have two main concerns here:

 1. the _business logic_, determining a winner given two weapons (we tested and implemented this in the previous article) - this can be implemented as a _service_; and
 2. the _user interface_, taking user input and showing the winner - this can be implemented as _components_.

React apps tend to have a root `App` component, which we could use as a coordinator here. It will:

- render a form with our input controls (two `<select>`s and a `<button>`);
- communicate with the service (RPS logic we already have); and
- display the outcome.

We can model this as follows:

```
   App <--> Service
  /   \
Form  Outcome
```

We already have an integration test covering these parts working together, but we can create unit tests for the service and the low-level components.

## At your service [5/8]

We already have this! You should still have a function named `rps` from the previous article, along with a suite of tests. Place the function in a file named `./src/rpsService.js` and export it:

```javascript
export function rps(left, right) {
  // ...
}
```

then place the test suite in a file named `./src/rpsService.test.js` along with an import:

```javascript
import { rps } from "./rpsService";

describe("rock, paper, scissors", () => {
  // ...
});
```

All of the same tests should pass happily in the new context. Once all of the service tests are passing (although `./src/App.test.js` will still fail), commit it:

```bash
$ git add .
$ git status
On branch main
Changes to be committed:
  (use "git restore --staged <file>..." to unstage)
        new file:   src/rpsService.js
        new file:   src/rpsService.test.js

$ git commit --message 'Migrate tested service logic'
[main 732e441] Migrate tested service logic
 2 files changed, 75 insertions(+)
 create mode 100644 src/rpsService.js
 create mode 100644 src/rpsService.test.js
```

## Component unit tests [6/8]

The `Outcome` component is going to be very simple, as it only has to display the text we want given a result, so let's start with that. Add the following to `./src/Outcome.test.js`:

```jsx
import { render, screen } from "@testing-library/react";

import Outcome from "./Outcome";

describe("App component", () => {
  it("displays 'Right wins!' when right wins", () => {
    render(<Outcome result="right" />);
    expect(screen.getByTestId("outcome")).toHaveTextContent("Right wins!");
  });
});
```

Once again we can talk about the interface before we're tied to an implementation. In this case, I've assumed the component will have a single prop named `result`, that matches the value returned from the service, and will render an element with `data-testid="outcome"`, to match our higher-level tests, with the expected text.

Call the shot and run the test. Initially it will fail because Jest `Cannot find module './Outcome' from 'src/Outcome.test.js'` - that should make sense, we haven't created that file yet. Go through the process of making small changes and re-running the test until it passes, with the _simplest possible implementation_. Remember to call the shot before each test run, and aim to change the error you get step by step rather than just jumping to the passing test.

At this point, you should have something like:

```jsx
export default function Outcome() {
  return <div data-testid="outcome">Right wins!</div>;
}
```

If you have any logic in your component, go back! It's too complicated; remember to write the simplest code that passes the tests and let additional test cases force you to add complexity.

Make a commit to save your progress, with a message like _"Implement Outcome for right winning"_. Now repeat the process for each of the following tests, one at a time: add the test case; call the shot; get it passing; refactor as desired; make a commit with a sensible message.

 1. Left wins:

        :::jsx
        it("displays 'Left wins!' when left wins", () => {
          render(<Outcome result="left" />);
          expect(screen.getByTestId("outcome")).toHaveTextContent("Left wins!");
        });

 2. Draw:
        
        :::jsx
        it("displays 'Draw!' when there's a draw", () => {
          render(<Outcome result="draw" />);
          expect(screen.getByTestId("outcome")).toHaveTextContent("Draw!");
        });

Once all three tests are passing, we can move on to the next component. Add the following to `./src/Form.test.js`:

```jsx
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";

import Form from "./Form";

describe("Form component", () => {
  it("emits a pair of selections when the form is submitted", async () => {
    const left = "scissors";
    const right = "paper";
    const onSubmit = jest.fn();
    const user = userEvent.setup();
    render(<Form onSubmit={onSubmit} />);
    
    await user.selectOptions(screen.getByLabelText("Left"), left);
    await user.selectOptions(screen.getByLabelText("Right"), right);
    await user.click(screen.getByText("Throw"));

    expect(onSubmit).toHaveBeenCalledWith([left, right]);
  });
});
Form.
```

This looks quite a lot like the end-to-end and integration tests, but with a more limited scope - we only care that the user input is taken correctly, not that the appropriate winner is determined. This is part of the process of _decomposing_ the problem into smaller (and easier-to-solve) pieces, which is the reason I think starting with the end-to-end tests makes sense.

It also introduces a Jest _"mock function"_, a [test double] we can pass to the `Form` component in place of a real function prop. The expectation here is that this mock function gets called with the appropriate values, as this is how the data will be passed up to the `App` component.

Again this gives us an opportunity to talk about the API details of the component before it even exists. Perhaps it should return an object `{ left, right }` instead of an array `[left, right]`? Is `onSubmit` the best name for the prop? It's easier to have these discussions when changing the API is a matter of changing your mind rather than changing the code.

Repeat the usual process until you get this test passing. Covering the details of how to implement something like this in React are a bit beyond the scope of this article, but one way is to create some [controlled components] that update the component's state. Once it passes, make another commit:

```bash
$ git add .

$ git status
On branch master
Changes to be committed:
  (use "git restore --staged <file>..." to unstage)
	new file:   src/Form.js
	new file:   src/Form.test.js


$ git commit -m 'Implement Form component'
[master eca31d7] Implement Form component
 2 files changed, 46 insertions(+)
 create mode 100644 src/Form.js
 create mode 100644 src/Form.test.js
```

## Putting it all back together [7/8]

Now we have a bunch of well-tested components and a service, but our integration and E2E tests are still failing, so it's time to bring everything together. Given that we already have two layers of testing for `./src/App.js` and most of the work is done elsewhere let's not add unit tests too; something like the following should be enough to get everything passing:

```jsx
import { useState } from "react";

import Form from "./Form";
import Outcome from "./Outcome";
import { rps } from "./rpsService";

function App() {
  const [result, setResult] = useState();
  
  const onThrow = ([left, right]) => {
    setResult(rps(left, right));
  }
  
  return (
    <div>
      <Form onSubmit={onThrow} />
      {result && <Outcome result={result} />}
    </div>
  );
}

export default App;
```

Call the shot and run the whole suite:

```bash
$ CI=true npm test

> rps-e2e@0.1.0 test path/to/rps-e2e
> react-scripts test

PASS src/Outcome.test.js
PASS src/App.test.js
PASS src/Form.test.js
PASS src/rpsService.test.js

Test Suites: 4 passed, 4 total
Tests:       14 passed, 14 total
Snapshots:   0 total
Time:        6.826 s
Ran all test suites.
```

All of the unit tests should now be passing, so call the final shot and run the end-to-end test:

```bash
$ npm run e2e

> rps-e2e@0.1.0 e2e
> cypress run


DevTools listening on ws://127.0.0.1:54317/devtools/browser/fb0390d2-e65c-4fa8-bf24-27d80cf3928e
Couldn't find tsconfig.json. tsconfig-paths will be skipped

====================================================================================

  (Run Starting)

  ┌────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Cypress:        12.16.0                                                                        │
  │ Browser:        Electron 106 (headless)                                                        │
  │ Node Version:   v16.20.0 (path/to/node).                                                       │
  │ Specs:          1 found (journey.cy.js)                                                        │
  │ Searched:       cypress/e2e/**/*.cy.{js,jsx,ts,tsx}                                            │
  └────────────────────────────────────────────────────────────────────────────────────────────────┘


────────────────────────────────────────────────────────────────────────────────────────────────────
                                                                                                    
  Running:  journey.cy.js                                                                   (1 of 1)


  ✓ should say left wins for rock vs. scissors (602ms)

  1 passing (618ms)


  (Results)

  ┌────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Tests:        1                                                                                │
  │ Passing:      1                                                                                │
  │ Failing:      0                                                                                │
  │ Pending:      0                                                                                │
  │ Skipped:      0                                                                                │
  │ Screenshots:  0                                                                                │
  │ Video:        false                                                                            │
  │ Duration:     0 seconds                                                                        │
  │ Spec Ran:     journey.cy.js                                                                    │
  └────────────────────────────────────────────────────────────────────────────────────────────────┘


====================================================================================

  (Run Finished)


       Spec                                              Tests  Passing  Failing  Pending  Skipped  
  ┌────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ ✔  journey.cy.js                            616ms        1        1        -        -        - │
  └────────────────────────────────────────────────────────────────────────────────────────────────┘
    ✔  All specs passed!                        616ms        1        1        -        -        -  

```

That's it! We've created a simple UI for our RPS implementation, test-driving it from the outside in. Create a commit to save this work:

```bash
$ git add .

$ git status
On branch master
Changes to be committed:
  (use "git restore --staged <file>..." to unstage)
	modified:   src/App.js


$ git commit -m 'Complete RPS UI implementation'
[master c6cd9a8] Complete RPS UI implementation
 1 file changed, 22 insertions(+), 25 deletions(-)
 rewrite src/App.js (90%)
```

Now reflect on the exercise - how does the implementation compare to what you'd initially imagined? What felt good or bad about the process?

You can see my copy of this exercise at [https://github.com/textbook/rps-e2e][github].

## Exercises [8/8]

Here are some additional exercises you can run through:

 1. Repeat the process from the beginning and try to come up with a different implementation (including running through the core service logic, rather than copying it over). Was your new route easier or harder?

 1. I mentioned various alternatives to the user interface we implemented, e.g. allowing free text input. Pick one of my suggestions (or come up with your own) and implement it from the outside in.

 1. If you implemented additional weapons in your `rps` implementation, extend the UI to support them. If not, maybe this is a good time to revisit it!

 1. The UI is pretty basic - we've tested the _functionality_ but said nothing about how it should look. Improve the styling while keeping the tests passing.

 1. Repeat the exercise without writing _any_ unit-level tests; use the same end-to-end test then drive everything else from the integration level. What does this make easier and harder?
 
 1. There are a bunch of unhappy paths and un-/under-specified/edge cases in this implementation. For example:

    - Which weapons should be selected by default? If "none", what should happen when the Throw button is clicked and one or both weapons are still unselected?

    - What should happen if one of the weapons is changed after the Throw button is clicked?

    - What should happen when the page is refreshed?

    Pick one or more of these. Which part(s) of the React app (currently `App`, `Form`, `Outcome` or `rpsService`) should be responsible for dealing with it? Write an E2E test case for the scenario, then use integration and/or unit tests to test drive the implementation in whichever part you choose.

 1. Pick another simple TDD task (e.g. FizzBuzz, BMI calculator, ...) and use these techniques to test drive a React UI for it.

I'd recommend creating a new git branch for each one you try (e.g. use `git checkout -b <name>`) and making commits as appropriate.

> **Once you're ready to move on**, check out [the next article] in this series where we'll learn more about how to deal with sources of data outside of our control.

## Linting [Bonus]

Depending on your setup, you may have noticed that your IDE was warning that `cy` is undefined; the default CRA linting settings include the `no-undef` rule and there's nothing to tell ESLint that `cy` is going to be defined. To be able to easily run the linter, add another script to the package file:
 
```json
  "scripts": {
    "e2e": "cypress run",
    "lint": "eslint cypress/ src/",
    "start": "react-scripts start",
    "build": "react-scripts build",
    "test": "react-scripts test",
    "eject": "react-scripts eject"
  },
```

You can now run this to see the problem:

```bash
npm run lint

> rps-e2e@0.1.0 lint path/to/rps-e2e
> eslint cypress/ src/


path/to/rps-e2e/cypress/integration/e2e.test.js
  2:3  error  'cy' is not defined  no-undef
  3:3  error  'cy' is not defined  no-undef
  4:3  error  'cy' is not defined  no-undef
  6:3  error  'cy' is not defined  no-undef
  8:3  error  'cy' is not defined  no-undef

✖ 5 problems (5 errors, 0 warnings)

npm ERR! code ELIFECYCLE
npm ERR! errno 1
npm ERR! rps-e2e@0.1.0 lint: `eslint cypress/ src/`
npm ERR! Exit status 1
npm ERR! 
npm ERR! Failed at the rps-e2e@0.1.0 lint script.
npm ERR! This is probably not a problem with npm. There is likely additional logging output above.

npm ERR! A complete log of this run can be found in:
npm ERR!     path/to/.npm/_logs/2020-11-03T22_41_51_438Z-debug.log
```

To fix this, we can add an ESLint plugin that knows about the Cypress globals:

```bash
$ npm install eslint-plugin-cypress

added 1 package, and audited 1621 packages in 4s

251 packages are looking for funding
  run `npm fund` for details

74 vulnerabilities (69 moderate, 5 high)

To address issues that do not require attention, run:
  npm audit fix

To address all issues (including breaking changes), run:
  npm audit fix --force

Run `npm audit` for details.
```

We could just add this plugin at the top level, but it's better to be specific - `cy` will only be in scope for the files in the `cypress/` directory, so we can set an ESLint _override_ for those files in `package.json`:

```json
  "eslintConfig": {
    "extends": [
      "react-app",
      "react-app/jest"
    ],
    "overrides": [
      {
        "extends": [
          "plugin:cypress/recommended"
        ],
        "files": [
          "cypress/**/*.js"
        ]
      }
    ]
  },
```

Now `npm run lint` should be fine.

  [controlled components]: https://react.dev/reference/react-dom/components/input#controlling-an-input-with-a-state-variable
  [cra]: https://create-react-app.dev/docs/getting-started
  [cra future]: https://github.com/reactjs/react.dev/pull/5487#issuecomment-1409720741
  [Cypress]: https://cypress.io
  [cypress assertions]: https://docs.cypress.io/guides/references/assertions.html
  [cypress base url]: https://docs.cypress.io/guides/references/best-practices.html#Setting-a-global-baseUrl
  [cypress cli]: https://docs.cypress.io/guides/guides/command-line.html
  [cypress config]: https://docs.cypress.io/guides/references/configuration.html
  [cypress selectors]: https://docs.cypress.io/guides/references/best-practices.html#Selecting-Elements
  [Cypress Testing Library]: https://testing-library.com/docs/cypress-testing-library/intro/
  [dropped support]: https://jestjs.io/docs/upgrading-to-jest29#compatibility
  [Git BASH]: https://gitforwindows.org/
  [github]: https://github.com/textbook/rps-e2e
  [Jest]: https://jestjs.io/
  [npm audit]: https://github.com/facebook/create-react-app/issues/11174
  [Node]: https://nodejs.org/
  [Testing Library]: https://testing-library.com
  [test double]: https://tanzu.vmware.com/content/pivotal-engineering-journal/the-test-double-rule-of-thumb-2
  [the next article]: {filename}/development/js-tdd-api.md
  [the previous article]: {filename}/development/js-tdd-ftw.md
  [WSL]: https://docs.microsoft.com/en-us/windows/wsl/about
