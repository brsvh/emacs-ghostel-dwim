## Why

`ghostel-dwim` currently provides directory-scoped terminal management, but it
does not provide a command family for terminals that belong to the current
`project.el` project. Directory scope is useful for narrow workflows, but
project-level workflows often need terminals from several subdirectories to be
managed as one project session set.

Project-scoped sessions are the next foundation for later `ghostel-dwim`
behavior: project reuse, project cleanup, and a future project DWIM entry point
all need a reliable way to discover, open, and switch only the Ghostel buffers
associated with the current project.

## What Changes

- Add project-scoped Ghostel buffer discovery for the current `project.el`
  project.
- Add a command to open a fresh Ghostel project session at the current project
  root.
- Add a command to open a fresh Ghostel project session while requesting that
  Emacs avoid reusing the selected window.
- Add a command to switch among Ghostel buffers associated with the current
  project.
- Validate explicit non-interactive project switch targets against the current
  project scope.
- Respect Ghostel's project buffer membership semantics, including
  `ghostel-project-buffer-scope` when Ghostel project discovery is reused.
- Exclude non-`ghostel-mode` buffers and Ghostel buffers from other projects.
- Signal `user-error` when project-scoped commands are used outside a
  `project.el` project.
- Do not add idle/running reuse, cleanup, batch kill, bottom window cleanup, or
  a project DWIM reuse command in this change.
- Do not modify `ghostel.el` or reimplement Ghostel's terminal, PTY, native
  module, shell integration, or TRAMP internals.

## Capabilities

### New Capabilities

- `project-sessions`: Discover, open, and switch Ghostel sessions associated
  with the current `project.el` project.

### Modified Capabilities

None.

## Impact

- Extends the independent `ghostel-dwim` package with project-scoped public
  APIs.
- Introduces public commands:
  - `ghostel-dwim-project-open`
  - `ghostel-dwim-project-open-other-window`
  - `ghostel-dwim-project-switch`
- Introduces public helper:
  - `ghostel-dwim-project-buffers`
- Uses Emacs `project.el` to require and identify the current project context.
- Uses Ghostel's project creation path, preferably `ghostel-project` with fresh
  semantics, so project buffer naming and identity remain compatible with
  Ghostel.
- May reuse Ghostel's project buffer discovery behind a small compatibility
  helper so `ghostel-project-buffer-scope` behavior stays aligned with Ghostel.
- Tests should avoid requiring Ghostel's native module or real shell startup by
  stubbing Ghostel project creation and project buffer discovery boundaries.
