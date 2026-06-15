## Context

`ghostel-dwim` already has directory and project scope primitives:

- directory discovery through `ghostel-dwim-directory-buffers`
- directory fresh creation through `ghostel-dwim-open`
- directory manual switching through `ghostel-dwim-switch`
- project discovery through `ghostel-dwim-project-buffers`
- project fresh creation through `ghostel-dwim-project-open`
- project manual switching through `ghostel-dwim-project-switch`

The missing layer is automatic reuse. A DWIM entry point needs to decide
whether a scoped Ghostel buffer is currently safe to reuse before creating a
new session.

Ghostel exposes shell integration hooks for OSC 133 command state:

- `ghostel-command-start-functions` runs when Ghostel sees command start.
- `ghostel-command-finish-functions` runs when Ghostel sees command finish.

These hooks provide a better boundary for idle/running state than buffer
names, prompt text, terminal contents, or assuming every live PTY process is
idle.

## Goals

- Add a public predicate, `ghostel-dwim-idle-p`, that answers whether a buffer
  is a reusable idle Ghostel session.
- Add `ghostel-dwim` as the directory-scope DWIM command.
- Add `ghostel-dwim-project` as the project-scope DWIM command.
- Reuse existing directory and project discovery helpers for candidate sets.
- Reuse existing fresh open commands for creation.
- Keep open commands always fresh and switch commands switch-only.
- Keep implementation independent from `ghostel.el` changes and Ghostel PTY
  initialization internals.

## Non-Goals

- Do not add cleanup, batch kill, exited-buffer cleanup, bottom-window cleanup,
  or fixed layout behavior.
- Do not add an idle-buffer selection UI.
- Do not add recency, least-recently-used, or name-based selection policy.
- Do not parse shell prompt text or terminal buffer contents.
- Do not execute shell commands or read files for idle detection.
- Do not treat every live Ghostel process as idle.
- Do not change directory or project membership rules.
- Do not modify `ghostel.el` or copy Ghostel terminal creation internals.

## Decisions

### Scoped Reuse

Directory reuse will call `ghostel-dwim-directory-buffers` and filter that
result with `ghostel-dwim-idle-p`. Project reuse will call
`ghostel-dwim-project-buffers` and filter that result with
`ghostel-dwim-idle-p`.

This keeps reuse aligned with the already accepted directory/project specs and
prevents a second membership implementation from drifting out of sync.

### Deterministic First Idle Candidate

When multiple idle buffers exist in a scope, the DWIM command will reuse the
first idle buffer returned by the relevant scoped discovery helper.

This is intentionally simple. The existing switch commands remain available
when the user wants to choose manually. More advanced selection policy can be
specified separately later.

### Idle State Boundary

Idle detection will be centralized behind a small helper that interprets
Ghostel state. The preferred implementation is to maintain a buffer-local
command-running state from Ghostel's command start/finish hooks:

- command start marks the Ghostel buffer as running
- command finish marks the Ghostel buffer as idle

`ghostel-dwim-idle-p` will also require that the buffer is live, is derived
from `ghostel-mode`, and has a live Ghostel process.

Any direct access to Ghostel private state, such as process storage, should be
kept inside one compatibility helper. DWIM commands should only consume
`ghostel-dwim-idle-p`, not Ghostel internals.

### Conservative Unknown State

If a Ghostel buffer has a live process but its command state is unknown,
`ghostel-dwim-idle-p` should return nil rather than guessing. This avoids
reusing a session that may be running a foreground command, especially for
buffers created before the hooks were installed or shells that do not emit the
expected shell integration markers.

The implementation may initialize newly created Ghostel buffers to an idle
state only where Ghostel's creation path establishes that the session starts at
a prompt. That initialization must stay in the same command-state boundary.

### Creation Delegation

If no idle scoped buffer exists, `ghostel-dwim` will call
`ghostel-dwim-open`, and `ghostel-dwim-project` will call
`ghostel-dwim-project-open`.

The DWIM commands must not call Ghostel creation internals directly. This
preserves the already specified fresh behavior and keeps Ghostel native module,
PTY, shell integration, TRAMP, and naming behavior delegated to Ghostel and the
existing wrapper commands.

### Display Behavior

Reused buffers will be displayed through the existing display helper or normal
Emacs buffer display mechanisms. DWIM reuse does not impose a window layout and
does not request minibuffer selection.

## Risks

- Some shells or configurations may not emit OSC 133 command markers. In that
  case, state can remain unknown and reuse will conservatively create fresh
  sessions instead of risking reuse of a running command.
- Buffers created before `ghostel-dwim` installed its hooks may not have known
  command state until Ghostel emits a later command marker.
- Ghostel has process and identity details that are not all public API. Any
  necessary private reads need to remain concentrated and tested as a
  compatibility boundary.
- Choosing the first idle buffer is stable and simple, but may not match a
  user's preferred recency behavior. That policy can be changed by a later
  spec.

## Test Strategy

- Use ERT with test buffers, stubbed Ghostel mode/process state, and local
  function rebinding.
- Avoid starting the real Ghostel native module, shell, network, or TRAMP
  connections in CI.
- Cover idle detection for non-Ghostel, killed, no-process, exited, running,
  unknown, and idle states.
- Cover directory DWIM reuse, fresh creation fallback, running-buffer skip,
  out-of-directory exclusion, and stable first-idle selection.
- Cover project DWIM reuse, fresh project creation fallback, running-buffer
  skip, out-of-project exclusion, no-project error propagation, and stable
  first-idle selection.
- Add non-regression tests showing open commands remain always fresh and switch
  commands do not auto-create when no candidate exists.
