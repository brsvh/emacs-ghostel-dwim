## 1. Cleanup Helpers

- [ ] 1.1 Add exited, running, and live-risk predicates that reuse the existing Ghostel process and command-state boundary.
- [ ] 1.2 Add a scoped cleanup orchestrator that accepts a buffer provider, predicate, and kill mode.
- [ ] 1.3 Add a confirmation helper that can be stubbed in tests and prompts once before risky kill-all cleanup.
- [ ] 1.4 Add a buffer kill helper that skips dead buffers and returns whether a buffer was actually killed.
- [ ] 1.5 Add bottom-window detection and deletion helpers for windows displaying killed Ghostel buffers.

## 2. Directory Cleanup Commands

- [ ] 2.1 Implement `ghostel-dwim-clear-buffers` using `ghostel-dwim-directory-buffers` and the exited predicate.
- [ ] 2.2 Implement `ghostel-dwim-clear-idle-buffers` using `ghostel-dwim-directory-buffers` and `ghostel-dwim-idle-p`.
- [ ] 2.3 Implement `ghostel-dwim-kill-buffers` to kill all current-directory Ghostel buffers after required confirmation.
- [ ] 2.4 Ensure directory cleanup commands return the number of buffers killed and remain no-op when there are no matching buffers.

## 3. Project Cleanup Commands

- [ ] 3.1 Implement `ghostel-dwim-project-clear-buffers` using `ghostel-dwim-project-buffers` and the exited predicate.
- [ ] 3.2 Implement `ghostel-dwim-project-clear-idle-buffers` using `ghostel-dwim-project-buffers` and `ghostel-dwim-idle-p`.
- [ ] 3.3 Implement `ghostel-dwim-project-kill-buffers` to kill all current-project Ghostel buffers after required confirmation.
- [ ] 3.4 Ensure project cleanup commands propagate the existing no-project `user-error` behavior and kill no buffers outside a project.

## 4. Cleanup Tests

- [ ] 4.1 Add ERT coverage for directory exited cleanup, including live, other-directory, non-Ghostel, and no-op cases.
- [ ] 4.2 Add ERT coverage for directory idle cleanup, including idle, running, unknown live, exited, other-directory, and no-op cases.
- [ ] 4.3 Add ERT coverage for directory kill-all cleanup, including no-prompt, prompt-on-running, prompt-on-unknown-live, confirm, decline, and other-directory cases.
- [ ] 4.4 Add ERT coverage for project exited cleanup, including live, other-project, and no-project cases.
- [ ] 4.5 Add ERT coverage for project idle cleanup, including idle, running, unknown live, other-project, and no-project cases.
- [ ] 4.6 Add ERT coverage for project kill-all cleanup, including no-prompt, prompt-on-running, prompt-on-unknown-live, confirm, decline, other-project, and no-project cases.
- [ ] 4.7 Add ERT coverage for bottom-window cleanup, including bottom windows, multiple bottom windows, ordinary windows, non-bottom side windows, and confirmation cancellation.

## 5. Safety And Regression Tests

- [ ] 5.1 Test that cleanup commands do not call `ghostel`, `ghostel-project`, or Ghostel creation internals.
- [ ] 5.2 Test that cleanup commands do not execute shell commands, inspect terminal contents, or read files.
- [ ] 5.3 Test that cleanup uses existing directory and project discovery results without mutating discovery behavior.
- [ ] 5.4 Test that existing open commands remain always fresh after cleanup is added.
- [ ] 5.5 Test that existing reuse and switch commands keep their current semantics after cleanup is added.

## 6. Verification

- [ ] 6.1 Run the batch ERT suite for `ghostel-dwim`.
- [ ] 6.2 Run `openspec status --change "session-cleanup"` and confirm the change is apply-ready.
- [ ] 6.3 Review the implementation to confirm `ghostel.el` and the Nix store are not modified.
- [ ] 6.4 Manually verify directory cleanup with exited, idle, running, and other-directory Ghostel sessions.
- [ ] 6.5 Manually verify project cleanup with exited, idle, running, and other-project Ghostel sessions.
- [ ] 6.6 Manually verify that killed Ghostel buffers displayed in bottom windows cause those bottom windows to be deleted.
