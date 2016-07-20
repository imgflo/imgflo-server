
enabled = process.env.NEW_RELIC_LICENSE_KEY?
if enabled
    nr = require('newrelic');

exports.onJobCompleted = (job) ->
    return if not job.type == 'process-image'
    return if not enabled

    d = job.data
    runtime = d.runtime
    runtime = 'noflo' if runtime == 'noflo-browser' or runtime == 'noflo-nodejs'
    totalDuration = job.completed_at-job.created_at
    event =
        client: d.apikey
        graph: d.graph
        runtime: runtime
        duration: totalDuration
        outtype: d.outtype
        width: d.iips.width
        height: d.iips.height
        error: job.error

    name = 'ImgfloImageComputed'
    nr.recordCustomEvent name, event
