Title: JS TDD FTW
Date: 2020-08-31 16:00
Modified: 2020-09-02 16:00
Tags: javascript, tdd, xp
Authors: Jonathan Sharpe
Summary: Test-driven JavaScript development done right - part 1

One of the key Extreme Programming ([XP]) engineering practices is test-driven development (TDD), usually expressed as repeatedly following this simple, three-step process:

 1. **Red** - write a failing test that describes the behaviour you want;
 2. **Green** - write the simplest possible code to make the test pass; and
 3. **Refactor** - clean up your code without breaking the tests.

I was recently asked if I knew of a good TDD intro for people who were comfortable with JavaScript but hadn't done much testing, so I did some research. There are lots of examples of testing and TDD out there, but often: tied to specific frameworks (e.g. React); with unclear prerequisites; and even showing poor testing practices. So below I'm going to give a proper example of vanilla JavaScript TDD done _"the right way"_, sprinkling some bonus command line and git practice throughout.

### Requirements

I've aimed this content at more junior developers, so there are more explanations than all readers will need, but anyone new to testing and TDD should find something to take from it. We'll need:

- *nix command line: already provided on macOS and Linux; if you're using Windows try [WSL] or [Git BASH];
- [Node] \(10+ recommended, run `node -v` to check) and NPM; and
- Familiarity with ES6 JavaScript syntax (specifically arrow functions).

We also need something to implement. [Rock Paper Scissors] \(or just RPS) is a simple playground game that takes some inputs (the shapes that the players present) and gives a single output (the outcome), which makes it a good fit for a simple function to test drive. If you're not familiar with the rules, read the linked Wikipedia article before continuing.

Before we get into the TDD process, think about what the code for an implementation of RPS might look like. Don't write any code yet (we don't have the failing tests to make us do that!) but imagine a function - what parameters would it accept? What would it return? We're expecting different outputs for different inputs, which implies some conditional logic - what conditions do you think would be involved? Note your ideas down, we'll revisit them later.

As we go through, please carefully _read everything_. I'd recommend _typing the code_ rather than copy-pasting, especially if you're a new developer; it's good practice to build your muscle memory.

## Setup [1/10]

Let's get up and running. Starting in your working directory (e.g. I use `~/workspace`), run the following:

```bash
$ mkdir rps-tdd && cd $_ && git init && git commit --allow-empty -m 'Initial commit'
Initialized empty Git repository in path/to/rps-tdd/.git/
[master (root-commit) <hash>] Initial commit
```

By chaining multiple commands using `&&` (_"and"_, assuming the previous commands all succeeded), this will:

