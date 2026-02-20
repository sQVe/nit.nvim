# Workflow

Nit annotates your buffers with PR context and gives you commands to act. No
sidebar, no managed layout. You work in your normal buffers; nit stays in the
background until you invoke it.

## Session lifecycle

A review session is explicit. Start it, work through files at your own pace,
end it when done.

- `require('nit').start()` detects the PR from the current branch, fetches
  data, and begins annotating buffers. Any file the user opens that belongs to
  the PR gets signs in the gutter.
- `require('nit').stop()` tears down the session, removes signs and highlights,
  and cleans up state.
- `require('nit').menu()` is the single entry point for all actions.
  Context-aware: shows relevant options based on cursor position and visual
  selection.

## Comment display

When a session is active and the user opens a file with PR comments, signs
appear in the gutter on commented lines. Nothing else until the user asks.

`require('nit').next_comment()` and `require('nit').prev_comment()` jump
between comments in the current buffer. The user binds these however they want.

Opening a thread shows a floating window anchored to the code range:

- **Top**: full conversation thread with author, timestamp, reactions, and
  resolved status.
- **Bottom**: reply input area. Submit with `<C-s>`.

The floating window has its own keybindings (e.g., `<C-r>` to toggle resolved
status), shown in a hint line at the bottom.

## Adding comments

The menu adapts to context:

- **Visual selection active**: "Comment on selection" opens an input window
  anchored to the range. "Suggest change" opens the same window but pre-fills
  the selected code so the user can edit it into their proposed change. The
  result is wrapped in GitHub's suggestion markdown on submit.
- **Cursor on a line (no selection)**: "Comment on line" opens an input window
  anchored to the current line.
- **File-level**: "Comment on file" opens an input window for a general comment
  on the current file, not tied to a specific line.

All new comments are pending by default. They appear with a distinct sign style
to distinguish them from submitted comments. Pending comments persist across
Neovim sessions.

## Review submission

A two-step flow:

1. Pick the review type: approve, request changes, or comment.
2. A floating window opens showing a read-only summary of all pending comments
   grouped by file (comment text, line/range). Below the summary, a review body
   input area. Submit with `<C-s>`.

All pending comments are submitted together with the review, matching GitHub's
native review model.

The summary lets the user scan everything before sending. To fix a pending
comment, close the window, navigate to it, edit or delete it, and come back.

## The action menu

`require('nit').menu()` opens a context-aware popup with hotkeys right-aligned.
Actions that don't apply to the current context are hidden, not greyed out.

**Cursor on a commented line:**

| Action      | Key |
| ----------- | --- |
| Open thread | `o` |

**Visual selection active:**

| Action               | Key |
| -------------------- | --- |
| Comment on selection | `c` |
| Suggest change       | `s` |

**Always available:**

| Action          | Key |
| --------------- | --- |
| Comment on line | `c` |
| Comment on file | `C` |
| Submit review   | `S` |
| Changed files   | `f` |
| View diff       | `d` |

## Changed files

A minimal floating list showing files changed in the PR with status indicators
(added, modified, deleted, renamed). Selecting a file opens it.

Intentionally basic. `require('nit').get_changed_files()` exposes the file list
via Lua API so users can feed it into whatever picker they prefer.

## Diff viewing

Nit does not provide its own diff viewer. The "View diff" action opens the base
branch version of the current file in a vertical split and runs `diffthis` on
both buffers. Comments and signs remain visible in the working copy side.
