Monitoring
-----------

* Requests per minute. Cache/process, ratio
* Image sizes. Average, median, histogram
* Request response time. Cache/process, average, quartile, 95 percentile
* Processing request time should be scaled by image size (per megapixel)?
* Which graphs are requested/processed
* Which apps are making cache/process requests, quotas
* Number of errors (client/server) last minute

Should be able to set warning thresholds on parameters, if exceeded
should send email and/or instant-message to admin

Dashboard should include Flowhub links, to look inside the service.


Apps
----------------
When we scale horizonally, should support multiple apps
Self-managed for getting API keys, changing plans etc
Free tier for testing
Probably use TheGrid for authentication and billing
Graphs/components should be per-app
Base set of graphs/components available to everyone

Not easy to securely allow custom components, would
need virtualization or to use dedicated workers in (DMZ)
for that case. Could be premium feature
