Title: JS TDD E2E
Date: 2020-11-03 23:30
Tags: javascript, tdd, xp
Authors: Jonathan Sharpe
Summary: Test-driven JavaScript development done right - part 2
Status: draft

In [the previous post] in this series, I introduced some of the basics of test-driven development (TDD):

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

One thing that seems to frustrate people new to TDD is that many of the examples are, like my previous post, pretty trivial. They're useful for teaching the flow, but don't actually show you how to test most real applications. So to address that I thought for round two I'd meet a pretty common need - end-to-end (E2E, sometimes known as acceptance or functional) testing a web app. This will still use the TDD flow, but add an extra layer with some [Cypress] browser tests.

### Requirements

The prerequisites here are the same as the previous post:

- *nix command line: already provided on macOS and Linux; if you're using Windows try [WSL] or [Git BASH];
- [Node] \(10+ recommended, Jest 26 [dropped support] for Node 8; run `node -v` to check) and NPM; and
- Familiarity with ES6 JavaScript syntax (specifically arrow functions).

In addition, given the domain for this post, you'll need:

- Familiarity with React development.

We're going to expand on the previous article and add a web UI for our Rock Paper Scissors implementation. This article moves quite quickly; the libraries involved ([Cypress], [Jest], [Testing Library]) have quite large APIs, so it's best to read the details in their documentation.

Again please carefully _read everything_, and for newer developers I'd recommend _typing the code_ rather than copy-pasting.

## Setup [1/6]

To begin, let's create a new React app in our workspace using [Create React App][cra] (CRA):

```bash
$ npx create-react-app@latest --use-npm rps-e2e

# ...

We suggest that you begin by typing:

  cd rps-e2e
  npm start

Happy hacking!
```

There's a _lot_ of output here, so I've skipped most of it. This takes care of the initial steps like creating a directory, a git repository (with `node_modules/` already ignored for us) and an NPM package, as well as installing the appropriate dependencies.

This time, before getting to the unit test level with Jest (which CRA has already set up for us), let's enter that directory and install Cypress for our end-to-end tests:

```bash
$ cd rps-e2e/

$ npm install cypress
npm WARN deprecated har-validator@5.1.5: this library is no longer supported

> cypress@5.4.0 postinstall path/to/rps-e2e/node_modules/cypress
> node index.js --exec install

Installing Cypress (version: 5.4.0)

  ✔  Downloaded Cypress
  ✔  Unzipped Cypress
  ✔  Finished Installation path/to/Cypress/5.4.0

You can now open Cypress by running: node_modules/.bin/cypress open

https://on.cypress.io/installing-cypress

npm notice created a lockfile as package-lock.json. You should commit this file.
npm WARN rps-e2e@1.0.0 No description
npm WARN rps-e2e@1.0.0 No repository field.

+ cypress@5.4.0
added 215 packages from 147 contributors and audited 215 packages in 207.262s

12 packages are looking for funding
  run `npm fund` for details

found 0 vulnerabilities
```

Cypress is slightly more complex than the other packages we've used; it downloads and installs the main application as a post-install step. This is installed globally, so if you have another package somewhere that's using Cypress you may see `Cypress <version> is installed in path/to/Cypress/<version>` instead. That's fine, the rest should still work. Note also that CRA installs everything as a regular dependency rather than a development dependency, so I didn't use `--save-dev`.

Let's follow the suggestion in that output and use `cypress open` to open up the Cypress UI. `./node_modules/.bin/` is where NPM puts all of the executables that your installed packages define (for example, if you look in that directory for the `rps-tdd/` project, you'll see `jest` in there). You can use these executables in the scripts in your package file, as we've done with `"test": "jest"`, but you can also run them directly. In this case we only need to run `open` once, so let's do it like this:

```bash
$ ./node_modules/.bin/cypress open

```

This should open the Cypress UI, but also create a `cypress.json` configuration file (initally just an empty object, you can see the configuration options [in the docs][cypress config]) and a `cypress/` directory containing, among other things, a bunch of example tests.

You can take a look at the examples if you like. Once you're ready to move on, though, let's quit the UI then get rid of the examples:

```bash
$ rm -rf ./cypress/integration/examples/ ./cypress/fixtures/example.json
```

