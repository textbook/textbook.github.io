Title: JS TDD API
Date: 2021-04-10 20:30
Modified: 2023-06-27 15:30
Tags: javascript, tdd, xp
Authors: Jonathan Sharpe
Summary: Test-driven JavaScript development done right - part 3

Welcome to part 3 of this ongoing series on test-driven development (TDD) in JavaScript. So far we've covered:

- **[Part 1]** - the basic principles of test-driven development, showing unit testing using [Jest]
- **[Part 2]** - expanding to higher level testing, using [Cypress] for E2E and Jest for integration (and unit) testing of a simple React app with [Testing Library]

In the second part, I covered:

- How to add Cypress tests to a basic [Create React App][cra] project
- Outside-in TDD, working from E2E tests in Cypress; through integration tests of multiple components working together; down to the unit level of individual components
- Testing _presentation_ components (`<Outcome result={...} />`) by rendering them with different props and checking what gets displayed in the DOM
- Testing _interaction_ components (`<Form onSubmit={...} />`) by passing _test doubles_ for their callbacks and checking they get called appropriately on simulated user interaction

If you haven't read these yet, I'd suggest you go back and run through them before getting stuck into this one. Make sure you're confident with the approach so far, because we're going to add in a few new ideas here.

So what's next? Our rock, paper, scissors (RPS) game isn't very much fun right now, because the second player can guarantee a win by waiting to see what the first player throws and choosing their weapon accordingly. Instead, let's make it a one-player game where you're taking on a random user:

![Mockup of the proposed RPS UI]({static}/images/rps-api-ui.png)