- Create a new directory named `rps-tdd/`;
- Switch into it (`$_` references the argument to the last command, see e.g. [this SO question](https://stackoverflow.com/q/30154694/3001761));
- Initialise a new git repository; and
- Create an empty initial commit (`--allow-empty` lets us create this first commit without having any content, and `-m` lets us supply the commit message on the command line).

Now we need a basic Node project:

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


[master <hash>] Create NPM package
 1 file changed, 12 insertions(+)
 create mode 100644 package.json
```

This:

- Creates a basic `package.json`;
- Adds that to our repo; and
- Makes another commit.

Next, we're going to need something to _run_ our tests. There are loads of options here (I've used [Jasmine], [Mocha], [tape], ...) but we're going to start with one that's become very popular recently: [Jest]. Let's install it as a *development dependency*:

```bash
$ npm install --save-dev jest
npm WARN deprecated request@2.88.2: request has been deprecated, see https://github.com/request/request/issues/3142
npm WARN deprecated request-promise-native@1.0.9: request-promise-native has been deprecated because it extends the now deprecated request package, see https://github.com/request/request/issues/3142
npm WARN deprecated har-validator@5.1.5: this library is no longer supported
npm notice created a lockfile as package-lock.json. You should commit this file.
npm WARN rps-tdd@1.0.0 No description
npm WARN rps-tdd@1.0.0 No repository field.

+ jest@26.4.2
added 506 packages from 347 contributors and audited 506 packages in 18.837s

21 packages are looking for funding
  run `npm fund` for details

found 0 vulnerabilities
```

That's quite a lot of information, most of which isn't relevant to us right now - if the install succeeded (you can run `echo $?` and should see the "success" exit code of `0`, if you're unsure), we can move on. If you really want to know what the other details mean, see the end of this post.

We should update our repo:

```bash
$ git status
On branch master
Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git restore <file>..." to discard changes in working directory)
	modified:   package.json

Untracked files:
  (use "git add <file>..." to include in what will be committed)
	node_modules/
	package-lock.json

no changes added to commit (use "git add" and/or "git commit -a")
```

So we've changed `package.json`, created the `node_modules/` dependencies directory and added `package-lock.json`. Typically we don't want all of the dependencies in our source control, so let's:

- Ignore the dependencies directory by adding it to a `.gitignore` file
- Add all of the rest (`git add .` means _"add everything from this directory and below"_, so will add both `.gitignore` and `package-lock.json` as well as the changes to `package.json`); and
- Commit the result.

```bash
$ echo 'node_modules/' > .gitignore && git add . && git commit -m 'Install Jest'
[master <hash>] Install Jest
 3 files changed, 4680 insertions(+), 1 deletion(-)
 create mode 100644 .gitignore
 create mode 100644 package-lock.json
```

## Running Jest [2/10]

Now we can update `package.json` to set Jest to be our test command. By default, NPM creates a test script that will throw an error, as we saw above:

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

Edit `package.json` to update the script to `"test": "jest"`, using an editor or IDE of your choice, to use the test framework we just installed. Then run the tests again:

```bash
$ npm t

> rps-tdd@1.0.0 test path/to/rps-tdd
> jest

No tests found, exiting with code 1
Run with `--passWithNoTests` to exit with code 0
In path/to/rps-tdd
  2 files checked.
  testMatch: **/__tests__/**/*.[jt]s?(x), **/?(*.)+(spec|test).[tj]s?(x) - 0 matches
  testPathIgnorePatterns: /node_modules/ - 2 matches
  testRegex:  - 0 matches
Pattern:  - 0 matches
npm ERR! Test failed.  See above for more details.
```

This seems unhappy, but reading the output we can see why: `No tests found`. One option given there is to add the `--passWithNoTests` flag, but maybe we should write a test instead. Let's start with something completely trivial to make sure everything is working; add the following to a file named `index.test.js`:

```javascript
it("should work", () => {
  const left = 1;
  const right = 2;
  
  const result = left + right;
  
  expect(result).toBe(3);
});
``` 

Now run the tests a third time:

```bash
$ npm t

> rps-tdd@1.0.0 test path/to/rps-tdd
> jest

 PASS  ./index.test.js
  ✓ should work (2 ms)

Test Suites: 1 passed, 1 total
Tests:       1 passed, 1 total
Snapshots:   0 total
Time:        1.224 s
Ran all test suites.
```

Much happier! So what does that test _do_, what's going on there?

 1. We call the `it` function (provided by Jest, you can also use the name `test`) to **register a test**. We pass it two things:
     - The name of the test, as a string (you can see this name in the output, too). In this style of testing we use the function name along with the test as one sentence describing our expectation: _"it should work"_.
     - The body of the test, as a function. Right now we're just *registering* the test, Jest will call that function for us when it runs the test.
 2. Within the test body, we **establish our expectations**. What exactly do we think should happen? I've split this into three sections:
     - **Arrange** (sometimes known as _"given"_) - set up the preconditions for our test, in this case two initial values.
     - **Act** (or _"when"_) - do some work, in this case adding them together. This is what we're actually testing.
     - **Assert** (or _"then"_) - make sure that the work was done correctly. The `expect` function is also provided by Jest; it takes the value we want to check and returns an object with a lot of helpful [matcher methods] to describe our expectations of it. Again the naming convention allows us to write out a simple sentence: _"expect result to be 3"_.

One of the things Jest does really well is test feedback. If we had an inaccurate expectation:

```js
it("should work", () => {
  const left = 2;
  const right = 2;

  const result = left + right;

  expect(result).toBe(5);
});
```

it would tell us exactly what the problem was:

```bash
$ npm t

> rps-tdd@1.0.0 test path/to/rps-tdd
> jest

 FAIL  ./index.test.js
  ✕ should work (4 ms)

  ● should work

    expect(received).toBe(expected) // Object.is equality

    Expected: 5
    Received: 4

       5 |   const result = left + right;
       6 |
    >  7 |   expect(result).toBe(5);
         |                  ^
       8 | });
       9 |
      10 |

      at Object.<anonymous> (index.test.js:7:18)

