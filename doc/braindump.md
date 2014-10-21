Monitoring
-----------

* Requests per minute. Cache/process, ratio
* Image sizes. Average, median, histogram
* Request response time. Cache/process, average, quartile, 95 percentile
* Processing request time should be scaled by image size (per megapixel)?
* Which graphs are requested/processed
* Which apps are making cache/process requests, quotas
* Number of errors (client/server) last minute
* Number of images cached, total size

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
Needs to be kept in a database or something
Base set of graphs/components available to everyone

When allowing custom graphs, must ensure that failures are handled
gracefully and that good error messages are returned
It would also be useful to offer an interactive runtime as-a-service,
to facilitate quick and easy development of new graphs.
It should also allow to deploy graphs directly from Flowhub.
Through github or FBP protocol? GH would allow collaboration...

Not easy to securely allow custom components, would
need virtualization or to use dedicated workers in (DMZ)
for that case. Could be premium feature


Componentization
-----------------
Making imgflo-server build on NoFlo, and be a proper Flowhub runtime/app

First wrap the high-level modules/interfaces
that already existing into components:
* Processor
* Cache

* Request routing
* Download

Data sent between components should be plain JS objects preferably

The places which currently do @emitEvent() is probably be where edges should be.
Should maybe migrate away from event system as second step.
Components could have port where they emit events,
wired to central handler (could be exported outport).

Keep the HTTP front-end code as the outermost shell?
.. Check what Reserve does
Should prepare for Download+Processor become its own worker role,
communicate with frontend over AMQP
.. Use Poly code as a starting-point

How to logically represent multiple workers for same components,
generate a graph which just has those N workers, with inports/outports?

Processing workers
-------------------
| client  |   frontend  | queue    |  worker  |

# Request is already cached
  /A
             isCached?
  /cached/A   <- yes
  
# Request is not cached, needs processing
  /B
           isCached?
              no            ->     
				      isCached?
  					no
				       process()
					 |
   				    putIntoCache()
                                         |
  /cached/B                 <-  


| client  |   frontend  | queue    |  worker  |
  
# Multiple request which are not initially cached
# one gets processed and all pending requests for that
# resource get responses from it

  /C [1]
          isCached?
             no             -> 1 
  /C [2]
          isCached?
             no             -> 2
			       1 ->
				      isCached?
                                        no
                                      process()
					 |	 
				      putCache()
			    <- 1
    findPending()
      [1, 2]
  /cached/C [1]
  /cached/C [2]
			       2 ->   isCached?
                            <- 2         yes
    findPending()
      []

  # Don't think we can decide which frontend messages go
  # so probably needs to be pub-sub in that direction?

Appropo, sequence diagrams could be a nifty DSL
for describing test scenarioes?
