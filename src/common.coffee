#     imgflo-server - Image-processing server
#     (c) 2014 The Grid
#     imgflo-server may be freely distributed under the MIT license

# Interface for Processors
class Processor
    constructor: (verbose) ->
        @verbose = verbose

    # FIXME: clean up interface
    # callback should be called with (err, error_string)
    process: (outputFile, outType, graph, iips, inputFile, inputType, callback) ->
        throw new Error 'Processor.process() not implemented'

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

exports.clone = clone
exports.Processor = Processor
