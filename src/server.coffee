#     imgflo-server - Image-processing server
#     (c) 2014 The Grid
#     imgflo-server may be freely distributed under the MIT license

noflo = require './noflo'
imgflo = require './imgflo'
common = require './common'

http = require 'http'
fs = require 'fs'
child_process = require 'child_process'
EventEmitter = (require 'events').EventEmitter
url = require 'url'
querystring = require 'querystring'
path = require 'path'
crypto = require 'crypto'
request = require 'request'

node_static = require 'node-static'
async = require 'async'

# TODO: support using long-lived workers as Processors, use FBP WebSocket API to control

installdir = __dirname + '/../install/'

downloadFile = (src, out, callback) ->
    req = request src, (error, response) ->
        if error
            return callback error, null
        if response.statusCode != 200
            return callback response.statusCode, null

        callback null, response.headers['content-type']

    stream = fs.createWriteStream out
    s = req.pipe stream

waitForDownloads = (files, callback) ->
    f = files.input
    if f?
        downloadFile f.src, f.path, (err, contentType) ->
            return callback err, null if err
            f.type = contentType
            return callback null, files
    else
        return callback null, files

getGraphs = (directory, callback) ->
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


hashFile = (path) ->
    hash = crypto.createHash 'sha1'
    hash.update path
    return hash.digest 'hex'

keysNotIn = (A, B) ->
    notIn = []
    for a in Object.keys A
        isIn = false
        for b in Object.keys B
            if b == a
                isIn = true
        if not isIn
            notIn.push a
    return notIn

typeFromMime = (mime) ->
    type = null
    if mime == 'image/jpeg'
        type = 'jpg'
    else if mime == 'image/png'
        type = 'png'
    return type

runtimeForGraph = (g) ->
    runtime = 'imgflo'
    if g.properties and g.properties.environment and g.properties.environment.type
        runtime = g.properties.environment.type
    return runtime

enrichGraphDefinition = (graph, publicOnly) ->
    runtime = runtimeForGraph graph
    if (runtime.indexOf 'noflo') != -1
        noflo.enrichGraphDefinition graph, publicOnly
    else if (runtime.indexOf 'imgflo') != -1
        imgflo.enrichGraphDefinition graph, publicOnly


parseRequestUrl = (u) ->
    parsedUrl = url.parse u, true

    files = {} # port -> {}
    # TODO: transform urls to downloaded images for all attributes, not just "input"
    if parsedUrl.query.input
        src = parsedUrl.query.input.toString()

        # Add extension so GEGL load op can use the correct file loader
        ext = path.extname src
        if ext not in ['.png', '.jpg', '.jpeg']
            ext = ''

        files.input = { src: src, extension: ext, path: null }

    iips = {}
    for key, value of parsedUrl.query
        iips[key] = value if key != 'input'

    p = parsedUrl.pathname.replace '/graph/', ''
    outtype = (path.extname p).replace '.', ''
    graph = path.basename p, path.extname p
    if not outtype
        outtype = 'png'

    out =
        graph: graph
        files: files
        iips: iips
        outtype: outtype
    return out