<small>_Created with [reMarkable](https://remarkable.com/)._</small>

Here the `???`s indicate information that will be random - we don't know the _name_ of the opponent or which _weapon_ they'll choose and therefore what the _outcome_ will be. That's part of the fun! But it also makes it a little trickier to test.

This also gives us the opportunity to practice interacting with an API; making requests and handling responses, and seeing how to test that at various levels. Again this adds complexity, this time because it's random and because it's _asynchronous_. We will get the opponent data from `https://randomuser.me/`, a really handy API for exactly this kind of exercise.

Before we continue, think about how you might actually implement that UI in React - what components would you have, how would they interact, where would the state live? Note your ideas down, we'll revisit them later.

### Requirements

The prerequisites here are the same as the previous articles:

- *nix command line: already provided on macOS and Linux; if you're using Windows try [WSL] or [Git BASH];
- [Node] \(16+ recommended, Jest 29 [dropped support] for Node 12; run `node -v` to check) and NPM; and
- Familiarity with ES6 JavaScript syntax.

In addition, given the domain for this post, you'll need:

- Familiarity with React development - I'm going to assume you know how to write a basic implementation, guiding you with test cases and a few function component examples.
- Familiarity with promises - the asynchronous parts will use `async`/`await` syntax, and Cypress uses `.then` in a similar way to promises.

Again please carefully _read everything_, and for newer developers I'd recommend _typing the code_ rather than copy-pasting.

## Setup [1//8]

Let's create a new CRA-with-Cypress project. You can return to part 2 for more detailed instructions, or follow the steps below if you're feeling more confident (I've also published instructions and even a script to automate the process in [this Gist]):

1. Create a new React app with `npx create-react-app@latest rps-api`
2. Enter the project directory with `cd rps-api/`
3. Add Cypress and the relevant Testing Library utilities with `npm install cypress @testing-library/{cypress,react,user-event}@latest`
4. Open the Cypress UI to do the initial setup with `npx cypress open`, select "E2E Testing" then quit the UI
5. Remove the example fixture with `rm ./cypress/fixtures/example.json`
6. Configure Cypress to look for the CRA app and not create videos by adding `baseUrl: "http://localhost:3000"` and `video: false` into the `e2e` object in `cypress.config.js`
7. Set up the Testing Library utilities by adding `import "@testing-library/cypress/add-commands";` to `./cypress/support/commands.js`
8. Exclude any files Cypress generates from your commits by adding `cypress/downloads/`, `cypress/screenshots/` and `cypress/videos/` to `.gitignore`
9. Add a command to run the E2E tests by adding `"e2e": "cypress run"` into the `"scripts"` object in `package.json`
10. Create a new test file with `touch ./cypress/e2e/journey.cy.js` (you may need to `mkdir ./cypress/e2e` first)
11. _[Optional]_ Install the ESLint plugin with `npm install eslint-plugin-cypress` and add the following to the `eslintConfig` in `package.json`:

        :::json
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

If you've done all of the above correctly, you should be able to run `npm start` in one terminal window and then `npm run e2e` in another, giving the following output:

```bash
$ npm run e2e                    

> rps-api@0.1.0 e2e
> cypress run


DevTools listening on ws://127.0.0.1:55431/devtools/browser/75378efa-5dd2-45b5-b0c0-91fb862e7076
Couldn't find tsconfig.json. tsconfig-paths will be skipped

====================================================================================

  (Run Starting)

  ┌────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Cypress:        12.16.0                                                                        │
  │ Browser:        Electron 106 (headless)                                                        │
  │ Node Version:   v16.20.0 (path/to/node)                                                        │
  │ Specs:          1 found (journey.cy.js)                                                        │
  │ Searched:       cypress/e2e/**/*.cy.{js,jsx,ts,tsx}                                            │
  └────────────────────────────────────────────────────────────────────────────────────────────────┘


────────────────────────────────────────────────────────────────────────────────────────────────────
                                                                                                    
  Running:  journey.cy.js                                                                   (1 of 1)


  0 passing (0ms)


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


====================================================================================

  (Run Finished)


       Spec                                              Tests  Passing  Failing  Pending  Skipped  
  ┌────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ ✔  journey.cy.js                              0ms        -        -        -        -        - │
  └────────────────────────────────────────────────────────────────────────────────────────────────┘
    ✔  All specs passed!                          0ms        -        -        -        -        -  

```

If you don't see that output, go back and double-check you've followed all of the steps as written. If you do, great! Make a commit:

```bash
$ git add .

$ git status
On branch main
Changes to be committed:
  (use "git restore --staged <file>..." to unstage)
        modified:   .gitignore
        new file:   cypress.config.js
        new file:   cypress/e2e/journey.cy.js
        new file:   cypress/plugins/index.js
        new file:   cypress/support/commands.js
        new file:   cypress/support/index.js
        modified:   package-lock.json
        modified:   package.json


$ git commit -m 'Install and configure Cypress'
[main 9d1af26] Install and configure Cypress
 8 files changed, 2242 insertions(+)
 create mode 100644 cypress.config.js
 create mode 100644 cypress/e2e/journey.cy.js
 create mode 100644 cypress/plugins/index.js
 create mode 100644 cypress/support/commands.js
 create mode 100644 cypress/support/index.js
```

## Dealing with unknowns [2/8]

Based on the above UI sketch, the way our new RPS game should work is as follows:

- You are always the "left" player, with the same drop-down to select  a weapon as before
- Your opponent is always the "right" player, a computer player with random personal details (we'll show their avatar and name)
- When you throw, the computer player picks a random weapon
- The outcome is displayed exactly as before ("Left wins!", "Right wins!" or "Draw")

I'm going to split that into two tests in `cypress/e2e/journey.cy.js `:

```javascript
it("displays a random opponent", () => {
  cy.visit("/");

  cy.findByTestId("opponent-name").should("contain.text", /* ??? */);
  cy.findByTestId("opponent-avatar").should("have.attr", "src", /* ??? */);
});

it("displays the appropriate winner", () => {
  cy.visit("/");

  cy.findByLabelText("Left").select("rock");  
  cy.findByText("Throw").click();

  cy.findByTestId("opponent-weapon").should("contain.text", /* ??? */);
  cy.findByTestId("outcome").should("contain.text", /* ??? */);
});
```

Immediately we can see a problem - if the opponent and their throw are random, we don't know what the _values_ are going to be. I'll explore three different ways to deal with this.

1. **Broaden expectations** - we could use less specific expectations to test that the _shape_ of the output is appropriate, without checking the details of the _values_:

        :::javascript
        it("displays an opponent from the API", () => {
          cy.visit("/");
        
          cy.findByTestId("opponent-name")
            .invoke("text")
            .should("match", /[A-Z][a-z]+ [A-Z][a-z]+/);
          cy.findByTestId("opponent-avatar")
            .should("have.attr", "src")
            .and("match", /^https:\/\/randomuser\.me\/api\/portraits/);
        });
    
    If you're unfamiliar with the regular expression (_"regex"_) syntax used in `match`, you can paste those patterns into e.g. [Regex 101] to get an explanation, but basically this says that the name should be two words, each starting with a capital letter, and the avatar's source should start like a URL. This means we don't have to know exactly what data we'll get back from the API to make an assertion on it.

    **Note** that this isn't a very thorough regex, and people's names take [a lot of forms][names] not considered by it. While writing this article I got one assertion error due to it failing to match an entirely valid name:

    ```
    AssertionError: Timed out retrying after 4000ms: expected 'Maïwenn Gaillard' to match /[A-Z][a-z]+ [A-Z][a-z]+/
    ```

    I'm using it here as an example to show how you can provide a "fuzzier" match for uncontrolled data, it shouldn't be used for e.g. input validation in a real system.

2. **Fake data** - for sources of unknown data _outside_ of our application, that we're getting from APIs, we can provide known fake data. Cypress 6 [introduced][cypress blog] _"next generation network stubbing"_, so I thought it would be interesting to show how we can use that, but note there are lots of other ways to do this (see e.g. [this post][spa config] on how to configure single-page apps, letting you fetch data from a different API for testing).
    
    To make sure our example is as realistic as possible, let's get it directly from the API we're going to use:
    
        :::bash
        $ curl https://api.randomuser.me > ./cypress/fixtures/example.json
          % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                         Dload  Upload   Total   Spent    Left  Speed
        100  1167    0  1167    0     0   5984      0 --:--:-- --:--:-- --:--:--  5984
        
        $ cat ./cypress/fixtures/example.json
        {"results":[{"gender":"male","name":{"title":"Mr","first":"Randy","last":"Wheeler"},"location":{"street":{"number":9524,"name":"Forest Ln"},"city":"Knoxville","state":"North Dakota","country":"United States","postcode":66112,"coordinates":{"latitude":"83.6453","longitude":"-96.6784"},"timezone":{"offset":"-1:00","description":"Azores, Cape Verde Islands"}},"email":"randy.wheeler@example.com","login":{"uuid":"cf6f47a9-05a0-48c7-b09b-f7f25c1fb43f","username":"organicpeacock969","password":"1103","salt":"cuNdIWCC","md5":"34329408fbe3f2b9e8e06ca4d9e03eec","sha1":"c68b20496e5d747f5b6b2ea75852a4dc8b8e87f0","sha256":"85a51818e94cf3e751fe76dff562d6047c261e9a6911994156b5c90176eb2580"},"dob":{"date":"1970-11-28T01:34:37.972Z","age":50},"registered":{"date":"2018-10-14T00:27:46.788Z","age":2},"phone":"(370)-972-2945","cell":"(464)-808-2579","id":{"name":"SSN","value":"721-97-7603"},"picture":{"large":"https://randomuser.me/api/portraits/men/12.jpg","medium":"https://randomuser.me/api/portraits/med/men/12.jpg","thumbnail":"https://randomuser.me/api/portraits/thumb/men/12.jpg"},"nat":"US"}],"info":{"seed":"133d55784bdd75c9","results":1,"page":1,"version":"1.3"}}

    
    Note that your data will most likely be different, but I'll use the data shown above for the rest of the article. We can now tell Cypress to respond to the request with the data stored in our fixture, then assert on the values from the fixture:
    
        :::javascript
        it("displays an opponent from a fixture", () => {
          cy.intercept("GET", "https://api.randomuser.me", { fixture: "example.json" });
        
          cy.visit("/");
          
          cy.findByTestId("opponent-name").should("contain.text", "Randy Wheeler");
          cy.findByTestId("opponent-avatar")
            .should("have.attr", "src", "https://randomuser.me/api/portraits/thumb/men/12.jpg");
        });
    
    **Note** that this approach is not without risk - if the API we're mocking changes such that the content of `example.json` doesn't match the response, our tests will still pass but the code _won't work_ in real life.

3. **Reimplement logic** - for sources of unknown data _inside_ our application, usually some kind of randomness, we may end up reimplementing some of the logic we're testing. Here we know that the left player will throw `"rock"`, because we control this, but right player could throw either `"rock"`, `"paper"` _or_ `"scissors"`. Therefore there are three possible outcomes:

        :::javascript
        const OUTCOMES = {
          "rock": "Draw!",  // rock draws with rock
          "paper": "Right wins!",  // paper wraps rock
          "scissors": "Left wins!",  // scissors are blunted by rock
        };
    
    Although we can't tell in advance which will be randomly picked, once we see the opponent's choice we know what the outcome should be. So we can use Cypress's [closures][cypress closures], an API very similar to _promises_, to get access to the opponent's choice and use that to determine the expected outcome and make the appropriate assertion:
        
        :::javascript
        it("displays the appropriate winner", () => {
          cy.visit("/");
          
          cy.findByLabelText("Left").select("rock");  
          cy.findByText("Throw").click();
          
          cy.findByTestId("opponent-weapon").then(($weapon) => {
            cy.findByTestId("outcome").should("contain.text", OUTCOMES[$weapon.text()]);
          });
        });
        
    **Note** that if you're seeing ESLint warnings it will be unhappy with the last few lines, even if you added the Cypress configuration in step 11 above. One of the Jest-specific rules doesn't understand how the Cypress closures work, so you'll need to explicitly disable it by adding `"rules": {"jest/valid-expect-in-promise": "off"}` into the override for Cypress files.

By combining these three approaches, we can be confident that our app works correctly despite the uncertainty around the specific values we'll be getting. Call the shots and run the tests:

```bash
$ npm run e2e

> rps-api@0.1.0 e2e
> cypress run


====================================================================================

  (Run Starting)

  ┌────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Cypress:        12.16.0                                                                        │
  │ Browser:        Electron 106 (headless)                                                        │
  │ Node Version:   v16.20.0 (path/to/node)                                                        │
  │ Specs:          1 found (journey.cy.js)                                                        │
  │ Searched:       cypress/e2e/**/*.cy.{js,jsx,ts,tsx}                                            │
  └────────────────────────────────────────────────────────────────────────────────────────────────┘


────────────────────────────────────────────────────────────────────────────────────────────────────
                                                                                                    
  Running:  journey.cy.js                                                                   (1 of 1)


  1) displays an opponent from the API
  2) displays an opponent from a fixture
  3) displays the appropriate winner

  0 passing (13s)
  3 failing

  1) displays an opponent from the API:
     AssertionError: Timed out retrying after 4000ms: Unable to find an element by: [data-testid="opponent-name"]

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
      at Context.eval (webpack:///./cypress/e2e/journey.cy.js:4:5)

  2) displays an opponent from a fixture:
     AssertionError: Timed out retrying after 4000ms: Unable to find an element by: [data-testid="opponent-name"]

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
      at Context.eval (webpack:///./cypress/e2e/journey.cy.js:17:35)

  3) displays the appropriate winner:
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
      at Context.eval (webpack:///./cypress/e2e/journey.cy.js:25:5)




  (Results)

  ┌────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Tests:        3                                                                                │
  │ Passing:      0                                                                                │
  │ Failing:      3                                                                                │
  │ Pending:      0                                                                                │
  │ Skipped:      0                                                                                │
  │ Screenshots:  3                                                                                │
  │ Video:        false                                                                            │
  │ Duration:     12 seconds                                                                       │
  │ Spec Ran:     journey.cy.js                                                                    │
  └────────────────────────────────────────────────────────────────────────────────────────────────┘


  (Screenshots)

  -  path/to/rps-api/cypress/screenshots/journey.cy.js/displays an opponent from the      (1280x720)
     API (failed).png                                              
  -  path/to/rps-api/cypress/screenshots/journey.cy.js/displays an opponent from a fi     (1280x720)
     xture (failed).png                                            
  -  path/to/rps-api/cypress/screenshots/journey.cy.js/displays the appropriate winne     (1280x720)
     r (failed).png                                                


====================================================================================

  (Run Finished)


       Spec                                              Tests  Passing  Failing  Pending  Skipped  
  ┌────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ ✖  journey.cy.js                            00:12        3        -        3        -        - │
  └────────────────────────────────────────────────────────────────────────────────────────────────┘
    ✖  1 of 1 failed (100%)                     00:12        3        -        3        -        -  

```

They all fail for uninteresting reasons at the moment (can't find elements by the test ID or label), but it gives us something to work towards. Make a commit, and we'll move down to the React level.

```bash
$ git add .
$ git status
On branch main
Changes to be committed:
  (use "git restore --staged <file>..." to unstage)
        modified:   cypress/e2e/journey.cy.js
        new file:   cypress/fixtures/example.json

$ git commit -m 'Failing end-to-end-tests'
[main 37fd8f7] Failing end-to-end-tests
 2 files changed, 38 insertions(+)
 create mode 100644 cypress/fixtures/example.json
```

## Dealing with APIs [3/8]

As we move to the source code, let's think about architecture. Our previous RPS app had the following structure:

```
   App <--> rpsService
  /   \
Form  Outcome
```

We're extending this 

```
API <-...-> randomUserService <--> App <--> rpsService
                                  / | \
                              Form  |  Opponent
                                 Outcome
```

Alone with the coordinating `App` component, that now gives us two services, two presentation components and one interaction component.

- When the app loads, the `App` calls the `randomUserService` to get an opponent 
- The `App` passes that to `Opponent` for  display
- When the user makes a choice and clicks the Throw button, their choice is sent from the `Form` to the `App`
- The `App` calls the `rpsService` to get a random weapon for the opponent
- The `App` calls the `rpsService` again to get the outcome given the player's input and the opponent's weapon
- The `App` passes that outcome to `Outcome` for display

The `...` on the left represents a request going over the network - the API itself is _outside_ our system. These are relatively slow, so we don't want them happening for real in our integration or lower level tests. They also introduce variability that makes tests less reliable; your code can be working fine, but a test fails because your wifi is flaky.

Take a typical request from a single-page app:

```javascript
fetch(someUrl)
  .then((res) => res.json())
  .then((data) => /* use data */);
```

You might think we should simply replace `fetch` with a test double. The rule of thumb is _"don't mock what you don't own"_, though, and here are a few reasons why:

- If we replace `fetch` we couple our code and tests too closely to that interface. Say we decided to use [`axios`][axios] instead of `fetch`; our existing tests wouldn't help us, we'd have to rewrite all of them. It's hard to be confident that eveything's still correct when you've changed the implementation _and_ the tests.

- Worse still, if the `fetch` API changed, our tests would continue to pass even though the implementation doesn't actually work with the new interface. Because we're testing the implementation against the test double, everything seems fine.

- You could even be wrong about the interface you're replacing and write tests that drive the _wrong_ impementation. For example check out [this Stack Overflow answer], where I found out that the questioner's test double didn't actually match the interface it was replacing.

- `fetch` specifically is a relatively complicated interface; our test double needs to return a promise of an object with a `json` method that returns a promise of the response data:

        :::javascript
        const fetchTestDouble = jest.fn().mockResolvedValue({
          json: jest.fn().mockResolvedValue(data),
        });

    Our test double will only gets more complex as our code begins to use other parts of the `fetch` API (e.g. checking `headers` or looking the `status` of the response).

Instead we're going to use [Mock Service Worker][msw] (MSW) to test that the appropriate _request_ gets made, irrespective of how that's done. This allows us to test the _behaviour_ (we make a GET request to the random user API) rather than _implementation_ (we call `fetch` with the correct URL). Let's add MSW to our app, following along with [their instructions][msw get started], and write an integration test. Start by installing the package:

```bash
$ npm i msw

added 66 packages, and audited 1680 packages in 8s

258 packages are looking for funding
  run `npm fund` for details

74 vulnerabilities (69 moderate, 5 high)

To address issues that do not require attention, run:
  npm audit fix

To address all issues (including breaking changes), run:
  npm audit fix --force

Run `npm audit` for details.
```

As this is a relatively simple configuration, rather than splitting it across multiple files, put the following in `src/setupTests.js` (beneath the existing `@testing-library` import) to reuse the fixture from our Cypress tests with MSW:

```javascript
import { rest } from "msw";
import { setupServer } from "msw/node";

import fixture from "../cypress/fixtures/example.json";

const server = setupServer(
  rest.get("https://api.randomuser.me", (req, res, ctx) => {
    return res(ctx.status(200), ctx.json(fixture));
  }),
);

beforeAll(() => server.listen());

afterEach(() => server.resetHandlers());

afterAll(() => server.close());
```

Our fixture data will be used to respond to a GET request to the API in all of our Jest tests, and everything will be reset between the tests. In the test itself we need to check that the data is appropriately displayed, replacing the content of `src/App.test.js` with the following:

```jsx
import { render, screen } from "@testing-library/react";

import App from "./App";

describe("App", () => {
  it("displays the opponent", async () => {
    render(<App />);

    await screen.findByTestId("opponent");

    expect(screen.getByTestId("opponent-name")).toHaveTextContent("Randy Wheeler");
    expect(screen.getByTestId("opponent-avatar"))
      .toHaveAttribute("src", "https://randomuser.me/api/portraits/thumb/men/12.jpg");
  });
});
```

**Note** we're using two different query methods here, first awaiting the asynchronous `findByTestId` because it will allow the testing library to wait (up to 1,000ms, by default) for the element to appear, then using the synchronous `getByTestId` once we know the elements are rendered. Making a request takes _time_, and we don't want our whole web app to stop working while we wait for it, so we do it _asynchronously_ in the background. That makes testing trickier, we need to _wait_ for the output we want to be available (Cypress is also doing this, but it does it in the background for you).

Call the shot, and run the tests:

```bash
$ CI=true npm test

> rps-api@0.1.0 test
> react-scripts test

FAIL src/App.test.js
  App
    ✕ displays the opponent (1036 ms)

  ● App › displays the opponent

    Unable to find an element by: [data-testid="opponent"]

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

       7 |     render(<App />);
       8 |
    >  9 |     await screen.findByTestId("opponent");
         |                  ^
      10 |
      11 |     expect(screen.getByTestId("opponent-name")).toHaveTextContent("Randy Wheeler");
      12 |     expect(screen.getByTestId("opponent-avatar"))

      at waitForWrapper (node_modules/@testing-library/dom/dist/wait-for.js:173:27)
      at findByTestId (node_modules/@testing-library/dom/dist/query-helpers.js:101:33)
      at Object.<anonymous> (src/App.test.js:9:18)

Test Suites: 1 failed, 1 total
Tests:       1 failed, 1 total
Snapshots:   0 total
Time:        6.134 s
Ran all test suites.
```

As you hopefully predicted, the test failed (after just over one second) because the required element never appeared in the default CRA page content. Make a commit to save your work so far:

```bash
$ git add .
$ git status
On branch main
Changes to be committed:
  (use "git restore --staged <file>..." to unstage)
        modified:   package-lock.json
        modified:   package.json
        modified:   src/App.test.js
        modified:   src/setupTests.js

$ git commit -m 'Failing integration test for opponent'
[main a46387e] Failing integration test for opponent
 4 files changed, 1252 insertions(+), 41 deletions(-)
```

## Opposing forces [4/8]

From the diagram above you can see that `App` will use two things to do this: a component and a service.  We can do those in either order, so let's start by writing a unit test for the presentation component that will show the opponent; put the following into `src/Opponent.test.js`:

```jsx
Opp
```

Call the shot and run the test (note that you'll have _two_ failing tests in Jest, you can use e.g. `npm test Opponent` to run only the one above). Initially it will fail because Jest `Cannot find module './Opponent' from 'src/Opponent.test.js'` - that should make sense, we haven't created that file yet. Go through the process of making small changes and re-running the test until it passes, with the _simplest possible implementation_. Remember to call the shot before each test run, and aim to change the error you get step by step rather than just jumping to the passing test. Once that component works, make a commit to save your work:

```bash
$ git add .

$ git status
On branch main
Changes to be committed:
  (use "git restore --staged <file>..." to unstage)
        new file:   src/Opponent.js
        new file:   src/Opponent.test.js


$ git commit -m 'Implement Opponent component'
[main 46a5dfa] Implement Opponent component
 2 files changed, 30 insertions(+)
 create mode 100644 src/Opponent.js
 create mode 100644 src/Opponent.test.js
```

Now we need a service. We _could_ write another integration-style test, using the fixture data from MSW, for example. That seems a bit repetitive, as we're already using MSW at the integration level, so this is a good opportunity to introduce another testing technique for these unit tests. As mentioned above we don't want to mock an interface we don't own, but we could introduce a new interface that we _do_ own and mock that. This is often referred to as a _"facade"_ because (like [these false buildings] hiding part of the London Underground) it's a thin layer that's easy to fake. For example, you could create this simple function in `src/api.js`:

```javascript
export const fetchJson = (url) => fetch(url).then((res) => res.json());
```

We can then mock out this facade (an interface we own) and test the service against it by creating the following tests in `src/randomUserService.test.js`:

```javascript
import { fetchJson } from "./api";
import { getRandomUser } from "./randomUserService";

jest.mock("./api");

describe("random user service", () => {
  it("requests data from the random user API", async () => {
    fetchJson.mockResolvedValue({ results: [] });
    
    await getRandomUser();

    expect(fetchJson).toHaveBeenCalledWith("https://api.randomuser.me");
  });
  
  it("extracts the user data from the response body", async () => {
    const user = { name: { first: "Jane", last: "Doe" } };
    fetchJson.mockResolvedValue({ results: [user] });
    
    const actual = await getRandomUser();

    return expect(actual).toEqual(user);
  });
});
```

You might wonder how we make sure that facade works without mocking `fetch`. The answer is that _we don't need to_ - facades are deliberately very simple, and the code in them is tested at higher levels (in this case by our MSW integration tests and Cypress E2E tests). Run the test (again you can use `npm test randomUser` to focus down to this case) and drive out a implementation. Once it's working, make a commit:

```bash
$ git add .

$ git status
On branch main
Changes to be committed:
  (use "git restore --staged <file>..." to unstage)
        new file:   src/api.js
        new file:   src/randomUserService.js
        new file:   src/randomUserService.test.js


$ git commit -m 'Implement random user service'
[main 52d9f2e] Implement random user service
 3 files changed, 27 insertions(+)
 create mode 100644 src/api.js
 create mode 100644 src/randomUserService.js
 create mode 100644 src/randomUserService.test.js
```

At this point you should have three passing unit tests and one failing integration test. Fix the implementation in the coordinating `App` component to call `getRandomUser` when the component loads and render an `Opponent` presentation component once the data is available. Once all of the tests are passing, return to the E2E tests. We had three Cypress test cases, so call all of the shots then run them:

```bash
$ npm run e2e

> rps-api@0.1.0 e2e
> cypress run


====================================================================================

  (Run Starting)

  ┌────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Cypress:        12.16.0                                                                        │
  │ Browser:        Electron 106 (headless)                                                        │
  │ Node Version:   v16.20.0 (path/to/node)                                                        │
  │ Specs:          1 found (journey.cy.js)                                                        │
  │ Searched:       cypress/e2e/**/*.cy.{js,jsx,ts,tsx}                                            │
  └────────────────────────────────────────────────────────────────────────────────────────────────┘


────────────────────────────────────────────────────────────────────────────────────────────────────
                                                                                                    
  Running:  journey.cy.js                                                                   (1 of 1)


  ✓ displays an opponent from the API (432ms)
  ✓ displays an opponent from a fixture (76ms)
  1) displays the appropriate winner

  2 passing (5s)
  1 failing

  1) displays the appropriate winner:
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
        data-testid="opponent"
      >
        <span
          data-testid="opponent-name"
        >
          Liselotte
           
          Welte
        </span>
        <img
          alt=""
          data-testid="opponent-avatar"
          src="https://randomuser.me/api/portraits/thumb/women/46.jpg"
        />
      </div>
    </div>
    
    
    
  


  </body>
</html>...
      at Context.eval (webpack:///./cypress/e2e/journey.cy.js:25:5)




  (Results)

  ┌────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Tests:        3                                                                                │
  │ Passing:      2                                                                                │
  │ Failing:      1                                                                                │
  │ Pending:      0                                                                                │
  │ Skipped:      0                                                                                │
  │ Screenshots:  1                                                                                │
  │ Video:        false                                                                            │
  │ Duration:     4 seconds                                                                        │
  │ Spec Ran:     journey.cy.js                                                                    │
  └────────────────────────────────────────────────────────────────────────────────────────────────┘


  (Screenshots)

  -  path/to/rps-api/cypress/screenshots/journey.cy.js/displays the appropriate winne     (1280x720)
     r (failed).png                                                


====================================================================================

  (Run Finished)


       Spec                                              Tests  Passing  Failing  Pending  Skipped  
  ┌────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ ✖  journey.cy.js                            00:04        3        2        1        -        - │
  └────────────────────────────────────────────────────────────────────────────────────────────────┘
    ✖  1 of 1 failed (100%)                     00:04        3        2        1        -        -  


```

Hopefully both of the opponent display test cases (_"displays a random opponent from the API"_ and _"displays an opponent from a fixture"_) are passing, so even though the third (_"displays the appropriate winner"_) is failing, let's make a commit:

```bash
$ git add .

$ git status
On branch main
Changes to be committed:
  (use "git restore --staged <file>..." to unstage)
        modified:   src/App.js


$ git commit -m 'Implement computer opponent display'
[main 037e7ab] Implement computer opponent display
 1 file changed, 20 insertions(+), 25 deletions(-)
 rewrite src/App.js (90%)
```

## On form [5/8]

Let's bring in the actual game playing. From the `App` component's perspective, we can write an integration test very similar to the one we have at the E2E level; add the following to `App.test.js` (you'll also need to `import userEvent from "@testing-library/user-event";`):

```jsx
  it("lets you play the random opponent", async () => {
    const playerWeapon = "scissors";
    const outcomes = {
      "rock": "Right wins!",
      "paper": "Left wins!",
      "scissors": "Draw",
    };
    const user = userEvent.setup();
    render(<App />);
  
    await user.selectOptions(screen.getByLabelText("Left"), playerWeapon);
    await user.click(screen.getByText("Throw"));
    await screen.findByTestId("opponent-weapon");
  
    const opponentWeapon = screen.getByTestId("opponent-weapon").textContent
    expect(screen.getByTestId("outcome")).toHaveTextContent(outcomes[opponentWeapon]);
  });
```

I've deliberately chosen a different weapon and set of outcomes to the E2E test - if we have the same test case over and over again at different levels we might miss some of the cases or hard-code something accidentally. We'll use this test to guide the next few steps, slowly moving the point of failure further through the test, until it's passing. Call the shot and run the test; hopefully it's failing for a sensible reason. If so, commit it:

```bash
$ git add .

$ git status
On branch main
Changes to be committed:
  (use "git restore --staged <file>..." to unstage)
        modified:   src/App.test.js


$ git commit -m 'Failing integration test for playing opponent'
[main 960d7c6] Failing integration test for playing opponent
 1 file changed, 18 insertions(+)
```

Our form is a bit simpler than last time, as we only have one input. Add the following to `src/Form.test.js` and use it to drive out the implementation.

```javascript
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";

import Form from "./Form";

describe("Form component", () => {
  it("emits the user's input", async () => {
    const onSubmit = jest.fn();
    const user = userEvent.setup();
    const weapon = "paper";
    render(<Form onSubmit={onSubmit} />);

    await user.selectOptions(screen.getByLabelText("Left"), weapon);
    await user.click(screen.getByText("Throw"));

    expect(onSubmit).toHaveBeenCalledWith(weapon);
  });
});
```

Once it's passing, run the `App` integration tests too - you should be able to change the current failure for that test by adding in the `Form` component (note you'll probably want to set `onSubmit={() => {}}` in `App` to prevent `TypeError: onSubmit is not a function`). Call the shot, run the test. Once the failure's coming later in the test, make a commit:

```bash
$ git add .

$ git status
On branch main
Changes to be committed:
  (use "git restore --staged <file>..." to unstage)
        modified:   src/App.js
        new file:   src/Form.js
        new file:   src/Form.test.js


$ git commit -m 'Implement Form component'
[main bb3f4d6] Implement Form component
 3 files changed, 40 insertions(+)
 create mode 100644 src/Form.js
 create mode 100644 src/Form.test.js
```

## A roll of the dice [6/8]

Now we can implement the RPS service. We already have most of it from previous implementations, so copy the existing `rpsService.js` and `rpsService.test.js` into `src/` and commit it:

```bash
$ cp path/to/rps-e2e/src/rpsService*.js ./src

$ git add .

$ git status
On branch main
Changes to be committed:
  (use "git restore --staged <file>..." to unstage)
        new file:   src/rpsService.js
        new file:   src/rpsService.test.js


$ git commit -m 'Implement RPS service'
[main 498c60f] Implement RPS service
 2 files changed, 75 insertions(+)
 create mode 100644 src/rpsService.js
 create mode 100644 src/rpsService.test.js
```

Now we're going to add some new functionality, a function that gives us a random weapon. So we can think about how to test it, here's a basic implementation of a coin flip:

```javascript
const flipCoin = () => Math.random() < 0.5 ? "heads" : "tails";
```

We can be pretty confident that if we call this function a large number of times we'll get roughly half of each outcome:

```javascript
> Array(10).fill(null).map(() => flipCoin());
[ "tails", "heads", "heads", "tails", "tails", "tails", "heads", "heads", "tails", "tails" ]
```

but for a given call we can't be sure which it will be. So how can we write a test for that? We could reach for the facade pattern again, extract `const random = () => Math.random()` and replace that with a test double. This would work fine, but be very tightly coupled to the implementation:

```javascript
describe("flipCoin", () => {
  it("returns 'heads' when the random number is less than 0.5", () => {
    random.mockReturnValue = 0.3;

    expect(flipCoin()).toEqual("heads");
  });
});
```

One alternative is to write tests based on the _properties_ of the implementation we want. For example, although we don't know the specific values, we do know:

- It should always give one of the expected outcomes; and
- It shouldn't always give the same outcome (otherwise `() => "heads"` would be a valid implementation).

We can express these properties through a pair of tests as follows:

```javascript
describe("flipCoin", () => {
  const expectedOutcomes = ["heads", "tails"];

  it("always gives one of the expected outcomes", () => {
    const outcomes = Array(100).fill(null).map(() => flipCoin());

    expect(outcomes.every((outcome) => expectedOutcomes.includes(outcome))).toBe(true);
  });

  it("doesn't always give the same outcome", () => {
    const outcomes = Array(100).fill(null).map(() => flipCoin());

    expect(expectedOutcomes.every((outcome) => outcomes.includes(outcome))).toBe(true);
  });
});
```

This is less coupled because it describes the **what**, the _behaviour_ we want from the function, not the **how**, the details of the implementation. That allows us to refactor with confidence if we think of a better way to do it later.

We could also try to test for the property that it's roughly 50:50 `"heads"` to `"tails"`, but then questions like _"what do you mean by 'roughly'?"_ come up. If you try to be too specific, the tests will often fail due to the randomness in the real data. Note that the second test above could already occasionally fail; it's not impossible to get 100 heads in a row, just extremely unlikely.

Write two tests for a `randomWeapon` function, to ensure it always returns one of the three expected weapons `"rock"`, `"paper"` or `"scissors"` but doesn't always return the same weapon, then write an implementation that passes those tests by returning a random weapon. Once that's working, make a commit:

```bash
$ git add .

$ git status
On branch main
Changes to be committed:
  (use "git restore --staged <file>..." to unstage)
        modified:   src/rpsService.js
        modified:   src/rpsService.test.js


$ git commit -m 'Implement random weapon function'
[main 2937240] Implement random weapon function
 2 files changed, 19 insertions(+), 1 deletion(-)
```

## A good outcome [7/8]

Now we need to display this random weapon for the opponent, but only once it's been selected, so add two new tests to `Opponent.test.js` as follows:

```javascript
it("doesn't show the opponent's weapon initially", () => {
  render(<Opponent opponent={{ name: {}, picture: {} }} />);

  expect(screen.queryByTestId("opponent-weapon")).not.toBeInTheDocument();
});

it("shows the opponent's weapon once selected", () => {
  const weapon = "scissors";

  render(<Opponent weapon={weapon} opponent={{ name: {}, picture: {} }} />);

  expect(screen.getByTestId("opponent-weapon")).toHaveTextContent(weapon);
});
```

Once these tests are passing, update the `App` component to move the failure of its integration test along again.

```bash
$ git add .

$ git status
On branch main
Changes to be committed:
  (use "git restore --staged <file>..." to unstage)
        modified:   src/App.js
        modified:   src/Opponent.js
        modified:   src/Opponent.test.js


$ git commit -m 'Add weapon to the Opponent component'
[main e037a5f] Add weapon to the Opponent component
 3 files changed, 24 insertions(+), 3 deletions(-)
```

The `Outcome` component is exactly the same as last time, so let's copy that in too:

```bash
$ cp path/to/rps-e2e/src/Outcome*.js ./src
```

This is already tested and working, so wire it into the `App` component to complete the implementation. Check that it's working correctly by running all of the Jest unit/integration tests then the Cypress E2E tests. Congratulations, you're done, make a final commit!

```bash
$ git add .

$ git status
On branch main
Changes to be committed:
  (use "git restore --staged <file>..." to unstage)
        modified:   src/App.js
        new file:   src/Outcome.js
        new file:   src/Outcome.test.js


$ git commit -m 'Show the outcome'
[main 71f7eab] Show the outcome
 3 files changed, 39 insertions(+), 3 deletions(-)
 create mode 100644 src/Outcome.js
 create mode 100644 src/Outcome.test.js
```

Now reflect on the exercise - how does the implementation compare to what you'd initially imagined? What felt good or bad about the process?

You can see my copy of this exercise at [https://github.com/textbook/rps-api][github].

## Exercises [8/8]

Here are some additional exercises you can run through:

1. What should happen if a request to the random user API fails? How can you test for that, and at what levels (using Cypress E2E, MSW integration and/or unit tests)? Note that the `fetch` facade should hide the details of the transport layer:

        :::javascript
        const fetchJson = (url) => fetch(url).then((res) => {
          if (res.status === 200) {
            return res.json();
          }
          /* Throw error? Return default values? */
        });


1. Refactor one or more of the components from function-based to class-based, or vice versa. You shouldn't need to change any of the tests!

1. Try to repeat the whole exercise _without_ integration or end-to-end tests, just driving out the code with unit tests and putting them together yourself. Does that feel better or worse? Do you make any mistakes higher-level tests would have caught?

1. Perhaps the `Opponent` component should make the request for the user data itself (e.g. a `fetch` in a `useEffect` hook)? Refactor accordingly - what new tests are needed, which existing tests need to be changed, and which ones get removed entirely?

1. What should happen when the player changes their input but haven't yet clicked the "Throw" button? Currently the opponent's last throw is still shown, along with an outcome that no longer applies. Test drive out better behaviour.

1. Refactor the components (`Form`, `Opponent`, `Outcome`- don't include `App`) into a new directory `src/components/` and the services (`randomUserService` plus `api`, `rpsService`) into another directory `src/services/`. Did the tests make this easier? Harder?

1. Find another free API (see e.g. [https://apilist.fun/][api list]) and test-drive some kind of UI for it. Include tests that use the real API as well as those that provide test doubles at various levels.

1. If you've implemented additional weapons (e.g. Rock Paper Scissors Lizard Spock) in the previous implementations, extend the UI to support them. If not, maybe now's the time!

I'd recommend creating a new git branch for each one you try (e.g. use `git checkout -b <name>`) and making commits as appropriate.

> **Once you're ready to move on**, check out [the next article] in this series where we'll cover testing the API producer and discuss more about how tests drive design.

## Automatic E2E [bonus]

As I mentioned in my [article on automation], I'm a fan of making developers' lives easier through automating the things you do frequently. You may have found it a bit annoying that you had to manually juggle two terminal windows through the last two articles, one where the app's running (`npm start`) and another where you run the E2E tests (`npm run e2e`). So let's simplify that!

First, install some useful helper dependencies:

```bash
$ npm install concurrently cross-env wait-on
```

Then add some extra scripts to the `package.json`:

```json
"e2e:ci": "concurrently --kill-others --success first \"npm:e2e:ci:*\"",
"e2e:ci:app": "cross-env BROWSER=none PORT=4321 npm start",
"pree2e:ci:run": "wait-on --log --timeout 30000 http-get://localhost:4321",
"e2e:ci:run": "cross-env CYPRESS_BASE_URL=http://localhost:4321 npm run e2e",
```

So what does that do? When we run `npm run e2e:ci`, the `concurrently` script is going to run two things in parallel for us:

- `e2e:ci:app`: Run the app using `npm start`, with some environment variables set via `cross-env` (this allows it to work on *nix and Windows):
    - `BROWSER=none` stops the browser from popping up and taking over the screen; and
    - `PORT=4321` runs the app on the specified port (so we can still have a version running on port 3000 without causing any conflicts).
- `e2e:ci:run`: Run the E2E tests in a two-step process:
    - The `pre` script runs first, and uses `wait-on` to wait for up to 30,000ms for the app to be running on the specified port; then
    - If that works (i.e. the app starts in less than 30s) run the actual tests, with the `baseUrl` configuration overridden to point to the right place.

The other configuration options passed to `concurrently` itself are:

- `--kill-others`, meaning stop all of the other processes when one exits (in this case we expect our tests to exit at some point and want to stop the app when they do); and
- `--success first`, meaning that the output of the overall command is the output of the first one to exit (i.e. output from the `e2e:ci` command should be the output from the tests).

The overall result will look like the following (`concurrently` prefixes the logs from the different processes so you can see what's coming from where):

```bash
$ npm run e2e:ci

> rps-api@0.1.0 e2e:ci
> concurrently --kill-others --success first "npm:e2e:ci:*"

[app] 
[app] > rps-api@0.1.0 e2e:ci:app
[app] > cross-env BROWSER=none PORT=4321 npm start
[app] 
[run] 
[run] > rps-api@0.1.0 pree2e:ci:run
[run] > wait-on --log --timeout 30000 http-get://localhost:4321
[run] 
[run] waiting for 1 resources: http-get://localhost:4321
[app] 
[app] > rps-api@0.1.0 start
[app] > react-scripts start
[app] 
[app] (node:74442) [DEP_WEBPACK_DEV_SERVER_ON_AFTER_SETUP_MIDDLEWARE] DeprecationWarning: 'onAfterSetupMiddleware' option is deprecated. Please use the 'setupMiddlewares' option.
[app] (Use `node --trace-deprecation ...` to show where the warning was created)
[app] (node:74442) [DEP_WEBPACK_DEV_SERVER_ON_BEFORE_SETUP_MIDDLEWARE] DeprecationWarning: 'onBeforeSetupMiddleware' option is deprecated. Please use the 'setupMiddlewares' option.
[app] Starting the development server...
[app] 
[app] Compiled successfully!
[app] 
[app] You can now view rps-api in the browser.
[app] 
[app]   Local:            http://localhost:4321
[app]   On Your Network:  http://192.168.1.235:4321
[app] 
[app] Note that the development build is not optimized.
[app] To create a production build, use npm run build.
[app] 
[app] webpack compiled successfully
[run] wait-on(74439) complete
[run] 
[run] > rps-api@0.1.0 e2e:ci:run
[run] > cross-env CYPRESS_BASE_URL=http://localhost:4321 npm run e2e
[run] 
[run] 
[run] > rps-api@0.1.0 e2e
[run] > cypress run
[run] 
[run] 
[run] DevTools listening on ws://127.0.0.1:56736/devtools/browser/d1f8b0f9-39f5-4af0-b8f4-a7dc10ba3b68
[run] Couldn't find tsconfig.json. tsconfig-paths will be skipped
[run] 
[run] ====================================================================================
[run] 
[run]   (Run Starting)
[run] 
[run]   ┌────────────────────────────────────────────────────────────────────────────────────────────────┐
[run]   │ Cypress:        12.16.0                                                                        │
[run]   │ Browser:        Electron 106 (headless)                                                        │
[run]   │ Node Version:   v16.20.0 (path/to/node)                                                        │
[run]   │ Specs:          1 found (journey.cy.js)                                                        │
[run]   │ Searched:       cypress/e2e/**/*.cy.{js,jsx,ts,tsx}                                            │
[run]   └────────────────────────────────────────────────────────────────────────────────────────────────┘
[run] 
[run] 
[run] ────────────────────────────────────────────────────────────────────────────────────────────────────
[run]                                                                                                     
[run]   Running:  journey.cy.js                                                                   (1 of 1)
[run] 
[run] 
[run]   ✓ displays an opponent from the API (413ms)
[run]   ✓ displays an opponent from a fixture (81ms)
[run]   ✓ displays the appropriate winner (277ms)
[run] 
[run]   3 passing (793ms)
[run] 
[run] 
[run]   (Results)
[run] 
[run]   ┌────────────────────────────────────────────────────────────────────────────────────────────────┐
[run]   │ Tests:        3                                                                                │
[run]   │ Passing:      3                                                                                │
[run]   │ Failing:      0                                                                                │
[run]   │ Pending:      0                                                                                │
[run]   │ Skipped:      0                                                                                │
[run]   │ Screenshots:  0                                                                                │
[run]   │ Video:        false                                                                            │
[run]   │ Duration:     0 seconds                                                                        │
[run]   │ Spec Ran:     journey.cy.js                                                                    │
[run]   └────────────────────────────────────────────────────────────────────────────────────────────────┘
[run] 
[run] 
[run] ====================================================================================
[run] 
[run]   (Run Finished)
[run] 
[run] 
[run]        Spec                                              Tests  Passing  Failing  Pending  Skipped  
[run]   ┌────────────────────────────────────────────────────────────────────────────────────────────────┐
[run]   │ ✔  journey.cy.js                            790ms        3        3        -        -        - │
[run]   └────────────────────────────────────────────────────────────────────────────────────────────────┘
[run]     ✔  All specs passed!                        790ms        3        3        -        -        -  
[run] 
[run] npm run e2e:ci:run exited with code 0
--> Sending SIGTERM to other processes..
[app] npm run e2e:ci:app exited with code 1
```

You can go even further and run the end-to-end tests against the build output, rather than the development server, which lets you check that the app compiles correctly. Run `npm install serve` to add a simple web server package, then replace the `"e2e:ci:app"` script with:

```json
    "pree2e:ci:app": "npm run build",
    "e2e:ci:app": "serve -l 4321 build/",
```

As above the `pre` script runs first, to build the app, then if that's successful the main script starts to serve on the appropriate port (`-l 4321`) from the output directory (`build/`).

  [api list]: https://apilist.fun/
  [article on automation]: {filename}/development/automation-for-the-people.md
  [axios]: https://www.npmjs.com/package/axios
  [cra]: https://create-react-app.dev/docs/getting-started
  [Cypress]: https://cypress.io
  [cypress blog]: https://www.cypress.io/blog/2020/11/24/introducing-cy-intercept-next-generation-network-stubbing-in-cypress-6-0/
  [cypress closures]: https://docs.cypress.io/guides/core-concepts/variables-and-aliases.html#Closures
  [dropped support]: https://jestjs.io/docs/upgrading-to-jest29#compatibility
  [Git BASH]: https://gitforwindows.org/
  [github]: https://github.com/textbook/rps-api
  [Jest]: https://jestjs.io/
  [msw]: https://mswjs.io/
  [msw get started]: https://mswjs.io/docs/getting-started
  [names]: https://www.kalzumeus.com/2010/06/17/falsehoods-programmers-believe-about-names/
  [Node]: https://nodejs.org/
  [Part 1]: {filename}/development/js-tdd-ftw.md
  [Part 2]: {filename}/development/js-tdd-e2e.md
  [Regex 101]: https://regex101.com/
  [SPA config]: {filename}/development/spa-config.md
  [Testing Library]: https://testing-library.com
  [the next article]: {filename}/development/js-tdd-ohm.md
  [these false buildings]: https://en.wikipedia.org/wiki/Leinster_Gardens#False_houses
  [this Gist]: https://gist.github.com/textbook/3377dda14efe4449772c2377188c3fa8
  [this Stack Overflow answer]: https://stackoverflow.com/a/65627662/3001761
  [WSL]: https://docs.microsoft.com/en-us/windows/wsl/about
