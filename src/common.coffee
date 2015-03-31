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

exports.clone = clone
exports.Processor = Processor
exports.getInstalledVersions = getInstalledVersions
exports.updateInstalledVersions = updateInstalledVersions
exports.installdir = installdir
exports.CacheServer = CacheServer
exports.errors = {
    UnsupportedImageType: UnsupportedImageTypeError
}
