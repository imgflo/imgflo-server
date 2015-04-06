
processing = require './processing'
common = require './common'

msgflo = require 'msgflo'

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

exports.getParticipant = (config) ->
  client = msgflo.transport.getClient config.broker_url
  participant = ProcessImageParticipant client, 'worker'
  participant.executor = new processing.JobExecutor config
  return participant

exports.main = ->
  config = common.getProductionConfig()
  participant = exports.getParticipant config
  participant.connectGraphEdgesFile './service.fbp', (err) ->
    throw callback err if err
    participant.start (err) ->
      throw callback err if err

      console.log "worker started using broker #{config.broker_url}"
      participant.messaging.channel.prefetch 4 # allow N concurrent requests
