BUILD ?= 1.60.1.70959

.PHONY: lint test zip

lint:
	luacheck .

test:
	busted

zip:
	rm -rf dist && mkdir -p dist/WarcraftBets
	cp -r WarcraftBets.toc *.lua Locales LICENSE README.md dist/WarcraftBets/
	cd dist && zip -qr WarcraftBets.zip WarcraftBets && rm -rf WarcraftBets
