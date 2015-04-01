#     imgflo-server - Image-processing server
#     (c) 2014-2015 The Grid
#     imgflo-server may be freely distributed under the MIT license

uuid = require 'uuid'
msgflo = require 'msgflo'

common = require './common'
local = require './local'
worker = require './worker'

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

class JobManager
    constructor: (@options) ->
        console.log 'JobManager options', @options
        @jobs = {} # pending/in-flight
        @worker = null
        @frontend = null

    start: (callback) ->
        broker = msgflo.transport.getBroker @options.broker_url if @options.broker_url.indexOf('direct://') == 0
        broker.connect(->) if broker # HACK
        console.log 'broker created???'
        c = msgflo.transport.getClient @options.broker_url
        @frontend = FrontendParticipant c
        @frontend.on 'data', (port, data) =>
            console.log 'participant data on port', port
            @onResult data if port == 'jobresult'
        @frontend.start (err) =>
            return callback err if err
            return callback null if @options.worker_type != 'internal'
            @worker = new worker.getParticipant @options
            @worker.start callback

    stop: (callback) ->
        @frontend.stop (err) =>
            @frontend = null
            return callback err if err
            return callback null if not @worker
            @worker.stop (err) =>
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
        @frontend.send 'newjob', job, () =>
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
