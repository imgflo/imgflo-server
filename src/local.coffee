#     imgflo-server - Image-processing server
#     (c) 2014 The Grid
#     imgflo-server may be freely distributed under the MIT license

common = require './common'
processing = require './processing'

fs = require 'fs'
path = require 'path'
url = require 'url'
node_static = require 'node-static'
temp = require 'temp'

class Cache extends common.CacheServer
    constructor: (options) ->
        @dir = options.cache_local_directory
        if not fs.existsSync @dir
            fs.mkdirSync @dir
        defaults = {}
        @options = defaults
        for k,v of options
            @options[k] = v
        @server = new node_static.Server @dir

    keyExists: (key, callback) ->
        target = @filePathForKey key
        fs.exists target, (exists) =>
            cached = if exists then @urlForKey key else null
            callback null, cached

    putFile: (source, key, callback) ->
        # check if already existing, mostly to avoid corruption
        @keyExists key, (err, cached) =>
            return callback err if err
            return callback null, cached if cached

            # Not in cache, actually store
            # To be atomic, write to temp file then rename to final location
            temppath = temp.path
                dir: @dir
                prefix: key
            from = fs.createReadStream source
            to = new common.FsyncedWriteStream temppath
            from.pipe to
            from.on 'error', (err) ->
                return callback err, null
            to.on 'error', (err) ->
                return callback err, null
            to.on 'fsynced', () =>
                # Somehow even waiting for fsync is not enough...
                setTimeout () =>
                    fs.rename temppath, @filePathForKey(key), (err) =>
                        return callback err, @urlForKey(key)
                , 300

    handleKeyRequest: (key, request, response) ->
        @server.serveFile key, 200, {}, request, response

    filePathForKey: (key) ->
        return path.join @dir, key

    urlForKey: (key) ->
        # relative url rewritten on receive
        return "./#{key}"

exports.Cache = Cache
