class LogHandler
    @errors = null
    constructor: (server) ->
        @errors = []
        server.on 'logevent', @logEvent

    logEvent: (id, data) =>
        if id == 'process-request-end'
            if data.stderr
                for e in data.stderr.split '\n'
                    e = e.trim()
                    @errors.push e if e
            if data.err
                @errors.push data.err
        else if (id.indexOf 'error') != -1
            if data.err
                @errors.push data
        else if id == 'request-received' or id == 'serve-processed-file'
            #
        else
            console.log 'WARNING: unhandled log event', id

    popErrors: () ->
        errors = (e for e in @errors)
        @errors = []
        return errors

exports.LogHandler = LogHandler
