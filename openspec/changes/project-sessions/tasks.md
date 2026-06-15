## 1. Project API Surface

- [x] 1.1 Require `project` where needed without changing the existing Ghostel package dependency model.
- [x] 1.2 Add public autoloaded command stubs for `ghostel-dwim-project-open`, `ghostel-dwim-project-open-other-window`, and `ghostel-dwim-project-switch`.
- [x] 1.3 Add the public helper `ghostel-dwim-project-buffers`.
- [x] 1.4 Update package commentary or README text to describe project-scoped commands and their non-goals.

## 2. Project Discovery

- [x] 2.1 Implement a helper that requires a current `project.el` project and signals `user-error` when none exists.
- [x] 2.2 Implement a single Ghostel project discovery compatibility helper, preferring Ghostel's existing project buffer discovery semantics.
- [x] 2.3 Ensure `ghostel-dwim-project-buffers` returns only live `ghostel-mode` buffers associated with the current project.
- [x] 2.4 Ensure buffer rename does not affect project membership.
- [x] 2.5 Ensure discovery respects `ghostel-project-buffer-scope` for `default-directory`, `identity`, and `both` behavior.
- [x] 2.6 Avoid adding shell commands, terminal text parsing, Ghostel package edits, or extra process mutation during discovery.

## 3. Project Opening Commands

- [x] 3.1 Implement `ghostel-dwim-project-open` so it requests a fresh Ghostel project session.
- [x] 3.2 Ensure project open starts from the current project root rather than the caller's subdirectory.
- [x] 3.3 Ensure project open uses Ghostel's project-prefixed naming and identity behavior.
- [x] 3.4 Ensure repeated project open calls request fresh sessions instead of reusing an existing project session.
- [x] 3.5 Implement `ghostel-dwim-project-open-other-window` so it requests a fresh project session and expresses same-window avoidance as display intent.
- [x] 3.6 Keep project session creation delegated to Ghostel's project creation path instead of copying private PTY, native module, TRAMP, shell integration, or process initialization logic.

## 4. Project Switching Command

- [x] 4.1 Implement candidate reading for current-project Ghostel buffers.
- [x] 4.2 Ensure interactive `ghostel-dwim-project-switch` prompts only among current-project Ghostel buffers.
- [x] 4.3 Ensure `ghostel-dwim-project-switch` signals `user-error` when the current buffer has no project.
- [x] 4.4 Ensure `ghostel-dwim-project-switch` signals `user-error` when no current-project Ghostel buffers exist.
- [x] 4.5 Implement explicit target validation for missing buffers, non-Ghostel buffers, out-of-project Ghostel buffers, and valid in-project Ghostel buffers.
- [x] 4.6 Ensure project switch displays the selected buffer without creating, killing, restarting, or mutating Ghostel processes.

## 5. Unit Tests

- [x] 5.1 Add ERT tests for project discovery including current-project inclusion, other-project exclusion, non-Ghostel exclusion, no-project errors, and renamed Ghostel buffers.
- [x] 5.2 Add ERT tests for `ghostel-project-buffer-scope` compatibility covering `default-directory`, `identity`, and `both`.
- [x] 5.3 Add ERT tests for project switch validation including no candidates, no current project, missing target, non-Ghostel target, out-of-project target, and valid in-project target.
- [x] 5.4 Add ERT tests proving `ghostel-dwim-project-open` requests Ghostel project fresh creation, starts from the project root, preserves project-prefixed identity behavior, and remains fresh across repeated calls.
- [x] 5.5 Add ERT tests proving `ghostel-dwim-project-open-other-window` expresses same-window avoidance without asserting a concrete final window layout.
- [x] 5.6 Keep tests independent of real Ghostel native module startup, networking, and interactive shell processes by stubbing Ghostel project creation and discovery boundaries.

## 6. Verification

- [x] 6.1 Run the batch ERT suite with the `src` directory on the load path.
- [x] 6.2 Confirm no implementation changes were made to the installed `ghostel.el` package or any Nix store path.
- [ ] 6.3 Manually verify two-project behavior with real Ghostel sessions when the Ghostel native module is available.
- [ ] 6.4 Manually verify identity scope and default-directory scope behavior after a project Ghostel shell changes directory.
