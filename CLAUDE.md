# CLAUDE.md

## Commands

- `make test` — run tests
- `make lint` — lint with selene
- `make typecheck` — type check with lua-language-server
- `make format` — format code with stylua and prettier
- `make ci` — run full CI pipeline

## Issue tracking

This project uses **bd (beads)** for issue tracking. Run `bd prime` for workflow context.

- `bd ready` - Find unblocked work
- `bd list` - All open issues
- `bd create "Title" --type task --priority 2` - Create issue
- `bd close <id>` - Complete work
- `bd sync` - Sync with git (run at session end)

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
