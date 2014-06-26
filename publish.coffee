events = Npm.require 'events'
fs = Npm.require 'fs'
path = Npm.require 'path'
walk = Npm.require 'walkdir'
yfm = Npm.require 'yaml-front-matter'

switch
    when Meteor.settings.STATIC_ROOT?
        @static_root = Meteor.settings.STATIC_ROOT
    when process.env.STATIC_ROOT?
        @static_root = process.env.STATIC_ROOT
    else
        candidate_path = process.cwd()
        while candidate_path.length > 1
            @static_root = "#{candidate_path}/static-files"
            try
                if (fs.statSync static_root).isDirectory()
                    break
            catch error
                unless error.code is 'ENOENT'
                    throw error
            @static_root = undefined
            candidate_path = path.dirname candidate_path
        unless static_root?
            throw Error 'Please set STATIC_ROOT in your settings or environment'

default_collection = Meteor.settings.STATIC_DEFAULT_COLLECTION ? 'pages'

collections = {}
event_hub = new events.EventEmitter()
event_hub.setMaxListeners 0

watch_paused = false
watch_pending = {}

scan_file = (item_path) ->
    path_rel = path.relative static_root, item_path
    try
        data = yfm.loadFront item_path
    catch error
        console.error error
        console.log "Bad static file #{item_path}"
        throw Error "Bad static file #{item_path}"
    if data._id?
        data.__path = path_rel
    else
        data._id = path_rel
    if match = path_rel.match /^(.*)\/_(.*)\/([^\/]*)(\.md)?$/
        collection = data.collection ? match[2]
        data.path ?= match[1]
        data.slug ?= match[3]
    else
        collection = data.collection ? "#{path.basename item_path, '.md'}s"
        data.path ?= path.dirname path_rel
    [data, collection]


update_item = (item_path, filename) ->
    if watch_paused
        watch_pending[item_path] ?= {}
        watch_pending[item_path][filename] ?= true
    else
        changed_path = "#{item_path}/#{filename}"
        console.log "updating #{changed_path}"
        try
            new_stat = fs.statSync changed_path
        catch error
            unless error.code is 'ENOENT'
                throw error
            new_stat = null

        switch
            when new_stat is null
                console.log "#{changed_path} DELETED"
                path_rel = path.relative static_root, changed_path
                for collection, collection_data of collections
                    for _id, data of collection_data
                        data_path = data.__path ? data._id
                        if data_path.substr(0, path_rel.length) is path_rel
                            delete collection_data[_id]
                            console.log "removed #{_id} from #{collection}"
                            event_hub.emit "removed #{collection}", _id
            when new_stat.isDirectory()
                scan_dir changed_path
            when new_stat.isFile()
                try
                    [data, collection] = scan_file changed_path
                catch error
                    return
                collections[collection] ?= {}
                old_item = collections[collection][data._id]
                if (not old_item?) or new_stat.mtime > old_item.__mtime
                    data.__mtime = new_stat.mtime
                    collections[collection][data._id] = data
                    if old_item?
                        event_hub.emit "changed #{collection}", data._id
                    else
                        event_hub.emit "added #{collection}", data._id


scan_dir = (dir_path) ->
    walk.sync dir_path, (item_path, stat) ->
        switch
            when path.basename(item_path)[0] is '.'
                return
            when stat.isDirectory()
                fs.watch item_path, (event, filename) ->
                    if filename? # proper OS
                        return if filename[0] is '.'
                        update_item item_path, filename
                    else
                        console.log 'Watching for updates not supported on this OS yet'
            when stat.isFile()
                try
                    [data, collection] = scan_file item_path
                catch error
                    return
                data.__mtime = stat.mtime
                collections[collection] ?= {}
                collections[collection][data._id] = data
                event_hub.emit "added #{collection}", data._id

scan_dir static_root


Meteor.publish 'static-md-yaml', (collection) ->
    collection ?= default_collection
    collections[collection] ?= {}
    collection_data = collections[collection]
    for _id, item of collection_data
        # send if published is true or not declared
        if item.published or not item.published?
            @added collection, _id, item
    add_listener = (_id) =>
        @added collection, _id, collection_data[_id]
    change_listener = (_id) =>
        # FIXME: doesn't handle removed fields
        @changed collection, _id, collection_data[_id]
    remove_listener = (_id) =>
        try
            @removed collection, _id
        catch error
            console.log error
    event_hub.addListener "added #{collection}", add_listener
    event_hub.addListener "changed #{collection}", change_listener
    event_hub.addListener "removed #{collection}", remove_listener
    @onStop ->
        event_hub.removeListener "added #{collection}", add_listener
        event_hub.removeListener "changed #{collection}", change_listener
        event_hub.removeListener "removed #{collection}", remove_listener
    @ready()

StaticMarkdownYAML.getCollectionData = (collection) ->
    collection ?= default_collection
    item for _id, item of collections[collection]

StaticMarkdownYAML.getObjectData = (collection, _id) ->
    collection ?= default_collection
    collections[collection]?[_id]

StaticMarkdownYAML.pauseUpdates = ->
    watch_paused = true

StaticMarkdownYAML.resumeUpdates = ->
    watch_paused = false
    if watch_pending
        pending = watch_pending
        watch_pending = {}
        for item_path, files of pending
            for filename, _t of files
                update_item item_path, filename
