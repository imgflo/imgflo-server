#     imgflo-server - Image-processing server
#     (c) 2014 The Grid
#     imgflo-server may be freely distributed under the MIT license

common = require './common'

fs = require 'fs'
path = require 'path'
url = require 'url'
node_static = require 'node-static'
knox = require 'knox'

class Cache extends common.CacheServer
    constructor: (dir, options) ->
        defaults =
            key: null
            secret: null
            bucket: null
            region: 'us-west-2'
        @options = defaults
        for k,v of options
            @options[k] = v if v
        @client = knox.createClient @options

    # PERFORMANCE: keep a local index of keys?
    keyExists: (key, callback) ->
        @client.headFile key, (err, res) =>
            exists = res.headers['etag']
            cached = if exists then @urlForKey key else null
            return callback null, cached

    putFile: (source, key, callback) ->
        @client.putFile source, key, (err, res) =>
            return callback err, null if err
            return callback null, @urlForKey key

    urlForKey: (key) ->
        return "http://#{@options.bucket}.s3-#{@options.region}.amazonaws.com/#{key}"

exports.Cache = Cache
