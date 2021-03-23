Title: Runtime configuration for single-page apps
Date: 2020-09-19 15:15
Modified: 2021-03-21 20:00
Tags: xp, ci, angular, react
Authors: Jonathan Sharpe
Summary: Tips and tricks for deploying JavaScript SPAs with runtime configuration

## Setting the scene

Let's imagine the following scenario: you are working on a single-page app (SPA) that's part of a larger system. Could be Angular, React, Svelte, Vue, ... that doesn't really matter. What *does* matter is:

  - that it builds to HTML, CSS and JS; 
  - that those assets are deployed statically (i.e. *not* serving them from the same app that provides the backend APIs or using SSR to generate them at runtime, so you don't have access to environment variables);
  - that you're deploying to multiple different environments (e.g. acceptance, staging and production); and
  - that it needs some kind of configuration (e.g. URLs for relevant backend services) to run correctly that varies across the different environments.

This is quite a common problem, but it has tripped up a few teams I've worked with. The typical approach to per-environment configuration, setting environment variables that the app can access, isn't effective here. Because the assets are static files and the deployment environment is just a basic web server, it's not clear how to get the content from those environment variables into the assets. The SPA itself is actually running in your client's browser, which doesn't have access to the server-side environment at all.

**Note**: because I work for [VMware Tanzu Labs][4] and this is the technology I'm most familiar with using for these apps, the practical examples will be based around deployment to the [staticfile buildpack][5] on [Tanzu Application Service][6] (TAS). However, the patterns can be applied to whatever deployment environment you're using.

## Build-time configuration

One pattern that's used in e.g. React [custom environment variables][1] (using Webpack's [`DefinePlugin`][16]) and Angular [application environments][2] is injecting the configuration at _build_ time. The appropriate settings are taken from the environment or specific files and baked in when you create the static assets. This means that you have multiple _different_ sets of assets per commit, one for each environment you need to deploy to. You have two choices:

 1. These are all built at the same time from the same versions of the dependencies and stored in an artifact repository. This means holding and managing multiple (mostly identical) copies, some of which may never actually get used. But storage is cheap and the alternative is...
 2. They are built as needed, i.e. the staging build is only created when a specific commit is identified for review. This puts a lot of pressure on a reproducible build process, with all dependencies locked and still available (in the Node ecosystem `package-lock.json` and `npm ci` can recreate the same dependency tree, unless something got [unpublished][8]).

Either way, any issues in the build process could mean that one or more of the builds doesn't work correctly and, as you're not actually testing the same asset, you **only find out when that specific build is deployed**. This is not where you want to be for a modern, [12+ factor][14] application. Oh, and even if you choose approach 1, introducing a new environment you need to deploy to would automatically push you back to approach 2, needing to recreate an existing build with a new set of configuration.

## Runtime configuration