Test Suites: 1 failed, 1 total
Tests:       1 failed, 1 total
Snapshots:   0 total
Time:        0.979 s, estimated 1 s
Ran all test suites.
npm ERR! Test failed.  See above for more details.
```

> **Protip**: always read the outputs carefully! Sometimes a test fails for an unexpected reason, which usually tells you something interesting.

So, we're happy things are working so far.

## A failing test [3/10]

Let's start some actual TDD, and write our first failing test. Replace the content of `index.test.js` with:

```js
describe("rock, paper, scissors", () => {
  it("should say left wins for rock vs. scissors", () => {
    const left = "rock";
    const right = "scissors";
    
    const outcome = rps(left, right);
    
    expect(outcome).toBe("left");
  });
});
```

Note I've introduced another Jest function, `describe`. This registers a _group_ of tests, usually referred to as a _"suite"_. Like `it`/`test` it takes a name and a function, then our individual tests are registered inside that function.

Our first test is that, given that `left` is `"rock"` and `right` is `"scissors"` (_"Arrange"_), when the shapes are compared (_"Act"_) , then the winner should be `"left"` (_"Assert"_) because rock blunts scissors.

**Note** one key benefit of TDD here - we can try out how we should interact with our code (its _"interface"_) before we've even written any. Maybe it should return something other than a string, for example? We can have that discussion now, while it's just a matter of changing our minds rather than the code.

Before we run the first test, _"call the shot"_ - make a prediction of what the test result will be, pass or fail. If you think the test will fail, **why**; will the `expect`ation be unmet (and what value do you think you'll get instead) or will something else go wrong? This is really good practice for _"playing computer"_ (modelling the behaviour of the code in your head) and you can write your guess down (or say it out loud if you're pairing) to keep yourself honest. Now let's run it:

```
$ npm t

> rps-tdd@1.0.0 test path/to/rps-tdd
> jest

 FAIL  ./index.test.js
  rock, paper, scissors
    ✕ should say left wins for rock vs. scissors (2 ms)

  ● rock, paper, scissors › should say left wins for rock vs. scissors

    ReferenceError: rps is not defined

      4 |     const right = "scissors";
      5 |
    > 6 |     const outcome = rps(left, right);
        |                     ^
      7 |
      8 |     expect(outcome).toBe("left");
      9 |   });

      at Object.<anonymous> (index.test.js:6:21)

Test Suites: 1 failed, 1 total
Tests:       1 failed, 1 total
Snapshots:   0 total
Time:        1.226 s
Ran all test suites.
npm ERR! Test failed.  See above for more details.
```

...were you right?

## The simplest possible change [4/10]

As you may have guessed, this fails because `rps` _doesn't exist yet_. Let's make the simplest possible change that will at least change the error we're receiving; define the function. At this stage we could `import`/`require` the function from another file, but let's keep things simple for now; add the following to the top of `index.test.js`:

```js
function rps() {}
```

Call the shot, then run the test again to see if you were right:

```bash
$ npm t

> rps-tdd@1.0.0 test path/to/rps-tdd
> jest

 FAIL  ./index.test.js
  rock, paper, scissors
    ✕ should say left wins for rock vs. scissors (4 ms)

  ● rock, paper, scissors › should say left wins for rock vs. scissors

    expect(received).toBe(expected) // Object.is equality

    Expected: "left"
    Received: undefined

       8 |     const outcome = rps(left, right);
       9 |
    > 10 |     expect(outcome).toBe("left");
         |                     ^
      11 |   });
      12 | });
      13 |

      at Object.<anonymous> (index.test.js:10:21)

