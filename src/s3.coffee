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
    constructor: (config) ->
        options =
            key: config.cache_s3_keu
            secret: config.cache_s3_secret
            region: config.cache_s3_region
            bucket: config.cache_s3_bucket
            prefix: config.cache_s3_folder
        @client = knox.createClient @options

    # PERFORMANCE: keep a local index of keys?
    keyExists: (key, callback) ->
        @client.headFile @fullKey(key), (err, res) =>
            exists = res.headers['etag']
            cached = if exists then @urlForKey key else null
            return callback null, cached

    putFile: (source, key, callback) ->
        maxAge = 60*60*24 # seconds
        headers =
            'Cache-Control': "max-age=#{maxAge}"
        @client.putFile source, @fullKey(key), headers, (err, res) =>
            return callback err, null if err
            return callback null, @urlForKey key

    fullKey: (key) ->
        return "#{@options.prefix}/#{key}"
    urlForKey: (key) ->
        return "https://s3-#{@options.region}.amazonaws.com/#{@options.bucket}/#{@options.prefix}/#{key}"

exports.Cache = Cache
