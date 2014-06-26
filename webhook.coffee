running = null

StaticMarkdownYAML.installGitWebhook = (path) ->
    unless Package['iron-router']
        throw new Meteor.Error 404, 'StaticMarkdownYAML webhook requires Iron Router'

    child_process = Npm.require 'child_process'

    Package['iron-router'].Router.route 'StaticMarkdownYAML-webhook',
        where: 'server'
        path: path
        action: ->
            unless running?
                StaticMarkdownYAML.pauseUpdates()
                console.log "updating #{static_root} from git"
                running = child_process.spawn 'git', ['pull'],
                    cwd: static_root
                    stdio: 'inherit'
                running.on 'exit', ->
                    running = null
                    StaticMarkdownYAML.resumeUpdates()
            @response.end 'ok'
