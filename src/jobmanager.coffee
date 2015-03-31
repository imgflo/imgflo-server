#     imgflo-server - Image-processing server
#     (c) 2014-2015 The Grid
#     imgflo-server may be freely distributed under the MIT license

uuid = require 'uuid'
common = require './common'
local = require './local'

# Performs jobs using workers over AMQP/msgflo
class AmqpWorker extends common.JobWorker # TODO: implement
    constructor: () ->


class JobManager
    constructor: (@options) ->
        console.log 'JobManager options', @options
        @jobs = {} # pending/in-flight
        @worker = null

    start: (callback) ->
        # FIXME: use msgflo transport abstraction for local versus AMQP case.
        # Still need to create participant though
        @worker = new local.Worker @options

        @worker.onJobUpdated = (result) =>
            @onResult result
        @worker.setup callback

    stop: (callback) ->
        @worker.destroy (err) ->
            @worker = null
            return callback err

    createJob: (type, data) ->
        # TODO: validate type and data
        job =
            type: type
            data: data
            id: uuid.v4()
            callback: null
        @worker.addJob job, () ->
        @jobs[job.id] = job
        return job

    doJob: (type, data, callback) ->
        job = @createJob type, data
        @jobs[job.id].callback = callback

    onResult: (result) ->
        job = @jobs[result.id]
        # TODO: sanity check job.data.request result.data.request
        err = if result.error then result.error else null
        job.callback err, result if job.callback

exports.JobManager = JobManager
