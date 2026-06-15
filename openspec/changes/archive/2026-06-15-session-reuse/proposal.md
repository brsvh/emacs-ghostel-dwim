## Why

`ghostel-dwim` can now explicitly open fresh sessions and switch within
directory or project scopes, but it cannot automatically reuse an idle
terminal in the current working context. Users still have to decide manually
whether an existing scoped Ghostel buffer is reusable before opening another
terminal.

Session reuse is the next DWIM layer on top of the completed directory and
project session discovery work: it needs those scoped buffer sets, and later
cleanup behavior also needs the same idle/running distinction.

## What Changes

- Add idle Ghostel session detection for deciding whether a buffer is reusable.
- Add a directory DWIM entry command, `ghostel-dwim`, that reuses an idle
  Ghostel buffer in the current directory before opening a fresh directory
  session.
- Add a project DWIM entry command, `ghostel-dwim-project`, that reuses an idle
  Ghostel buffer in the current project before opening a fresh project session.
- Reuse existing scoped discovery:
  - `ghostel-dwim-directory-buffers`
  - `ghostel-dwim-project-buffers`
- Reuse existing fresh creation commands:
  - `ghostel-dwim-open`
  - `ghostel-dwim-project-open`
- Reuse normal Emacs buffer display behavior for reused buffers.
- Avoid minibuffer selection in the DWIM commands; manual selection remains the
  responsibility of the existing switch commands.
- Do not change the always-fresh behavior of open commands.
- Do not change the switch-only behavior of switch commands.
- Do not add cleanup, batch kill, exited-buffer cleanup, bottom-window cleanup,
  or fixed window layout behavior in this change.
- Do not modify `ghostel.el` or reimplement Ghostel terminal, PTY, native
  module, shell integration, TRAMP, or process initialization internals.

## Capabilities

### New Capabilities

- `session-reuse`: Detect reusable idle Ghostel sessions and add directory and
  project DWIM commands that reuse idle sessions before creating fresh ones.

### Modified Capabilities

None.

## Impact

- Extends the independent `ghostel-dwim` package with public APIs:
  - `ghostel-dwim-idle-p`
  - `ghostel-dwim`
  - `ghostel-dwim-project`
- Adds a small Ghostel command-state compatibility boundary for idle/running
  detection, likely using Ghostel's OSC 133 command start/finish hooks and
  live process state.
- Keeps reuse behavior scoped through the existing directory and project
  discovery helpers.
- Keeps creation delegated to the existing fresh open commands rather than
  calling Ghostel creation internals.
- Tests should avoid real native module startup, networking, and interactive
  shells by using test buffers, fake processes, stubs, or mocked Ghostel state.
