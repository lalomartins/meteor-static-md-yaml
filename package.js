Package.describe({
  summary: 'Read static Markdown+YAML files and publish them as a collection'
});

Package.on_use(function (api) {
    Npm.depends({
        'yaml-front-matter': '3.0.1',
        'walkdir': '0.0.7',
    });
    api.use('coffeescript', 'server');
    api.use('iron-router', 'server', {weak: true});
    // too bad we can't export on server only
    api.export('StaticMarkdownYAML');
    api.add_files(['coffee-export-is-broken.js', 'publish.coffee', 'webhook.coffee'], 'server');
});
