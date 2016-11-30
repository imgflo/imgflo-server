
Deploying
============

Before deploying, it is good check that tests pass locally. Can save you time from Travis CI having to tell you.

    npm test

Deploying

    git tag $VERSION
    git push origin HEAD:master --tags

Check that the build for **the tag** (not master) succeeds on
[Travis CI](http://travis-ci.org/imgflo/imgflo-server).
If it passes, the new version should be up on Heroku. `GOTO Verifying deploy`

Notes:

Sometimes some *stress test fail* just barely.
This can happen due to variable performance on different Travis workers.
If this happens, just restart the build to try again.

Verifying deploy
================

There is a imgflo request URL configured for the [NewRelic APM](https://rpm.newrelic.com/accounts/946863/applications/5632805) pinger,
which goes through the entire processing loop every few seconds.
So generally unless that starts failing, things are at least working (might still be old version though).

Manual verification

* Go to [Activity on Heroku](https://dashboard.heroku.com/apps/imgflo/activity), check that a new version was activated.
* Go to [thegrid.io](https://thegrid.io) in *incognito browser*, verify cached images being served
* Go to [imgflo web interface](http://imgflo.herokuapp.com), enter info to run a processing request, verify it appears
* Check [Metrics on Heroku](https://dashboard.heroku.com/apps/imgflo)
that there is no/very-few 5xx errors, response time `< 500 ms`, and sane CPU/memory use.

Rolling back
===========

Go to [Activity on Heroku](https://dashboard.heroku.com/apps/imgflo/activity).
Hit "roll back to here" on the previous known-working version (usually the past one).
