.PHONY: test lint typecheck format format-check ci

test:
	nvim -l tests/minit.lua --minitest

lint:
	selene --display-style=quiet lua/ plugin/ tests/

typecheck:
	lua-language-server --configpath="$$(pwd)/.luarc.json" --check lua/ --checklevel=Warning

format:
	stylua lua/ plugin/ tests/
	npx prettier --write --ignore-unknown "**/*.{md,json,yaml,yml}"

format-check:
	stylua --check lua/ plugin/ tests/
	npx prettier --check --ignore-unknown "**/*.{md,json,yaml,yml}"

ci: test lint typecheck format-check
