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
processing = require './processing'

FrontendParticipant = (client, role) ->

  outproxies = ['urgentjob', 'urgentjobnoflo', 'backgroundjob', 'backgroundjobnoflo']
  inproxies = ['jobresult']

  id = if process.env.DYNO then process.env.DYNO else uuid.v4()
  id = "#{role}-#{id}"

  definition =
    id: id
    component: 'imgflo-server/HttpApi'
    icon: 'code'
    label: 'Creates processing jobs from HTTP requests'
    inports: []
    outports: []

  for name in outproxies
    definition.inports.push { id: name, hidden: true }
    definition.outports.push { id: name }
  for name in inproxies
    definition.inports.push { id: name, hidden: true }
    definition.outports.push { id: name, hidden: true }
    # fanout handling, need unique queue for every participant.
    uniqueQueue = "#{id}.#{name.toUpperCase()}"
    definition.inports.push { id: name+'-unique', queue: uniqueQueue, '_originalid': name, persistent: false }

  func = (inport, indata, send) ->
    # map unique ports back to base/logical name
    normalized = inport.substring(0, inport.indexOf('-unique'))
    inport = normalized if normalized

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

getPubsubSource = (graph, pubSubNode) ->
    pubsubs = {}
    for name, process of graph.processes
        continue if process.component != 'msgflo/PubSub'
        pubsubs[name] = {}
    for connection in graph.connections
        tgtnode = connection.tgt.process
        srcnode = connection.src.process

        pubsubs[tgtnode].src = connection.src if pubsubs[tgtnode]
        pubsubs[srcnode].tgt = connection.tgt if pubsubs[srcnode]

    queueName = (p) ->
        return "#{p.process}.#{p.port.toUpperCase()}" # FIXME: relies on convention
    for name, connection of pubsubs
        return queueName(connection.src) if name == pubSubNode
    return null

pubsubBindings = (frontend, graph) ->
    bindings = []
    def = frontend.definition
    for conn in graph.connections
        continue if conn.tgt.process != def.role
        portName = conn.tgt.port+'-unique'
        port = def.inports.filter((p) -> p.id == portName)[0]
        continue if not port
        original = port['_originalid']
        if original
            # bind shared queue to per-participant/unique queue
            srcQueue = getPubsubSource graph, conn.src.process
            throw new Error "Cannot find target for port #{port.id}" if not srcQueue
            bindings.push
                type: 'pubsub'
                src: srcQueue
                tgt: port.queue

    return bindings

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
        setup.extrabindings = pubsubBindings @frontend, graph
        roles = []
        for n, proc of graph.processes
            continue if proc.component == 'msgflo/PubSub'
            continue if n == 'imgflo_api'
            roles.push n

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

        if typeErr = processing.runtimeSupportsType data.runtime, data.outtype
            # check here to avoid useless traffic in queue, causing workers to stay up and waste money
            return callback typeErr, job

        onSent = (err) =>
            @logEvent 'job-created', { job: job.id, err: err }
            return callback err if err
            @jobs[job.id] = job
            return callback null, job
        port = if urgency == 'urgent' then "urgentjob" else "backgroundjob"
        if data.runtime == 'noflo-browser' or data.runtime == 'noflo-nodejs'
            port += 'noflo'
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
