#     imgflo-server - Image-processing server
#     (c) 2014-2015 The Grid
#     imgflo-server may be freely distributed under the MIT license

common = require './common'
# Processors
noflo = require './noflo'
imgflo = require './imgflo'
#
cache = require './cache'
GraphsStore = require './graphs'

metrics = require './newrelic'

EventEmitter = require('events').EventEmitter
request = require 'request'
async = require 'async'
fs = require 'fs'
path = require 'path'
temp = require 'temp'

class NoopProcessor
    constructor: (verbose) ->
        @verbose = verbose

    process: (outputFile, outType, graph, iips, inputFile, inputType, callback) ->
        if outType and (outType != inputType)
            console.log "WARNING: noop with mismatching input and output types. Got intype=#{inputType} and outtype=#{outType}"

        # Just copy file byte-for-byte to expected output location
        ins = fs.createReadStream inputFile
        outs = fs.createWriteStream outputFile
        outs.on 'error', (err) ->
            return if not callback
            callback err
            callback = null
        ins.pipe outs
        outs.on 'finish', () ->
            return if not callback
            callback null
            callback = null

# TODO: support using long-lived workers as Processors, use FBP WebSocket API to control?

downloadFile = (src, out, callback) ->
    contentType = null
    requestOptions =
        encoding: null # expect binary
        timeout: 20*1000
    req = request src, requestOptions
    req.on 'response', (response) ->
        if response.statusCode != 200
            return if not callback
            callback new Error "Failed to download input #{src}: HTTP error #{response.statusCode}", null
            callback = null
        else
            contentType = response.headers['content-type']

    req.on 'error', (err) ->
        return if not callback
        callback err
        callback = null

    stream = fs.createWriteStream out
    s = req.pipe stream
    stream.on 'finish', () ->
        return if not callback
        callback null, contentType
        callback = null

waitForDownloads = (files, callback) ->
    f = files.input
    if f?
        downloadFile f.src, f.path, (err, contentType) ->
            return callback err, null if err
            f.type = contentType
            return callback null, files
    else
        return callback null, files

jobResult = (job, err, cachedUrl) ->
    r = common.clone job
    r.completed_at = Date.now()
    r.results = {}
    r.results.url = cachedUrl if cachedUrl
    r.error = err if err
    return r

runtimeSupportsType = (runtime, type) ->
    err = null
    if runtime == 'noflo-browser' or runtime == 'noflo-nodejs'
        err = new common.errors.UnsupportedImageType type, noflo.supportedTypes if type not in noflo.supportedTypes
    else if runtime == 'imgflo'
        err = new common.errors.UnsupportedImageType type, imgflo.supportedTypes if type not in imgflo.supportedTypes
    else if runtime == 'noop'
        # does not care, support everything
    else
        err = new Error "runtimeSupportsType: Unknown runtime #{runtime}"
    return err

maybeUnlink = (f, cb) ->
    # handle null ...
    return cb null if not f
    fs.unlink f, cb