Test Suites: 1 failed, 1 total
Tests:       1 failed, 1 total
Snapshots:   0 total
Time:        1.196 s
Ran all test suites.
npm ERR! Test failed.  See above for more details.
```

Our test still doesn't pass, but at least we've changed the error message - we're now reaching the actual expectation, instead of crashing when we try to call the function. So let's make the simplest possible change that should get this passing:

```js
function rps() {
  return "left";
}
```

Call the shot, then run the test again to see if you were right:

```
$ npm t

> rps-tdd@1.0.0 test path/to/rps-tdd
> jest

 PASS  ./index.test.js
  rock, paper, scissors
    ✓ should say left wins for rock vs. scissors (2 ms)

Test Suites: 1 passed, 1 total
Tests:       1 passed, 1 total
Snapshots:   0 total
Time:        1.198 s
Ran all test suites.
```

Great! This calls for a celebratory commit:

```bash
$ git add . && git commit -m 'First test - rock vs. scissors'
[master <hash>] First test - rock vs. scissors
 2 files changed, 15 insertions(+), 1 deletion(-)
 create mode 100644 index.test.js
```

**Note** another key benefit of TDD here - it tells you when you're done. Once the tests are passing, the implementation meets the current requirements.

## The difficult second test [5/10]

_"But wait"_, you might be thinking, _"that's pointless, it doesn't **do** anything!"_ And to an extent, that's true; our function just returns a hard-coded string. But let's think about what else has happened:

- We've decided on an interface for our function, what it's going to receive and return;
- We've proved out a test setup that lets us make assertions on the behaviour of that function; and
- We've created the simplest possible implementation for the requirements we've expressed through tests so far, making our code very robust.

So let's build on that foundation; flip the shapes around to change the output so we can expect the test to fail. Add the following into the `describe` callback in `index.test.js`:

```js
it("should say right wins for scissors vs. rock", () => {
  const left = "scissors";
  const right = "rock";
  
  const result = rps(left, right);
  
  expect(result).toBe("right");
});
```

Note that the _"Act"_ is the same, but the _"Arrange"_ and _"Assert"_ have changed. Call the shot, then run the test again to see if you were correct:

```bash
$ npm t

> rps-tdd@1.0.0 test path/to/rps-tdd
> jest

 FAIL  ./index.test.js
  rock, paper, scissors
    ✓ should say left wins for rock vs. scissors (6 ms)
    ✕ should say right wins for scissors vs. rock (4 ms)

  ● rock, paper, scissors › should say right wins for scissors vs. rock

    expect(received).toBe(expected) // Object.is equality

    Expected: "right"
    Received: "left"

      19 |     const result = rps(left, right);
      20 |
    > 21 |     expect(result).toBe("right");
         |                    ^
      22 |   });
      23 | });
      24 |

      at Object.<anonymous> (index.test.js:21:20)

Test Suites: 1 failed, 1 total
Tests:       1 failed, 1 passed, 2 total
Snapshots:   0 total
Time:        1.201 s
Ran all test suites.
npm ERR! Test failed.  See above for more details.
```

Read that through carefully. What does it tell us?

 1. Our first test is still passing. That's good news, we haven't broken anything!
 2. Our second test fails, because it returns `"left"` but we want it to return `"right"`.

So, what's the simplest possible change that would get this test passing? Think about it for a minute or two.

We're going to need some kind of _conditional logic_ here, because we return different results in different cases. However, we're supposed to be keeping things simple, so we don't want to leap all the way to a full implementation. How about this:

```js
function rps(left) {
  return left === "rock" ? "left" : "right";
}
```

Call the shot, then run the test again to see if you were right:

```bash
$ npm t

> rps-tdd@1.0.0 test path/to/rps-tdd
> jest

 PASS  ./index.test.js
  rock, paper, scissors
    ✓ should say left wins for rock vs. scissors (2 ms)
    ✓ should say right wins for scissors vs. rock

Test Suites: 1 passed, 1 total
Tests:       2 passed, 2 total
Snapshots:   0 total
Time:        1.216 s
Ran all test suites.
```

Alright, two down, let's commit what we've done so far:

```bash
$ git commit -a -m 'Second test - scissors vs. rock'
[master bd4bbd6] Second test - scissors vs. rock
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
  
  expect(result).toBe("left");
});
```

Call the shot, then run the test again to see if you were right:

```bash
npm t

