#     imgflo - Flowhub.io Image-processing runtime
#     (c) 2014 The Grid
#     imgflo may be freely distributed under the MIT license

server = require '../src/server'
utils = require './utils'
chai = require 'chai'
yaml = require 'js-yaml'
request = require 'request'
async = require 'async'
statistics = require 'simple-statistics'

http = require 'http'
fs = require 'fs'
path = require 'path'
url = require 'url'

# TODO:
# add cases
# - concurrent requests processing different inputs through same graph
# - for noflo-canvas
#
# lowest series indicating latency lower boundary, slope indicating scaling
# will need to do multiple rounds on each test series to get enough data
# add a way to clean cache between each round?
# add a way to generate images which can be used as inputs
#
# Measure processing time per request. Store raw data as .json
# URL + time(s)
# Build statistics, evaluate if acceptable
# mean+median latency, quartiles, std-dev, percentage above soft+hard limit
# differences between request sizes, evaluate scaleability
# should have confidence tests
# very huge timeout, like 5 mins?
# only run if a flag is set (opt-in)
# ideally be able to directly on server, to evaluate how much network latency is
# also run with a mix of local input images and remote
# Verify correctness of images against eachohter. SHA sum based on first

urlbase = process.env.IMGFLO_TESTS_TARGET
urlbase = 'localhost:8888' if not urlbase
port = (urlbase.split ':')[1]
host = (urlbase.split ':')[0]
verbose = process.env.IMGFLO_TESTS_VERBOSE?
startServer = (urlbase.indexOf 'localhost') == 0
itSkipRemote = if not startServer then it.skip else it
describeSkipPerformance = if process.env.IMGFLO_TESTS_PERFORMANCE? then describe else describe.skip

requestRecordTime = (reqUrl, callback) ->
    startTime = process.hrtime()
    req = request reqUrl, (err, response) ->
        timeDiff = process.hrtime(startTime)
        timeDiffMs = timeDiff[0]*1000 + timeDiff[1]/1000000
        return callback err, timeDiffMs if err
        return callback null, timeDiffMs

    return req

randomString = (n) ->
    text = "";
    possible = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
    for i in [0...n]
        idx = Math.floor Math.random()*possible.length
        text += possible.charAt idx
    return text;

identicalRequests = (u, number) ->
    return (u for n in [0...number])

randomRequests = (graph, props, number, randomprop) ->
    f = () ->
        props[randomprop] = randomString 5+(number/10)
        return utils.formatRequest urlbase, graph, props
    return (f() for n in [0...number])

describeTimings = (times) ->
    r =
        values: times
        mean: statistics.mean(times)
        stddev: statistics.standard_deviation(times)
        min: statistics.min(times)
        max: statistics.max(times)
    r['stddev-perc'] = r.stddev/r.mean*100
    return r

# End-to-end stress-tests of image processing server, particularly performance
describeSkipPerformance 'Stress', ->
    s = null
    l = null
    outdir = "spec/out"
    stresstests = yaml.safeLoad fs.readFileSync 'spec/stresstests.yml', 'utf-8'
    fs.writeFileSync outdir+'/stresstests.json', (JSON.stringify(stresstests))

    before (done) ->
        wd = './stressteststemp'
        if fs.existsSync wd
            for f in fs.readdirSync wd
                fs.unlinkSync path.join wd, f
        if startServer
            s = new server.Server wd, null, null, verbose
            l = new utils.LogHandler s
            s.listen 'localhost', port, done
    after ->
        s.close() if startServer


    describe "Cached graph", ->
        testid = 'cached_graph'
        requestUrl = utils.formatRequest urlbase, 'gradientmap', {input: 'demo/gradient-black-white.png'}
        testcases = stresstests[testid]

        it 'generating cache', (done) ->
            cacheUrl = requestUrl
            requestRecordTime cacheUrl, (err, res) ->
                chai.expect(err).to.not.exist;
                done()

        testcases.expected[host].forEach (expect, i) ->
            concurrent = testcases.concurrent[i]

            describe "#{concurrent} concurrent requests", (done) ->
                total = testcases.concurrent[testcases.expected[host].length-1]
                requestUrls = identicalRequests requestUrl, total

                it "average response time should be below #{expect} ms", (done) ->
                    @timeout 5*60*1000
                    async.mapLimit requestUrls, concurrent, requestRecordTime, (err, times) ->
                        chai.expect(err).to.not.exist
                        results = describeTimings times
                        fname = outdir+"/stress.#{testid}.#{concurrent}.json"
                        c = JSON.stringify results
                        fs.writeFile fname, c, (err) ->
                            console.log 'Mean, std-dev (%)', results.mean, results['stddev-perc']
                            chai.expect(results.mean).to.be.below expect
                            done()


    describe "Processing same input with different attributes", ->
        testid = 'process_same_input'
        testcases = stresstests[testid]

        testcases.expected[host].forEach (expect, i) ->
            concurrent = testcases.concurrent[i]

            describe "#{concurrent} concurrent requests", (done) ->
                total = testcases.concurrent[testcases.expected[host].length-1]*10
                requestUrls = randomRequests 'passthrough', {input: 'demo/grid-toastybob.jpg'}, total, 'ignored'

                it "average response time should be below #{expect} ms", (done) ->
                    @timeout 1*60*1000
                    async.mapLimit requestUrls, concurrent, requestRecordTime, (err, times) ->
                        chai.expect(err).to.not.exist
                        results = describeTimings times
                        fname = outdir+"/stress.#{testid}.#{concurrent}.json"
                        c = JSON.stringify results
                        fs.writeFile fname, c, (err) ->
                            console.log 'Mean, std-dev (%)', results.mean, results['stddev-perc']
                            chai.expect(results.mean).to.be.below expect
                            done()

    # FIXME: should be different sizes of input image
    describe "Processing same input at different sizes", ->
        testid = 'process_different_sizes'
        testcases = stresstests[testid]
        concurrent = 2

        testcases.expected[host].forEach (expect, i) ->
            size = testcases.sizes[i]

            describe "#{size}x#{size} pixels", (done) ->
                total = concurrent*5
                props = {input: 'demo/mountains.png', height: size, width: size}
                requestUrls = randomRequests 'passthrough', props, total, 'ignored'

                it "average response time should be below #{expect} ms", (done) ->
                    @timeout 5*60*1000
                    async.mapLimit requestUrls, concurrent, requestRecordTime, (err, times) ->
                        chai.expect(err).to.not.exist
                        results = describeTimings times
                        fname = outdir+"/stress.#{testid}.#{size}.json"
                        c = JSON.stringify results
                        fs.writeFile fname, c, (err) ->
                            console.log 'Mean, std-dev (%)', results.mean, results['stddev-perc']
                            chai.expect(results.mean).to.be.below expect
                            done()
