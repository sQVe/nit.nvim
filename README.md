# nit.nvim

A file-centric GitHub PR review plugin for Neovim.

## Requirements

- Neovim >= 0.10.0
- [gh CLI](https://cli.github.com/) (authenticated)

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  'sqve/nit.nvim',
  config = function()
    require('nit').setup({})
  end,
}
```

## Usage

_Documentation coming soon._

## Development

This project uses test-driven development (TDD). Tests are written before implementation.

### Running tests

```bash
make test
```

Tests run in an isolated environment using [lazy.minit](https://github.com/folke/lazy.nvim) which automatically bootstraps mini.test and luassert.

### Linting and formatting

```bash
make lint          # Run selene
make format        # Format with stylua
make format-check  # Check formatting
```

## License

MIT
