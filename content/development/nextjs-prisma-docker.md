Title: Next.js and Prisma in Docker
Date: 2024-12-24 11:30
Modified: 2024-12-24 12:00
Tags: javascript, docker, ci
Authors: Jonathan Sharpe
Summary: Containerisation patterns for a Next.js + Prisma full-stack application.

For my work with [CodeYourFuture], earlier this year I helped one of the product teams I work with to put together a `Dockerfile` for their application, which was based on [Next.js][next] and [Prisma].
This proved to be a little trickier than I'd anticipated, so I wanted to document what we figured out.

This is going to focus on building a simple app, designed to be deployed as a single container to e.g. a Kubernetes cluster, but the commentary should help signpost where updates are needed for other deployment topologies.

## Create Next.js app

To start off let's create a brand new Next.js project:

```shell
npx create-next-app@latest
```

Make your own selections for TypeScript, [app vs. pages routing][next-app-vs-pages], whether to apply ESLint, etc.
But I would recommend using the [`src/` directory][next-src], as this simplifies copying your code into the container later on.

### npm configuration

For the sake of stable, reproducible builds, you can then add an explicit [`engines` field][npm-engines], e.g. by running:

```bash
$ npm pkg set 'engines.node=^22.11'
$ npm install --package-lock-only  # sync package-lock.json
```

which will update `package.json` as follows:

```diff
+   },
+   "engines": {
+     "node": "^22.11"
    }
  }
```

Next tell npm you want it to validate the Node version when e.g. installing dependencies:

```bash
$ npm config --location=project set engine-strict=true
```

which creates an `.npmrc` file containing:

```ini
engine-strict=true
```

### Build output types

The first trick to a good Next.js image is to leverage [standalone mode][next-standalone], where it creates (in `.next/standalone`) an app that can be deployed as-is, including only the dependencies required at runtime in a cut-down `node_modules/`.
To enable this mode, update `next.config.mjs` as follows:

```diff
  /** @type {import('next').NextConfig} */
- const nextConfig = {};
+ const nextConfig = {
+   output: 'standalone',
+ };
  
  export default nextConfig;
```

Now when you run the build:

```bash
$ npm run build

> demo-app@0.1.0 build
> next build

   ▲ Next.js 15.1.2

   Creating an optimized production build ...
 ✓ Compiled successfully
 ✓ Linting and checking validity of types    
 ✓ Collecting page data    
 ✓ Generating static pages (5/5)
 ✓ Collecting build traces    
 ✓ Finalizing page optimization    

Route (app)                              Size     First Load JS
┌ ○ /                                    5.62 kB         111 kB
└ ○ /_not-found                          979 B           106 kB
+ First Load JS shared by all            105 kB
  ├ chunks/4bd1b696-20882bf820444624.js  52.9 kB
  ├ chunks/517-cf5b1ec733e34704.js       50.5 kB
  └ other shared chunks (total)          1.89 kB


○  (Static)  prerendered as static content

```

you can test out the standalone app by running its `server.js` entrypoint:

```bash
$ node .next/standalone/server.js
   ▲ Next.js 15.1.2
   - Local:        http://localhost:3000
   - Network:      http://0.0.0.0:3000

 ✓ Starting...
 ✓ Ready in 78ms
```

If you _visit_ that site, though, it will look a little bit weird:

[![Screenshot of an empty Next.js standalone app][next-standalone-image]][next-standalone-image]

Next.js separates out the `public/` and `.next/static/` directories, intending these to be served separately via CDN; we'll deal with this when building the Docker image.

## Next.js Docker image

Next.js does have [a page][next-docker] on deploying in Docker, which points to some examples.
We'll work through [this example][next-dockerfile] section by section, with some changes I've added on top based on my own experience and the [Docker and Node.js Best Practices][node-best-practice].