Much better than baking in the configuration when you build the assets is to be able to inject it at runtime. One method that I've used in various guises is extracting the app's configuration to one specific file. From there you have various options for switching configuration between environments, for example:

  - Copy across an environment-specific file over the default; or
  - Generate a new file from a template and e.g. environment variables (see [my colleague's post][10] on how to do that with `envsubst`, for example).

These methods are much simpler and therefore safer operations than rebuilding or transforming the source code itself; they can trivially be scripted as part of an automated deployment process. Broadly there are three ways to do this, outlined below.

### JavaScript

Probably the most common way to extract configuration is to load a separate JavaScript file directly in your HTML (i.e. _not_ part of the bundle that e.g. Webpack is creating):

```html
<script src="config.js"></script>
```

then in the file you're loading, in this case `config.js`, add whatever configuration you need to the global `window` object so your app code can access it:

```javascript
window.configuration = {
  backend: "host.domain.ext",
};
```

### HTML

Server-side includes (SSI) are a way to dynamically inject content into the responses you're serving. So in your `index.html` you would have an include directive:

```html
<div id="root"></div>
<!--#include virtual="globals.html" --> 
```

then in `globals.html` have a script element that updates the `window` object as above:

```html
<script>
  window.configuration = {
    message: "Production",
  };
</script>
```

Configuring this in the buildpack is simple; you can just add `ssi: enabled` to a `Staticfile` at the root of the deployed directory, along with any other configuration (e.g. `pushstate: enabled` to enable client-side routing using the history API).

**Note** you'll have to make sure your build process leaves the directives in the HTML; I discovered while putting examples together for this post that Create React App [stripped comments out][7], for example, so you need to make sure you're using version 5.1.0 or newer of `html-minifier-terser` where these directives are ignored by default (see this [Pull Request][11]).

### JSON

A third option is having a JSON file, and making a request for it when the app starts up. Rather than the browser making the request for you, as with the JavaScript options, this is made explicitly from the app itself. Once the request resolves the configuration data can be added to the `window` as above.

The downside of this is that you need to wait for a request to finish _in the app runtime_ before the configuration is available. Some frameworks can help you with this; for example, Angular provides [`APP_INITIALIZER`][9], a hook that allows you to delay initial loading of your app code until the promises you supply have been resolved.

```typescript
interface Configuration {
  message: string
};

@Injectable()
export class ConfigurationService {
  public configuration: Configuration;

  constructor(private http: HttpClient) { }

  initialise(): Promise<void> {
    return this.http
      .get<Configuration>('/config.json')
      .pipe(
        map((configuration) => {
          this.configuration = configuration;
        })
      )
      .toPromise();
  }
}
```
```typescript
  providers: [
    ConfigService,
    {
      provide: APP_INITIALIZER,
      useFactory: (service: ConfigurationService) => () => service.initialise(),
      deps: [ConfigurationService],
      multi: true,
    }
  ],
```

In React, this is the sort of thing that the experimental [suspense][13] API looks like it will be really useful for.

### Accessing configuration

However you're loading the configuration, you don't really want your components coupled to the `window` (this makes e.g. testing harder), so rather than having `window.configuration` accessed all over your app I would recommend having a single `configuration.js` containing something like:
    
```javascript
export default window.configuration || {
  message: "Development",
};
```

and using `import configuration from "path/to/configuration";` to access it in your other JavaScript files.

This is slightly more complicated when the additional configuration is loaded asynchronously (i.e. using the JSON method). The `||` in the file would only be evaluated once, which may be _before_ the non-default configuration has been loaded. One method to ensure the app always finds up-to-date configuration is to use a [`Proxy`][15] to ensure the latest `window.configuration` is checked for on every access:

```javascript
export default new Proxy({
  message: "Development",
}, {
  get: (defaults, prop) => (window.configuration || defaults)[prop],
});
```

### Trade-offs

Which of these methods you choose will depend on your specific context, I've summarised some of the pros and cons I thought of below:

<table>
  <thead>
    <tr>
      <th>Method</th>
      <th>Pros</th>
      <th>Cons</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>JavaScript</strong></td>
      <td>
        <ul>
          <li>No additional configuration needed</li>
          <li> JavaScript can include dynamic values if needed</li>
        </ul>
      </td>
      <td>
        <ul>
          <li>Another round trip to the server</li>
        </ul>
      </td>
    </tr>
    <tr>
      <td><strong>HTML</strong></td>
      <td>
        <ul>
          <li>Guaranteed to be available when the app loads, no additional round trips</li>
          <li>JavaScript can include dynamic values if needed</li>
          <li>Works for arbitrary content (e.g. tracking pixels)</li>
        </ul>
      </td>
      <td>
        <ul>
          <li>Requires buildpack/server configuration</li>
          <li>Processing overhead on requests (only for the <code>text/html</code> MIME type by default in NGINX)</li>
        </ul>
      </td>
    </tr>
    <tr>
      <td><strong>JSON</strong></td>
      <td>
        <ul>
          <li>No additional configuration needed</li>
        </ul>
      </td>
      <td>
        <ul>
          <li>Adds complexity to the app to handle asynchronous access to configuration</li>
          <li>Another round trip to the server</li>
          <li>Limited to static JSON content</li>
        </ul>
      </td>
    </tr>
  </tbody>
</table>

**Note** that although I've classed dynamic value support as a Pro above, the flexibility of arbitrary JS code (loaded via HTML or JS files) vs. static JSON data also introduces a security risk. Use with caution! 

I've created simple examples in various frameworks to show how these ideas can be applied practically, they're all published in [this GitHub org][12].

## Path routing

If you're using a managed deployment platform that handles routing for you, or can set up routing using something like [Spring Cloud Gateway][17], you can send traffic to different apps depending on the path. This means you don't need to configure the client the different service APIs at all (or need to configure CORS on the server), because the requests get automagically routed for you.

For example, I've used this in TAS to set up an Angular frontend served by NGINX on `host.domain.ext`, with a Spring Boot backend on `host.domain.ext/api` so that the frontend can make relative requests (i.e. to `"/api/endpoint"` rather than `"host.domain.ext/api/endpoint"`), even though they're still _two separate apps_. You can even set this up from a single manifest file, if you're working in a monorepo:

```yaml
---
applications:
- name: frontend
  routes:
  - host.domain.ext
  buildpacks:
  - staticfile_buildpack
  ...
- name: backend
  routes:
  - host.domain.ext/api
  ...
```

The configuration for this is covered [here][3]. **Note** that the `path` key in the manifest file is the directory within your repo that the app is in, _not_ the network path to host the app at.

The TAS router is smart enough to allow push-state routing, too; a request to `host.domain.ext/foo` will go to the frontend app unless you explicitly mount another app at `/foo`. Between that and the ability to simply set `pushstate: enabled` in the `Staticfile`, this is a really easy way to handle client-side routing with something like [React Router][18] or the built-in [Angular router][19], taking full advantage of the [HTML5 history API][20]. The buildpack will configure NGINX to handle serving the `index.html` for any missing requests and your SPA can take over from there.

One limitation of the path routing approach is that this _only_ removes the configuration issue for API URLs; if you have other configuration that varies by environment you'll need to manage that using the methods above. However, if you can make a relative request and have that routed to a dynamic application, the JSON approach can be used and the request fulfilled based on environment variables, so you don't need to swap out files between environments.

  [1]: https://create-react-app.dev/docs/adding-custom-environment-variables/
  [2]: https://angular.io/guide/build#configuring-application-environments
  [3]: https://docs.cloudfoundry.org/devguide/deploy-apps/routes-domains.html#-create-an-http-route-with-a-path
  [4]: https://tanzu.vmware.com/labs
  [5]: https://docs.cloudfoundry.org/buildpacks/staticfile/index.html
  [6]: https://tanzu.vmware.com/application-service
  [7]: https://github.com/facebook/create-react-app/issues/4245
  [8]: https://www.theregister.co.uk/2016/03/23/npm_left_pad_chaos/
  [9]: https://angular.io/api/core/APP_INITIALIZER
  [10]: https://timysewyn.be/blog/2017-12-27-Deploying-web-applications-with-environment-specific-configurations/
  [11]: https://github.com/DanielRuf/html-minifier-terser/pull/39
  [12]: https://github.com/spa-configuration
  [13]: https://reactjs.org/docs/concurrent-mode-suspense.html
  [14]: https://tanzu.vmware.com/content/blog/beyond-the-twelve-factor-app
  [15]: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Proxy
  [16]: https://webpack.js.org/plugins/define-plugin/
  [17]: https://spring.io/projects/spring-cloud-gateway
  [18]: https://github.com/ReactTraining/react-router
  [19]: https://angular.io/guide/router
  [20]: https://developer.mozilla.org/en-US/docs/Web/API/History
