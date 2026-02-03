.PHONY: test lint format

test:
	nvim -l tests/minit.lua --minitest

lint:
	selene lua/

format:
	stylua lua/ tests/ plugin/

format-check:
	stylua --check lua/ tests/ plugin/