```dockerfile
FROM node:18-alpine AS base

# Install dependencies only when needed
FROM base AS deps
# Check https://github.com/nodejs/docker-node/tree/b4117f9333da4138b03a546ec926ef50a31506c3#nodealpine to understand why libc6-compat might be needed.
RUN apk add --no-cache libc6-compat
WORKDIR /app

# Install dependencies based on the preferred package manager
COPY package.json yarn.lock* package-lock.json* pnpm-lock.yaml* ./
RUN \
  if [ -f yarn.lock ]; then yarn --frozen-lockfile; \
  elif [ -f package-lock.json ]; then npm ci; \
  elif [ -f pnpm-lock.yaml ]; then corepack enable pnpm && pnpm i --frozen-lockfile; \
  else echo "Lockfile not found." && exit 1; \
  fi


# Rebuild the source code only when needed
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Next.js collects completely anonymous telemetry data about general usage.
# Learn more here: https://nextjs.org/telemetry
# Uncomment the following line in case you want to disable telemetry during the build.
# ENV NEXT_TELEMETRY_DISABLED 1

RUN \
  if [ -f yarn.lock ]; then yarn run build; \
  elif [ -f package-lock.json ]; then npm run build; \
  elif [ -f pnpm-lock.yaml ]; then corepack enable pnpm && pnpm run build; \
  else echo "Lockfile not found." && exit 1; \
  fi

# Production image, copy all the files and run next
FROM base AS runner
WORKDIR /app

ENV NODE_ENV production
# Uncomment the following line in case you want to disable telemetry during runtime.
# ENV NEXT_TELEMETRY_DISABLED 1

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public

# Set the correct permission for prerender cache
RUN mkdir .next
RUN chown nextjs:nodejs .next

# Automatically leverage output traces to reduce image size
# https://nextjs.org/docs/advanced-features/output-file-tracing
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000

ENV PORT 3000

# server.js is created by next build from the standalone output
# https://nextjs.org/docs/pages/api-reference/next-config-js/output
CMD HOSTNAME="0.0.0.0" node server.js
```

This uses a good pattern for building Docker images, a [multi-stage build][docker-multi-stage], to maximise the efficiency of Docker's layer caching and keep the final artifact as small as possible.
However, it also includes some unnecessary steps and complexity that practical builds will not need.

### Setting up the image

For the sake of efficiency, reducing the number of files copied into the [build context][docker-build-context], create a `.dockerignore` file containing:

```none
.next/
node_modules/
```

Then the first stage in our `Dockerfile` will be defining a consistent base image:

```dockerfile
ARG NODE_VERSION=jod

FROM node:${NODE_VERSION}-alpine AS base
```

Specifying the `NODE_VERSION` [build `ARG`][docker-build-arg] allows the Node version to be overridden at build time with the `--build-arg` flag.
For example, one way to utilise this if you have a [`.nvmrc`][nvm-rcfile] file to manage your Node versions is to `docker build --build-arg "NODE_VERSION=$(cat .nvmrc)" ...`.
It defaults to the latest release of the current LTS (long-term support) version, Node 22 "Jod" (a common German-derived name for [iodine], in keeping with the "elements" naming theme), rather than the older Node 18 "Hydrogen" line.

We then use this version with the `-alpine` variant, built on [Alpine Linux][alpine], which leads to much smaller images than the default Debian-based images (e.g. `node:22.12.0` on Debian 12 "Bookworm" is 1.6GB, whereas `node:22.12.0-alpine` is 221MB).
This can _occasionally_ cause build problems; see the official notes [here][node-docker-alpine] and consider either adding the compatibility libraries or switching to the `-slim` variant (341MB for the same Node.js version) if you have an issue.

### Building the application

Splitting up dependency installation and building into two separate stages seems unnecessary here.
The advantage of having a separate dependency stage is that when you copy the `node_modules/` through you don't also get npm's _cache_ of files it downloaded.
But here we're only going to copy `.next/standalone` (which has its own `node_modules/`) and a few other selected directories into the last stage anyway.

