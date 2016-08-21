
debug = process.env.IMGFLO_DEBUG_METRICS
enabled = process.env.NEW_RELIC_LICENSE_KEY?
if enabled
    nr = require('newrelic');

prepareEvent = (job) ->
    d = job.data
    runtime = d.runtime
    runtime = 'noflo' if runtime == 'noflo-browser' or runtime == 'noflo-nodejs'
    totalDuration = job.completed_at-job.created_at

    steps =
        queue: job.started_at-job.created_at
        download: job.downloaded_at-job.started_at
        processing: job.processed_at-job.downloaded_at
    stepsTotal = 0
    for k,v of steps
        if isNaN(v)
            steps[k] = undefined
        else
            stepsTotal += v

    slush = totalDuration - stepsTotal
    event =
        # id
        request: d.request
        # request info
        client: d.apikey
        graph: d.graph
        runtime: runtime
        outtype: d.outtype
        width: d.iips.width
        height: d.iips.height
        urgency: job.urgency
        input: d.files?.input?.src
        # metrics
        duration: totalDuration
        processing: steps.processing
        downloading: steps.download
        queueing: steps.queue
        slush: slush
        # error
        error: job.error?.result?.error

    return event

exports.onJobCompleted = (job) ->
    return if not job.type == 'process-image'
    return if not (enabled or debug)

    name = 'ImgfloImageComputed'
    event = prepareEvent job
    console.log 'MetricEvent', name, '\n', event if debug

    return if not enabled
    nr.recordCustomEvent name, event
