## Context

Ghostel already provides global terminal commands and project-scoped commands,
but those commands do not model the current directory as a scope. The new
`ghostel-dwim` package should add that scope without changing Ghostel itself.

Ghostel tracks a terminal buffer's current directory through buffer-local
`default-directory`; shell `cd` changes can update that value through Ghostel's
OSC 7 handling. Directory membership should therefore use the buffer-local
directory value instead of parsing buffer names, shell output, or prompt text.

The current repository is an independent package repository. The installed
Ghostel package lives in the Nix store and must be treated as read-only.

## Goals / Non-Goals

**Goals:**

- Add a small independent `ghostel-dwim.el` package.
- Discover Ghostel buffers associated with the current directory.
- Open fresh Ghostel sessions in the current directory.
- Offer a best-effort command for opening in another window.
- Switch only among Ghostel buffers associated with the current directory.
- Keep tests batch-friendly and avoid real Ghostel native module startup.

**Non-Goals:**

- Do not add idle/running reuse behavior.
- Do not add project-scoped behavior.
- Do not add cleanup or kill commands.
- Do not modify `ghostel.el`.
- Do not reimplement Ghostel's terminal creation, PTY setup, shell integration,
  TRAMP support, or native module loading.
- Do not guarantee a fixed window placement such as bottom or side windows.

## Decisions

1. Use buffer-local `default-directory` for directory membership.

   Rationale: Ghostel already maintains this value for terminal buffers. This
   also keeps membership independent from buffer names, which Ghostel may rename
   based on title or directory.

   Alternative considered: parse buffer names or shell prompt text. That is less
   reliable and conflicts with Ghostel's existing directory tracking.

2. Normalize directories with lightweight path string operations only.

   Directory matching should expand names and normalize trailing slashes, but it
   should not call `file-truename`, `file-directory-p`, `project-current`, or
   external commands during discovery.

   Rationale: discovery runs interactively and may see TRAMP paths. Filesystem
   probes can block or connect to remote hosts.

   Alternative considered: compare true names to collapse symlinks. That gives
   stronger filesystem identity but is too expensive and side-effect-prone for
   this scope.

3. Treat only `ghostel-mode` buffers as directory session candidates.

   Rationale: `default-directory` alone is too broad because ordinary editing
   buffers can share the same directory.

4. Create sessions through Ghostel's public command path.

   `ghostel-dwim-open` should invoke Ghostel with fresh-buffer semantics rather
   than calling private internals such as `ghostel--create` or
   `ghostel--start-process`.

   Rationale: Ghostel's creation path handles native module loading, PTY setup,
   shell integration, TRAMP behavior, sizing, and buffer identity. Duplicating
   that logic would make `ghostel-dwim` fragile.

5. Model `open-other-window` as display intent, not layout ownership.

   `ghostel-dwim-open-other-window` should request same-window avoidance using
   Emacs display-buffer mechanisms where possible. It should not promise a
   concrete window location.

   Rationale: users may already have `display-buffer-alist` rules for terminal
   buffers. The package should cooperate with those rules.

6. Keep switch validation explicit.

   Interactive switching should offer only directory candidates. Non-interactive
   switching with an explicit buffer or buffer name should validate that the
   target exists, is a Ghostel buffer, and belongs to the current directory.

   Rationale: this makes programmatic use predictable and prevents accidental
   cross-directory switches.

## Risks / Trade-offs

- Symlink aliases are treated as distinct directories -> Accept this to avoid
  filesystem probing and remote TRAMP latency.
- `open-other-window` may not perfectly override Ghostel's internal display
  action -> Treat the behavior as best-effort and test only the intent unless a
  public Ghostel API becomes available.
- Tests that call real `ghostel` would load the native module -> Stub the
  creation path for unit tests and reserve real Ghostel startup for manual
  verification.
- Requiring Ghostel at package load time means missing Ghostel fails early ->
  This is intentional because `ghostel-dwim` is an add-on, not a fallback
  terminal implementation.