class JobExecutor extends EventEmitter
    constructor: (config) ->

        @workdir = config.workdir
        if not fs.existsSync @workdir
            fs.mkdirSync @workdir
        @graphs = new GraphsStore config

        n = new noflo.Processor config.verbose
        @processors =
            imgflo: new imgflo.Processor config.verbose, common.installdir
            'noflo-browser': n
            'noflo-nodejs': n
            'noop': new NoopProcessor config.verbose

        if not fs.existsSync @workdir
            fs.mkdirSync @workdir

        @cache = cache.fromOptions config
        @options = config

    getGraph: (name, callback) ->
        @graphs.get name, callback

    logEvent: (id, data) ->
        @emit 'logevent', id, data

    # on new job:
    #   download inputs
    #   load graph, chose & run Processor
    #   upload results to S3 cache
    #   post job results to output queue
    doJob: (job, done) ->
        callback = (r) ->
            metrics.onJobCompleted r
            return done r
        checkCache = (key, callback) =>
            return callback null, null if job.data.noCache # ignore fact that exists in cache
            return @cache.keyExists key, callback

        job.started_at = Date.now()
        checkCache job.data.cachekey, (err, u) =>
            if u
                # Was processed while job was in queue
                result = jobResult job, err, u
                return callback result

            @processAndCache job, (err, u) ->
                result = jobResult job, err, u
                return callback result

    processAndCache: (job, callback) ->
        key = job.data.cachekey
        request_url = job.data.request

        workdir_filepath = require('temp').path { dir: @workdir, prefix: key+'-processed-' }
        @downloadAndRender workdir_filepath, job, (err, stderr) =>
            @logEvent 'process-request-end', { request: request_url, err: err, stderr: stderr, file: workdir_filepath }
            return callback err, null if err

            @logEvent 'put-into-cache', { request: request_url, path: workdir_filepath, key: key }
            @cache.putFile workdir_filepath, key, (err, cached) =>
                job.uploaded_at = Date.now()
                fs.unlink workdir_filepath, (e) =>
                    @logEvent 'remove-tempfile-error', { request: request_url, file: workdir_filepath, err: e } if e

                    # temp file removed
                    return callback err, null if err
                    @logEvent 'job-completed', { request: request_url, url: cached, err: err }
                    return callback null, cached

    downloadAndRender: (outf, job, callback) =>
        req = job.data
        request_url = job.data.request

        # Add local paths for downloading to
        for port, file of req.files
            file.path = temp.path
                dir: path.join @workdir
                prefix: common.hashFile(file.src)+'-downloaded-'
                suffix: file.extension

        @getGraph req.graph, (err, graph) =>
            if err
                @logEvent 'read-graph-error', { request: request_url, err: err, file: graph }
                return callback err, null

            invalid = common.keysNotIn req.iips, graph.inports
            if invalid.length > 0
                @logEvent 'invalid-graph-properties-error', { request: request_url, props: invalid }
                return callback { code: 449, result: graph }, null

            runtime = common.runtimeForGraph graph
            processor = @processors[runtime]
            if not processor?
                e =
                    request: request_url
                    runtime: runtime
                    valid: Object.keys @processors
                @logEvent 'no-processor-for-runtime-error', e
                return callback { code: 500, result: {} }, null

            @logEvent 'download-inputs-start', { request: request_url, files: req.files }
            waitForDownloads req.files, (err, downloads) =>
                job.downloaded_at = Date.now()
                if err
                    @logEvent 'download-input-error', { request: request_url, files: req.files, err: err }
                    return callback { code: 504, result: { error: err.message, files: req.files } }, null

                inputType = if downloads.input? then common.typeFromMime downloads.input.type else null
                inputFile = if downloads.input? then downloads.input.path else null
                processor.process outf, req.outtype, graph, req.iips, inputFile, inputType, (err, stderr, metadata={}) =>
                    job.processed_at = Date.now()

                    job.input_width = metadata.input?.width
                    job.input_height = metadata.input?.height
                    job.output_width = metadata.output?.width
                    job.output_height = metadata.output?.height
                    job.init_processing = metadata.init?.duration
                    @collectImageStats inputFile, (err, inStats) =>
                        @logEvent 'image-stats-error', { request: request_url, err: err } if err
                        @collectImageStats outf, (err, outStats) =>
                            @logEvent 'image-stats-error', { request: request_url, err: err } if err
                            job.input_bytes = inStats?.bytes
                            job.output_bytes = outStats?.bytes

                            maybeUnlink inputFile, (e) =>
                                @logEvent 'remove-tempfile-error', { request: request_url, file: inputFile, err: e } if e
                            job.stated_at = Date.now()
                            return callback err, stderr

    collectImageStats: (filepath, callback) ->
        return callback null, {} if not filepath # optional
        # TODO: also collect size in pixels
        fs.stat filepath, (err, stat) ->
            return callback err if err
            return callback null, { bytes: stat.size }

exports.JobExecutor = JobExecutor
exports.runtimeSupportsType = runtimeSupportsType