> rps-tdd@1.0.0 test path/to/rps-tdd
> jest

 FAIL  ./index.test.js
  rock, paper, scissors
    ✓ should say left wins for rock vs. scissors (1 ms)
    ✓ should say right wins for scissors vs. rock
    ✕ should say left wins for scissors vs. paper (3 ms)

  ● rock, paper, scissors › should say left wins for scissors vs. paper

    expect(received).toBe(expected) // Object.is equality

    Expected: "left"
    Received: "right"

      28 |     const result = rps(left, right);
      29 |
    > 30 |     expect(result).toBe("left");
         |                    ^
      31 |   });
      32 | });
      33 |

      at Object.<anonymous> (index.test.js:30:20)

Test Suites: 1 failed, 1 total
Tests:       1 failed, 2 passed, 3 total
Snapshots:   0 total
Time:        1.227 s
Ran all test suites.
npm ERR! Test failed.  See above for more details.
```

So how can we get this to pass? We can no longer rely on the value of the first parameter alone, because we have two _different_ outputs where `left` is `"scissors"`, so we're going to have to also check the `right` value. For example:

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

> rps-tdd@1.0.0 test path/to/rps-tdd
> jest

 PASS  ./index.test.js
  rock, paper, scissors
    ✓ should say left wins for rock vs. scissors (1 ms)
    ✓ should say right wins for scissors vs. rock (1 ms)
    ✓ should say left wins for scissors vs. paper

Test Suites: 1 passed, 1 total
Tests:       3 passed, 3 total
Snapshots:   0 total
Time:        1.109 s
Ran all test suites.
```

That's a successful outcome, but our code is a bit of a mess; a conditional expression inside another conditional expression isn't very clear and we've repeated the _"magic value"_ `"left"` twice. So now we can **refactor**, keep the tests passing but change the implementation. For example, how about:

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

> rps-tdd@1.0.0 test path/to/rps-tdd
> jest

 PASS  ./index.test.js
  rock, paper, scissors
    ✓ should say left wins for rock vs. scissors (1 ms)
    ✓ should say right wins for scissors vs. rock (1 ms)
    ✓ should say left wins for scissors vs. paper

Test Suites: 1 passed, 1 total
Tests:       3 passed, 3 total
Snapshots:   0 total
Time:        1.109 s
Ran all test suites.
```

**Note** a third key benefit of TDD here - we know that the code still does exactly what it's supposed to even though we've just changed the implementation. This allows us to confidently refactor towards cleaner code and higher quality.

Let's treat ourselves to a commit:

```bash
$ git commit -a -m 'Third test - scissors vs. paper'
[master <hash>] Third test - scissors vs. paper
 1 file changed, 13 insertions(+), 2 deletions(-)
```

## Are there any puns about four? [7/10]

Let's flip the last condition to cover the other case involving paper and scissors:

```js
it("should say right wins for paper vs. scissors", () => {
  const left = "paper";
  const right = "scissors";

  const result = rps(left, right);

  expect(result).toBe("right");
});
```

Call the shot, then run the test again to see if you were right:

```bash
$ npm t

> rps-tdd@1.0.0 test path/to/rps-tdd
> jest

 PASS  ./index.test.js
  rock, paper, scissors
    ✓ should say left wins for rock vs. scissors (1 ms)
    ✓ should say right wins for scissors vs. rock
    ✓ should say left wins for scissors vs. paper
    ✓ should say right wins for paper vs. scissors

Test Suites: 1 passed, 1 total
Tests:       4 passed, 4 total
Snapshots:   0 total
Time:        0.879 s, estimated 1 s
Ran all test suites.
```

...huh. `left` isn't `"rock"` and `right` isn't `"paper"`, so it returns `"right"`, which is the answer we wanted. This doesn't drive our implementation forward, but it is the behaviour we want, so let's commit this too:

```
$ git commit -a -m 'Fourth test - paper vs. scissors'
[master <hash>] Fourth test - paper vs. scissors
 1 file changed, 9 insertions(+)
