#     imgflo-server - Image-processing server
#     (c) 2014 The Grid
#     imgflo-server may be freely distributed under the MIT license

common = require './common'
processing = require './processing'

fs = require 'fs'
path = require 'path'
url = require 'url'
node_static = require 'node-static'

class FsyncedWriteStream extends fs.WriteStream
    close: (cb) ->
        return super cb if not @fd
        fs.fsync @fd, (err) =>
            @emit 'error', err if err
            @emit 'fsynced' if not err
            super cb

class Cache extends common.CacheServer
    constructor: (options) ->
        console.log 'cache options', options
        @dir = options.directory
        if not fs.existsSync @dir
            fs.mkdirSync @dir
        defaults =
            route: '/cache/'
            baseurl: 'localhost'
        @options = defaults
        for k,v of options
            @options[k] = v
        @server = new node_static.Server @dir

    keyExists: (key, callback) ->
        target = path.join @dir, key
        fs.exists target, (exists) =>
            cached = if exists then @urlForKey key else null
            callback null, cached

    putFile: (source, key, callback) ->
        target = path.join @dir, key
        from = fs.createReadStream source
        to = new FsyncedWriteStream target
        from.pipe to
        from.on 'error', (err) ->
            callback err, null
        to.on 'error', (err) ->
            callback err, null
        to.on 'fsynced', () =>
            # Somehow even waiting for fsync is not enough...
            setTimeout () =>
                callback null, @urlForKey key
            , 300

    handleRequest: (request, response) ->
        u = url.parse request.url, true
        filepath = u.pathname.replace "#{@options.route}", ''
        @server.serveFile filepath, 200, {}, request, response

    urlForKey: (key) ->
        return "http://#{@options.baseurl}/cache/#{key}"

# Perform jobs by executing locally
class LocalWorker extends common.JobWorker
    constructor: (@options) ->
        @worker = null

    setup: (callback) ->
        @worker = new processing.JobExecutor @options
        return callback null
    destroy: (callback) ->
        @worker = null
        return callback null

    addJob: (job, callback) ->
        @worker.doJob job, (results) =>
            @onJobUpdated results
        return callback null


exports.Worker = LocalWorker
exports.Cache = Cache
