## Context

`ghostel-dwim` already provides directory-scoped discovery, fresh opening, and
switching. The project-scoped layer should add the same shape of commands for
the current `project.el` project while staying compatible with Ghostel's native
project behavior.

Ghostel already has project commands and project discovery behavior:
`ghostel-project` starts terminals at the current project root using
project-prefixed naming, and Ghostel scopes project buffers through
`ghostel-project-buffer-scope`. That scope may be based on current
`default-directory`, creation-time Ghostel buffer identity, or both.

The installed Ghostel package is in the Nix store and is read-only. This
repository should remain an independent add-on package rather than a fork or
replacement for Ghostel internals.

## Goals / Non-Goals

**Goals:**

- Discover Ghostel buffers associated with the current `project.el` project.
- Preserve Ghostel's project buffer membership semantics, including
  `ghostel-project-buffer-scope`.
- Open fresh Ghostel project sessions at the current project root.
- Use Ghostel's project-prefixed naming and identity behavior for project
  sessions.
- Offer a best-effort command for opening project sessions in another window.
- Switch only among Ghostel buffers associated with the current project.
- Keep tests batch-friendly and avoid real Ghostel native module startup.

**Non-Goals:**

- Do not add idle/running reuse behavior.
- Do not add a project DWIM command that creates or reuses based on session
  state.
- Do not change directory-scoped behavior.
- Do not add cleanup, kill, or bottom-window management commands.
- Do not modify `ghostel.el`.
- Do not reimplement Ghostel's terminal creation, PTY setup, shell integration,
  TRAMP support, or native module loading.
- Do not guarantee a fixed window placement such as bottom or side windows.

## Decisions

1. Require a current `project.el` project for all project-scoped commands.

   Project scope is not meaningful without a project root. Commands such as
   `ghostel-dwim-project-buffers`, `ghostel-dwim-project-open`,
   `ghostel-dwim-project-open-other-window`, and
   `ghostel-dwim-project-switch` should signal `user-error` when
   `project-current` cannot identify a project.

   Alternative considered: fall back to directory scope outside projects. That
   would hide project configuration problems and make project commands overlap
   with existing directory commands.

2. Reuse Ghostel project discovery behind one compatibility helper.

   `ghostel--project-buffers` already implements Ghostel's
   `ghostel-project-buffer-scope` behavior. Calling it through a single helper,
   for example `ghostel-dwim--project-buffers`, keeps `ghostel-dwim` aligned
   with Ghostel for `default-directory`, `identity`, and `both` scope modes.

   This is a private Ghostel API, so the dependency should be concentrated in
   one helper and covered by tests that stub the boundary. Code outside that
   helper should work with ordinary buffer lists and should not copy Ghostel's
   discovery internals.

   Alternative considered: implement independent project membership from
   `project-root` and buffer-local `default-directory`. That would be simpler
   but would not preserve identity scope, where project membership remains tied
   to buffers created through `ghostel-project` even after shell `cd`.

3. Open project sessions through `ghostel-project` with fresh semantics.

   `ghostel-dwim-project-open` should call Ghostel's public project command
   with a non-numeric prefix argument, such as `(ghostel-project t)`, rather
   than binding `default-directory` and calling plain `ghostel`.

   Rationale: `ghostel-project` sets the project root and uses
   project-prefixed buffer naming before delegating to Ghostel creation. That
   preserves compatibility with identity-based project buffer discovery.

   Alternative considered: call `ghostel` after binding `default-directory` to
   the project root. That would start in the right directory but would lose
   Ghostel's project identity behavior.

4. Model project `open-other-window` as display intent.

   `ghostel-dwim-project-open-other-window` should reuse the same display
   intent used by directory `open-other-window`, binding
   `display-buffer-overriding-action` to request same-window avoidance before
   calling `ghostel-dwim-project-open`.

   Rationale: Emacs display-buffer rules and user configuration should control
   the final layout. This package should not force a bottom, side, or split
   window.

   Alternative considered: call private Ghostel creation internals with a
   custom display action. That would be too fragile and would duplicate the
   creation path this package should delegate to Ghostel.

5. Keep project switching validation explicit.

   Interactive switching should prompt only among the current project's
   Ghostel buffers. Non-interactive switching with a buffer or buffer name
   should validate that a project exists, the target exists, the target is a
   Ghostel buffer, and the target is part of the current project set.

   Rationale: explicit validation prevents accidental cross-project switches
   and gives programmatic callers predictable failures.

## Risks / Trade-offs

- Private Ghostel discovery dependency -> Keep the dependency inside one
  helper and add tests for the expected boundary behavior. If Ghostel later
  exposes a public project discovery function, replace the helper without
  changing public `ghostel-dwim` APIs.
- Project discovery can inherit Ghostel's local `project-current` behavior ->
  Do not add extra per-buffer project lookups in `ghostel-dwim`. When
  delegating to Ghostel discovery, accept Ghostel's existing behavior so scope
  semantics remain compatible.
- `open-other-window` may not override every display path -> Treat the command
  as same-window-avoidance intent and test the intent rather than a fixed final
  layout.
- Tests that call real `ghostel-project` would load the native module -> Stub
  project creation in unit tests and reserve real Ghostel startup for manual
  verification.
- Missing Ghostel fails at load time -> Accept this because `ghostel-dwim` is a
  Ghostel add-on, not a fallback terminal implementation.