So we're going to use the `base` image directly and install the dependencies with npm's ["clean install"][npm-clean-install] (which follows the lockfile exactly and bails out if it's missing or out-of-sync).
```dockerfile
FROM base AS builder

WORKDIR /app

COPY .npmrc package*.json ./
RUN npm --no-fund --no-update-notifier ci
```

Note that we **only** copy in the relevant files for npm (`.npmrc`, `package.json` and `package-lock.json`) before installing the dependencies.
This allows Docker to _cache_ the installation layer, such that it only re-runs the installation process if one of those three files changes.
For changes to the app code that _don't_ involve changing the dependencies, this means much faster rebuilds.

We don't bother with the conditional logic to handle multiple possible package managers, just including the one that's relevant for the current project.
Setting the [`fund`][npm-fund] and [`update-notifier`][npm-update-notifier] flags disables the _"packages are looking for funding"_ and _"New minor version of npm available!"_ messages, which aren't relevant in a non-interactive context.

With our dependencies available, we can re-run the build, this time _inside_ the container we're building:

```dockerfile
COPY public/ ./public
COPY src/ ./src
COPY next.config.mjs ./
RUN NEXT_TELEMETRY_DISABLED=1 npm run build
```

Again only the necessary files are copied in before the build takes place, so the layers can be cached appropriately - this is why the `src/` directory option was recommended above, it's much simpler than copying in multiple directories (`app/`, `components/`, `lib/`, etc.) when using common [organisation patterns][next-organisation].

**Note** if you have issues due to missing build tools during install or build, you may need to add `RUN apk add --no-cache libc6-compat` back in at the start of this stage.

### Creating the final image

```dockerfile
FROM base AS app

RUN apk add --no-cache tini

WORKDIR /app

COPY --from=builder --chown=node /app/.next/standalone ./
COPY --from=builder --chown=node /app/.next/static ./.next/static
COPY --from=builder --chown=node /app/public ./public

COPY start.sh /usr/local/bin

ENV HOSTNAME=0.0.0.0
ENV NEXT_TELEMETRY_DISABLED=1
ENV NODE_ENV=production
ENV PORT=3000

EXPOSE 3000

USER node

ENTRYPOINT [ "start.sh" ]
```

Node.js is [not designed][node-kernel-signals] to be run as the root process, we start by adding [`tini`][tini] to run it (this is built into Docker as of v1.13, but other environments might not have it).

As previously mentioned a standalone build is set up for some files to be deployed from a CDN, but we want a single deployment artifact. So from the previous stage we copy all of:

- The standalone build itself, `.next/standalone/`, including the server and minimal dependencies;
- The static outputs, `.next/static/`, e.g. compiled client-side JS and CSS; and
- The public directory, `public/`, for static assets like images and e.g. `robots.txt`.

These are all colocated in the same directory, so Next.js can find and serve these assets alongside API endpoints.
As each one is copied in, its ownership is allocated to the [non-root user][node-non-root-user] so the container can run under the [principle of least privilege][polp].
However, we don't need to create another non-root user and associated group specifically for Next.js.

Once we have the build outputs, we add a script to actually start the application when the container is created.
That script, `start.sh`, should look like:

```shell
#!/bin/sh
set -ex

exec /sbin/tini -- node server.js
```

Ensure this script is user-executable by running `chmod u+x start.sh` once you've created it. 
So far this is pretty minimal, all it does is:

1. Declare the appropriate script type with a [shebang];
2. Set some basic flags to exit the shell script if any individual step has an error (`-e`) and print out each command before running it (`-x`); and
3. Use the aforementioned `tini` to run our server with Node.js.

By copying it into `/usr/local/bin` it's available on the `PATH`, hence the initial entrypoint of the container can simply be `start.sh`.

Next we set some environment variables, to give the app appropriate configuration for running in the container, plus some metadata to tell other tools what ports will be exposed.
Finally we switch to the non-root user, as discussed above, and declare the script as the default entrypoint.

### Testing the container

```bash
# Build the image
$ docker build --tag 'nextjs-image' .

# Run the image
$ docker run --publish 3000:3000 'nextjs-image'
```

While the app is running with the default entrypoint, you can visit the app on localhost at port 3000; it should now appear with the correct styling and images.

## Prisma

Prisma is an ORM (object-relational mapper) - you describe the shape of your data (in `schema.prisma`) and it handles validating, storing and retrieving objects in the database.
It generates a type-safe client (using TypeScript types) matching your schema, to give better IDE support while interacting with the database.
It also generates migrations for you, so that as you [evolve][martin-fowler-evodb] your schema you can keep databases in different environments up-to-date.

### Installation

We can add Prisma to the app by following the [quickstart][prisma-quickstart] - I'm using Postgres, but other providers are also supported:

```bash
# Install Prisma CLI
$ npm install prisma --save-dev

# Set up basic structure
npx prisma init --datasource-provider postgresql
```

Here you can already see hints of the first conflict:

```bash
warn You already have a .gitignore file. Don't forget to add `.env` in it to not commit any private information.

Next steps:
1. Set the DATABASE_URL in the .env file to point to your existing database. ...
```

Whereas Next.js handles [multiple `.env` files][next-dotenv], Prisma assumes [only `.env`][prisma-dotenv] will exist (although it checks for it in a few locations).
Also Next.js assumes that only the `.local` versions of the files should be considered secret.
It includes the following in `.gitignore`:

```gitignore
# env files (can opt-in for committing if needed)
.env*
```

but adds in the documentation:

> **Good to know**: `.env`, `.env.development`, and `.env.production` files should be included in your repository as they define defaults.
> All `.env` files are excluded in `.gitignore` by default, allowing you to opt-into committing these values to your repository.

By contrast, Prisma suggests placing your `DATABASE_URL`, which should not be tracked, in a _non_-`.local` `.env` file.
To deal with this:

- Rename the `.env` file Prisma created to `.env.local`;
- Install `dotenv-cli`, as Prisma's [docs][prisma-managing-env-files] recommend; and
- Add a helper script entrypoint to run Prisma with the `-c`ascading env files loaded.

```bash
$ mv .env{,.local}
$ npm install dotenv-cli
$ npm pkg set 'scripts.prisma=dotenv -c -- prisma'
```

Update `.env.local` to set up a valid connection string for whichever data source you've selected.
Now e.g. `npm run prisma -- migrate dev` will try to set up the configured DB:

```bash
$ npm run prisma -- migrate dev

> my-app@0.1.0 prisma
> dotenv -c -- prisma migrate dev

Prisma schema loaded from prisma/schema.prisma
Datasource "db": PostgreSQL database "prisma", schema "public" at "localhost:5432"

Already in sync, no schema change or pending migration was found.

Running generate... (Use --skip-generate to skip the generators)
Error: 
You don't have any models defined in your schema.prisma, so nothing will be generated.
You can define a model like this:

model User {
  id    Int     @id @default(autoincrement())
  email String  @unique
  name  String?
}

More information in our documentation:
https://pris.ly/d/prisma-schema
```

Add the suggested `User` model to `prisma/schema.prisma`, then re-run the dev migration command - when prompted, enter e.g. _"create user"_ as the migration name.
Something like the following will be generated in `prisma/migrations/<timestamp>_create_user.sql`:

```sql
-- CreateTable
CREATE TABLE "User" (
    "id" SERIAL NOT NULL,
    "email" TEXT NOT NULL,
    "name" TEXT,

    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "User_email_key" ON "User"("email");
```
and you'll be told:

```
Your database is now in sync with your schema.
```

Add a [`pre-` script][npm-pre-post-script] to ensure the Prisma client is always regenerated when the app is built, then re-run the Next.js build:

```bash
$ npm pkg set 'scripts.prebuild=prisma generate'
$ npm run build
```

In `src/app/api/users/route.js`, write the following:

```javascript
import { PrismaClient } from "@prisma/client";

export async function GET() {
  const users = await new PrismaClient().user.findMany();
  return Response.json({ users });
}
```

Note that `.user` is autocompleted by your IDE; this is the benefit of `prisma generate`-ing the client, which includes type definitions, from the schema.
If you `npm run dev`, you should be able to both visit the home page and hit this new API endpoint:

```bash
$ curl --silent 'http://localhost:3000/api/users'
{"users": []}
```

As we're now using the Prisma client in the Next.js code, when you re-run `npm run build` your `.next/standalone/node_modules/` should now include `.prisma/` (the generated client) and `@prisma/` (the core library).
We also want to make sure the Prisma files are available at image build time, so the client can be generated.
In the `Dockerfile`, add:

```diff
  RUN npm --no-fund --no-update-notifier ci
  
+ COPY prisma/ ./prisma
  COPY public/ ./public
```

### Aside: Next.js 14

When we try to `docker build` the container, if using Next.js v14, it fails:

```bash
11.29 Error occurred prerendering page "/api/users". Read more: https://nextjs.org/docs/messages/prerender-error
11.29 
11.29 PrismaClientInitializationError: 
11.29 Invalid `prisma.user.findMany()` invocation:
11.29 
11.29 
11.29 error: Environment variable not found: DATABASE_URL.
11.29   -->  schema.prisma:13
11.29    | 
11.29 12 |   provider = "postgresql"
11.29 13 |   url      = env("DATABASE_URL")
11.29    | 
11.29 
11.29 Validation Error Count: 1
```

To be able to pre-render and cache all of the API routes, Next.js tries to invoke them all at build time.
As that now involves retrieving user records from the database, Prisma is trying to do just that.
Inside the container, though, no connection string for the database is available, so it bails out and the build fails.

It's possible to solve this by adding another [build argument][docker-build-arg], allowing this to be passed in (`docker build --build-arg DATABASE_URL=... ...`).
_"Baking in"_ database credentials like this can be a serious security vulnerability - in this case, as it's only in an intermediate stage, it's not so risky, but it's still not a good practice.
We could provide more protection by treating it as a [build secret][docker-build-secret], but ideally we want to have a single artifact we can test in and promote between different environments (I expand on the reasons for this [here]({filename}/development/spa-config.md)).

So to force Next.js _not_ to pre-render API routes that need to hit the database for data, [opt out of caching][next-route-caching-opt-out].
For example, add the [config][next-route-segment-config]:

```diff
  import { PrismaClient } from "@prisma/client";
+ 
+ export const dynamic = "force-dynamic";
  
  export async function GET() {
```

Now the build should work just fine.
In Node.js v15, the caching is opted out of [by default][next-changelog-caching], and you have to opt back in as needed.

### Migrations

The Prisma files now need to be copied through to the final image so they're available at runtime for the migrations:

```diff
  COPY --from=builder --chown=node /app/.next/static ./.next/static
+ COPY --from=builder --chown=node /app/prisma ./prisma
  COPY --from=builder --chown=node /app/public ./public
  
  COPY start.sh /usr/local/bin

+ ENV CHECKPOINT_DISABLE=1
+ ENV DISABLE_PRISMA_TELEMETRY=true
  ENV HOSTNAME=0.0.0.0
```

which we can add to the start script:

```diff
  set -ex
+  
+ npx --no-update-notifier prisma migrate deploy

  exec /sbin/tini -- node server.js
```

But when we rebuild and _run_ the container, although it tries to apply the migrations, there are two problems:

```bash
npm warn exec The following package was not found and will be installed: prisma@5.14.0
Prisma schema loaded from prisma/schema.prisma
Datasource "db": PostgreSQL database

Error: Prisma schema validation - (get-config wasm)
Error code: P1012
error: Environment variable not found: DATABASE_URL.
  -->  prisma/schema.prisma:13
   | 
12 |   provider = "postgresql"
13 |   url      = env("DATABASE_URL")
   | 

Validation Error Count: 1
```

1. The first problem is that `npx` is installing Prisma CLI, _at container start time_. This both:
    - Slows down starting the container; and
    - Risks version drift between `@prisma/client` and `prisma`, which could cause hard-to-debug problems; and
2. The second problem is that, like at build time, the database connection string isn't available.

To fix the first one, we want to install the right version of Prisma CLI _at build time_.
As this dependency isn't used at runtime, the output tracing won't include it in `.next/standalone/node_modules`, and the version in `package.json` will generally be a semver range rather than specific.
But `@prisma/client` _is_ included, and we know we want the same version, so we can look that up from the package file:

```diff
  COPY --from=builder --chown=node /app/public ./public
+ 
+ RUN npm install --global --save-exact "prisma@$(node --print 'require("./node_modules/@prisma/client/package.json").version')"
  
  COPY start.sh /usr/local/bin
```

You can check that this does the right thing by rebuilding, then using the CLI as the container entrypoint:

```bash
$ docker run --entrypoint prisma 'nextjs-image' version
prisma                  : 6.1.0
@prisma/client          : 6.1.0
# ...
```

To fix the second problem, provide the connection string when starting the container, e.g.:

```bash
$ docker run --env 'DATABASE_URL=...' 'nextjs-image'
```

(**Note** that if you want it to use a database on your local machine, you'll probably have to [replace `localhost`][docker-host-service] with `host.docker.internal`.)

## Run the container

You should now be able to run the final container, and expose it on your local network:

```bash
$ docker run --env 'DATABASE_URL=...' --publish 3000:3000 nextjs-image
+ npx --no-update-notifier prisma migrate deploy
Prisma schema loaded from prisma/schema.prisma
Datasource "db": PostgreSQL database "prisma", schema "public" at "host.docker.internal:5432"

1 migration found in prisma/migrations


No pending migrations to apply.
+ exec /sbin/tini -- node server.js
   ▲ Next.js 15.1.2
   - Local:        http://localhost:3000
   - Network:      http://0.0.0.0:3000

 ✓ Starting...
 ✓ Ready in 57ms
```

Have a play with it - visit the home page, hit the `/api/users` endpoint, and everything should work fine.
This is now ready for deployment to any container runtime!

## More complex topologies

As mentioned above, this setup is for a fairly simple Next.js container; it can run happily as a single instance.
If you need high performance and availability, consider:

- Serving the public and static asset directories from a static file server or CDN, rather than Node.js.
- Running migrations in a separate [init container], rather than when the main container starts up.
    - This reduces the possibility of race conditions around the migrations if you're running multiple instances.
    - Installing the Prisma CLI seems to add substantially to the image size, so having a separate container for this would also lead to faster image pulls.
- Ensuring you have appropriate logging - Next.js doesn't output anything after the startup message, in production mode.

## Docker tools \[Bonus]

If you're new to working with Docker containers, I'd recommend the following to allow you to explore in detail what's happening:

- During the `docker build` process, you can see more of the logs by passing `--progress plain` - this outputs everything into your terminal, rather than just scrolling through a few lines of each step and leaving the summary.

- `docker run --entrypoint sh --interactive --tty <tag>` (or replace `--interactive --tty` with simply `-it`) runs a simple shell inside your container, so you can explore what's there with e.g. `ls` and `cat`.

    **Note** that `sh` on Alpine Linux is [`ash`][ash] by default, rather than e.g. `bash` (Ubuntu) or `zsh` (macOS).

- [dive] describes itself as:

    > A tool for exploring a docker image, layer contents, and discovering ways to shrink the size of your Docker/OCI image.

    It gives a very helpful text representation of each layer in your image, showing step-by-step where files are added.

[alpine]: https://www.alpinelinux.org/
[ash]: https://en.wikipedia.org/wiki/Almquist_shell
[codeyourfuture]: https://codeyourfuture.io/
[dive]: https://github.com/wagoodman/dive
[docker-build-arg]: https://docs.docker.com/build/guide/build-args/
[docker-build-context]: https://docs.docker.com/build/building/context/
[docker-build-secret]: https://docs.docker.com/build/building/secrets/
[docker-host-service]: https://docs.docker.com/desktop/networking/#i-want-to-connect-from-a-container-to-a-service-on-the-host
[docker-multi-stage]: https://docs.docker.com/build/building/multi-stage/
[init container]: https://kubernetes.io/docs/concepts/workloads/pods/init-containers/
[iodine]: https://en.wikipedia.org/wiki/Iodine
[martin-fowler-evodb]: https://martinfowler.com/articles/evodb.html
[next]: https://nextjs.org/
[next-app-vs-pages]: https://nextjs.org/docs#app-router-vs-pages-router
[next-changelog-caching]: https://nextjs.org/blog/next-15#caching-semantics
[next-docker]: https://nextjs.org/docs/pages/building-your-application/deploying#docker-image
[next-dockerfile]: https://github.com/vercel/next.js/blob/430e71a38db549e99d8daad2caac160316aa30a1/examples/with-docker/Dockerfile
[next-dotenv]: https://nextjs.org/docs/pages/building-your-application/configuring/environment-variables
[next-organisation]: https://nextjs.org/docs/app/building-your-application/routing/colocation#store-project-files-outside-of-app
[next-route-caching-opt-out]: https://nextjs.org/docs/14/app/building-your-application/routing/route-handlers#opting-out-of-caching
[next-route-segment-config]: https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config#dynamic
[next-src]: https://nextjs.org/docs/app/building-your-application/configuring/src-directory
[next-standalone]: https://nextjs.org/docs/app/api-reference/next-config-js/output#automatically-copying-traced-files
[next-standalone-image]: {static}/images/next-standalone.png
[next-telemetry]: https://nextjs.org/telemetry
[npm-clean-install]: https://docs.npmjs.com/cli/v10/commands/npm-ci
[npm-engines]: https://docs.npmjs.com/cli/v10/configuring-npm/package-json#engines
[npm-fund]: https://docs.npmjs.com/cli/v10/using-npm/config#fund
[npm-pre-post-script]: https://docs.npmjs.com/cli/v10/using-npm/scripts?v=true#pre--post-scripts
[npm-update-notifier]: https://docs.npmjs.com/cli/v10/using-npm/config#update-notifier
[node-best-practice]: https://github.com/nodejs/docker-node/blob/1ed1dd596c1f074bbfe907381e8b7f28866faa54/docs/BestPractices.md
[node-docker-alpine]: https://github.com/nodejs/docker-node/tree/1ed1dd596c1f074bbfe907381e8b7f28866faa54?tab=readme-ov-file#nodealpine
[node-kernel-signals]: https://github.com/nodejs/docker-node/blob/main/docs/BestPractices.md#handling-kernel-signals
[node-non-root-user]: https://github.com/nodejs/docker-node/blob/main/docs/BestPractices.md#non-root-user
[nvm-rcfile]: https://github.com/nvm-sh/nvm?tab=readme-ov-file#nvmrc
[polp]: https://en.wikipedia.org/wiki/Principle_of_least_privilege
[prisma]: https://www.prisma.io/
[prisma-dotenv]: https://www.prisma.io/docs/orm/more/development-environment/environment-variables/env-files
[prisma-managing-env-files]: https://www.prisma.io/docs/orm/more/development-environment/environment-variables/managing-env-files-and-setting-variables#manage-env-files-manually
[prisma-quickstart]: https://www.prisma.io/docs/getting-started/quickstart
[shebang]: https://en.wikipedia.org/wiki/Shebang_(Unix)
[tini]: https://github.com/krallin/tini
