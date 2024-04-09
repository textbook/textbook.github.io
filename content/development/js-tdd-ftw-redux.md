Title: JS TDD FTW (redux)
Date: 2024-04-09 23:40
Tags: javascript, tdd, xp
Authors: Jonathan Sharpe
Summary: Test-driven JavaScript development done right - part 1, again

> **Note**: this was originally published as [JS TDD FTW], using Jest, but has been rewritten to use the Node.js test runner. The principles and process are exactly the same.

One of the key Extreme Programming ([XP]) engineering practices is test-driven development (TDD), usually expressed as repeatedly following this simple, three-step process:

 1. **Red** - write a failing test that describes the behaviour you want;
 2. **Green** - write the simplest possible code to make the test pass; and
 3. **Refactor** - clean up your code without breaking the tests.

I was recently asked if I knew of a good TDD intro for people who were comfortable with JavaScript but hadn't done much testing, so I did some research.
There are lots of examples of testing and TDD out there, but often: tied to specific frameworks (e.g. React); with unclear prerequisites; and even showing poor testing practices.
So below I'm going to give a proper example of vanilla JavaScript TDD done _"the right way"_, sprinkling some bonus command line and git practice throughout.

### Requirements

I've aimed this content at more junior developers, so there are more explanations than all readers will need, but anyone new to testing and TDD should find something to take from it.
We'll need:

- *nix command line: already provided on macOS and Linux; if you're using Windows try [WSL] or [Git BASH];
- [Node] \(minimum v16.17; run `node -v` to check) and npm; and
- Familiarity with ES6 JavaScript syntax (specifically arrow functions).

We also need something to implement.
[Rock Paper Scissors] \(or just RPS) is a simple playground game that takes some inputs (the shapes that the players present) and gives a single output (the outcome), which makes it a good fit for a simple function to test drive.
If you're not familiar with the rules, read the linked Wikipedia article before continuing.

Before we get into the TDD process, think about what the code for an implementation of RPS might look like.
Don't write any code yet (we don't have the failing tests to make us do that!) but imagine a function - what parameters would it accept?
What would it return?
We're expecting different outputs for different inputs, which implies some conditional logic - what conditions do you think would be involved?
Note your ideas down, we'll revisit them later.

As we go through, please carefully _read everything_.
I'd recommend _typing the code_ rather than copy-pasting, especially if you're a new developer; it's good practice to build your muscle memory.

## Setup [1/10]

Let's get up and running.
Starting in your working directory (e.g. I use `~/workspace`), run the following:

```bash
$ mkdir rps-tdd && cd $_ && git init && git commit --allow-empty -m 'Initial commit'
Initialized empty Git repository in path/to/rps-tdd/.git/
[main (root-commit) <hash>] Initial commit
```

By chaining multiple commands using `&&` (_"and"_, assuming the previous commands all succeeded), this will:

