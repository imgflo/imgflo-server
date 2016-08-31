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

graphSuffix = '.json.info'

validGraph = (filepath) ->
    rightSuffix = common.endsWith filepath, graphSuffix
    return rightSuffix and filepath.indexOf('Test') == -1

class GraphsStore
    constructor: (@config) ->

    # list: would return

    getAll: (callback) ->
        directory = @config.graphdir
        graphs = {}

        fs.readdir directory, (err, files) =>
            if err
                callback err, null

            graphnames = []
            for f in files
                if validGraph f
                    name = f.replace(graphSuffix, '')
                    graphnames.push name

            getGraph = (name, cb) =>
                @get name, { publicOnly: true }, cb
            async.map graphnames, getGraph, (err, results) ->
                return callback err, null if err
                # return as dictionary
                for i in [0...results.length]
                    name = graphnames[i]
                    graphs[name] = results[i]
                return callback null, graphs

    get: (name, options, callback) ->
        # TODO: cache graphs
        graphPath = path.join @config.graphdir, name + graphSuffix
        return new Error "Invalid processing graph '#{name}'" if not validGraph graphPath

        fs.readFile graphPath, (err, contents) =>
            return callback err, null if err
            def = JSON.parse contents
            enrichGraphDefinition def, options.publicOnly
            return callback null, def

module.exports = GraphsStore
