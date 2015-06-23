#     imgflo-server - Image-processing server
#     (c) 2014-2015 The Grid
#     imgflo-server may be freely distributed under the MIT license

uuid = require 'uuid'
msgflo = require 'msgflo'
EventEmitter = require('events').EventEmitter
async = require 'async'

common = require './common'
local = require './local'
worker = require './worker'

FrontendParticipant = (client, role) ->

  outproxies = ['urgentjob', 'backgroundjob']
  inproxies = ['jobresult']

  definition =
    component: 'imgflo-server/HttpApi'
    icon: 'code'
    label: 'Creates processing jobs from HTTP requests'
    inports: []
    outports: []

  for name in outproxies
    definition.inports.push { id: name, hidden: true }
    definition.outports.push { id: name }
  for name in inproxies
    definition.inports.push { id: name }
    definition.outports.push { id: name, hidden: true }


  func = (inport, indata, send) ->
    isProxy = outproxies.indexOf(inport) != -1 or inproxies.indexOf(inport) != -1
    throw new Error "Unknown port #{inport}" if not isProxy
    # forward
    send inport, null, indata

  return new msgflo.participant.Participant client, definition, func, role

startInternalWorkers = (manager, roles, callback) =>
  startWorker = (role, cb) =>
      w = worker.getParticipant manager.options, role
      manager.workers[role] = w
      w.executor.on 'logevent', (id, data) =>
        manager.logEvent id, data
      w.start cb

  return callback null if manager.options.worker_type != 'internal'
  async.map roles, startWorker, callback

class JobManager extends EventEmitter
    constructor: (@options) ->
        @jobs = {} # pending/in-flight
        @workers = {} # internal workers
        @frontend = null

    start: (callback) ->
        broker = msgflo.transport.getBroker @options.broker_url if @options.broker_url.indexOf('direct://') == 0
        broker.connect(->) if broker # HACK
        c = msgflo.transport.getClient @options.broker_url
        @frontend = FrontendParticipant c, 'imgflo_api'
        @frontend.on 'data', (port, data) =>
            @onResult data if port == 'jobresult'

        setup =
          broker: @options.broker_url
          graphfile: './graphs/imgflo-server.fbp'
        graph = require('fbp').parse(require('fs').readFileSync(setup.graphfile, 'utf-8'))
        roles = Object.keys(graph.processes).filter((n) -> n != 'imgflo_api')
        startInternalWorkers this, roles, (err) =>
          return callback err if err
          @frontend.start (err) =>
              return callback err if err
              msgflo.setup.bindings setup, callback

    stop: (callback) ->
        @frontend.stop (err) =>
            @frontend = null
            return callback err if err
            stopWorker = (n, cb) =>
                w = @workers[n]
                delete @workers[n]
                w.stop cb
            async.map Object.keys(@workers), stopWorker, callback

    logEvent: (id, data) ->
        @emit 'logevent', id, data

    createJob: (type, urgency, data, callback) ->
        # TODO: validate type and data
        job =
            urgency: urgency
            type: type
            data: data
            id: uuid.v4()
            created_at: Date.now()
            callback: null
        onSent = (err) =>
            @logEvent 'job-created', { job: job.id, err: err }
            return callback err if err
            @jobs[job.id] = job
            return callback null, job
        port = if urgency == 'urgent' then "urgentjob" else "backgroundjob"
        @frontend.send port, job
        onSent null # FIXME: Participant.send should take callback


    doJob: (type, data, jobcallback, callback) ->
        urgency = if jobcallback then 'urgent' else 'background'
        @createJob type, urgency, data, (err, job) =>
            return callback err if err
            # FIXME: callback should be in another mapping, to separate from plain,peristable data
            @jobs[job.id].callback = jobcallback if jobcallback
            return callback null

    onResult: (result) ->
        job = @jobs[result.id]
        @logEvent 'job-result', { job: result.id, pending: if job? then "true" else "false" }
        return if not job # we got results from a non-pending job
        delete @jobs[result.id]
        # TODO: sanity check job.data.request result.data.request
        err = if result.error then result.error else null
        return job.callback(err, result) if job.callback

exports.JobManager = JobManager
