# CLAUDE.md

## Commands

- `make test` — run tests
- `make lint` — lint with selene
- `make typecheck` — type check with lua-language-server
- `make format` — format code with stylua and prettier
- `make ci` — run full CI pipeline

## Guidelines

- Follow existing patterns in `lua/nit/`
- Tests go in `tests/*_spec.lua`
- Use LuaCATS annotations for types
