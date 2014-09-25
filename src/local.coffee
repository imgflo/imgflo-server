#     imgflo-server - Image-processing server
#     (c) 2014 The Grid
#     imgflo-server may be freely distributed under the MIT license

common = require './common'

fs = require 'fs'
path = require 'path'
url = require 'url'
node_static = require 'node-static'

class Cache extends common.CacheServer
    constructor: (dir, options) ->
        @dir = dir
        if not fs.existsSync dir
            fs.mkdirSync dir
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
        fs.exists target, callback

    putFile: (source, key, callback) ->
        target = path.join @dir, key
        from = fs.createReadStream source
        to = fs.createWriteStream target
        from.pipe to
        from.on 'error', (err) ->
            callback err, null
        to.on 'error', (err) ->
            callback err, null
        to.on 'finish', () =>
            callback null, @urlForKey key

    handleRequest: (request, response) ->
        u = url.parse request.url, true
        filepath = u.pathname.replace "#{@options.route}", ''
        @server.serveFile filepath, 200, {}, request, response

    urlForKey: (key) ->
        return "http://#{@options.baseurl}/cache/#{key}"

exports.Cache = Cache