```

## Gift-wrapped rock [8/10]

At this point you can probably see what's coming next; paper wraps rock:

```js
it("should say left wins for paper vs. rock", () => {
  const left = "paper";
  const right = "rock";

  const result = rps(left, right);

  expect(result).toBe("left");
});
```

Call the shot, then run the test again to see if you were right:

```bash
$ npm t

> rps-tdd@1.0.0 test path/to/rps-tdd
> jest

 FAIL  ./index.test.js
  rock, paper, scissors
    ✓ should say left wins for rock vs. scissors (2 ms)
    ✓ should say right wins for scissors vs. rock
    ✓ should say left wins for scissors vs. paper
    ✓ should say right wins for paper vs. scissors (1 ms)
    ✕ should say left wins for paper vs. rock (3 ms)

  ● rock, paper, scissors › should say left wins for paper vs. rock

    expect(received).toBe(expected) // Object.is equality

    Expected: "left"
    Received: "right"

      48 |     const result = rps(left, right);
      49 |
    > 50 |     expect(result).toBe("left");
         |                    ^
      51 |   });
      52 | });
      53 |

      at Object.<anonymous> (index.test.js:50:20)

Test Suites: 1 failed, 1 total
Tests:       1 failed, 4 passed, 5 total
Snapshots:   0 total
Time:        1.234 s
Ran all test suites.
npm ERR! Test failed.  See above for more details.
```

Alright, this time we do get a failure again. Have a play with the implementation for a few minutes, see if you can come up with a way to write an implementation of the form `<condition> ? "left" : "right";` that passes all five tests. Remember: write the code, call the shot, run the test, compare.

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
$ git commit -a -m 'Fifth test - paper vs. rock'
[master <bash>] Fifth test - paper vs. rock
 1 file changed, 10 insertions(+), 1 deletion(-)
```

```js
it("should say right wins for rock vs. paper", () => {
  const left = "rock";
  const right = "paper";

  const result = rps(left, right);

  expect(result).toBe("right");
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
$ git commit -a -m 'Sixth test - rock vs. paper'
[master <hash>] Sixth test - rock vs. paper
 1 file changed, 14 insertions(+), 1 deletion(-)
```

## Draw! [9/10]

So far we've assumed the two participants choose different values. If you've played RPS, you'll know that's not always the case in real life - sometimes it's a draw.

This brings us to the idea of _parameterised testing_ - generating tests based on canned data. Jest has built-in functionality to do this, named [`each`][each], but it's often as easy to do it with an array and `forEach`:

```js
["rock", "paper", "scissors"].forEach((both) => {
  it(`should say draw for ${both} vs. ${both}`, () => {
    expect(rps(both, both)).toBe("draw");
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
$ git commit -a -m 'Handle the draw cases'
[master <hash>] Handle the draw cases
 1 file changed, 9 insertions(+)
```

That's it! We've just test-driven an implementation of RPS, the right way. Reflect on the exercise - how does the implementation compare to what you'd initially imagined? What felt good or bad about the process?

