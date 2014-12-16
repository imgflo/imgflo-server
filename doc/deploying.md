
Deploying
============

Before deploying, it is often smart to check that tests pass locally.

    npm test

Deploying

    git tag $VERSION
    git push origin HEAD:master --tags

Check that build succeeds on [Travis CI](http://travis-ci.org/jonnor/imgflo-server).
Sometimes some *stress test fail* just barely.
This can happen due to variable performance on different Travis workers.
If this happens, just restart the build to try again.

Verifying deploy
================

* Go to [thegrid.io](https://thegrid.io) in *incognito browser*, verify cached images being served
* Go to [imgflo web interface](http://imgflo.herokuapp.com), enter info to run a processing request, verify it appears
* Check [Metrics on Heroku](https://dashboard.heroku.com/apps/imgflo)

TODO: create automated production checks

Rolling back
===========

Go to [Activity on Heroku](https://dashboard.heroku.com/apps/imgflo/activity).
Hit "roll back to here" on the previous known-working version (usually the past one).
