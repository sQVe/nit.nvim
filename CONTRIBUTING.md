# Contributing

## Setup

Requires Neovim 0.10+ and:

- [selene](https://github.com/Kampfkarren/selene) for linting
- [stylua](https://github.com/JohnnyMorganz/StyLua) for formatting
- [lua-language-server](https://github.com/LuaLS/lua-language-server) for type checking

## Development

- `make test` — run tests
- `make lint` — lint with selene
- `make typecheck` — type check with lua-language-server
- `make format` — format with stylua and prettier

## Pull requests

1. Branch from `main`
2. Verify `make ci` passes
3. Open a PR to `main`