You can see my copy of this exercise at [https://github.com/textbook/rps-tdd][github].

## Exercises [10/10]

Practices makes perfect! Here are some additional exercises you can run through:

 1. Repeat the process, but tackle the pairs in a different order. What impact does the order have on how and when your implementation gains complexity? Do you end up with a different implementation?

 2. Extend your implementation for [additional weapons] (e.g. Rock Paper Scissors Lizard Spock). How easy or hard is this?

     - **Advanced** - read about the _"open-closed principle"_, [OCP]. Can you refactor your code such that adding more weapons doesn't mean a change to the `rps` function?

 3. Test-drive out some validation - what should your code do if either or both of the inputs aren't recognised shapes? If you decide to throw an error, note that per [the Jest docs] you need to pass a function to defer execution: 

    ```
    expect(() => rps("bananas", 123)).toThrowError();
    ```
    
    otherwise the error's thrown too early and Jest can't handle it.

 4. Refactor the tests to group the test cases into three parameterised tests: one for `"left"`; one for `"right"`; and one for `"draw"`.

     - **Advanced** - use Jest's [`each`][each] method, either with an array or a template literal.

## Installation explained [Bonus]

As promised above, here's an explanation of everything you were told during the `npm install`.

```bash
npm WARN deprecated request@2.88.2: request has been deprecated, see https://github.com/request/request/issues/3142
npm WARN deprecated request-promise-native@1.0.9: request-promise-native has been deprecated because it extends the now deprecated request package, see https://github.com/request/request/issues/3142
npm WARN deprecated har-validator@5.1.5: this library is no longer supported
```

Over time, libraries published on NPM will become out-of-date. For various reasons, their maintainers may decide to stop supporting them, or to stop supporting older major versions. This isn't _necessarily_ a problem, but means that future vulnerabilities won't be addressed; try not to depend on deprecated packages.

```bash
npm notice created a lockfile as package-lock.json. You should commit this file.
```

If you look in the package file after the install, the only information about the dependencies is `"jest": "^26.4.2"`. This means _"requires Jest of at least `v26.4.2` and up to (but not including) `v27.0.0`"_ (you can learn more about this notation with [the semver calculator]). Given the number of dependencies installed (see below), that's not a lot of information - if you installed this package on another machine, it might get a quite different set of dependencies. So that you can reproduce a specific install more easily, NPM stores the _exact_ versions of _all_ of the dependencies in `package-lock.json`.

```bash
npm WARN rps-tdd@1.0.0 No description
npm WARN rps-tdd@1.0.0 No repository field.
```

The shortcut we used to create the `package.json`, `npm init -y`, created all of the _required_ fields but not all of the _recommended_ fields. If you want to avoid this warning in the future, add a description and repository into your `package.json` per [the NPM docs]. When creating new packages you can use `npm init` instead to go through an interactive process to enter more of the fields.

```bash
+ jest@26.4.2
added 506 packages from 347 contributors and audited 506 packages in 18.837s
```

That's the bit we actually care about; Jest (and all of its own dependencies) **has been installed**.

```bash
21 packages are looking for funding
  run `npm fund` for details
```

Per [RFC 0017], NPM allows package maintainers to solicit funding by adding information to their package files. As the message says, you can run [`npm fund`][fund] to see which packages are asking for financial support, and how to provide it.

```bash
found 0 vulnerabilities
```

NPM checks whether there are any known vulnerabilities in the packages in your `node_modules/`. This can tell you when you need to update your dependencies, especially anything you use in production (as opposed to development dependencies like Jest). You can run [`npm audit`][audit] at any time to get the latest updates and see more information.

  [additional weapons]: https://en.wikipedia.org/wiki/Rock_paper_scissors#Additional_weapons
  [audit]: https://docs.npmjs.com/cli-commands/audit.html
  [each]: https://jestjs.io/docs/en/api#testeachtablename-fn-timeout
  [fund]: https://docs.npmjs.com/cli-commands/fund.html
  [Git BASH]: https://gitforwindows.org/
  [github]: https://github.com/textbook/rps-tdd
  [Jasmine]: https://jasmine.github.io/
  [Jest]: https://jestjs.io/
  [matcher methods]: https://jestjs.io/docs/en/expect
  [Mocha]: https://mochajs.org/
  [Node]: https://nodejs.org/
  [OCP]: https://en.wikipedia.org/wiki/Open%E2%80%93closed_principle
  [RFC 0017]: https://github.com/npm/rfcs/blob/2d2f00457ab19b3003eb6ac5ab3d250259fd5a81/accepted/0017-add-funding-support.md
  [Rock Paper Scissors]: https://en.wikipedia.org/wiki/Rock_paper_scissors
  [Stryker]: https://stryker-mutator.io/
  [tape]: https://www.npmjs.com/package/tape
  [the Jest docs]: https://jestjs.io/docs/en/expect#tothrowerror
  [the NPM docs]: https://docs.npmjs.com/files/package.json
  [the semver calculator]: https://semver.npmjs.com/
  [WSL]: https://docs.microsoft.com/en-us/windows/wsl/about
  [XP]: http://wiki.c2.com/?ExtremeProgramming