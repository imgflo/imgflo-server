#     imgflo-server - Image-processing server
#     (c) 2014-2015 The Grid
#     imgflo-server may be freely distributed under the MIT license

async = require 'async'
fs = require 'fs'
path = require 'path'

imgflo = require './imgflo'
noflo = require './noflo'
common = require './common'

enrichGraphDefinition = (graph, publicOnly) ->
    runtime = common.runtimeForGraph graph
    if (runtime.indexOf 'noflo') != -1
        noflo.enrichGraphDefinition graph, publicOnly
    else if (runtime.indexOf 'imgflo') != -1
        imgflo.enrichGraphDefinition graph, publicOnly

class GraphsStore
    constructor: (@config) ->

    # list: would return

    getAll: (callback) ->
        directory = @config.graphdir
        graphs = {}

        fs.readdir directory, (err, files) ->
            if err
                callback err, null

            graphfiles = []
            for f in files
                graphfiles.push path.join directory, f if (path.extname f) == '.json'

            async.map graphfiles, fs.readFile, (err, results) ->
                if err
                    return callback err, null

                for i in [0...results.length]
                    name = path.basename graphfiles[i]
                    name = (name.split '.')[0]
                    def = JSON.parse results[i]
                    enrichGraphDefinition def, true
                    graphs[name] = def

                return callback null, graphs

    get: (name, callback) ->
        # TODO: cache graphs
        graphPath = path.join @config.graphdir, name + '.json'
        fs.readFile graphPath, (err, contents) =>
            return callback err, null if err
            def = JSON.parse contents
            enrichGraphDefinition def
            return callback null, def

module.exports = GraphsStore
