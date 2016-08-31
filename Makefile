
VERSION=$(shell echo `git describe --tags`)
#PREFIX=/opt/imgflo
PREFIX=$(shell echo `pwd`/install)
#TESTS=

PROJECTDIR=$(shell echo `pwd`)

ifdef TESTS
TEST_ARGUMENTS=--grep "$(TESTS)"
endif

TRAVIS_DEPENDENCIES=$(shell echo `cat .vendor_urls | sed -e "s/heroku/travis-${TRAVIS_OS_NAME}/" | tr -d '\n'`)

FBP_GRAPHS = $(wildcard ./graphs/*.fbp)
JSON_GRAPHS = $(wildcard ./graphs/*.json)
GRAPHS=$(FBP_GRAPHS:%.fbp=%.json.info)
GRAPHS+=$(JSON_GRAPHS:%.json=%.json.info)

INTERNAL_GRAPHS=./graphs/imgflo-server.json.info ./graphs/performance.json.info

PROCESSING_GRAPHS:=$(filter-out $(INTERNAL_GRAPHS),$(GRAPHS))

all: install

run: install
	npm start
run-runtime: runtime
	cd runtime && make PREFIX=$(PREFIX) run

runtime:
	cd runtime && make PREFIX=$(PREFIX) install

version:
	echo 'No version info installed'

install: env version procfile runtime components graphs webpack

env:
	mkdir -p $(PREFIX) || true
	sed -e 's|@PREFIX@|$(PREFIX)|' runtime/env.sh.in > $(PREFIX)/env.sh
	chmod +x $(PREFIX)/env.sh

travis-deps:
	wget -O imgflo-dependencies.tgz $(TRAVIS_DEPENDENCIES)
	tar -xf imgflo-dependencies.tgz

components: env
	cd runtime && make components PREFIX=$(PREFIX) COMPONENTDIR=$(PROJECTDIR)/components/extra

component: env
	cd runtime && make component PREFIX=$(PREFIX) \
		COMPONENT=$(COMPONENT) \
		COMPONENTINSTALLDIR=$(COMPONENTINSTALLDIR) \
		COMPONENTDIR=$(COMPONENTDIR) \
		COMPONENT_NAME_PREFIX=$(COMPONENT_NAME_PREFIX) \
		COMPONENT_NAME_SUFFIX=$(COMPONENT_NAME_SUFFIX)

%.json: %.fbp
	./node_modules/.bin/fbp $< > $@

%.json.info: %.json
	$(PREFIX)/env.sh imgflo-graphinfo --graph $< > $@

graphs: $(PROCESSING_GRAPHS)

procfile:
	./node_modules/.bin/msgflo-procfile --ignore imgflo_api --ignore pubsub --ignore pubsub_noflo --include 'web: node index.js' ./graphs/imgflo-server.fbp > Procfile
webpack:
	./node_modules/.bin/webpack

dependencies:
	cd runtime/dependencies && make PREFIX=$(PREFIX) dependencies
gegl:
	cd runtime/dependencies && make PREFIX=$(PREFIX) gegl
babl:
	cd runtime/dependencies && make PREFIX=$(PREFIX) babl
glib:
	cd runtime/dependencies && make PREFIX=$(PREFIX) glib
libsoup:
	cd runtime/dependencies && make PREFIX=$(PREFIX) libsoup

check: install runtime-check server-check

server-check:
	echo "WARNING: You need to setup RabbitMQ to run tests, due to https://github.com/msgflo/msgflo-nodejs/issues/1"
	IMGFLO_BROKER_URL=amqp://localhost ./node_modules/.bin/mocha --reporter spec --compilers .coffee:coffee-script/register ./spec/*.coffee $(TEST_ARGUMENTS)

runtime-check:
	./node_modules/.bin/mocha --reporter spec --compilers .coffee:coffee-script/register ./runtime/spec/*.coffee $(TEST_ARGUMENTS)

clean:
	git clean -dfx --exclude node_modules --exclude install

release: check
	cd $(PREFIX) && tar -caf ../imgflo-$(VERSION).tgz ./

.PHONY:all run dependencies runtime graphs
