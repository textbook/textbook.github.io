Title: Python TDD FTW
Date: 2024-08-17 11:30
Tags: python, tdd, xp
Authors: Jonathan Sharpe
Summary: Test-driven Python development done right - part 1

> **Note**: this was originally published as [JS TDD FTW], using JavaScript with Jest, but I've recently been working with a client using [Python], so this article is an updated version of the same example using the latter tech stack.

One of the key Extreme Programming ([XP]) engineering practices is test-driven development (TDD), usually expressed as repeatedly following this simple, three-step process:

 1. **Red** - write a failing test that describes the behaviour you want;
 2. **Green** - write the simplest possible code to make the test pass; and
 3. **Refactor** - clean up your code without breaking the tests.

Below I'm going to give a proper example of vanilla Python TDD done _"the right way"_, sprinkling some bonus command line and git practice throughout.

### Requirements

I've aimed this content at more junior developers, so there are more explanations than all readers will need, but anyone new to testing and TDD should find something to take from it. We'll need:

- *nix command line: already provided on macOS and Linux; if you're using Windows try [WSL] or [Git BASH];
- Python installed (any 3.x version should work); and
- Familiarity with basic Python syntax.

We also need something to implement. [Rock Paper Scissors] \(or just RPS) is a simple playground game that takes some inputs (the shapes that the players present) and gives a single output (the outcome), which makes it a good fit for a simple function to test drive.
If you're not familiar with the rules, read the linked Wikipedia article before continuing.

Before we get into the TDD process, think about what the code for an implementation of RPS might look like.
Don't write any code yet (we don't have the failing tests to make us do that!) but imagine a function - what parameters would it accept?
What would it return?
We're expecting different outputs for different inputs, which implies some conditional logic - what conditions do you think would be involved?
Note your ideas down, we'll revisit them later.

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
- Switch into it (`$_` references the argument to the last command, see e.g. [this SO question][so-q30154694]);
- Initialise a new git repository; and
- Create an empty initial commit (`--allow-empty` lets us create this first commit without having any content, and `-m` lets us supply the commit message on the command line).

## Running tests [2/10]

Next, we're going to need something to _run_ our tests.
To keep things simple, we're going to start with one that's built right into the standard library: [`unittest`][python-unittest].
This is an xUnit-style framework, where test suites and cases are represented as classes and methods respectively.
Run it as follows:

```bash
$ python3 -m unittest

----------------------------------------------------------------------
Ran 0 tests in 0.000s

NO TESTS RAN
```

This is a little bit unhappy, it has a non-zero exit code, but you can see why - there were no tests.
Let's give it a simple test to run; create a file named `tests.py` containing:

```python
from unittest import TestCase


class Tests(TestCase):

    def test_should_work(self):
        left = 1
        right = 2

        result = left + right

        self.assertEqual(result, 3)
```

Now run the tests a second time:

```bash
$ python3 -m unittest
.
----------------------------------------------------------------------
Ran 1 test in 0.000s

OK
```

Much happier!
So what does that test _do_, what's going on there?

 1. We create a class named `Tests` that extends `unittest`'s built-in `TestCase`. This represents our test suite.
 2. We create a method to **register a test**. This represents an individual test within the suite - when we run the tests, `unittest` will call each test method to run the test. The method name is the name of our test, and must start with `test_`.
 3. Within the test body, we **establish our expectations**. What exactly do we think should happen? I've split this into three sections:
     - **Arrange** (sometimes known as _"given"_) - set up the preconditions for our test, in this case two initial values.
     - **Act** (or _"when"_) - do some work, in this case adding them together. This is what we're actually testing.
     - **Assert** (or _"then"_) - make sure that the work was done correctly. `TestCase` has a lot of helpful [matcher methods][python-unittest-assert-methods] to describe our expectations, taking the _actual_ and _expected_ values and comparing them.

The point of tests is to give us good feedback.
If we had an inaccurate expectation:

```diff
         result = left + right
 
-        self.assertEqual(result, 3)
+        self.assertEqual(result, 5)
```

it would tell us exactly what the problem was:

```bash
$ python3 -m unittest
F
======================================================================
FAIL: test_should_work (tests.Tests.test_should_work)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "path/to/rps-tdd/tests.py", line 12, in test_should_work
    self.assertEqual(result, 5)
AssertionError: 3 != 5

----------------------------------------------------------------------
Ran 1 test in 0.000s

FAILED (failures=1)
```