Add a script to run those tests (note we're now using `run`, rather than `open` - you can read more about the commands [in the docs][cypress cli]) into the package file:

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

> rps-e2e@0.1.0 e2e path/to/rps-e2e
> cypress run

Can't run because no spec files were found.

We searched for any files inside of this folder:

path/to/rps-e2e/cypress/integration
npm ERR! code ELIFECYCLE
npm ERR! errno 1
npm ERR! rps-e2e@0.1.0 e2e: `cypress run`
npm ERR! Exit status 1
npm ERR! 
npm ERR! Failed at the rps-e2e@0.1.0 e2e script.
npm ERR! This is probably not a problem with npm. There is likely additional logging output above.

npm ERR! A complete log of this run can be found in:
npm ERR!     path/to/.npm/_logs/2020-11-03T20_39_39_337Z-debug.log
```

Cypress refuses to run at all if it can't find any test files, so let's create an empty test file and re-run our now-present (but still empty) test suite:

```bash
$ touch ./cypress/integration/e2e.test.js

$ npm run e2e

> rps-e2e@0.1.0 e2e path/to/rps-e2e
> cypress run


====================================================================================================

  (Run Starting)

  ┌────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Cypress:    5.4.0                                                                              │
  │ Browser:    Electron 85 (headless)                                                             │
  │ Specs:      1 found (e2e.test.js)                                                              │
  └────────────────────────────────────────────────────────────────────────────────────────────────┘


────────────────────────────────────────────────────────────────────────────────────────────────────
                                                                                                    
  Running:  e2e.test.js                                                                     (1 of 1)


  0 passing (4ms)


  (Results)

  ┌────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Tests:        0                                                                                │
  │ Passing:      0                                                                                │
  │ Failing:      0                                                                                │
  │ Pending:      0                                                                                │
  │ Skipped:      0                                                                                │
  │ Screenshots:  0                                                                                │
  │ Video:        true                                                                             │
  │ Duration:     0 seconds                                                                        │
  │ Spec Ran:     e2e.test.js                                                                      │
  └────────────────────────────────────────────────────────────────────────────────────────────────┘


  (Video)

  -  Started processing:  Compressing to 32 CRF                                                     
  -  Finished processing: path/to/rps-e2e/cypress/videos/e2e.test.js.mp4                 (0 seconds)                 


====================================================================================================

  (Run Finished)


       Spec                                              Tests  Passing  Failing  Pending  Skipped  
  ┌────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ ✔  e2e.test.js                                1ms        -        -        -        -        - │
  └────────────────────────────────────────────────────────────────────────────────────────────────┘
    ✔  All specs passed!                          1ms        -        -        -        -        -  
```

Unlike Jest, Cypress doesn't mind if there aren't any tests in the files and considers that a successful run. Note it also created a video of the run; Cypress can create both videos and screenshots to help with debugging tests. We don't want to track all of these in git, though, so add the following to `.gitignore`.

```ignore
# cypress
cypress/screenshots/
cypress/videos/
```

Before we write our first test, let's make a commit:

```
$ git add .

$ git commit -m 'Install Cypress'
[master fca7904] Install Cypress
 8 files changed, 1018 insertions(+)
 create mode 100644 cypress.json
 create mode 100644 cypress/integration/e2e.test.js
 create mode 100644 cypress/plugins/index.js
 create mode 100644 cypress/support/commands.js
 create mode 100644 cypress/support/index.js
```

## Writing the E2E test [2/6]

For consistency with the unit tests, which use [Testing Library] by default in CRA, let's install their Cypress utilities via NPM:

```bash
$ npm install @testing-library/cypress
npm WARN tsutils@3.17.1 requires a peer of typescript@>=2.8.0 || >= 3.2.0-dev || >= 3.3.0-dev || >= 3.4.0-dev || >= 3.5.0-dev || >= 3.6.0-dev || >= 3.6.0-beta || >= 3.7.0-dev || >= 3.7.0-beta but none is installed. You must install peer dependencies yourself.

+ @testing-library/cypress@7.0.1
added 1 package from 1 contributor and audited 2094 packages in 19.571s

115 packages are looking for funding
  run `npm fund` for details

found 0 vulnerabilities
```
and load it for the tests by adding the following import to `cypress/support/commands.js`:

```javascript
import '@testing-library/cypress/add-commands';
```

Now we want to actually visit our page. The best practice, [per the docs][cypress base url], is to configure a global base URL and navigate relative to that, so let's add the default CRA URL (along with disabling the video recordings, to simplify the outputs) to `cypress.json`:

```json
{
  "baseUrl": "http://localhost:3000",
  "video": false
}
```

Just like with Jest, Cypress provides an `it` function for registering a test, again taking the name of the test as a string and the body of the test as a function:

```javascript
it("should say left wins for rock vs. scissors", () => {
  cy.visit("/");
  cy.findByLabelText("Left").select("rock");
  cy.findByLabelText("Right").select("scissors");

  cy.findByText("Throw").click();

  cy.findByTestId("outcome").should("contain.text", "Left wins!");
});
```

_(If your IDE seems unhappy with `cy`, just ignore it for now, but check out the bonus section on Linting at the end of the article.)_

This is basically the same expectation as the first unit test case we wrote last time, but at the end-to-end level. `cy` is a global object that provides access to various Cypress methods; this is a pretty big API (and we've added more things to it from Testing Library!) so for now note that:

- we're `visit`ing the root path based on the base URL we already set. This should take us to the home page of our site;
- we're selecting the `rock` option in an element with the label `Left`;
- we're selecting the `scissors` option in an element with the label `Right`;
- we're clicking the `Throw` button; and
- we're checking that the outcome being being displayed, in the element with the appropriate test ID (using stable attribute selectors is another [Cypress best practice][cypress selectors] and Testing Library gives us functions to easily access elements, assuming the attribute is named `data-testid`), is the expected `Left wins!`

As before, _none of this exists yet_, so we can easily talk about how this user interface should work without the friction of having to implement it. Maybe the user should enter free text instead of selecting from a list? Maybe it should automatically show the outcome when the second input is provided, rather than requiring a button click? Maybe there should be names for the users instead of left and right? This is making us think in concrete terms about how the users should interact with the system.

For now, we'll use the proposed interface. Just like with Jest, call the shot then run the tests:

```bash
$ npm run e2e

> rps-e2e@0.1.0 e2e path/to/rps-e2e
> cypress run

Cypress could not verify that this server is running:

  > http://localhost:3000

We are verifying this server because it has been configured as your `baseUrl`.

Cypress automatically waits until your server is accessible before running tests.

We will try connecting to it 3 more times...
We will try connecting to it 2 more times...
We will try connecting to it 1 more time...

Cypress failed to verify that your server is running.

Please start this server and then run Cypress again.
npm ERR! code ELIFECYCLE
npm ERR! errno 1
npm ERR! rps-e2e@0.1.0 e2e: `cypress run`
npm ERR! Exit status 1
npm ERR! 
npm ERR! Failed at the rps-e2e@0.1.0 e2e script.
npm ERR! This is probably not a problem with npm. There is likely additional logging output above.

npm ERR! A complete log of this run can be found in:
npm ERR!     path/to/.npm/_logs/2020-11-03T21_01_26_636Z-debug.log
```

Cypress is unhappy because we're _not actually running the app_. As a simple fix, open an extra command line, navigate to the working directory and run `npm start`. Once the default CRA home screen shows up in your browser, call the shot then run the E2E tests again in your first command line:

```bash
$ npm run e2e

> rps-e2e@0.1.0 e2e path/to/rps-e2e
> cypress run


====================================================================================================

  (Run Starting)

  ┌────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Cypress:    5.4.0                                                                              │
  │ Browser:    Electron 85 (headless)                                                             │
  │ Specs:      1 found (e2e.test.js)                                                              │
  └────────────────────────────────────────────────────────────────────────────────────────────────┘


────────────────────────────────────────────────────────────────────────────────────────────────────
                                                                                                    
  Running:  e2e.test.js                                                                     (1 of 1)


  1) should say left wins for rock vs. scissors

  0 passing (5s)
  1 failing

  1) should say left wins for rock vs. scissors:
     TestingLibraryElementError: Timed out retrying: Unable to find a label with the text of: Left
      at Object.getElementError (http://localhost:3000/__cypress/tests?p=cypress/support/index.js:1688:17)
      at getAllByLabelText (http://localhost:3000/__cypress/tests?p=cypress/support/index.js:2816:25)
      at eval (http://localhost:3000/__cypress/tests?p=cypress/support/index.js:2560:24)
      at eval (http://localhost:3000/__cypress/tests?p=cypress/support/index.js:2611:25)
      at baseCommandImpl (http://localhost:3000/__cypress/tests?p=cypress/support/index.js:1148:16)
      at commandImpl (http://localhost:3000/__cypress/tests?p=cypress/support/index.js:1151:40)
      at getValue (http://localhost:3000/__cypress/tests?p=cypress/support/index.js:1175:23)
      at resolveValue (http://localhost:3000/__cypress/tests?p=cypress/support/index.js:1215:35)




  (Results)

  ┌────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Tests:        1                                                                                │
  │ Passing:      0                                                                                │
  │ Failing:      1                                                                                │
  │ Pending:      0                                                                                │
  │ Skipped:      0                                                                                │
  │ Screenshots:  1                                                                                │
  │ Video:        false                                                                            │
  │ Duration:     5 seconds                                                                        │
  │ Spec Ran:     e2e.test.js                                                                      │
  └────────────────────────────────────────────────────────────────────────────────────────────────┘


  (Screenshots)

  -  path/to/rps-e2e/cypress/screenshots/e2e.test.js/should say left wins for rock vs     (1280x720)
     . scissors (failed).png                                       

====================================================================================================

  (Run Finished)


       Spec                                              Tests  Passing  Failing  Pending  Skipped  
  ┌────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ ✖  e2e.test.js                              00:05        1        -        1        -        - │
  └────────────────────────────────────────────────────────────────────────────────────────────────┘
    ✖  1 of 1 failed (100%)                     00:05        1        -        1        -        -  

npm ERR! code ELIFECYCLE
npm ERR! errno 1
npm ERR! rps-e2e@0.1.0 e2e: `cypress run`
npm ERR! Exit status 1
npm ERR! 
npm ERR! Failed at the rps-e2e@0.1.0 e2e script.
npm ERR! This is probably not a problem with npm. There is likely additional logging output above.

npm ERR! A complete log of this run can be found in:
npm ERR!     path/to/.npm/_logs/2020-11-03T21_04_24_496Z-debug.log
```
OK, we've moved on a step - the test is now failing because it can't find the element on the page. So far we haven't actually added anything to the page, so that makes sense, it's just showing the default CRA info (you can see this in the screenshot, check it out!)

This is going to be our guiding star for the rest of the exercise, so let's make a commit to store this state:

```bash
$ git add .

$ git status
On branch master
Changes to be committed:
  (use "git restore --staged <file>..." to unstage)
        modified:   cypress.json
        modified:   cypress/integration/e2e.test.js
        modified:   cypress/support/commands.js
        modified:   package-lock.json
        modified:   package.json


$ git commit -m 'Implement E2E test'
[master c89108b] Implement E2E test
 5 files changed, 25 insertions(+), 1 deletion(-)
```

## Moving to the unit level [3/6]

Let's think about the structure of our app. We know that broadly we're going to have two `<select>` inputs (left and right), one `<button>` and some kind of output element. We also know we're going to have some business logic, independent of that UI; the `rps` implementation we built previously.

So let's assume the main `App` component is just going to have a coordinating role. It will render a `Form` component, which deals with the user input, and communicate with an `rpsService` where the business logic lives:

```
App -- rpsService
 |
Form
```

As we've already worked a lot on the core service logic, let's start with the form. Create a new directory named `Form` inside `src`, and add an `index.test.js` file into it with the following content:

```javascript
import { render } from '@testing-library/react';
import userEvent from '@testing-library/user-event';

describe('Form component', () => {
  it('emits a pair of selections when the form is submitted', async () => {
    const left = 'rock';
    const right = 'scissors';
    const onSubmit = jest.fn();
    const { getByLabelText, getByText } = render(<Form onSubmit={onSubmit} />);
    
    userEvent.selectOptions(getByLabelText('Left'), left);
    userEvent.selectOptions(getByLabelText('Right'), right);
    userEvent.click(getByText('Throw'));

    expect(onSubmit).toHaveBeenCalledWith([left, right]);
  });
});
```

You can read about the details in the Jest and Testing Library documentation, but at a high level we:

- Create a Jest _"mock function"_, a [test double] we can pass to the `Form` component in place of a real function;
- Render the form, passing the test double as a prop, and _destructure_ the element selection methods we'll need;
- Make two selections and click the button; and
- Assert that the test double was called with the expected values.

This looks quite a lot like the end-to-end test, but with a slightly more limited scope - we only care that the user input is taken correctly, not that the appropriate winner is determined. This is part of the process of _decomposing_ the problem into smaller (and easier-to-solve) pieces, which is the reason I think starting with the end-to-end tests makes sense.

Again this gives us an opportunity to talk about the API details of the component before it even exists. Perhaps it should return an object `{ left, right }` instead of an array `[left, right]`? Is `onSubmit` the best name for the prop? It's easier to have these discussions when changing the API is a matter of changing your mind rather than changing the code.

Call the shot, run the test:

```
 FAIL  src/Form/index.test.js
  Form component
    ✕ emits a pair of selections when the form is submitted (2 ms)

  ● Form component › emits a pair of selections when the form is submitted

    ReferenceError: Form is not defined

       7 |     const right = 'scissors';
       8 |     const onSubmit = jest.fn();
    >  9 |     const { getByLabelText, getByText } = render(<Form onSubmit={onSubmit} />);
         |                                                   ^
      10 |     
      11 |     userEvent.selectOptions(getByLabelText('Left'), left);
      12 |     userEvent.selectOptions(getByLabelText('Right'), right);

      at Object.<anonymous> (src/Form/index.test.js:9:51)
```

Right, we don't actually have the component yet! Create a new file `index.js` containing a minimal component:

```javascript
const Form = () => null;

export default Form;
```

and import that at the top of `index.test.js`:

```javascript
import Form from '.';
```

Call the shot, run the test:

```
 FAIL  src/Form/index.test.js
  Form component
    ✕ emits a pair of selections when the form is submitted (29 ms)

  ● Form component › emits a pair of selections when the form is submitted

    TestingLibraryElementError: Unable to find a label with the text of: Left

    <body>
      <div />
    </body>

      11 |     const { getByLabelText, getByText } = render(<Form onSubmit={onSubmit} />);
      12 |     
    > 13 |     userEvent.selectOptions(getByLabelText('Left'), left);
         |                             ^
      14 |     userEvent.selectOptions(getByLabelText('Right'), right);
      15 |     userEvent.click(getByText('Throw'));
      16 | 

      at Object.getElementError (node_modules/@testing-library/dom/dist/config.js:37:19)
      at getAllByLabelText (node_modules/@testing-library/dom/dist/queries/label-text.js:115:38)
      at node_modules/@testing-library/dom/dist/query-helpers.js:62:17
      at getByLabelText (node_modules/@testing-library/dom/dist/query-helpers.js:106:19)
      at Object.<anonymous> (src/Form/index.test.js:13:29)
```

We're a bit further, now there's no component with the specified label. Note that the actual element is displayed - so far it's just an empty `<div/>`. Now we can dive into the details of the component. 

Covering the details of how to implement something like this in React are a bit beyond the scope of this article, but one way we can create a [controlled component] that passes the test is as follows:

```jsx
import { useState } from 'react';

const Form = ({ onSubmit }) => {
  const [left, setLeft] = useState('rock');
  const [right, setRight] = useState('rock');

  return (
    <div>
      <label>
        Left
        <select value={left} onChange={({ target: { value }}) => setLeft(value)}>
          <option value="rock">Rock</option>
          <option value="paper">Paper</option>
          <option value="scissors">Scissors</option>
        </select>
      </label>
      <label>
        Right
        <select value={right} onChange={({ target: { value }}) => setRight(value)}>
          <option value="rock">Rock</option>
          <option value="paper">Paper</option>
          <option value="scissors">Scissors</option>
        </select>
      </label>
      <button onClick={() => onSubmit([left, right])}>Throw</button>
    </div>
  );
};

export default Form;
```

You might think the `<select>` part is a bit repetitive, and that's fair, so let's use the fact that the test gives us confidence that our implementation continues to work to refactor a bit:

```jsx
import { useState } from 'react';

const Select = ({ label, onChange, value }) => (
  <label>
    {label}
    <select value={value} onChange={({ target: { value }}) => onChange(value)}>
      <option value="rock">Rock</option>
      <option value="paper">Paper</option>
      <option value="scissors">Scissors</option>
    </select>
  </label>
);

const Form = ({ onSubmit }) => {
  const [left, setLeft] = useState('rock');
  const [right, setRight] = useState('rock');

  return (
    <div>
      <Select label="Left" onChange={setLeft} value={left} />
      <Select label="Right" onChange={setRight} value={right} />
      <button onClick={() => onSubmit([left, right])}>Throw</button>
    </div>
  );
};

export default Form;
```

## At your service [4/6]

We already have this! You should still have a function named `rps` from the previous article, along with a suite of tests. Place the function in a file named `rpsService.js` and export it:

```javascript
export function rps(left, right) {
  // ...
}
```

then place the test suite in a file named `rpsService.test.js` along with an import:

```javascript
import { rps } from './rpsService';

describe('rock, paper, scissors', () => {
  // ...
});
```

All of the same tests should pass happily in the new context.

## Putting it all back together [5/6]

For the `App` component itself, which coordinates the `Form` and `rpsService`, the only logic needed is the display of the outcome. We have four cases:

 1. Before any selection is made, no outcome is shown;
 2. If the left throw wins, display `Left wins!`;
 3. If the right throw wins, display `Right wins!`; or
 4. If neither throw wins, display `Draw!`.

We could test this component in isolation, e.g. mocking out the service, but given how simple the other parts of this system are we can just write a more integration-level test, making sure the three parts work together. To match the above cases, replace the content of `App.test.js` with the following:

```jsx
import { render } from '@testing-library/react';
import userEvent from '@testing-library/user-event';

import App from './App';

describe("App component", () => {
  it("doesn't display an outcome at first", () => {
    const { queryByTestId } = render(<App />);

    expect(queryByTestId('outcome')).toBeNull();
  });

  it.skip("displays left wins when appropriate", () => {
    const { getByLabelText, getByTestId, getByText } = render(<App />);

    userEvent.selectOptions(getByLabelText('Left'), 'paper');
    userEvent.selectOptions(getByLabelText('Right'), 'rock');
    userEvent.click(getByText('Throw'));

    expect(getByTestId('outcome')).toHaveTextContent('Left wins!');
  });

  it.skip("displays right wins when appropriate", () => {
    const { getByLabelText, getByTestId, getByText } = render(<App />);

    userEvent.selectOptions(getByLabelText('Left'), 'paper');
    userEvent.selectOptions(getByLabelText('Right'), 'scissors');
    userEvent.click(getByText('Throw'));

    expect(getByTestId('outcome')).toHaveTextContent('Right wins!');
  });

  it.skip("displays draw when appropriate", () => {
    const { getByLabelText, getByTestId, getByText } = render(<App />);

    userEvent.selectOptions(getByLabelText('Left'), 'paper');
    userEvent.selectOptions(getByLabelText('Right'), 'paper');
    userEvent.click(getByText('Throw'));

    expect(getByTestId('outcome')).toHaveTextContent('Draw!');
  });
});
```

These seem pretty close to the format of the end-to-end tests, and that should make sense - we're integrating the client app parts together. Note the use of `it.skip`, which prevents the test case from actually running; only the first test is currently active. This is to encourage the same kind of test-driven development as we used in the previously article. Get each test passing in turn, then **delete the `.skip` from the next one** to activate it. By the end all four tests should be passing, and you may have something like:
 

```jsx
import { useState } from 'react';

import Form from './Form';
import { rps } from './rpsService';

const outcomes = {
  draw: 'Draw!',
  left: 'Left wins!',
  right: 'Right wins!',
};

const App = () => {
  const [winner, setWinner] = useState(undefined);

  const handleThrows = ([left, right]) => {
    setWinner(rps(left, right));
  };

  return (
    <div className="App">
      <Form onSubmit={handleThrows} />
      {winner && <div data-testid="outcome">{outcomes[winner]}</div>}
    </div>
  );
}

export default App;
```

All of the unit tests should now be passing, so call the final shot and run the end-to-end test:

```bash
$ npm run e2e

> rps-e2e@0.1.0 e2e path/to/rps-e2e
> cypress run


====================================================================================================

  (Run Starting)

  ┌────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Cypress:    5.4.0                                                                              │
  │ Browser:    Electron 85 (headless)                                                             │
  │ Specs:      1 found (e2e.test.js)                                                              │
  └────────────────────────────────────────────────────────────────────────────────────────────────┘


────────────────────────────────────────────────────────────────────────────────────────────────────
                                                                                                    
  Running:  e2e.test.js                                                                     (1 of 1)


  ✓ should say left wins for rock vs. scissors (1329ms)

  1 passing (1s)


  (Results)

  ┌────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Tests:        1                                                                                │
  │ Passing:      1                                                                                │
  │ Failing:      0                                                                                │
  │ Pending:      0                                                                                │
  │ Skipped:      0                                                                                │
  │ Screenshots:  0                                                                                │
  │ Video:        false                                                                            │
  │ Duration:     1 second                                                                         │
  │ Spec Ran:     e2e.test.js                                                                      │
  └────────────────────────────────────────────────────────────────────────────────────────────────┘


====================================================================================================

  (Run Finished)


       Spec                                              Tests  Passing  Failing  Pending  Skipped  
  ┌────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ ✔  e2e.test.js                              00:01        1        1        -        -        - │
  └────────────────────────────────────────────────────────────────────────────────────────────────┘
    ✔  All specs passed!                        00:01        1        1        -        -        -  

```

That's it! We've created a simple UI for our RPS implementation, test-driving it from the outside in. Create a commit to save this work:

```bash
$ git add .

$ git commit -m 'Implement RPS UI'
[master be3db46] Implement RPS UI
 6 files changed, 190 insertions(+), 33 deletions(-)
 rewrite src/App.js (85%)
 rewrite src/App.test.js (87%)
 create mode 100644 src/Form/index.js
 create mode 100644 src/Form/index.test.js
 create mode 100644 src/rpsService.js
 create mode 100644 src/rpsService.test.js
```

## Exercises [6/6]

Here are some additional exercises you can run through:

 1. Repeat the process from the beginning and try to come up with a different implementation (including running through the `rps` part, if you like). Was your new route easier or harder?

 1. I mentioned various alternatives to the user interface we implemented, e.g. allowing free text input. Pick one of my suggestions (or come up with your own) and implement it from the outside in.

 1. If you implemented additional weapons in your `rps` implementation, extend the UI to support them. If not, maybe this is a good time to revisit it!
 
 1. Rather than `useState('rock')` in the `Form` component, we should start with `useState()`, which gives an initial value of `undefined`. How should this appear in the `<select>` components? Can `onSubmit` still be called with undefined values - which part of the system should deal with that? Write tests based on these decisions, then implement it.

I'd recommend creating a new git branch for each one you try (e.g. use `git checkout -b <name>`) and making commits as appropriate.

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
npm WARN tsutils@3.17.1 requires a peer of typescript@>=2.8.0 || >= 3.2.0-dev || >= 3.3.0-dev || >= 3.4.0-dev || >= 3.5.0-dev || >= 3.6.0-dev || >= 3.6.0-beta || >= 3.7.0-dev || >= 3.7.0-beta but none is installed. You must install peer dependencies yourself.

+ eslint-plugin-cypress@2.11.2
added 1 package from 1 contributor and audited 2092 packages in 18.002s

119 packages are looking for funding
  run `npm fund` for details

found 0 vulnerabilities
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

  [controlled component]: https://reactjs.org/docs/forms.html#controlled-components
  [cra]: https://create-react-app.dev/docs/getting-started
  [Cypress]: https://cypress.io
  [cypress base url]: https://docs.cypress.io/guides/references/best-practices.html#Setting-a-global-baseUrl
  [cypress cli]: https://docs.cypress.io/guides/guides/command-line.html
  [cypress config]: https://docs.cypress.io/guides/references/configuration.html
  [cypress selectors]: https://docs.cypress.io/guides/references/best-practices.html#Selecting-Elements
  [Jest]: https://jestjs.io/
  [Testing Library]: https://testing-library.com
  [test double]: https://engineering.pivotal.io/post/the-test-double-rule-of-thumb/
  [the previous post]: {filename}/development/js-tdd-ftw.md
