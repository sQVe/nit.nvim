# Requirements: nit.nvim

**Core value:** Review PRs inside Neovim in a workflow-agnostic, out-of-the-way manner, preserving full LSP/editor capabilities.

## v1.1 Open requirements

Enables reading and responding to PR review threads through navigation, a context-aware menu, and an enhanced thread popup with reply and resolve capabilities.

### Mutations (MUT)

- [ ] **MUT-01**: Reply to a review thread via GitHub GraphQL API (`addPullRequestReviewComment` with `inReplyTo`)
- [ ] **MUT-02**: Resolve a review thread via GitHub GraphQL API (`resolveReviewThread`)
- [ ] **MUT-03**: Unresolve a review thread via GitHub GraphQL API (`unresolveReviewThread`)
- [ ] **MUT-04**: Rate-limited mutation queue with minimum delay between consecutive requests
- [ ] **MUT-05**: User-visible error notification on mutation failure (network, permissions, rate limit)

### Orchestration (ORC)

- [ ] **ORC-01**: Optimistic state update on mutation for immediate UI feedback
- [ ] **ORC-02**: Rollback to previous state when a mutation fails
- [ ] **ORC-03**: Mutation versioning to discard stale async responses

### Navigation (NAV)

- [ ] **NAV-01**: Jump to next comment in current buffer
- [ ] **NAV-02**: Jump to previous comment in current buffer
- [ ] **NAV-03**: Wrap with notification when reaching buffer boundary

### Menu (MENU)

- [ ] **MENU-01**: Context-aware floating menu opens via command or Lua API
- [ ] **MENU-02**: "Open thread" action when cursor is on a commented line
- [ ] **MENU-03**: Unavailable actions hidden, not greyed out
- [ ] **MENU-04**: Hotkeys displayed right-aligned per menu item

### Thread popup (THRD)

- [ ] **THRD-01**: Floating window showing full conversation thread with author and timestamp
- [ ] **THRD-02**: Thread resolved status displayed in popup
- [ ] **THRD-03**: Reply input area within the popup
- [ ] **THRD-04**: Submit reply with `<C-s>` (immediate submission to GitHub)
- [ ] **THRD-05**: Toggle resolved/unresolve with `<C-r>`
- [ ] **THRD-06**: Close popup with `q` or `<Esc>`
- [ ] **THRD-07**: Keybinding hints visible in popup border or footer

### Public API (API)

- [ ] **API-01**: `require('nit').menu()` opens the action menu
- [ ] **API-02**: `require('nit').next_comment()` navigates to next comment
- [ ] **API-03**: `require('nit').prev_comment()` navigates to previous comment
- [ ] **API-04**: `:Nit menu`, `:Nit next`, `:Nit prev` subcommands
- [ ] **API-05**: No automatic keybindings (Lua API only, user maps keys)

### Phase mapping

| Requirement                        | Phase                  |
| ---------------------------------- | ---------------------- |
| NAV-01–03                          | Phase 8 (done)         |
| MUT-01–03                          | Phase 9 (done)         |
| ORC-01–03                          | Phase 10 (done)        |
| THRD-01, THRD-02, THRD-06, THRD-07 | Phase 11 (in progress) |
| THRD-03–05                         | Phase 12               |
| MUT-04–05                          | Phase 13               |
| MENU-01–04                         | Phase 14               |
| API-01–05                          | Phase 15               |

## v1.2 Deferred requirements

### New comments

- **NCMT-01**: Add comment on line via floating input
- **NCMT-02**: Add comment on visual selection (range)
- **NCMT-03**: Add file-level comment
- **NCMT-04**: Pending comments with distinct sign style
- **NCMT-05**: Pending comments persist across Neovim sessions

### Review submission

- **REVW-01**: Pick review type (approve, request changes, comment)
- **REVW-02**: Summary of pending comments before submission
- **REVW-03**: Review body input with pending comment summary
- **REVW-04**: All pending comments submitted with review

### Suggestions

- **SUG-01**: Create suggestion from selected range
- **SUG-02**: Pre-fill input with current code
- **SUG-03**: Generate GitHub suggestion markdown format

### Additional actions

- **EACT-01**: Edit own comments
- **EACT-02**: Changed files list with status indicators
- **EACT-03**: Diff viewing via `diffthis` with base branch

## Out of scope

| Feature                 | Reason                                  |
| ----------------------- | --------------------------------------- |
| Delete own comments     | Destructive, low value relative to risk |
| Emoji reactions         | Low priority, deferred to v2            |
| CI/checks display       | Separate concern, deferred to v2        |
| Rich markdown rendering | High complexity, deferred to v2         |
| Commit-by-commit review | Different workflow mode, deferred to v2 |
| Creating PRs            | Review-only tool                        |
| Automatic keybindings   | Violates Lua API-only principle         |