> **Protip**: always read the outputs carefully! Sometimes a test fails for an unexpected reason, which usually tells you something interesting.

So, we're happy things are working so far.

## A failing test [3/10]

Let's start some actual TDD, and write our first failing test. Replace the content of `tests.py` with:

```python
from unittest import TestCase


class RpsTests(TestCase):

    def test_rock_vs_scissors_left_wins(self):
        left = "rock"
        right = "scissors"

        result = rps(left, right)

        self.assertEqual(result, "left")
```

Our first test is that, given that `left` is `"rock"` and `right` is `"scissors"` (_"Arrange"_), when the shapes are compared (_"Act"_) , then the winner should be `"left"` (_"Assert"_) because rock blunts scissors.

**Note** one key benefit of TDD here - we can try out how we should interact with our code (its _"interface"_) before we've even written any.
Maybe it should return something other than a string, for example?
We can have that discussion now, while it's just a matter of changing our minds rather than the code.

Before we run the first test, [_"call the shot"_][call the shot] - make a prediction of what the test result will be, pass or fail.
If you think the test will fail, **why**; will the expectation be unmet (and what value do you think you'll get instead) or will something else go wrong?
This is really good practice for _"playing computer"_ (modelling the behaviour of the code in your head) and you can write your guess down (or say it out loud if you're pairing) to keep yourself honest.
Now let's run it:

```bash
$ python3 -m unittest
E
======================================================================
ERROR: test_rock_vs_scissors_left_wins (tests.RpsTests.test_rock_vs_scissors_left_wins)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "path/to/rps-tdd/tests.py", line 10, in test_rock_vs_scissors_left_wins
    result = rps(left, right)
             ^^^
NameError: name 'rps' is not defined

----------------------------------------------------------------------
Ran 1 test in 0.001s

FAILED (errors=1)
```

...were you right?

## The simplest possible change [4/10]

As you may have guessed, this fails because `rps` _doesn't exist yet_.
Let's make the simplest possible change that will at least change the error we're receiving; define the function.
At this stage we could `import` the function from another file, but let's keep things simple for now; add the following to the top of `tests.py`:

```python
def rps():
    pass
```

Call the shot, then run the test again to see if you were right:

```bash
$ python3 -m unittest
E
======================================================================
ERROR: test_rock_vs_scissors_left_wins (tests.RpsTests.test_rock_vs_scissors_left_wins)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "path/to/rps-tdd/tests.py", line 14, in test_rock_vs_scissors_left_wins
    result = rps(left, right)
             ^^^^^^^^^^^^^^^^
TypeError: rps() takes 0 positional arguments but 2 were given

----------------------------------------------------------------------
Ran 1 test in 0.000s

FAILED (errors=1)
```

Our test still doesn't pass, but at least we've changed the error message.
So let's make the simplest possible change that should at least change the error:

```diff
-def rps():
+def rps(left, right):
     pass
```

Call the shot, then run the test again to see if you were right:

```bash
$ python3 -m unittest
F
======================================================================
FAIL: test_rock_vs_scissors_left_wins (tests.RpsTests.test_rock_vs_scissors_left_wins)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "path/to/rps-tdd/tests.py", line 16, in test_rock_vs_scissors_left_wins
    self.assertEqual(result, "left")
AssertionError: None != 'left'

----------------------------------------------------------------------
Ran 1 test in 0.000s

FAILED (failures=1)
```

The test now fails (`F`) instead of throwing an error (`E`), we're now reaching the actual expectation instead of crashing when we try to call the function.
So let's make the simplest possible change that should get this passing:

```diff
 def rps(left, right):
-    pass
+    return "left"
```

Call the shot, then run the test again to see if you were right:

```bash
$ python3 -m unittest
.
----------------------------------------------------------------------
Ran 1 test in 0.000s

OK
```

Great!
This calls for a celebratory commit.
But have a look at what's currently in your repo:

```bash
$ git status
On branch main
Untracked files:
  (use "git add <file>..." to include in what will be committed)
	__pycache__/
	tests.py

nothing added to commit but untracked files present (use "git add" to track)
```

`tests.py` is the file we've been working on, but we don't want to track changes to the `__pycache__/` directory (for more on what it is, see [this SO question][so-q16869024]).
Create a `.gitignore` containing the following:

```gitignore
__pycache__/
```

The status should now update accordingly:

```bash
$ git status
On branch main
Untracked files:
  (use "git add <file>..." to include in what will be committed)
	.gitignore
	tests.py

nothing added to commit but untracked files present (use "git add" to track)
```

So we can make a commit:

```bash
$ git add . && git commit -m 'First test - rock vs. scissors'
[main 544d1ac] First test - rock vs. scissors
 2 files changed, 17 insertions(+)
 create mode 100644 .gitignore
 create mode 100644 tests.py
```

**Note** another key benefit of TDD here - it tells you when you're done. Once the tests are passing, the implementation meets the current requirements.

## The difficult second test [5/10]

_"But wait"_, you might be thinking, _"that's pointless, it doesn't **do** anything!"_
And to an extent, that's true; our function just returns a hard-coded string.
But let's think about what else has happened:

- We've decided on an interface for our function, what it's going to receive and return;
- We've proved out a test setup that lets us make assertions on the behaviour of that function; and
- We've created the simplest possible implementation for the requirements we've expressed through tests so far, making our code very robust.

So let's build on that foundation; flip the shapes around to change the output so we can expect the test to fail.
Add the following into the `RpsTests` suite in `tests.py`:

```python
    def test_scissors_vs_rock_right_wins(self):
        left = "scissors"
        right = "rock"

        result = rps(left, right)

        self.assertEqual(result, "right")
```

Note that the _"Act"_ is the same, but the _"Arrange"_ and _"Assert"_ have changed.
Call the shot, then run the test again to see if you were correct:

```bash
$ python3 -m unittest
.F
======================================================================
FAIL: test_scissors_vs_rock_right_wins (tests.RpsTests.test_scissors_vs_rock_right_wins)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "path/to/rps-tdd/tests.py", line 24, in test_scissors_vs_rock_right_wins
    self.assertEqual(result, "right")
AssertionError: 'left' != 'right'
- left
+ right


----------------------------------------------------------------------
Ran 2 tests in 0.000s

FAILED (failures=1)
```

Read that through carefully.
What does it tell us?

 1. Our first test is still passing. That's good news, we haven't broken anything!
 2. Our second test fails, because it returns `"left"` but we want it to return `"right"`.

So, what's the simplest possible change that would get this test passing?
Think about it for a minute or two.

We're going to need some kind of _conditional logic_ here, because we return different results in different cases. 
However, we're supposed to be keeping things simple, so we don't want to leap all the way to a full implementation.
How about this:

```diff
 def rps(left, right):
-    return "left"
+    return "left" if left == "rock" else "right"
```

Call the shot, then run the test again to see if you were right:

```bash
$ python3 -m unittest
..
----------------------------------------------------------------------
Ran 2 tests in 0.000s

OK
```

Alright, two down, let's commit what we've done so far:

```bash
$ git commit -a -m 'Second test - scissors vs. rock'
[main 3a4c6bd] Second test - scissors vs. rock
 1 file changed, 9 insertions(+), 1 deletion(-)
```

We haven't created any new files since the last commit, so we can use the `-a`/`--all` flag to `git commit` to include changes to all files, instead of needing to `git add` anything.

## Third time's the charm [6/10]

We've handled both of the cases involving rock and scissors, so let's try this one, scissors cut paper:

```python
    def test_scissors_vs_paper_left_wins(self):
        left = "scissors"
        right = "paper"

        result = rps(left, right)

        self.assertEqual(result, "left")
```

Call the shot, then run the test again to see if you were right:

```bash
$ python3 -m unittest
.F.
======================================================================
FAIL: test_scissors_vs_paper_left_wins (tests.RpsTests.test_scissors_vs_paper_left_wins)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "path/to/rps-tdd/tests.py", line 32, in test_scissors_vs_paper_left_wins
    self.assertEqual(result, "left")
AssertionError: 'right' != 'left'
- right
+ left


----------------------------------------------------------------------
Ran 3 tests in 0.000s

FAILED (failures=1)
```

So how can we get this to pass?
We can no longer rely on the value of the first parameter alone, because we have two _different_ outputs where `left` is `"scissors"`, so we're going to have to check the `right` value.
For example:

```diff
 def rps(left, right):
-    return "left" if left == "rock" else "right"
+    return "right" if right == "rock" else "left"
```

Call the shot, then run the test again to see if you were right:

```bash
$ python3 -m unittest
...
----------------------------------------------------------------------
Ran 3 tests in 0.000s

OK
```

That's a successful outcome.
However, it seems a bit odd to have `"right"` on the left-hand side of the expression and `"left"` on the right-hand side.
So now we can **refactor**, keep the tests passing but change the implementation.
For example, how about:

```diff
 def rps(left, right):
-    return "right" if right == "rock" else "left"
+    return "left" if right != "rock" else "right"
```

Call the shot, then run the test again to see if you were right:

```bash
$ python3 -m unittest
...
----------------------------------------------------------------------
Ran 3 tests in 0.000s

OK
```

**Note** a third key benefit of TDD here - we know that the code still does exactly what it's supposed to even though we've just changed the implementation. This allows us to confidently refactor towards cleaner code and higher quality.
Let's treat ourselves to a commit:

```bash
$ git commit -a -m 'Third test - scissors vs. paper'
[main ee7c6f0] Third test - scissors vs. paper
 1 file changed, 9 insertions(+), 1 deletion(-)
```

## Are there any puns about four? [7/10]

Let's flip the last condition to cover the other case involving paper and scissors:

```python
    def test_paper_vs_scissors_right_wins(self):
        left = "paper"
        right = "scissors"

        result = rps(left, right)

        self.assertEqual(result, "right")
```

Call the shot, then run the test again to see if you were right:

```bash
$ python3 -m unittest
F...
======================================================================
FAIL: test_paper_vs_scissors_right_wins (tests.RpsTests.test_paper_vs_scissors_right_wins)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "path/to/rps-tdd/tests.py", line 40, in test_paper_vs_scissors_right_wins
    self.assertEqual(result, "right")
AssertionError: 'left' != 'right'
- left
+ right


----------------------------------------------------------------------
Ran 4 tests in 0.000s

FAILED (failures=1)
```

At this point we can no longer check one parameter or the other, we must check _both_.
For example:

```diff
 def rps(left, right):
-    return "left" if right != "rock" else "right"
+    return "left" if left != "paper" and right != "rock" else "right"
```

Call the shot, then run the test again to see if you were right:

```bash
$ python3 -m unittest
....
----------------------------------------------------------------------
Ran 4 tests in 0.000s

OK
```

More progress, let's commit this too:

```
$ git commit -a -m 'Fourth test - paper vs. scissors'
[main c34de33] Fourth test - paper vs. scissors
 1 file changed, 9 insertions(+), 1 deletion(-)
```

## Gift-wrapped rock [8/10]

At this point you can probably see what's coming next; paper wraps rock:

```python
    def test_paper_vs_rock_left_wins(self):
        left = "paper"
        right = "rock"

        result = rps(left, right)

        self.assertEqual(result, "left")
```

Call the shot, then run the test again to see if you were right:

```bash
$ python3 -m unittest
F....
======================================================================
FAIL: test_paper_vs_rock_left_wins (tests.RpsTests.test_paper_vs_rock_left_wins)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "path/to/rps-tdd/tests.py", line 48, in test_paper_vs_rock_left_wins
    self.assertEqual(result, "left")
AssertionError: 'right' != 'left'
- right
+ left


----------------------------------------------------------------------
Ran 5 tests in 0.000s

FAILED (failures=1)
```

Have a play with the implementation for a few minutes, see if you can come up with a way to write an implementation that passes all five tests.
Remember: write the code, call the shot, run the test, compare.

For example, you might get to something like:

```python
def rps(left, right):
    return (
        "left"
        if (left == "paper" and right == "rock")
        or (left != "paper" and right != "rock")
        else "right"
    )
```

Let's commit it and then flip to the last case:

```bash
$ git commit -a -m 'Fifth test - paper vs. rock'
[main 21cdaf8] Fifth test - paper vs. rock
 1 file changed, 14 insertions(+), 1 deletion(-)
```

```python
    def test_rock_vs_paper_right_wins(self):
        left = "rock"
        right = "paper"

        result = rps(left, right)

        self.assertEqual(result, "right")
```

Now we've reached a point where, however we try to rearrange it, we're _forced_ to be explicit about all of the cases. For example, we might write:

```python
def rps(left, right):
    return (
        "left"
        if (left == "rock" and right == "scissors")
        or (left == "paper" and right == "rock")
        or (left == "scissors" and right == "paper")
        else "right"
    )
```

How does this compare with how you imagined implementing it to begin with?
Let's save it.

```bash
$ git commit -a -m 'Sixth test - rock vs. paper'
[main 54c00b7] Sixth test - rock vs. paper
 1 file changed, 11 insertions(+), 2 deletions(-)
```

## Draw! [9/10]

So far we've assumed the two participants choose different values.
If you've played RPS, you'll know that's not always the case in real life - sometimes it's a draw.

This brings us to the idea of _parameterised testing_ - generating tests based on canned data.
`unittest` has built-in functionality to do this, named [`subTest`][python-unittest-subtest]:

```python
    def test_both_same_is_draw(self):
    for both in ["rock", "paper", "scissors"]:
        with self.subTest(both=both):
            result = rps(both, both)
            self.assertEqual(result, "draw")
```

Call the shot, run the tests, review the output then, if all of that makes sense, complete the implementation. Maybe something like:

```diff
 def rps(left, right):
+    if left == right:
+        return "draw"
     return (
         "left"
```

Once everything's passing and you're happy with your implementation, make the final commit:

```bash
$ git commit -a -m 'Handle the draw cases'
[main 95ed150] Handle the draw cases
 1 file changed, 8 insertions(+)
```

## Exercises [10/10] {#exercises}

Practice makes perfect! Here are some additional exercises you can run through:

 1. Repeat the process, but tackle the pairs in a different order. What impact does the order have on how and when your implementation gains complexity? Do you end up with a different implementation?

 2. Extend your implementation for [additional weapons] (e.g. Rock Paper Scissors Lizard Spock). How easy or hard is this?

     - **Advanced** - read about the _"open-closed principle"_, [OCP]. Can you refactor your code such that adding more weapons doesn't mean a change to the `rps` function?

 3. Test-drive out some validation - what should your code do if either or both of the inputs aren't recognised shapes? If you decide to throw an error, note that per [the docs][python-unittest-assert-raises] you need to use a _context manager_ to handle the exception: 

    ```
    with self.assertRaises(ValueError):
        rps("bananas", "apples")
    ```

 4. Refactor the tests to group the test cases into three parameterised tests: one for `"left"`; one for `"right"`; and one for `"draw"`.

 5. Run through the exercise with a different test framework, e.g. [pytest].

> **Once you're ready to move on**, check out [the next article] in this series where we'll cover testing of an API and discuss more about how tests drive design.

  [additional weapons]: https://en.wikipedia.org/wiki/Rock_paper_scissors#Additional_weapons
  [call the shot]: https://markhneedham.com/blog/2010/07/28/tdd-call-your-shots/
  [Git BASH]: https://gitforwindows.org/
  [js tdd ftw]: {filename}/development/js-tdd-ftw.md
  [OCP]: https://en.wikipedia.org/wiki/Open%E2%80%93closed_principle
  [pytest]: https://docs.pytest.org/en/stable/index.html
  [python]: https://www.python.org/
  [python-unittest]: https://docs.python.org/3/library/unittest.html
  [python-unittest-assert-methods]: https://docs.python.org/3/library/unittest.html#assert-methods
  [python-unittest-subtest]: https://docs.python.org/3/library/unittest.html#distinguishing-test-iterations-using-subtests
  [python-unittest-assert-raises]: https://docs.python.org/3/library/unittest.html#unittest.TestCase.assertRaises
  [Rock Paper Scissors]: https://en.wikipedia.org/wiki/Rock_paper_scissors
  [so-q16869024]: https://stackoverflow.com/q/16869024/3001761
  [so-q30154694]: https://stackoverflow.com/q/30154694/3001761
  [the next article]: {filename}/development/python-tdd-ohm.md
  [WSL]: https://docs.microsoft.com/en-us/windows/wsl/about
  [XP]: http://wiki.c2.com/?ExtremeProgramming
