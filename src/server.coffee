#     imgflo-server - Image-processing server
#     (c) 2014 The Grid
#     imgflo-server may be freely distributed under the MIT license

jobmanager = require './jobmanager'
common = require './common'
cache = require './cache'
processing = require './processing'
GraphsStore = require './graphs'

http = require 'http'
fs = require 'fs'
EventEmitter = (require 'events').EventEmitter
url = require 'url'
path = require 'path'
crypto = require 'crypto'
node_static = require 'node-static'
express = require 'express'

http.globalAgent.maxSockets = Infinity # for older node.js


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

    pathComponents = parsedUrl.pathname.split '/'
    pathComponents = pathComponents.splice(1)

    p = pathComponents[pathComponents.length-1]
    outtype = (path.extname p).replace '.', ''
    graph = path.basename p, path.extname p
    if not outtype
        outtype = 'jpg'
    if outtype == 'jpeg'
        outtype = 'jpg'
    apikey = if pathComponents.length > 2 then pathComponents[1] else null
    token = if pathComponents.length > 3 then pathComponents[2] else null
    cachekey = (common.hashFile "/graph/#{graph}#{parsedUrl.search}") + '.'+outtype

    out =
        graphspec: path.basename p
        graph: graph
        files: files
        iips: iips
        outtype: outtype
        apikey: apikey
        token: token
        cachekey: cachekey
        query: parsedUrl.search
        request: u
    return out



class Server extends EventEmitter

    constructor: (config) ->
        @workdir = config.workdir
        if not fs.existsSync @workdir
            fs.mkdirSync @workdir
        @resourcedir = config.resourcedir
        @graphs = new GraphsStore config
        @resourceserver = new node_static.Server config.resourcedir

        @port = null
        @host = null
        @verbose = config.verbose

        @authdb = null
        if config.api_key or config.api_secret
            @authdb = {}
            @authdb[config.api_key] = config.api_secret

        @cache = cache.fromOptions config
        @jobManager = new jobmanager.JobManager config
        @jobManager.on 'logevent', (id, data) =>
            @logEvent id, data

        @app = express()
        @setupRoutes @app
        @httpserver = http.createServer @app

    setupRoutes: (app) ->

        # processing
        app.get '/graph/:graphname', (req, res) =>
            @logEvent 'request-received', { request: req.url }
            @handleGraphRequest req, res
        app.get '/graph/:apikey/:apitoken/:graph', (req, res) =>
            @logEvent 'request-received', { request: req.url }
            @handleGraphRequest req, res
        app.get '/cache/:key', (req, res) =>
            @logEvent 'request-received', { request: req.url }
            key = req.params.key
            @cache.handleKeyRequest? key, req, res

        # UI
        app.get '/', (req, res) =>
            @logEvent 'request-received', { request: req.url }
            @serveDemoPage req, res
        app.get '/demo', (req, res) =>
            @logEvent 'request-received', { request: req.url }
            @serveDemoPage req, res
        app.get '/demo/*', (req, res) =>
            @logEvent 'request-received', { request: req.url }
            @serveDemoPage req, res

        # meta/management
        app.get '/version', (req, res) =>
            @logEvent 'request-received', { request: req.url }
            @handleVersionRequest req, res

    listen: (host, port, callback) ->
        @host = host
        @port = port
        @httpserver.listen port, (err) =>
            return callback err if err
            @jobManager.start callback
    close: (callback) ->
        @httpserver.close()
        @jobManager.stop (err) ->
            return callback err

    logEvent: (id, data) ->
        @emit 'logevent', id, data

    getDemoData: (callback) ->

        # TODO: this should be GET /graphs, useful not limited to demo page
        @graphs.getAll (err, res) =>
            d =
                graphs: res
            return callback null, d

    serveDemoPage: (request, response) ->
        u = url.parse request.url
        p = u.pathname
        if p == '/'
            p = '/demo/index.html'
        p = p.replace '/demo', ''
        if p
            @resourceserver.serveFile p, 200, {}, request, response
        else
            @getDemoData (err, data) ->
                response.statusCode = 200
                response.end JSON.stringify data

    handleVersionRequest: (request, response) ->
        common.getInstalledVersions (err, info) ->
            if err
                response.writeHead 500
                response.end JSON.stringify { 'err': err }
                return
            response.end JSON.stringify info

    redirectToCache: (err, target, response) ->
        if err
            if err.code?
                response.writeHead err.code, { 'Content-Type': 'application/json' }
                response.end JSON.stringify err.result
            else
                response.writeHead 500
                response.end JSON.stringify err
            return
        target = "http://#{@host}/cache/#{target.substr(2)}" if target.indexOf('./') == 0
        response.writeHead 301, { 'Location': target }
        response.end()

    checkAuth: (req) ->
        return true if not @authdb # Authentication disabled

        secret = @authdb[req.apikey]
        return false if not secret

        hash = crypto.createHash 'md5'
        hash.update req.graphspec+req.query+secret
        expectedToken = hash.digest 'hex'
        return req.token == expectedToken

    # GET /process
    # on new HTTP request:
    #   validate parameters & auth
    #   check S3 cache
    #   create job from request, submit
    # when job completes:
    #   set HTTP response with correct statuscode/data
    handleGraphRequest: (request, response) ->
        u = url.parse request.url, true
        req = parseRequestUrl request.url

        authenticated = @checkAuth req
        if not authenticated
            response.writeHead 403
            return response.end()

        @cache.keyExists req.cachekey, (err, cached) =>
            if cached
                @logEvent 'graph-in-cache', { request: request.url, key: req.cachekey, url: cached }
                @redirectToCache err, cached, response
            else
                @processAndCache request.url, req.cachekey, response, (err, cached) =>
                    @logEvent 'serve-processed-file', { request: request.url, url: cached, err: err }
                    @redirectToCache err, cached, response

    processAndCache: (request_url, key, response, callback) ->
        req = parseRequestUrl request_url
        #  Resolve relative request to localhost
        for port, file of req.files
            if (file.src.indexOf 'http://') == -1 and (file.src.indexOf 'https://') == -1
                file.src = 'http://localhost:'+@port+'/'+file.src

        # TODO: check that using req as job payload is sane
        @jobManager.doJob 'process-image', req, (err, job) =>
            @logEvent 'serve-processed-file', { request: req.request, url: job.results?.url }
            return callback err, job.results?.url

exports.Server = Server


exports.main = ->
    process.on 'uncaughtException', (err) ->
        console.log 'Uncaught exception: ', err
        console.log err.stack

    config = common.getProductionConfig()

    server = new Server config
    server.listen config.api_host, config.api_port, (err) ->
        throw err if err
        console.log "Server listening at port #{config.api_port} on host #{config.api_host}"
        console.log "with workdir #{config.workdir}"
        console.log "with #{config.cache_type} cache"
        console.log "with #{config.worker_type} workers"
        console.log "using broker #{config.broker_url}"
    server.on 'logevent', (id, data) ->
        console.log "EVENT: #{id}:", data
    
