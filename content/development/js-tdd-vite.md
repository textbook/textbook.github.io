Title: JS TDD Vite
Date: 2023-12-17 11:30
Tags: javascript, tdd, xp
Authors: Jonathan Sharpe
Summary: Test-driven JavaScript development done right - supplement A

Since I wrote some of the earlier parts of this series (see [part 2] and
[part 3]), [Create React App][cra] has become a little stale. As of right 
now, a brand new app shows multiple known vulnerabilities on installation:

```none
8 vulnerabilities (2 moderate, 6 high)

To address all issues (including breaking changes), run:
  npm audit fix --force

Run `npm audit` for details.
```
(this [isn't necessarily the problem][cra-npm-audit] it might appear, but 
likely wouldn't happen at all if the dependencies were kept up-to-date) and a
warning of imminent breakage on build (spelling error in original):

```none
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

(this is trivially fixable in your generated app, but has been known about 
for a while and still hasn't been fixed in CRA itself). The last available 
release, v5.0.1, dates back to April 12th, 2022 (~18 months ago and counting).
The [new React docs][react] don't even mention CRA. In this context, it 
might be time to think about moving away from CRA for new projects.

Probably the closest thing to a drop-in equivalent of CRA right now, in terms
of offering an opinionated client-side app setup, is [Vite]. So I thought I'd
provide a quick update to show how to get a React app ready for TDD on Vite.

**Note** that if a pure client-side/"single page" app doesn't meet your needs, 
there are some recommendations for more complex projects in the official React
docs [here][react-frameworks].

## Scaffolding the app \[1/5] {#part-1}

Create a new npm package with the Vite React structure using the following 
command (you can use the `react` or `react-swc` templates - there are also 
equivalents with TypeScript pre-configured if you like):

```bash
$ npm create vite@latest test-driven-vite -- --template react    
Need to install the following packages:
create-vite@5.1.0
Ok to proceed? (y) y

Scaffolding project in path/to/test-driven-vite...

Done. Now run:

  cd test-driven-vite
  npm install
  npm run dev
```

Follow the instructions it gave you:

```bash
$ cd test-driven-vite 
$ npm install

added 270 packages, and audited 271 packages in 35s

97 packages are looking for funding
  run `npm fund` for details

found 0 vulnerabilities
$ npm run dev

> test-driven-vite@0.0.0 dev
> vite


  VITE v5.0.10  ready in 5289 ms

  ➜  Local:   http://localhost:5173/
  ➜  Network: use --host to expose
  ➜  press h + enter to show help

```

This is roughly equivalent to scaffolding a new CRA app and running `npm 
start`; you should be able to visit the URL and see a basic app page. However,
there are a couple of things CRA did for us that `create-vite` doesn't, so
we'll need a few extra steps before we can start test-driving any real
functionality.

## Creating a git repo \[2/5] {#part-2}

Although the template does include a `.gitignore` file, a git repository is 
not created by default. If you try checking the status, you can see the 
directory doesn't contain one:

```bash
$ git status
fatal: not a git repository (or any of the parent directories): .git
```

So let's create a fresh git repo, as we did back in [part 1], then commit the 
files `create-vite` added for us:

```bash
$ git init
Reinitialized existing Git repository in path/to/test-driven-vite/.git/
$ git commit --allow-empty --message 'Initial commit'
[main (root-commit) cf3ac9f] Initial commit
$ git add .
$ git commit --message 'Create Vite app'
[main f9ab178] Create Vite app
 13 files changed, 4264 insertions(+)
 create mode 100644 .eslintrc.cjs
 # ... other files created
 create mode 100644 vite.config.js
```

Now all of our changes are safely under version control.

## Setting up testing \[3/5] {#part-3}

Another thing CRA included by default was a test, run with [Jest] and using 
[React Testing Library][rtl] to render and select elements. However, we can see 
that a new Vite app includes no test script at all:

```bash
$ npm t
npm ERR! Missing script: "test"
npm ERR! 
npm ERR! To see a list of scripts, run:
npm ERR!   npm run

npm ERR! A complete log of this run can be found in: path/to/something.log
```

As an alternative to Jest, there's [Vitest]. This test runner uses the same 
build tooling as Vite, and has API compatibility with Jest (so everything you
learned about `it`, `expect`, etc. still applies).

So let's install this, as well as JSDOM (which allows the components to be 
rendered outside of a real browser environment - this was installed as part 
of `jest-environment-jsdom` by CRA) and the same Testing Library utilities
we've used previously.

```bash
$ npm install --save-dev @testing-library/{jest-dom,react,user-event} jsdom vitest                 

added 129 packages, and audited 400 packages in 1s

124 packages are looking for funding
  run `npm fund` for details

found 0 vulnerabilities
```

We need a little bit of additional configuration in `vite.config.js`:

```diff
 export default defineConfig({
   plugins: [react()],
+  test: {
+    environment: 'jsdom',
+    globals: true,
+    setupFiles: [
+      '@testing-library/jest-dom',
+    ],
+  },
 })
```

This will:

1. Use the JSDOM test environment, to allow browser-based code to work;
2. Inject some global functions (e.g. `describe` and `it`) into the tests, as 
   Jest does; and
3. Load Testing Library's [Jest-DOM] selectors (like `.toHaveAttribute`), so we 
   can make assertions on the rendered elements.

Finally, let's tell npm we want to use Vitest to run our tests:

```bash
$ npm pkg set scripts.test='vitest'
```

Like Jest, Vitest will fail if you try to run it when there are no actual tests:

```bash
$ npm t

> test-driven-vite@0.0.0 test
> vitest


 DEV  v1.0.4 path/to/test-driven-vite

include: **/*.{test,spec}.?(c|m)[jt]s?(x)
exclude:  **/node_modules/**, **/dist/**, **/cypress/**, **/.{idea,git,cache,output,temp}/**, **/{karma,rollup,webpack,vite,vitest,jest,ava,babel,nyc,cypress,tsup,build,eslint,prettier}.config.*
watch exclude:  **/node_modules/**, **/dist/**

No test files found, exiting with code 1
```

## Writing a test \[4/5] {#part-4}

So let's create one, in `src/App.spec.jsx`. Pick some aspect of the page 
that gets rendered (in this case I've chosen the main heading that's shown) and 
write a simple test for it:

```javascript
import { render, screen } from '@testing-library/react'

import App from './App.jsx'

describe('App', () => {
  it('renders a top-level heading', async () => {
    render(<App />)

    expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent('Vite + React')
  })
})

```

As you can see, this looks identical to the sort of thing we had in Jest. 
When we run it, it should pass:

```bash
$  npm test

> test-driven-vite@0.0.0 test
> vitest


 DEV  v1.0.4 path/to/test-driven-vite

 ✓ src/App.spec.jsx (1)
   ✓ App (1)
     ✓ renders a top-level heading

 Test Files  1 passed (1)
      Tests  1 passed (1)
   Start at  00:09:12
   Duration  664ms (transform 30ms, setup 89ms, collect 85ms, tests 41ms, environment 277ms, prepare 63ms)


 PASS  Waiting for file changes...
       press h to show help, press q to quit
```
**Note** that like the default CRA Jest setup, Vitest enters a watch mode by 
default. To run the tests once then stop, use `npm test -- --run`.

Quit the test runner when you're satisfied everything is working, then commit 
the changes:

```bash
$ git add .
$ git status
On branch main
Changes to be committed:
  (use "git restore --staged <file>..." to unstage)
        modified:   package-lock.json
        modified:   package.json
        new file:   src/App.spec.jsx
        modified:   vite.config.js

$ git commit --message 'Add a simple test'
[main 2431a65] Add a simple test
 4 files changed, 1619 insertions(+), 51 deletions(-)
 create mode 100644 src/App.spec.jsx
```

## Exercises \[5/5] {#part-5}

This was just a supplement, so the exercise is pretty simple: redo an earlier 
exercise in the series, using Vite/Vitest instead of CRA/Jest.

**Note** that you can set up Cypress exactly as you did before - the 
end-to-end tests don't care what (if any) library or framework you're using 
to create the page. If you follow the guide from [part 3] on creating the 
`e2e:ci` _"automatic E2E"_, you don't need to install `serve` to test the 
app in production mode; `vite preview` already does this:

```json5
{
  // ...
  "scripts": {
    // ...
    "e2e:ci": "concurrently --kill-others --success first \"npm:e2e:ci:*\"",
    "pree2e:ci:app": "npm run build",
    "e2e:ci:app": "npm run preview",
    "pree2e:ci:run": "wait-on --log --timeout 60000 http-get://localhost:4173",
    "e2e:ci:run": "cross-env CYPRESS_BASE_URL=http://localhost:4173 npm run e2e",
    // ...
  },
  // ...
}
```

## To global, or not to global? \[Bonus] {#bonus}

By default, Vitest does **not** inject anything into the global scope. To keep 
things as similar to Jest as possible, we've overridden this with
`globals: true` above. Alternatively you could choose the more explicit option, 
and omit `globals: true` (or explicitly set `globals: false`) in the
configuration. But if you do that, you'll need to make some other adjustments:

1. Firstly, and most obviously, every test file will have to explicitly 
   import the functions it needs for defining suites, tests and expectations:

        :::javascript
        import { describe, expect, it } from 'vitest'

 2. Secondly, the default entrypoint for `@testing-library/jest-dom` that we 
    used in `setupFiles` assumes that `expect` will be provided globally. Now 
    that it won't be, we have to switch to the Vitest-specific entrypoint 
    `@testing-library/jest-dom/vitest`, which includes an explicit:

        :::javascript
        import {expect} from 'vitest'

    before extending `expect` with its own matchers.

 3. Finally, React Testing Library's [automatic application of
    `cleanup`][rtl-cleanup] only occurs if there's a globally-provided 
    `afterEach` function for it to hook into. This is explicitly called out in
    the [Vitest migration guide][vitest-migration]:

    > If you decide to keep globals disabled, be aware that common libraries
    > like `testing-library` will not run auto DOM cleanup.
    
    Without this, each test is adding more and more elements into the render
    result, which means your tests can interfere with each other (most likely
    with error messages about matching more than one element when only one is
    expected, but even worse a test could incorrectly _pass_ due to something
    that was rendered by a previous one still hanging around).

We can deal with 2 and 3 simultaneously by changing the configuration to:

```diff
   plugins: [react()],
   test: {
     environment: 'jsdom',
-    globals: true,
     setupFiles: [
-      '@testing-library/jest-dom'
+      './src/setupTests.js'
     ],
   },
 })
```

and creating the corresponding `src/setupTests.js` file containing:

```javascript
import '@testing-library/jest-dom/vitest'
import { cleanup } from '@testing-library/react'
import { afterEach } from 'vitest'

afterEach(() => {
  cleanup()
})
```

[cra]: https://create-react-app.dev/
[cra-npm-audit]: https://github.com/facebook/create-react-app/issues/11174
[jest]: https://jestjs.io/
[jest-dom]: https://testing-library.com/docs/ecosystem-jest-dom/
[part 1]: {filename}/development/js-tdd-ftw.md
[part 2]: {filename}/development/js-tdd-e2e.md
[part 3]: {filename}/development/js-tdd-api.md
[react]: https://react.dev/
[react-frameworks]: https://react.dev/learn/start-a-new-react-project
[rtl]: https://testing-library.com/docs/react-testing-library/intro
[rtl-cleanup]: https://testing-library.com/docs/react-testing-library/api#cleanup
[vite]: https://vitejs.dev/
[vitest]: https://vitest.dev/
[vitest-migration]: https://vitest.dev/
