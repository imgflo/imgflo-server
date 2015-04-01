#     imgflo-server - Image-processing server
#     (c) 2014-2015 The Grid
#     imgflo-server may be freely distributed under the MIT license

uuid = require 'uuid'
msgflo = require 'msgflo'

common = require './common'
local = require './local'

FrontendParticipant = (client, customId) ->
  id = 'http-api' + (process.env.DYNO or '')
  id = customId if customId

  definition =
    id: id
    'class': 'imgflo-server/HttpApi'
    icon: 'code'
    label: 'Creates processing jobs from HTTP requests'
    inports: [
      {
        id: 'newjob'
        type: 'object'
      },
      {
        id: 'jobresult'
        type: 'object'
        queue: 'job-results' # FIXME: load from .fbp / .json file
      }
    ]
    outports: [
      {
        id: 'newjob'
        queue: 'new-jobs' # FIXME: load from .fbp / .json file
        type: 'object'
      }
      ,
      {
        id: 'jobresult'
        type: 'object'
      }
    ]

  func = (inport, indata, send) ->
    console.log 'frontendparticipant', inport, indata.id
    if inport == 'newjob'
        # no-op, just forwards directly, so the job appears on output queue
        send 'newjob', null, indata
    else if inport == 'jobresult'
        # no-op, just forwards directly, so the job appears on output queue
        send 'jobresult', null, indata

  return new msgflo.participant.Participant client, definition, func

# Performs jobs using workers over AMQP/msgflo
class AmqpWorker extends common.JobWorker # TODO: implement
    constructor: (options) ->
        @client = msgflo.transport.getClient options.broker
        @participant = FrontendParticipant @client
        @participant.on 'data', (port, data) =>
            console.log 'participant data on port', port
            @onJobUpdated data if port == 'jobresult'

    setup: (callback) ->
        @participant.start (err) ->
            console.log 'participant started', err
            return callback err

    destroy: (callback) ->
        @participant.stop callback

    addJob: (job, callback) ->
        @participant.send 'newjob', job, () =>
            console.log 'job sent', job.id
        return callback null


class JobManager
    constructor: (@options) ->
        console.log 'JobManager options', @options
        @jobs = {} # pending/in-flight
        @worker = null

    start: (callback) ->
        # FIXME: use msgflo transport abstraction for local versus AMQP case.
        # Still need to create participant though
        @worker = new local.Worker @options
        #@worker = new AmqpWorker @options

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
        @jobs[job.id] = job
        @worker.addJob job, () ->
        console.log 'created job', job.id
        return job

    doJob: (type, data, callback) ->
        job = @createJob type, data
        @jobs[job.id].callback = callback

    onResult: (result) ->
        console.log 'onresult', result.id, Object.keys @jobs
        job = @jobs[result.id]
        console.log 'onresult job?', if job? then "true" else "false"
        return if not job # we got results from a non-pending job
        delete @jobs[result.id]
        # TODO: sanity check job.data.request result.data.request
        err = if result.error then result.error else null
        return job.callback(err, result) if job.callback

exports.JobManager = JobManager
