#     imgflo-server - Image-processing server
#     (c) 2014 The Grid
#     imgflo-server may be freely distributed under the MIT license

common = require './common'
errors = common.errors

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
    graph.inports.input = {}

supportedTypes = ['jpg', 'jpeg', 'png', null]

class NoFloProcessor extends common.Processor
    constructor: (verbose) ->
        @verbose = verbose

    process: (outputFile, outputType, graph, iips, inputFile, inputType, callback) ->
        return callback new errors.UnsupportedImageType outputType, supportedTypes if outputType not in supportedTypes
        return callback new errors.UnsupportedImageType inputType, supportedTypes if inputType not in supportedTypes

        g = prepareNoFloGraph graph, iips, inputFile, outputFile, inputType, outputType
        @run g, callback

    run: (graph, callback) ->
        s = JSON.stringify graph, null, "  "
        cmd = 'node_modules/.bin/noflo-nodejs'
        console.log s if @verbose

        # TODO: add support for reading from stdin to NoFlo?
        tmp.file {postfix: '.json'}, (err, graphPath) =>
            return callback err, null if err
            fs.writeFile graphPath, s, () =>
                args = [
                    '--catch-exceptions', 'false',
                    '--register', 'false',
                    '--cache', 'true',
                    '--port', '3311',
                    '--graph', graphPath
                    '--batch', 'true',
                ]
                @execute cmd, args, callback

    execute: (cmd, args, callback) ->
        args.unshift '--debug'
        console.log 'executing', cmd, args.join ' ' if @verbose
        stderr = ""
        process = child_process.spawn cmd, args, { stdio: ['pipe', 'pipe', 'pipe'] }
        process.on 'close', (exitcode) ->
            err = if exitcode then new Error "processor returned exitcode: #{exitcode}" else null
            return callback err, stderr
        process.stdout.on 'data', (d) =>
            console.log d.toString() if @verbose
        process.stderr.on 'data', (d)->
            stderr += d.toString()

prepareNoFloGraph = (basegraph, attributes, inpath, outpath, inType, outType) ->

    # Avoid mutating original
    def = common.clone basegraph

    # Add a input subgraph
    if inpath
        def.processes.canvas = { component: 'image/UrlToCanvas' }
    else
        # Just blank canvas
        def.processes.canvas = { component: 'canvas/CreateCanvas' }

    # Add a output node
    saveComponent = 'canvas/SavePNG'
    if outType == 'jpg'
        saveComponent = 'canvas/SaveJPEG'

    def.processes.resize = { component: 'core/Repeat' }
    def.processes.repeat = { component: 'core/RepeatAsync' }
    def.processes.save = { component: saveComponent }

    # Attach filepaths as IIPs
    def.connections.push { data: outpath, tgt: { process: 'save', port: 'filename'} }

    # Connect to actual graph
    canvas = def.inports.canvas
    def.connections.push { src: {process: 'canvas', port: 'canvas'}, tgt: canvas }

    out = def.outports.output
    def.connections.push { src: out, tgt: {process: 'resize', port: 'in', index: 1} }
    def.connections.push { src: {process: 'resize', port: 'out', index: 1}, tgt: {process: 'repeat', port: 'in'} }
    def.connections.push { src: {process: 'repeat', port: 'out'}, tgt: {process: 'save', port: 'canvas'} }

    if inpath
        # There is an input image
        tgt =
            process: 'canvas'
            port: 'url'
        def.connections.push { data: inpath, tgt: tgt }

        if attributes.height? or attributes.width?
            def.processes.resize = { component: 'canvas/ResizeCanvas' }
            def.inports.height.process = 'resize'
            def.inports.width.process = 'resize'
            attributes.height =  if attributes.height? then parseInt attributes.height else -1
            attributes.width = if attributes.width? then parseInt attributes.width else -1
    else
        # Defaults
        attributes.height = if attributes.height? then parseInt attributes.height else 400
        attributes.width = if attributes.width? then parseInt attributes.width else 600

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
