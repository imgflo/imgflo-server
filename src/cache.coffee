#     imgflo-server - Image-processing server
#     (c) 2014 The Grid
#     imgflo-server may be freely distributed under the MIT license

path = require 'path'

common = require './common'
local = require './local'
s3 = require './s3'

exports.fromOptions = (options) ->

    defaultcacheoptions =
        type: 'local'
    defaultcacheoptions.directory = path.join options.workdir, 'cache' if options.workdir
    cache = common.clone defaultcacheoptions
    for k,v of options
        cache[k] = v if v
    if cache.type == 's3'
        @cache = new s3.Cache cache
    else if cache.type == 'local'
        @cache = new local.Cache cache
    else
        @cache = new common.Cache cache

