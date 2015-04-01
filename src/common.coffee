#     imgflo-server - Image-processing server
#     (c) 2014 The Grid
#     imgflo-server may be freely distributed under the MIT license

async = require 'async'
pkginfo = (require 'pkginfo')(module, 'version')
path = require 'path'
child_process = require 'child_process'
fs = require 'fs'
crypto = require 'crypto'

installdir = __dirname + '/../install/'
projectdir = __dirname + '/..'

# Interface for Processors
class UnsupportedImageTypeError extends Error
    constructor: (attempt, supported) ->
        @name = 'unsupported-image-type'
        @code = 449
        @message = "Unsupported image type: " + attempt
        @result = { supported: supported, error: @message, code: @name }

class Processor
    constructor: (verbose) ->
        @verbose = verbose

    # FIXME: clean up interface
    # callback should be called with (err, error_string)
    process: (outputFile, outType, graph, iips, inputFile, inputType, callback) ->
        throw new Error 'Processor.process() not implemented'

# Interfaces for caching
class CacheServer
    constructor: (options) ->
        #

    # callback (err, url)
    putFile: (path, key, callback) ->
        #

    # callback (err, url)
    keyExists: (key, callback) ->
        #

# Interface for job queues
# Actually a 2-set of queues, bidirectional
class JobWorker
    constructor: (verbose) ->

    setup: (callback) ->
    destroy: (callback) ->

    # @job: { id: number/uuid, type: 'process-image', data: {} }
    addJob: (job) ->

    # to be called by queue when job has been updated (usually completed or failed)
    onJobUpdated: () ->
        throw new Error 'JobWorker.onJobUpdated not implemented'


# Key used in cache
exports.hashFile = (path) ->
    hash = crypto.createHash 'sha1'
    hash.update path
    return hash.digest 'hex'

exports.keysNotIn = (A, B) ->
    notIn = []
    for a in Object.keys A
        isIn = false
        for b in Object.keys B
            if b == a
                isIn = true
        if not isIn
            notIn.push a
    return notIn

exports.typeFromMime = (mime) ->
    type = null
    if mime == 'image/jpeg'
        type = 'jpg'
    else if mime == 'image/png'
        type = 'png'
    return type

exports.runtimeForGraph = (g) ->
    runtime = 'imgflo'
    if g.properties and g.properties.environment and g.properties.environment.type
        runtime = g.properties.environment.type
    return runtime

# Key used in cache
exports.hashFile = (path) ->
    hash = crypto.createHash 'sha1'
    hash.update path
    return hash.digest 'hex'

exports.keysNotIn = (A, B) ->
    notIn = []
    for a in Object.keys A
        isIn = false
        for b in Object.keys B
            if b == a
                isIn = true
        if not isIn
            notIn.push a
    return notIn

exports.typeFromMime = (mime) ->
    type = null
    if mime == 'image/jpeg'
        type = 'jpg'
    else if mime == 'image/png'
        type = 'png'
    return type

exports.runtimeForGraph = (g) ->
    runtime = 'imgflo'
    if g.properties and g.properties.environment and g.properties.environment.type
        runtime = g.properties.environment.type
    return runtime

clone = (obj) ->
  if not obj? or typeof obj isnt 'object'
    return obj

  if obj instanceof Date
    return new Date(obj.getTime())

  if obj instanceof RegExp
    flags = ''
    flags += 'g' if obj.global?
    flags += 'i' if obj.ignoreCase?
    flags += 'm' if obj.multiline?
    flags += 'y' if obj.sticky?
    return new RegExp(obj.source, flags)

  newInstance = new obj.constructor()

  for key of obj
    newInstance[key] = clone obj[key]

  return newInstance


gitDescribe = (path, callback) ->
    cmd = 'git describe --tags'
    child_process.exec cmd, { cwd: path }, (err, stdout, stderr) ->
        stdout = stdout.replace '\n', ''
        return callback err, stdout

getGitVersions = (callback) ->
  info =
       npm: module.exports.version
  names = [ 'server', 'runtime',
          'dependencies',
          'gegl',
          'babl'
  ]
  paths = [ './', 'runtime',
#          'runtime/dependencies',
#          'runtime/dependencies/gegl',
#          'runtime/dependencies/babl'
  ]
  paths = (path.join projectdir, p for p in paths)

  async.map paths, gitDescribe, (err, results) ->
      for i in [0...results.length]
          name = names[i]
          info[name] = results[i]

      callback err, info

getInstalledVersions = (callback) ->
    p = path.join installdir, 'imgflo.versions.json'
    fs.readFile p, (err, content) ->
        return callback err, null if err
        try
            callback null, JSON.parse content
        catch e
            callback e, null

updateInstalledVersions = (callback) ->

    fs.mkdir installdir, (err) ->
        return callback err, null if err and err.code != 'EEXIST'
        p = path.join installdir, 'imgflo.versions.json'
        getGitVersions (err, info) ->
          return callback err, null if err
          c = JSON.stringify info
          fs.writeFile p, c, (err) ->
              return callback err, null if err
              return callback null, p


exports.mergeDefaultConfig = (overrides) ->
    defaultConfig =
        verbose: false
        api_port: 8080
        api_host: 'localhost:8080' # note: depends on port
        api_key: process.env.IMGFLO_API_KEY
        api_secret: process.env.IMGFLO_API_SECRET
        workdir: './temp'
        graphdir: './graphs'
        resourcedir: './examples'

        worker_type: 'internal' # will start internal worker
        broker_url: 'direct://imgflo3'

        cache_type: 'local' # will start local cache server
        cache_s3_key: process.env.AMAZON_API_ID
        cache_s3_secret: process.env.AMAZON_API_TOKEN
        cache_s3_bucket: process.env.AMAZON_API_BUCKET
        cache_s3_region: process.env.AMAZON_API_REGION
        cache_s3_folder: 'test'
        cache_local_directory: './cache'

    config = clone defaultConfig
    for key, value of overrides
        config[key] = value if value
    return config

exports.getProductionConfig = () ->
    config =
        cache_s3_folder: 'p'
    config.api_port = process.env.PORT if process.env.PORT?
    config.api_host = process.env.HOSTNAME || "localhost:#{config.api_port}"
    config.cache_type = process.env.IMGFLO_CACHE or null
    config.worker_type = process.env.IMGFLO_WORKER or null
    config.broker_url = process.env.CLOUDAMQP_URL or null
    config = exports.mergeDefaultConfig config

    return config

exports.clone = clone
exports.Processor = Processor
exports.getInstalledVersions = getInstalledVersions
exports.updateInstalledVersions = updateInstalledVersions
exports.installdir = installdir
exports.CacheServer = CacheServer
exports.JobWorker = JobWorker
exports.errors = {
    UnsupportedImageType: UnsupportedImageTypeError
}