- Create a new directory named `rps-tdd/`;
- Switch into it (`$_` references the argument to the last command, see e.g. [this SO question](https://stackoverflow.com/q/30154694/3001761));
- Initialise a new git repository; and
- Create an empty initial commit (`--allow-empty` lets us create this first commit without having any content, and `-m` lets us supply the commit message on the command line).

Now we need a basic npm package:

```bash
$ npm init -y && git add package.json && git commit -m 'Create NPM package'
Wrote to path/to/rps-tdd/package.json:

{
  "name": "rps-tdd",
  "version": "1.0.0",
  "description": "",
  "main": "index.js",
  "scripts": {
    "test": "echo \"Error: no test specified\" && exit 1"
  },
  "keywords": [],
  "author": "",
  "license": "ISC"
}


[main <hash>] Create NPM package
 1 file changed, 12 insertions(+)
 create mode 100644 package.json
```

This:

- Creates a basic `package.json`;
- Adds that to our repo; and
- Makes another commit.

By default, NPM creates a test script that will throw an error, as we saw above:

```json
"test": "echo \"Error: no test specified\" && exit 1"
```

If you run this using `npm test` (alternatively `npm run test` or even just `npm t`) you see the result:

```bash
$ npm test

> rps-tdd@1.0.0 test path/to/rps-tdd
> echo "Error: no test specified" && exit 1

Error: no test specified
npm ERR! Test failed.  See above for more details.
```

## Running tests [2/10]

Next, we're going to need something to run our tests.
There are loads of options here (I've used [Jasmine], [Jest], [Mocha], [tape], ...) but we're going to start with one that's built right into your runtime: [Node test runner][node-test].
We can update `package.json` to set this to be our test command.

Edit `package.json` to update the script to `"test": "node --test"`, using either:

- an editor or IDE of your choice; or
- `npm pkg set scripts.test='node --test'`

to use the test runner. Then run the tests again:

```bash
$ npm test

> rps-tdd@0.1.0 test
> node --test

ℹ tests 0
ℹ suites 0
ℹ pass 0
ℹ fail 0
ℹ cancelled 0
ℹ skipped 0
ℹ todo 0
ℹ duration_ms 3.717458
```

This seems happy, but reading the output we can see there are no tests so far.
Let's start with something completely trivial to make sure everything is working; add the following to a file named `index.test.js`:

```javascript
const assert = require("node:assert/strict");
const { it } = require("node:test");

it("should work", () => {
  const left = 1;
  const right = 2;
  
  const result = left + right;
  
  assert.equal(result, 3);
});
``` 

Now run the tests a third time:

```bash
$ npm test

> rps-tdd@0.1.0 test
> node --test

✔ should work (0.672875ms)
ℹ tests 1
ℹ suites 0
ℹ pass 1
ℹ fail 0
ℹ cancelled 0
ℹ skipped 0
ℹ todo 0
ℹ duration_ms 43.945125
```

We have one passing test!
So what does that test _do_, what's going on there?

 1. We call the `it` function (imported from the test runner) to **register a test**. We pass it two things:
     - The name of the test, as a string (you can see this name in the output, too). In this style of testing we use the function name along with the test as one sentence describing our expectation: _"it should work"_.
     - The body of the test, as a function. Right now we're just _registering_ the test, the runner will call that function for us when it runs the test.
 2. Within the test body, we **establish our expectations**. What exactly do we think should happen? I've split this into three sections:
     - **Arrange** (sometimes known as _"given"_) - set up the preconditions for our test, in this case two initial values.
     - **Act** (or _"when"_) - do some work, in this case adding them together. This is what we're actually testing.
     - **Assert** (or _"then"_) - make sure that the work was done correctly. The `assert` object is also imported from Node, from the [`assert` module][node-assert]; it provides a method to compare the value we receive (often referred to as _"actual"_) with what we think it should be (_"expected"_).

If we had an inaccurate expectation:

```js
const assert = require("node:assert/strict");
const { it } = require("node:test");

it("should work", () => {
  const left = 2;
  const right = 2;

  const result = left + right;

  assert.equal(result, 5);
});
```

it would tell us exactly what the problem was:

```bash
$ npm t

> rps-tdd@0.1.0 test
> node --test

✖ should work (1.557708ms)
  AssertionError [ERR_ASSERTION]: Expected values to be strictly equal:
  
  3 !== 5
  
      at TestContext.<anonymous> (path/to/rps-tdd/index.test.js:10:10)
      at Test.runInAsyncScope (node:async_hooks:203:9)
      at Test.run (node:internal/test_runner/test:631:25)
      at Test.start (node:internal/test_runner/test:542:17)
      at startSubtest (node:internal/test_runner/harness:214:17) {
    generatedMessage: true,
    code: 'ERR_ASSERTION',
    actual: 3,
    expected: 5,
    operator: 'strictEqual'
  }

ℹ tests 1
ℹ suites 0
ℹ pass 0
ℹ fail 1
ℹ cancelled 0
ℹ skipped 0
ℹ todo 0
ℹ duration_ms 44.8275

✖ failing tests:

test at index.test.js:4:1
✖ should work (1.557708ms)
  AssertionError [ERR_ASSERTION]: Expected values to be strictly equal:
  
  3 !== 5
  
      at TestContext.<anonymous> (path/to/rps-tdd/index.test.js:10:10)
      at Test.runInAsyncScope (node:async_hooks:203:9)
      at Test.run (node:internal/test_runner/test:631:25)
      at Test.start (node:internal/test_runner/test:542:17)
      at startSubtest (node:internal/test_runner/harness:214:17) {
    generatedMessage: true,
    code: 'ERR_ASSERTION',
    actual: 3,
    expected: 5,
    operator: 'strictEqual'
  }
```

> **Protip**: always read the outputs carefully! Sometimes a test fails for an unexpected reason, which usually tells you something interesting.

So, we're happy things are working so far.

## A failing test [3/10]

Let's start some actual TDD, and write our first failing test. Replace the content of `index.test.js` with:

```js
const assert = require("node:assert/strict");
const { describe, it } = require("node:test");

describe("rock, paper, scissors", () => {
  it("should say left wins for rock vs. scissors", () => {
    const left = "rock";
    const right = "scissors";

    const outcome = rps(left, right);

    assert.equal(outcome, "left");
  });
});
```

Note I've introduced another function from the test runner, `describe`.
This registers a _group_ of tests, usually referred to as a _"suite"_.
Like `it` it takes a name and a function, then our individual tests are registered inside that function.

Our first test is that, given that `left` is `"rock"` and `right` is `"scissors"` (_"Arrange"_), when the shapes are compared (_"Act"_) , then the winner should be `"left"` (_"Assert"_) because rock blunts scissors.

**Note** one key benefit of TDD here - we can try out how we should interact with our code (its _"interface"_) before we've even written any.
Maybe it should return something other than a string, for example?
We can have that discussion now, while it's just a matter of changing our minds rather than the code.

Before we run the first test, [_"call the shot"_][call the shot] - make a prediction of what the test result will be, pass or fail.
If you think the test will fail, **why**; will the `expect`ation be unmet (and what value do you think you'll get instead) or will something else go wrong?
This is really good practice for _"playing computer"_ (modelling the behaviour of the code in your head) and you can write your guess down (or say it out loud if you're pairing) to keep yourself honest.
Now let's run it:

```
$  npm t

> rps-tdd@0.1.0 test
> node --test

▶ rock, paper, scissors
  ✖ should say left wins for rock vs. scissors (0.328041ms)
    ReferenceError [Error]: rps is not defined
        at TestContext.<anonymous> (path/to/rps-tdd/index.test.js:9:21)
        at Test.runInAsyncScope (node:async_hooks:203:9)
        at Test.run (node:internal/test_runner/test:631:25)
        at Test.start (node:internal/test_runner/test:542:17)
        at node:internal/test_runner/test:946:71
        at node:internal/per_context/primordials:487:82
        at new Promise (<anonymous>)
        at new SafePromise (node:internal/per_context/primordials:455:29)
        at node:internal/per_context/primordials:487:9
        at Array.map (<anonymous>)

▶ rock, paper, scissors (1.18ms)

ℹ tests 1
ℹ suites 1
ℹ pass 0
ℹ fail 1
ℹ cancelled 0
ℹ skipped 0
ℹ todo 0
ℹ duration_ms 45.090125

✖ failing tests:

test at index.test.js:5:3
✖ should say left wins for rock vs. scissors (0.328041ms)
  ReferenceError [Error]: rps is not defined
      at TestContext.<anonymous> (path/to/rps-tdd/index.test.js:9:21)
      at Test.runInAsyncScope (node:async_hooks:203:9)
      at Test.run (node:internal/test_runner/test:631:25)
      at Test.start (node:internal/test_runner/test:542:17)
      at node:internal/test_runner/test:946:71
      at node:internal/per_context/primordials:487:82
      at new Promise (<anonymous>)
      at new SafePromise (node:internal/per_context/primordials:455:29)
      at node:internal/per_context/primordials:487:9
      at Array.map (<anonymous>)
```

...were you right?

## The simplest possible change [4/10]

As you may have guessed, this fails because `rps` _doesn't exist yet_.
Let's make the simplest possible change that will at least change the error we're receiving; define the function.
At this stage we could `require` the function from another file, but let's keep things simple for now; add the following to the top of `index.test.js`:

```js
function rps() {}
```

Call the shot, then run the test again to see if you were right:

```bash
$  npm t

> rps-tdd@0.1.0 test
> node --test

▶ rock, paper, scissors
  ✖ should say left wins for rock vs. scissors (1.634458ms)
    AssertionError [ERR_ASSERTION]: Expected values to be strictly equal:
    + actual - expected
    
    + undefined
    - 'left'
        at TestContext.<anonymous> (path/to/rps-tdd/index.test.js:13:12)
        at Test.runInAsyncScope (node:async_hooks:203:9)
        at Test.run (node:internal/test_runner/test:631:25)
        at Test.start (node:internal/test_runner/test:542:17)
        at node:internal/test_runner/test:946:71
        at node:internal/per_context/primordials:487:82
        at new Promise (<anonymous>)
        at new SafePromise (node:internal/per_context/primordials:455:29)
        at node:internal/per_context/primordials:487:9
        at Array.map (<anonymous>) {
      generatedMessage: true,
      code: 'ERR_ASSERTION',
      actual: undefined,
      expected: 'left',
      operator: 'strictEqual'
    }

▶ rock, paper, scissors (2.574708ms)

ℹ tests 1
ℹ suites 1
ℹ pass 0
ℹ fail 1
ℹ cancelled 0
ℹ skipped 0
ℹ todo 0
ℹ duration_ms 47.723458

✖ failing tests:

test at index.test.js:7:3
✖ should say left wins for rock vs. scissors (1.634458ms)
  AssertionError [ERR_ASSERTION]: Expected values to be strictly equal:
  + actual - expected
  
  + undefined
  - 'left'
      at TestContext.<anonymous> (path/to/rps-tdd/index.test.js:13:12)
      at Test.runInAsyncScope (node:async_hooks:203:9)
      at Test.run (node:internal/test_runner/test:631:25)
      at Test.start (node:internal/test_runner/test:542:17)
      at node:internal/test_runner/test:946:71
      at node:internal/per_context/primordials:487:82
      at new Promise (<anonymous>)
      at new SafePromise (node:internal/per_context/primordials:455:29)
      at node:internal/per_context/primordials:487:9
      at Array.map (<anonymous>) {
    generatedMessage: true,
    code: 'ERR_ASSERTION',
    actual: undefined,
    expected: 'left',
    operator: 'strictEqual'
  }
```

Our test still doesn't pass, but at least we've changed the error message - we're now reaching the actual expectation, instead of crashing when we try to call the function.
So let's make the simplest possible change that should get this passing:

```js
function rps() {
  return "left";
}
```

Call the shot, then run the test again to see if you were right:

```
$ npm t

> rps-tdd@0.1.0 test
> node --test

▶ rock, paper, scissors
  ✔ should say left wins for rock vs. scissors (0.195792ms)
▶ rock, paper, scissors (1.037958ms)

ℹ tests 1
ℹ suites 1
ℹ pass 1
ℹ fail 0
ℹ cancelled 0
ℹ skipped 0
ℹ todo 0
ℹ duration_ms 42.535125
```

Great! This calls for a celebratory commit:

```bash
$ git add -AN && git commit -am 'First test - rock vs. scissors'
[main <hash>] First test - rock vs. scissors
 2 files changed, 22 insertions(+), 2 deletions(-)
 create mode 100644 index.test.js
```

**Note** another key benefit of TDD here - it tells you when you're done.
Once the tests are passing, the implementation meets the current requirements.

## The difficult second test [5/10]

_"But wait"_, you might be thinking, _"that's pointless, it doesn't **do** anything!"_ And to an extent, that's true; our function just returns a hard-coded string. But let's think about what else has happened:

- We've decided on an interface for our function, what it's going to receive and return;
- We've proved out a test setup that lets us make assertions on the behaviour of that function; and
- We've created the simplest possible implementation for the requirements we've expressed through tests so far, making our code very robust.

So let's build on that foundation; flip the shapes around to change the output so we can expect the test to fail.
Add the following into the `describe` callback in `index.test.js`:

```js
it("should say right wins for scissors vs. rock", () => {
  const left = "scissors";
  const right = "rock";
  
  const result = rps(left, right);
  
  assert.equal(result, "right");
});
```

Note that the _"Act"_ is the same, but the _"Arrange"_ and _"Assert"_ have changed. Call the shot, then run the test again to see if you were correct:

```bash
$  npm t                                                      

> rps-tdd@0.1.0 test
> node --test

▶ rock, paper, scissors
  ✔ should say left wins for rock vs. scissors (0.512792ms)
  ✖ should say right wins for scissors vs. rock (1.268042ms)
    AssertionError [ERR_ASSERTION]: Expected values to be strictly equal:
    + actual - expected
    
    + 'left'
    - 'right'
        at TestContext.<anonymous> (path/to/rps-tdd/index.test.js:24:12)
        at Test.runInAsyncScope (node:async_hooks:203:9)
        at Test.run (node:internal/test_runner/test:631:25)
        at Suite.processPendingSubtests (node:internal/test_runner/test:374:18)
        at Test.postRun (node:internal/test_runner/test:715:19)
        at Test.run (node:internal/test_runner/test:673:12)
        at async Promise.all (index 0)
        at async Suite.run (node:internal/test_runner/test:948:7)
        at async startSubtest (node:internal/test_runner/harness:214:3) {
      generatedMessage: true,
      code: 'ERR_ASSERTION',
      actual: 'left',
      expected: 'right',
      operator: 'strictEqual'
    }

▶ rock, paper, scissors (2.778583ms)

ℹ tests 2
ℹ suites 1
ℹ pass 1
ℹ fail 1
ℹ cancelled 0
ℹ skipped 0
ℹ todo 0
ℹ duration_ms 48.376417

✖ failing tests:

test at index.test.js:18:3
✖ should say right wins for scissors vs. rock (1.268042ms)
  AssertionError [ERR_ASSERTION]: Expected values to be strictly equal:
  + actual - expected
  
  + 'left'
  - 'right'
      at TestContext.<anonymous> (path/to/rps-tdd/index.test.js:24:12)
      at Test.runInAsyncScope (node:async_hooks:203:9)
      at Test.run (node:internal/test_runner/test:631:25)
      at Suite.processPendingSubtests (node:internal/test_runner/test:374:18)
      at Test.postRun (node:internal/test_runner/test:715:19)
      at Test.run (node:internal/test_runner/test:673:12)
      at async Promise.all (index 0)
      at async Suite.run (node:internal/test_runner/test:948:7)
      at async startSubtest (node:internal/test_runner/harness:214:3) {
    generatedMessage: true,
    code: 'ERR_ASSERTION',
    actual: 'left',
    expected: 'right',
    operator: 'strictEqual'
  }
```

Read that through carefully. What does it tell us?

 1. Our first test is still passing. That's good news, we haven't broken anything!
 2. Our second test fails, because it returns `"left"` but we want it to return `"right"`.

So, what's the simplest possible change that would get this test passing?
Think about it for a minute or two.

We're going to need some kind of _conditional logic_ here, because we return different results in different cases.
However, we're supposed to be keeping things simple, so we don't want to leap all the way to a full implementation.
How about this:

```js
function rps(left) {
  return left === "rock" ? "left" : "right";
}
```

Call the shot, then run the test again to see if you were right:

```bash
$ npm t

> rps-tdd@0.1.0 test
> node --test

▶ rock, paper, scissors
  ✔ should say left wins for rock vs. scissors (0.629167ms)
  ✔ should say right wins for scissors vs. rock (0.055334ms)
▶ rock, paper, scissors (1.677833ms)

ℹ tests 2
ℹ suites 1
ℹ pass 2
ℹ fail 0
ℹ cancelled 0
ℹ skipped 0
ℹ todo 0
ℹ duration_ms 46.227791
```

Alright, two down, let's commit what we've done so far:

```bash
$ git commit -am 'Second test - scissors vs. rock'
[main <hash>] Second test - scissors vs. rock
 1 file changed, 11 insertions(+), 2 deletions(-)
```

We haven't created any new files since the last commit, so we can use the `-a`/`--all` flag to `git commit` to include changes to all files, instead of needing to `git add` anything.

## Third time's the charm [6/10]

We've handled both of the cases involving rock and scissors, so let's try this one, scissors cut paper:

```js
it("should say left wins for scissors vs. paper", () => {
  const left = "scissors";
  const right = "paper";
  
  const result = rps(left, right);
  
  assert.equal(result, "left");
});
```

Call the shot, then run the test again to see if you were right:

```bash
$ npm t         

> rps-tdd@0.1.0 test
> node --test

▶ rock, paper, scissors
  ✔ should say left wins for rock vs. scissors (0.456666ms)
  ✔ should say right wins for scissors vs. rock (0.043917ms)
  ✖ should say left wins for scissors vs. paper (0.82575ms)
    AssertionError [ERR_ASSERTION]: Expected values to be strictly equal:
    + actual - expected
    
    + 'right'
    - 'left'
        at TestContext.<anonymous> (path/to/rps-tdd/index.test.js:33:12)
        at Test.runInAsyncScope (node:async_hooks:203:9)
        at Test.run (node:internal/test_runner/test:631:25)
        at Suite.processPendingSubtests (node:internal/test_runner/test:374:18)
        at Test.postRun (node:internal/test_runner/test:715:19)
        at Test.run (node:internal/test_runner/test:673:12)
        at async Suite.processPendingSubtests (node:internal/test_runner/test:374:7) {
      generatedMessage: true,
      code: 'ERR_ASSERTION',
      actual: 'right',
      expected: 'left',
      operator: 'strictEqual'
    }

▶ rock, paper, scissors (2.268291ms)

ℹ tests 3
ℹ suites 1
ℹ pass 2
ℹ fail 1
ℹ cancelled 0
ℹ skipped 0
ℹ todo 0
ℹ duration_ms 47.135125

✖ failing tests:

test at index.test.js:27:3
✖ should say left wins for scissors vs. paper (0.82575ms)
  AssertionError [ERR_ASSERTION]: Expected values to be strictly equal:
  + actual - expected
  
  + 'right'
  - 'left'
      at TestContext.<anonymous> (path/to/rps-tdd/index.test.js:33:12)
      at Test.runInAsyncScope (node:async_hooks:203:9)
      at Test.run (node:internal/test_runner/test:631:25)
      at Suite.processPendingSubtests (node:internal/test_runner/test:374:18)
      at Test.postRun (node:internal/test_runner/test:715:19)
      at Test.run (node:internal/test_runner/test:673:12)
      at async Suite.processPendingSubtests (node:internal/test_runner/test:374:7) {
    generatedMessage: true,
    code: 'ERR_ASSERTION',
    actual: 'right',
    expected: 'left',
    operator: 'strictEqual'
  }
```

So how can we get this to pass?
We can no longer rely on the value of the first parameter alone, because we have two _different_ outputs where `left` is `"scissors"`, so we're going to have to also check the `right` value.
For example:

```js
function rps(left, right) {
  return left === "rock"
    ? "left"
    : (right === "paper" ? "left" : "right");
}
```
Call the shot, then run the test again to see if you were right:

```
$ npm t

> rps-tdd@0.1.0 test
> node --test

▶ rock, paper, scissors
  ✔ should say left wins for rock vs. scissors (0.214833ms)
  ✔ should say right wins for scissors vs. rock (0.044542ms)
  ✔ should say left wins for scissors vs. paper (0.044708ms)
▶ rock, paper, scissors (1.210625ms)

ℹ tests 3
ℹ suites 1
ℹ pass 3
ℹ fail 0
ℹ cancelled 0
ℹ skipped 0
ℹ todo 0
ℹ duration_ms 43.86725
```

That's a successful outcome, but our code is a bit of a mess; a conditional expression inside another conditional expression isn't very clear and we've repeated the _"magic value"_ `"left"` twice.
So now we can **refactor**, keep the tests passing but change the implementation.
For example, how about:

```js
function rps(left, right) {
  return left === "rock" || right === "paper"
    ? "left"
    : "right";
}
```

Call the shot, then run the test again to see if you were right:

```
$ npm t

> rps-tdd@0.1.0 test
> node --test

▶ rock, paper, scissors
  ✔ should say left wins for rock vs. scissors (0.215584ms)
  ✔ should say right wins for scissors vs. rock (0.043833ms)
  ✔ should say left wins for scissors vs. paper (0.044292ms)
▶ rock, paper, scissors (1.188125ms)

ℹ tests 3
ℹ suites 1
ℹ pass 3
ℹ fail 0
ℹ cancelled 0
ℹ skipped 0
ℹ todo 0
ℹ duration_ms 43.331375
```

**Note** a third key benefit of TDD here - we know that the code still does exactly what it's supposed to even though we've just changed the implementation.
This allows us to confidently refactor towards cleaner code and higher quality.

Let's treat ourselves to a commit:

```bash
$ git commit -am 'Third test - scissors vs. paper'
[main <hash>] Third test - scissors vs. paper
 1 file changed, 13 insertions(+), 2 deletions(-)
```

## Are there any puns about four? [7/10]

Let's flip the last condition to cover the other case involving paper and scissors:

```js
it("should say right wins for paper vs. scissors", () => {
  const left = "paper";
  const right = "scissors";

  const result = rps(left, right);

  assert.equal(result, "right");
});
```

Call the shot, then run the test again to see if you were right:

```bash
$ npm t                                           

> rps-tdd@0.1.0 test
> node --test

▶ rock, paper, scissors
  ✔ should say left wins for rock vs. scissors (0.240583ms)
  ✔ should say right wins for scissors vs. rock (0.04775ms)
  ✔ should say left wins for scissors vs. paper (0.045666ms)
  ✔ should say right wins for paper vs. scissors (0.123792ms)
▶ rock, paper, scissors (1.43025ms)

ℹ tests 4
ℹ suites 1
ℹ pass 4
ℹ fail 0
ℹ cancelled 0
ℹ skipped 0
ℹ todo 0
ℹ duration_ms 43.704917
```

...huh. `left` isn't `"rock"` and `right` isn't `"paper"`, so it returns `"right"`, which is the answer we wanted. 
This doesn't drive our implementation forward, but it is the behaviour we want, so let's commit this too:

```
$ git commit -am 'Fourth test - paper vs. scissors'
[main <hash>] Fourth test - paper vs. scissors
 1 file changed, 9 insertions(+)
```

## Gift-wrapped rock [8/10]

At this point you can probably see what's coming next; paper wraps rock:

```js
it("should say left wins for paper vs. rock", () => {
  const left = "paper";
  const right = "rock";

  const result = rps(left, right);

  assert.equal(result, "left");
});
```

Call the shot, then run the test again to see if you were right:

```bash
$ npm t                                            

> rps-tdd@0.1.0 test
> node --test

▶ rock, paper, scissors
  ✔ should say left wins for rock vs. scissors (0.233458ms)
  ✔ should say right wins for scissors vs. rock (0.045917ms)
  ✔ should say left wins for scissors vs. paper (0.043667ms)
  ✔ should say right wins for paper vs. scissors (0.1115ms)
  ✖ should say left wins for paper vs. rock (0.787542ms)
    AssertionError [ERR_ASSERTION]: Expected values to be strictly equal:
    + actual - expected
    
    + 'right'
    - 'left'
        at TestContext.<anonymous> (path/to/rps-tdd/index.test.js:53:12)
        at Test.runInAsyncScope (node:async_hooks:203:9)
        at Test.run (node:internal/test_runner/test:631:25)
        at Suite.processPendingSubtests (node:internal/test_runner/test:374:18)
        at Test.postRun (node:internal/test_runner/test:715:19)
        at Test.run (node:internal/test_runner/test:673:12)
        at async Suite.processPendingSubtests (node:internal/test_runner/test:374:7) {
      generatedMessage: true,
      code: 'ERR_ASSERTION',
      actual: 'right',
      expected: 'left',
      operator: 'strictEqual'
    }

▶ rock, paper, scissors (2.216417ms)

ℹ tests 5
ℹ suites 1
ℹ pass 4
ℹ fail 1
ℹ cancelled 0
ℹ skipped 0
ℹ todo 0
ℹ duration_ms 46.239333

✖ failing tests:

test at index.test.js:47:3
✖ should say left wins for paper vs. rock (0.787542ms)
  AssertionError [ERR_ASSERTION]: Expected values to be strictly equal:
  + actual - expected
  
  + 'right'
  - 'left'
      at TestContext.<anonymous> (path/to/rps-tdd/index.test.js:53:12)
      at Test.runInAsyncScope (node:async_hooks:203:9)
      at Test.run (node:internal/test_runner/test:631:25)
      at Suite.processPendingSubtests (node:internal/test_runner/test:374:18)
      at Test.postRun (node:internal/test_runner/test:715:19)
      at Test.run (node:internal/test_runner/test:673:12)
      at async Suite.processPendingSubtests (node:internal/test_runner/test:374:7) {
    generatedMessage: true,
    code: 'ERR_ASSERTION',
    actual: 'right',
    expected: 'left',
    operator: 'strictEqual'
  }
```

Alright, this time we do get a failure again.
Have a play with the implementation for a few minutes, see if you can come up with a way to write an implementation of the form `<condition> ? "left" : "right";` that passes all five tests.
Remember: write the code, call the shot, run the test, compare.

For example, you might get to something like:

```js
function rps(left, right) {
  return left === "rock" || right === "paper" || (left === "paper" && right === "rock")
    ? "left"
    : "right";
}
```

Let's commit it and then flip to the last case:

```bash
$ git commit -am 'Fifth test - paper vs. rock'
[main <bash>] Fifth test - paper vs. rock
 1 file changed, 10 insertions(+), 1 deletion(-)
```

```js
it("should say right wins for rock vs. paper", () => {
  const left = "rock";
  const right = "paper";

  const result = rps(left, right);

  assert.equal(result, "right");
});
```

Now we've reached a point where, however we try to rearrange it, we're _forced_ to be explicit about all of the cases. For example, we might write:

```js
function rps(left, right) {
  return (
    (left === "rock" && right === "scissors")
    || (left === "scissors" && right === "paper")
    || (left === "paper" && right === "rock")
  )
    ? "left"
    : "right";
}
```

This probably looks a lot like what you imagined to begin with. Let's save it.

```bash
$ git commit -am 'Sixth test - rock vs. paper'
[main <hash>] Sixth test - rock vs. paper
 1 file changed, 14 insertions(+), 1 deletion(-)
```

## Draw! [9/10]

So far we've assumed the two participants choose different values.
If you've played RPS, you'll know that's not always the case in real life - sometimes it's a draw.

This brings us to the idea of _parameterised testing_ - generating tests based on canned data. We can do it with an array and `forEach`:

```js
["rock", "paper", "scissors"].forEach((both) => {
  it(`should say draw for ${both} vs. ${both}`, () => {
    assert.equal(rps(both, both), "draw");
  });
});
```

Call the shot, run the tests, review the output then, if all of that makes sense, complete the implementation. Maybe something like:

```js
function rps(left, right) {
  if (left === right) {
    return "draw";
  }
  return (
    (left === "rock" && right === "scissors")
    || (left === "scissors" && right === "paper")
    || (left === "paper" && right === "rock")
  )
    ? "left"
    : "right";
}
```

Once everything's passing and you're happy with your implementation, make the final commit:

```bash
$ git commit -am 'Handle the draw cases'
[main <hash>] Handle the draw cases
 1 file changed, 9 insertions(+)
```

That's it!
We've just test-driven an implementation of RPS, the right way.
Reflect on the exercise - how does the implementation compare to what you'd initially imagined?
What felt good or bad about the process?

You can see my copy of this exercise at [https://github.com/textbook/rps-tdd-redux][github].

## Exercises [10/10] {#exercises}

Practice makes perfect! Here are some additional exercises you can run through:

 1. Repeat the process, but tackle the pairs in a different order. What impact does the order have on how and when your implementation gains complexity? Do you end up with a different implementation?

 2. Extend your implementation for [additional weapons] (e.g. Rock Paper Scissors Lizard Spock). How easy or hard is this?

     - **Advanced** - read about the _"open-closed principle"_, [OCP]. Can you refactor your code such that adding more weapons doesn't mean a change to the `rps` function?

 3. Test-drive out some validation - what should your code do if either or both of the inputs aren't recognised shapes? If you decide to throw an error, note that per [the docs][node-assert-throws] you need to pass a function to defer execution: 

    ```
    assert.throws(() => rps("bananas", 123));
    ```
    
    otherwise the error's thrown too early and the runner can't handle it.

 4. Refactor the tests to group the test cases into three parameterised tests: one for `"left"`; one for `"right"`; and one for `"draw"`.

 5. Run through the exercise from the beginning, but using `npm t -- --watch` instead of just `npm t` (note the extra `--`, otherwise the `--watch` argument gets passed to NPM rather than the test runner).

    This will set up the runner to watch your files and re-run the tests if anything changes. Arrange your screen so you can see these outputs while you're writing your code, and leave it running the whole time (if this means you can't make commits, don't worry about it). What impact does that immediate and continuous feedback have on your experience of working on the code?

 6. Run through the exercise with a different test framework, e.g.:

    - [Mocha] with [Chai] assertions (try the BDD style, where it's `expect(foo).to.equal(bar)` rather than `assert.equal(foo, bar)`); or

    - [Jest] and its built-in [assertions][jest-expect] (where it's `expect(foo).toBe(bar)`) - try using [`it.each`][jest-each] for the parameterised tests.

  [additional weapons]: https://en.wikipedia.org/wiki/Rock_paper_scissors#Additional_weapons
  [call the shot]: https://markhneedham.com/blog/2010/07/28/tdd-call-your-shots/
  [chai]: https://www.chaijs.com/
  [Git BASH]: https://gitforwindows.org/
  [github]: https://github.com/textbook/rps-tdd-redux
  [Jasmine]: https://jasmine.github.io/
  [Jest]: https://jestjs.io/
  [jest-each]: https://jestjs.io/docs/en/api#testeachtablename-fn-timeout
  [jest-expect]: https://jestjs.io/docs/en/expect
  [js tdd ftw]: {filename}/development/js-tdd-ftw.md
  [Mocha]: https://mochajs.org/
  [Node]: https://nodejs.org/
  [node-assert]: https://nodejs.org/api/assert.html
  [node-assert-throws]: https://nodejs.org/api/assert.html#assertthrowsfn-error-message
  [node-test]: https://nodejs.org/api/test.html
  [OCP]: https://en.wikipedia.org/wiki/Open%E2%80%93closed_principle
  [Rock Paper Scissors]: https://en.wikipedia.org/wiki/Rock_paper_scissors
  [tape]: https://www.npmjs.com/package/tape
  [WSL]: https://docs.microsoft.com/en-us/windows/wsl/about
  [XP]: http://wiki.c2.com/?ExtremeProgramming
