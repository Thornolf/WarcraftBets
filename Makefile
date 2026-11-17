BUILD ?= 1.60.1.70959

.PHONY: lint test data zip

lint:
	luacheck .

test:
	busted

data:
	python3 tools/build_recipes.py --build $(BUILD)

zip:
	rm -rf dist && mkdir -p dist/WarcraftBets
	cp -r WarcraftBets.toc *.lua Locales Data LICENSE README.md dist/WarcraftBets/
	cd dist && zip -qr WarcraftBets.zip WarcraftBets && rm -rf WarcraftBets
