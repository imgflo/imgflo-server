
VERSION=$(shell echo `git describe --tags`)
#PREFIX=/opt/imgflo
PREFIX=$(shell echo `pwd`/install)

TRAVIS_DEPENDENCIES=$(shell echo `cat .vendor_urls | sed -e "s/heroku/travis/" | tr -d '\n'`)

all: install

run: install
	npm start

runtime:
	cd runtime && make PREFIX=$(PREFIX) install

install: env runtime

env:
	mkdir -p $(PREFIX) || true
	sed -e 's|@PREFIX@|$(PREFIX)|' runtime/env.sh.in > $(PREFIX)/env.sh
	chmod +x $(PREFIX)/env.sh

travis-deps:
	wget -O imgflo-dependencies.tgz $(TRAVIS_DEPENDENCIES)
	tar -xf imgflo-dependencies.tgz

dependencies:
	cd runtime/dependencies && make PREFIX=$(PREFIX) dependencies
gegl:
	cd runtime/dependencies && make PREFIX=$(PREFIX) gegl
glib:
	cd runtime/dependencies && make PREFIX=$(PREFIX) glib
libsoup:
	cd runtime/dependencies && make PREFIX=$(PREFIX) libsoup

check: install
	$(PREFIX)/env.sh npm test

clean:
	git clean -dfx --exclude node_modules --exclude install

release: check
	cd $(PREFIX) && tar -caf ../imgflo-$(VERSION).tgz ./

.PHONY:all run dependencies runtime
