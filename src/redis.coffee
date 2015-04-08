common = require './common'

redis = require 'redis'
url = require 'url'

# Transparent frontend for the real @cache
class Cache extends common.CacheServer
    constructor: (@cache, @config) ->
        if config.redis_url
            params = url.parse config.redis_url
            @client = redis.createClient params.port, params.hostname
            @client.auth params.auth.split(':')[1] if params.auth
        else
            @client = redis.createClient()
        @mapName = config.cache_redis_map or 'processed-file-url'

    keyExists: (key, callback) ->
        @client.hget @mapName, key, (err, res) =>
            console.log 'redis get', key, err, res
            return callback err if err
            return callback null, res if res

            @cache.keyExists key, (err, cached) =>
                return callback err if err
                return callback null, cached if not cached
                @client.hset @mapName, key, cached, (err) ->
                    return callback err, cached

    putFile: (source, key, callback) ->
        # Don't cache, let next keyExists check get it
        # This operation is comparitively very rare, avoids duplicate logic
        @cache.putFile source, key, callback

    handleKeyRequest: (key, request, response) ->
        @cache.handleKeyRequest? key, request, response

exports.Cache = Cache
