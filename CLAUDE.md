# CLAUDE.md

## Commands

- `make test` — run tests
- `make lint` — lint with selene
- `make typecheck` — type check with lua-language-server
- `make format` — format code with stylua and prettier
- `make ci` — run full CI pipeline

## Issue tracking

This project uses **br (beads_rust)** for issue tracking. Run `br prime` for workflow context.

**Note:** `br` is non-invasive and never executes git commands. After `br sync --flush-only`, you must manually run `git add .beads/ && git commit`.

- `br ready` - Find unblocked work
- `br list` - All open issues
- `br create "Title" --type task --priority 2` - Create issue
- `br close <id>` - Complete work
- Sync at session end:
  ```bash
  br sync --flush-only
  git add .beads/
  git commit -m "sync beads"
  ```

## Project expertise

Run `mulch prime` at session start to load architecture, conventions, pitfalls, and display knowledge.

- `mulch prime` - Load all expertise domains
- `mulch prime --context` - Load records for changed files
- `mulch search "query"` - Find relevant records

## Reference docs

- `docs/WORKFLOW.md` - Target UX vision: interaction flows, keybindings, session lifecycle
- `docs/REQUIREMENTS.md` - Open v1.1 requirements and deferred v1.2 requirements

## Guidelines

- Follow existing patterns in `lua/nit/`
- Tests go in `tests/*_spec.lua`
- Use LuaCATS annotations for types
