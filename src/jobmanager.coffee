#     imgflo-server - Image-processing server
#     (c) 2014-2015 The Grid
#     imgflo-server may be freely distributed under the MIT license

uuid = require 'uuid'
msgflo = require 'msgflo'
EventEmitter = require('events').EventEmitter

common = require './common'
local = require './local'
worker = require './worker'

FrontendParticipant = (client, role) ->

  definition =
    component: 'imgflo-server/HttpApi'
    icon: 'code'
    label: 'Creates processing jobs from HTTP requests'
    inports: [
      {
        id: 'newjob'
        type: 'object'
        hidden: true
      },
      {
        id: 'jobresult'
        type: 'object'
      }
    ]
    outports: [
      {
        id: 'newjob'
        type: 'object'
      }
      ,
      {
        id: 'jobresult'
        type: 'object'
        hidden: true
      }
    ]

  func = (inport, indata, send) ->
    if inport == 'newjob'
        # no-op, just forwards directly, so the job appears on output queue
        send 'newjob', null, indata
    else if inport == 'jobresult'
        # no-op, just forwards directly, so the job appears on output queue
        send 'jobresult', null, indata

  return new msgflo.participant.Participant client, definition, func, role

class JobManager extends EventEmitter
    constructor: (@options) ->
        @jobs = {} # pending/in-flight
        @worker = null
        @frontend = null

    start: (callback) ->
        broker = msgflo.transport.getBroker @options.broker_url if @options.broker_url.indexOf('direct://') == 0
        broker.connect(->) if broker # HACK
        c = msgflo.transport.getClient @options.broker_url
        @frontend = FrontendParticipant c, 'api'
        @frontend.on 'data', (port, data) =>
            @onResult data if port == 'jobresult'

        @frontend.connectGraphEdgesFile './service.fbp', (err) =>
            return callback err if err
            @frontend.start (err) =>
                return callback err if err
                return callback null if @options.worker_type != 'internal'
                @worker = new worker.getParticipant @options
                @worker.executor.on 'logevent', (id, data) => @logEvent id, data
                @worker.connectGraphEdgesFile './service.fbp', (err) =>
                    return callback err if err
                    @worker.start callback

    stop: (callback) ->
        @frontend.stop (err) =>
            @frontend = null
            return callback err if err
            return callback null if not @worker
            @worker.stop (err) =>
                @worker = null
                return callback err

    logEvent: (id, data) ->
        @emit 'logevent', id, data

    createJob: (type, data) ->
        # TODO: validate type and data
        job =
            type: type
            data: data
            id: uuid.v4()
            callback: null
        @jobs[job.id] = job
        @frontend.send 'newjob', job, () =>
        @logEvent 'job-created', { job: job.id }
        return job

    doJob: (type, data, callback) ->
        job = @createJob type, data
        @jobs[job.id].callback = callback

    onResult: (result) ->
        job = @jobs[result.id]
        @logEvent 'job-result', { job: result.id, pending: if job? then "true" else "false" }
        return if not job # we got results from a non-pending job
        delete @jobs[result.id]
        # TODO: sanity check job.data.request result.data.request
        err = if result.error then result.error else null
        return job.callback(err, result) if job.callback

exports.JobManager = JobManager
