common = require './common'

redis = require 'redis'
url = require 'url'

# Transparent frontend for the real @cache
class Cache extends common.CacheServer
    constructor: (@cache, @config) ->
        if @config.redis_url
            params = url.parse @config.redis_url
            @client = redis.createClient params.port, params.hostname
            @client.auth params.auth.split(':')[1] if params.auth
        else
            @client = redis.createClient()
        @prefix = @config.cache_redis_prefix or 'imgflo_cache'
        @expireSeconds = @config.cache_redis_ttl

    keyExists: (key, callback) ->
        redisKey = @redisPathForKey key
        @client.get redisKey, (err, res) =>
            return callback err if err
            return callback null, res if res

            @cache.keyExists key, (err, cached) =>
                return callback err if err
                return callback null, cached if not cached
                @client.set redisKey, cached, 'EX', @expireSeconds, (err) ->
                    return callback err, cached

    putFile: (source, key, callback) ->
        # Don't cache, let next keyExists check get it
        # This operation is comparitively very rare, avoids duplicate logic
        @cache.putFile source, key, callback

    handleKeyRequest: (key, request, response) ->
        @cache.handleKeyRequest? key, request, response

    redisPathForKey: (key) ->
        return "#{@prefix}/url/#{key}"

    # TEMP: needed as long as we return cache url in POST requests, and not job urls
    urlForKey: (key) ->
        return @cache.urlForKey key

exports.Cache = Cache
