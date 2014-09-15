#     imgflo-server - Image-processing server
#     (c) 2014 The Grid
#     imgflo-server may be freely distributed under the MIT license

common = require './common'

fs = require 'fs'
child_process = require 'child_process'

enrichGraphDefinition = (graph, publicOnly) ->
    # All imgflo graphs take height+width, set up by ImgfloProcessor
    # This is wired up using an internal GEGL scaling node
    if not graph.inports?
        graph.inports = {}
    graph.inports.height =
        process: 'rescale'
        port: 'y'
    graph.inports.width =
        process: 'rescale'
        port: 'x'

class ImgfloProcessor extends common.Processor

    constructor: (verbose, installdir) ->
        @verbose = verbose
        @installdir = installdir

    process: (outputFile, outputType, graph, iips, inputFile, inputType, callback) ->
        g = prepareImgfloGraph graph, iips, inputFile, outputFile, inputType, outputType
        @run g, callback

    run: (graph, callback) ->

        s = JSON.stringify graph, null, "  "
        cmd = @installdir+'env.sh'
        args = [ @installdir+'bin/imgflo', "-"]

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
        console.log s if @verbose
        process.stdin.write s
        process.stdin.end()

# srcnode PORT -> PORT tgtnode
fbpConn = (str) ->
    tok = str.split ' '
    if not tok.length == 5 and tok[2] == '->'
        throw new Error 'fbpConn: Invalid input'
    conn =
        src:
            process: tok[0]
            port: tok[1].toLowerCase()
        tgt:
            port: tok[3].toLowerCase()
            process: tok[4]
    return conn

prepareImgfloGraph = (basegraph, attributes, inpath, outpath, type, outtype) ->

    # Avoid mutating original
    def = common.clone basegraph

    loader = 'gegl/load'
    if type
        loader = "gegl/#{type}-load"

    # Add load, save, process nodes
    def.processes.load = { component: loader }
    def.processes.save = { component: "gegl/#{outtype}-save" }
    def.processes.proc = { component: 'Processor' }

    # Connect them to actual graph
    out = def.outports.output
    inp = def.inports.input

    if attributes.width? or attributes.height?
        rescale = 'rescale'
        def.processes.rescale = { component: 'gegl/scale-size' }
        def.connections.push fbpConn "load OUTPUT -> INPUT #{rescale}"
        def.connections.push { src: {process: rescale, port: 'output'}, tgt: inp }
    else
        # Connect directly
        def.connections.push { src: {process: 'load', port: 'output'}, tgt: inp }

    def.connections.push { src: out, tgt: {process: 'save', port: 'input'} }
    def.connections.push { src: {process: 'save', port: 'output'}, tgt: {process: 'proc', port: 'node'} }

    # Attach filepaths as IIPs
    def.connections.push { data: inpath, tgt: { process: 'load', port: 'path'} }
    def.connections.push { data: outpath, tgt: { process: 'save', port: 'path'} }

    # Attach processing parameters as IIPs
    for k, v of attributes
        tgt = def.inports[k]
        def.connections.push { data: v, tgt: tgt } if tgt.port and tgt.process

    # Clean up
    delete def.inports
    delete def.outports

    return def

exports.Processor = ImgfloProcessor
exports.enrichGraphDefinition = enrichGraphDefinition