class Server extends EventEmitter
    constructor: (workdir, resourcedir, graphdir, verbose) ->
        @workdir = workdir
        @resourcedir = resourcedir || './examples'
        @graphdir = graphdir || './graphs'
        @resourceserver = new node_static.Server resourcedir
        @fileserver = new node_static.Server workdir
        @httpserver = http.createServer @handleHttpRequest
        @port = null

        n = new noflo.Processor verbose
        @processors =
            imgflo: new imgflo.Processor verbose, installdir
            'noflo-browser': n
            'noflo-nodejs': n

        if not fs.existsSync workdir
            fs.mkdirSync workdir

    listen: (port) ->
        @port = port
        @httpserver.listen port
    close: ->
        @httpserver.close()

    logEvent: (id, data) ->
        @emit 'logevent', id, data

    handleHttpRequest: (request, response) =>
        @logEvent 'request-received', { request: request.url }
        request.addListener('end', () =>
            u = url.parse request.url, true
            if u.pathname == '/'
                u.pathname = '/demo/index.html'

            if (u.pathname.indexOf "/demo") == 0
                @serveDemoPage request, response
            else if (u.pathname.indexOf "/graph") == 0
                @handleGraphRequest request, response
            else
                @logEvent 'unknown-request', { request: request.url, path: u.pathname }
                response.statusCode = 404
                response.end "Cannot find #{u.pathname}"
        ).resume()

    getDemoData: (callback) ->

        getGraphs @graphdir, (err, res) =>
            if err
                throw err
            d =
                graphs: res
                images: ["demo/grid-toastybob.jpg", "http://thegrid.io/img/thegrid-overlay.png"]
            return callback null, d

    serveDemoPage: (request, response) ->
        u = url.parse request.url
        p = u.pathname
        if p == '/'
            p = '/demo/index.html'
        p = p.replace '/demo', ''
        if p
            p = path.join @resourcedir, p
            @resourceserver.serveFile p, 200, {}, request, response
        else
            @getDemoData (err, data) ->
                response.statusCode = 200
                response.end JSON.stringify data

    getGraph: (name, callback) ->
        # TODO: cache graphs
        graphPath = path.join @graphdir, name + '.json'
        fs.readFile graphPath, (err, contents) =>
            return callback err, null if err
            def = JSON.parse contents
            enrichGraphDefinition def
            return callback null, def

    handleGraphRequest: (request, response) ->
        u = url.parse request.url, true
        filepath = hashFile u.path
        workdir_filepath = path.join @workdir, filepath

        fs.exists workdir_filepath, (exists) =>
            if exists
                @logEvent 'serve-from-cache', { request: request.url, file: filepath }
                @fileserver.serveFile filepath, 200, {}, request, response
            else
                @processGraphRequest workdir_filepath, request.url, (err, stderr) =>
                    @logEvent 'process-request-end', { request: request.url, err: err, stderr: stderr }
                    if err
                        if err.code?
                            response.writeHead err.code, { 'Content-Type': 'application/json' }
                            response.end JSON.stringify err.result
                        else
                            response.writeHead 500
                            response.end()
                    else
                        # requested file shall now be present
                        @logEvent 'serve-processed-file', { request: request.url, file: filepath }
                        @fileserver.serveFile filepath, 200, {}, request, response

    processGraphRequest: (outf, request_url, callback) =>
        req = parseRequestUrl request_url

        for port, file of req.files
            file.path = path.join @workdir, (hashFile file.src) + file.extension
            if (file.src.indexOf 'http://') == -1 and (file.src.indexOf 'https://') == -1
                file.src = 'http://localhost:'+@port+'/'+file.src

        @getGraph req.graph, (err, graph) =>
            if err
                @logEvent 'read-graph-error', { request: request_url, err: err, file: graph }
                return callback err, null

            invalid = keysNotIn req.iips, graph.inports
            if invalid.length > 0
                @logEvent 'invalid-graph-properties-error', { request: request_url, props: invalid }
                return callback { code: 449, result: graph }, null

            runtime = runtimeForGraph graph
            processor = @processors[runtime]
            if not processor?
                e =
                    request: request_url
                    runtime: runtime
                    valid: Object.keys @processors
                @logEvent 'no-processor-for-runtime-error', e
                return callback { code: 500, result: {} }, null

            waitForDownloads req.files, (err, downloads) =>
                if err
                    @logEvent 'download-input-error', { request: request_url, files: req.files, err: err }
                    return callback { code: 504, result: {} }, null

                inputType = if downloads.input? then typeFromMime downloads.input.type else null
                inputFile = if downloads.input? then downloads.input.path else null
                processor.process outf, req.outtype, graph, req.iips, inputFile, inputType, callback

exports.Server = Server

exports.main = ->
    process.on 'uncaughtException', (err) ->
        console.log 'Uncaught exception: ', err

    port = process.env.PORT || 8080
    workdir = './temp'

    server = new Server workdir
    server.listen port
    server.on 'logevent', (id, data) ->
        console.log "EVENT: #{id}:", data

    console.log 'Server listening at port', port, "with workdir", workdir
