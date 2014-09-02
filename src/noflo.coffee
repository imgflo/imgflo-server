#     imgflo-server - Image-processing server
#     (c) 2014 The Grid
#     imgflo-server may be freely distributed under the MIT license

common = require './common'

fs = require 'fs'
child_process = require 'child_process'
tmp = require 'tmp'

enrichGraphDefinition = (graph, publicOnly) ->
    # All noflo-canvas graphs take height+width, set up by NoFloProcessor
    # This is wired up using an internal canvas inport
    delete graph.inports.canvas if publicOnly
    graph.inports.height =
        process: 'canvas'
        port: 'height'
    graph.inports.width =
        process: 'canvas'
        port: 'width'

class NoFloProcessor extends common.Processor
    constructor: (verbose) ->
        @verbose = verbose

    process: (outputFile, outputType, graph, iips, inputFile, inputType, callback) ->
        g = prepareNoFloGraph graph, iips, inputFile, outputFile, inputType
        @run g, callback

    run: (graph, callback) ->
        s = JSON.stringify graph, null, "  "
        cmd = 'node_modules/noflo-canvas/node_modules/.bin/noflo'
        console.log s if @verbose

        # TODO: add support for reading from stdin to NoFlo?
        tmp.file {postfix: '.json'}, (err, graphPath) =>
            return callback err, null if err
            fs.writeFile graphPath, s, () =>
                @execute cmd, [ graphPath ], callback

    execute: (cmd, args, callback) ->
        console.log 'executing', cmd, args if @verbose
        stderr = ""
        process = child_process.spawn cmd, args, { stdio: ['pipe', 'pipe', 'pipe'] }
        process.on 'close', (exitcode) ->
            err = if exitcode then new Error "processor returned exitcode: #{exitcode}" else null
            return callback err, stderr
        process.stdout.on 'data', (d) =>
            console.log d.toString() if @verbose
        process.stderr.on 'data', (d)->
            stderr += d.toString()

prepareNoFloGraph = (basegraph, attributes, inpath, outpath, type) ->

    # Avoid mutating original
    def = common.clone basegraph

    # Note: We drop inpath on the floor, only support pure generative for now

    # Add a input node
    def.processes.canvas = { component: 'canvas/CreateCanvas' }

    # Add a output node
    def.processes.repeat = { component: 'core/RepeatAsync' }
    def.processes.save = { component: 'canvas/SavePNG' }

    # Attach filepaths as IIPs
    def.connections.push { data: outpath, tgt: { process: 'save', port: 'filename'} }

    # Connect to actual graph
    canvas = def.inports.canvas
    def.connections.push { src: {process: 'canvas', port: 'canvas'}, tgt: canvas }

    out = def.outports.output
    def.connections.push { src: out, tgt: {process: 'repeat', port: 'in'} }
    def.connections.push { src: {process: 'repeat', port: 'out'}, tgt: {process: 'save', port: 'canvas'} }

    # Defaults
    if attributes.height?
        attributes.height = parseInt attributes.height
    else
        attributes.height = 400

    if attributes.width?
        attributes.width = parseInt attributes.width
    else
        attributes.width = 600

    # Attach processing parameters as IIPs
    for k, v of attributes
        tgt = def.inports[k]
        def.connections.push { data: v, tgt: tgt }

    # Clean up
    delete def.inports
    delete def.outports

    return def

exports.Processor = NoFloProcessor
exports.enrichGraphDefinition = enrichGraphDefinition
