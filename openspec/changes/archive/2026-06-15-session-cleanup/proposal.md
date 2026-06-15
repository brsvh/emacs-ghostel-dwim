## Why

`ghostel-dwim` can discover, open, switch, and reuse Ghostel sessions within
directory and project scopes, but it cannot clean up accumulated terminal
buffers within those same scopes.

Long-running Emacs sessions tend to collect Ghostel buffers in several states:

- exited terminal buffers no longer have a live process but remain in the
  buffer list
- idle terminal buffers may no longer be needed
- running terminal buffers are riskier to kill because they may be executing a
  foreground command
- bottom windows that displayed killed terminal buffers may remain and disrupt
  the user's layout

Scoped cleanup is the next layer after the completed directory sessions,
project sessions, and session reuse work. Directory and project discovery
define which buffers are in scope, while session reuse introduced the
idle/running/unknown state boundary needed to clean live buffers conservatively.

## What Changes

- Add directory cleanup commands:
  - `ghostel-dwim-clear-buffers` for exited current-directory Ghostel buffers
  - `ghostel-dwim-clear-idle-buffers` for idle current-directory Ghostel
    buffers
  - `ghostel-dwim-kill-buffers` for all current-directory Ghostel buffers
- Add project cleanup commands:
  - `ghostel-dwim-project-clear-buffers` for exited current-project Ghostel
    buffers
  - `ghostel-dwim-project-clear-idle-buffers` for idle current-project Ghostel
    buffers
  - `ghostel-dwim-project-kill-buffers` for all current-project Ghostel
    buffers
- Reuse existing scoped discovery:
  - `ghostel-dwim-directory-buffers`
  - `ghostel-dwim-project-buffers`
- Reuse existing session state helpers, especially `ghostel-dwim-idle-p`, and
  keep any live/running process checks behind the existing Ghostel compatibility
  boundary.
- Prompt once before killing scoped buffers when a running foreground command
  is present; if the user declines, kill no matching buffers.
- Treat unknown live sessions conservatively:
  - they are not idle
  - idle cleanup does not kill them
  - kill-all cleanup may kill them, but may also require confirmation as a
    live-risk session
- Delete bottom windows that displayed a Ghostel buffer killed by a cleanup
  command.
- Do not explicitly delete non-bottom windows; normal Emacs `kill-buffer`
  replacement behavior remains outside this helper's responsibility.
- Do not add timers, idle timeouts, global cleanup, cross-scope cleanup,
  completion UI, session restart, shell-command based exit, process interrupt,
  or custom process signal behavior.
- Do not modify `ghostel.el`, reimplement Ghostel terminal internals, parse
  terminal contents, or determine scope/state from buffer names.

## Capabilities

### New Capabilities

- `session-cleanup`: Provide directory- and project-scoped cleanup commands
  for exited, idle, and all Ghostel sessions, with running-session confirmation
  and bottom-window cleanup.

### Modified Capabilities

None.

## Impact

- Extends the independent `ghostel-dwim` package with public cleanup commands:
  - `ghostel-dwim-clear-buffers`
  - `ghostel-dwim-clear-idle-buffers`
  - `ghostel-dwim-kill-buffers`
  - `ghostel-dwim-project-clear-buffers`
  - `ghostel-dwim-project-clear-idle-buffers`
  - `ghostel-dwim-project-kill-buffers`
- Adds small internal cleanup helpers for exited/running predicates,
  confirmation, scoped cleanup orchestration, buffer killing, and bottom-window
  deletion.
- Keeps cleanup scoped through existing directory/project discovery helpers.
- Keeps cleanup independent of Ghostel creation paths and native module
  startup.
- Tests should run in batch Emacs without a real Ghostel native module,
  network, interactive shell, or real TRAMP connection by using test buffers,
  fake processes, stubs, and Emacs window primitives.
