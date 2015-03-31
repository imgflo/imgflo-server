
processing = require './processing'

msgflo = require 'msgflo'

ProcessImageParticipant = (client, customId) ->
  id = 'process-image-' + (process.env.DYNO or '')
  id = customId if customId

  definition =
    id: id
    'class': 'imgflo-server/ProcessImage'
    icon: 'file-word-o'
    label: 'Executes image processing jobs'
    inports: [
      id: 'job'
      queue: 'new-jobs' # FIXME: load from .fbp / .json file
      type: 'object'
    ]
    outports: [
      id: 'jobresult'
      queue: 'job-results' # FIXME: load from .fbp / .json file
      type: 'object'
    ]

  func = (inport, job, send) ->
    throw new Error 'Unsupported port: ' + inport if inport != 'job'

    # XXX: use an error queue?
    @executor.doJob job, (result) ->
        send 'jobresult', null, result

  return new msgflo.participant.Participant client, definition, func



exports.main = ->

  options = { workdir: 'worker', cache: { workdir: 'testtemp', baseurl: 'localhost:8888' } } # FIXME: use proper cache options from config
  address = 'amqp://localhost' # FIXME: use proper broker from config
  client = msgflo.transport.getClient address
  participant = ProcessImageParticipant client
  participant.executor = new processing.JobExecutor options
  participant.start (err) ->
    throw callback err if err

    # FIXME: prefetch is hardcoded to 1 in msgflo
    console.log 'worker started'
    client.channel.prefetch 1 # allow N concurrent requests
