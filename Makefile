
VERSION=$(shell echo `git describe --tags`)
#PREFIX=/opt/imgflo
PREFIX=$(shell echo `pwd`/install)
#TESTS=

PROJECTDIR=$(shell echo `pwd`)

ifdef TESTS
TEST_ARGUMENTS=--grep $(TESTS)
endif

TRAVIS_DEPENDENCIES=$(shell echo `cat .vendor_urls | sed -e "s/heroku/travis/" | tr -d '\n'`)

all: install

run: install
	npm start

runtime:
	cd runtime && make PREFIX=$(PREFIX) install

version:
	echo 'No version info installed'

install: env version runtime components

env:
	mkdir -p $(PREFIX) || true
	sed -e 's|@PREFIX@|$(PREFIX)|' runtime/env.sh.in > $(PREFIX)/env.sh
	chmod +x $(PREFIX)/env.sh

travis-deps:
	wget -O imgflo-dependencies.tgz $(TRAVIS_DEPENDENCIES)
	tar -xf imgflo-dependencies.tgz

components: env
	cd runtime && make components PREFIX=$(PREFIX) COMPONENTDIR=$(PROJECTDIR)/components

component: env
	cd runtime && make component PREFIX=$(PREFIX) \
		COMPONENT=$(COMPONENT) \
		COMPONENTINSTALLDIR=$(COMPONENTINSTALLDIR) \
		COMPONENTDIR=$(COMPONENTDIR) \
		COMPONENT_NAME_PREFIX=$(COMPONENT_NAME_PREFIX) \
		COMPONENT_NAME_SUFFIX=$(COMPONENT_NAME_SUFFIX)

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
	./node_modules/.bin/mocha --reporter spec --compilers .coffee:coffee-script/register ./spec/*.coffee $(TEST_ARGUMENTS)

runtime-check:
	./node_modules/.bin/mocha --reporter spec --compilers .coffee:coffee-script/register ./runtime/spec/*.coffee $(TEST_ARGUMENTS)

clean:
	git clean -dfx --exclude node_modules --exclude install

release: check
	cd $(PREFIX) && tar -caf ../imgflo-$(VERSION).tgz ./

.PHONY:all run dependencies runtime
