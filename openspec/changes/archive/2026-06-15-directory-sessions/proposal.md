## Why

Ghostel has global and project-scoped terminal commands, but it does not provide
a command family for terminals that belong specifically to the current
directory. This makes multi-directory workflows noisy because global buffer
lists mix unrelated terminals, while project scope is too broad when different
subdirectories need independent terminal sessions.

Directory-scoped sessions are the smallest useful foundation for later
`ghostel-dwim` behavior: reuse needs to know which terminals belong to the
current directory, and cleanup needs the same scoped buffer set.

## What Changes

- Add directory-scoped Ghostel buffer discovery based on buffer-local
  `default-directory`.
- Add a command to open a fresh Ghostel session in the current directory.
- Add a command to open a fresh Ghostel session while requesting that Emacs
  avoid reusing the selected window.
- Add a command to switch among Ghostel buffers associated with the current
  directory.
- Validate explicit non-interactive switch targets against the current
  directory scope.
- Exclude non-`ghostel-mode` buffers and buffers from other directories.
- Do not add idle/running reuse, project scope, cleanup, batch kill, or bottom
  window cleanup in this change.
- Do not modify `ghostel.el` or reimplement Ghostel's terminal, PTY, native
  module, shell integration, or TRAMP internals.

## Capabilities

### New Capabilities

- `directory-sessions`: Discover, open, and switch Ghostel sessions associated
  with the current directory.

### Modified Capabilities

None.

## Impact

- Adds a new independent Elisp package entry point for `ghostel-dwim`.
- Introduces public commands:
  - `ghostel-dwim-open`
  - `ghostel-dwim-open-other-window`
  - `ghostel-dwim-switch`
- Introduces public helper:
  - `ghostel-dwim-directory-buffers`
- Depends on Ghostel's public creation command and `ghostel-mode`.
- Uses buffer-local `default-directory` for scope and does not rely on buffer
  names for directory membership.
- Tests should avoid requiring Ghostel's native module or real shell startup by
  stubbing Ghostel creation and using lightweight `ghostel-mode` buffers.
