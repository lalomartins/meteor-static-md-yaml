# Static Markdown and YAML

You're writing a Meteor app, but you have a collection (or more) of data that's mostly text, and you don't want to put it in the database.

Many other frameworks have libraries that allow you to load data like that from Markdown files with “front matter” (a chunk of structured data, typically YAML, delimited by a `---` line).

Well, here it is for Meteor! It even updates the data if the files change.

**Important disclaimer:** This package assumes you're running your app on your own server, where you can have your Markdown+YAML data on a separate tree, and possibly update it from a git repository. It's **not** compatible with Galaxy deployment and running the app on `*.meteor.com`.

## Using it

- Install the package (manually, with [Meteor-shower](https://github.com/lalomartins/meteor-shower), or Meteorite).
- Set a variable `STATIC_ROOT` in your Meteor settings or environment, pointing to the directory where your static files are.
- Front matter is delimited by two `---` lines, one before (that is, the first line in the file) and one after.
- If you don't need any text in the file, just YAML, it still needs to be delimited before and after; otherwise the parser will assume it's all Markdown.
- The name of the file determines the collection; a file `page.md` goes in the `pages` collection. (Pluralisation is dumb, so you may end up with dumb names like `batchs`; sorry about that.) The `_id` will be the full path from the `STATIC_ROOT`.
- The Markdown content will be put in a `__content` property.
- *Advanced:* you may define a custom `_id` in the front matter; in that case, the package will insert a `__path` property with the full relative path.
- *Advanced:* you may create directories named after collections, underscore-prefixed, and then files with arbitrary names inside. That's especially useful for e.g. blog posts. A file `people/lalo/_posts/2014-05-26-happy-birthday.md` will create an object in the `posts` collection, with an `_id` and/or `__path` as usual, plus a `path` property of `'people/lalo'`, and a `slug` property of `'2014-05-26-happy-birthday'`. If you define custom `path` or `slug` properties in the front matter, those will take precedence.
- *Advanced:* you may specify the collection in the front matter, as well; but please don't do that — you will confuse people to death.
- *Advanced:* the package doesn't parse your Markdown at all. That means there's no reason why it *has* to be Markdown. You can just as well use this as “static-html-yaml” or “static-csv-yaml” or whatever…
- On the client, subscribe using calls like `Meteor.subscribe('static-md-yaml', 'pages')` (where the argument is the collection name).

## The git hook

If your app uses Iron Router, you may expose a server-side hook that causes this package to go to `STATIC_ROOT` and do a `git pull`. This hook is compatible, for example, with the Github standard push hook.

Just call `StaticMarkdownYAML.installGitWebhook(route_path)`, e.g.,
`StaticMarkdownYAML.installGitWebhook('/__github_webhook_for_static')`, on server code. To avoid opening a possible DOS window, I recommend you keep your webhook address secret.

If you're a rare bastion of sanity and you're using Bazaar or Mercurial or whatever, you may copy the code in `webhook.coffee` to base your own webhook route on.
