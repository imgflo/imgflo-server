#     imgflo-server - Image-processing server
#     (c) 2014 The Grid
#     imgflo-server may be freely distributed under the MIT license

path = require 'path'

common = require './common'
local = require './local'
s3 = require './s3'

exports.fromOptions = (config) ->

    type = config.cache_type
    if type == 's3'
        cache = new s3.Cache config
    else if type == 'local'
        cache = new local.Cache config
    else
        cache = new common.Cache config

    return cache

