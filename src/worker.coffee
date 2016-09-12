
processing = require './processing'
common = require './common'

msgflo = require 'msgflo-nodejs'

ProcessImageParticipant = (client, role) ->

  definition =
    component: 'imgflo-server/ProcessImage'
    icon: 'file-image-o'
    label: 'Executes image processing jobs'
    inports: [
      id: 'job'
      type: 'object'
    ]
    outports: [
      id: 'jobresult'
      type: 'object'
    ]

  func = (inport, job, send) ->
    throw new Error 'Unsupported port: ' + inport if inport != 'job'

    # XXX: use an error queue?
    @executor.doJob job, (result) ->
      send 'jobresult', null, result

  return new msgflo.participant.Participant client, definition, func, role

exports.getParticipant = (config, role='imgflo_worker') ->
  options =
    prefetch: 4
  client = msgflo.transport.getClient config.broker_url, options
  participant = ProcessImageParticipant client, role
  participant.executor = new processing.JobExecutor config
  return participant

exports.main = ->
  config = common.getProductionConfig()
  role = process.argv[2]
  participant = exports.getParticipant config, role

  process.on 'uncaughtException', (err) ->
    console.log 'Uncaught exception: ', err
    console.log err.stack

  participant.executor.on 'logevent', (id, data) ->
    console.log "EVENT: #{id}:", data

  participant.start (err) ->
    throw err if err

    console.log "#{role} started using broker #{config.broker_url}"
    console.log "with workdir #{config.workdir}"
    console.log "with #{config.cache_type} cache"
