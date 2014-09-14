#     imgflo-server - Image-processing server
#     (c) 2014 The Grid
#     imgflo-server may be freely distributed under the MIT license

url = require 'url'
child = require 'child_process'
path = require 'path'

class LogHandler
    @errors = null
    constructor: (server) ->
        @errors = []
        server.on 'logevent', @logEvent

    logEvent: (id, data) =>
        if id == 'process-request-end'
            if data.stderr
                for e in data.stderr.split '\n'
                    e = e.trim()
                    @errors.push e if e
            if data.err
                @errors.push data.err
        else if id == 'serve-from-cache'
            #
        else if (id.indexOf 'error') != -1
            if data.err
                @errors.push data
        else if id == 'request-received' or id == 'serve-processed-file'
            #
        else
            console.log 'WARNING: unhandled log event', id

    popErrors: () ->
        errors = (e for e in @errors)
        @errors = []
        return errors

exports.LogHandler = LogHandler

exports.compareImages = (actual, expected, callback) ->
    cmd = "./install/env.sh ./install/bin/gegl-imgcmp #{actual} #{expected}"
    options =
        timeout: 2000
    child.exec cmd, options, (error, stdout, stderr) ->
        return callback error, stderr, stdout

exports.requestFileFormat = (u) ->
    parsed = url.parse u
    graph = parsed.pathname.replace '/graph/', ''
    ext = (path.extname graph).replace '.', ''
    return ext || 'png'

exports.formatRequest = (host, graph, params) ->
    return url.format { protocol: 'http:', host: host, pathname: '/graph/'+graph, query: params }
