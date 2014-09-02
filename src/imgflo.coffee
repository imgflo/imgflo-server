#     imgflo-server - Image-processing server
#     (c) 2014 The Grid
#     imgflo-server may be freely distributed under the MIT license

common = require './common'

fs = require 'fs'
child_process = require 'child_process'

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

    def.connections.push { src: {process: 'load', port: 'output'}, tgt: inp }
    def.connections.push { src: out, tgt: {process: 'save', port: 'input'} }
    def.connections.push { src: {process: 'save', port: 'output'}, tgt: {process: 'proc', port: 'node'} }

    # Attach filepaths as IIPs
    def.connections.push { data: inpath, tgt: { process: 'load', port: 'path'} }
    def.connections.push { data: outpath, tgt: { process: 'save', port: 'path'} }

    # Attach processing parameters as IIPs
    for k, v of attributes
        tgt = def.inports[k]
        def.connections.push { data: v, tgt: tgt }

    # Clean up
    delete def.inports
    delete def.outports

    return def

exports.Processor = ImgfloProcessor
