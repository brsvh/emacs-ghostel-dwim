## 1. Ghostel Command State Boundary

- [ ] 1.1 Add buffer-local state for Ghostel command running/idle/unknown status.
- [ ] 1.2 Add hook handlers for `ghostel-command-start-functions` and `ghostel-command-finish-functions`.
- [ ] 1.3 Register the hook handlers when `ghostel-dwim` loads.
- [ ] 1.4 Keep any direct Ghostel private state reads inside one compatibility helper.

## 2. Idle Detection

- [ ] 2.1 Add `ghostel-dwim-idle-p` as a public predicate.
- [ ] 2.2 Make `ghostel-dwim-idle-p` return nil for missing, killed, and non-Ghostel buffers.
- [ ] 2.3 Make `ghostel-dwim-idle-p` require a live Ghostel process.
- [ ] 2.4 Make `ghostel-dwim-idle-p` return non-nil only for known idle command state.
- [ ] 2.5 Make unknown command state conservatively return nil.
- [ ] 2.6 Ensure idle detection does not parse buffer names, parse terminal text, run shell commands, or read files.

## 3. Directory DWIM Reuse

- [ ] 3.1 Add a helper that returns the first idle buffer from a scoped buffer list.
- [ ] 3.2 Add a helper that displays an idle candidate or calls a supplied open function.
- [ ] 3.3 Add `ghostel-dwim` to reuse the first idle buffer from `ghostel-dwim-directory-buffers`.
- [ ] 3.4 Make `ghostel-dwim` call `ghostel-dwim-open` when no idle current-directory buffer exists.
- [ ] 3.5 Ensure `ghostel-dwim` does not prompt with minibuffer completion.
- [ ] 3.6 Ensure `ghostel-dwim` does not kill, restart, interrupt, or mutate running Ghostel processes.

## 4. Project DWIM Reuse

- [ ] 4.1 Add `ghostel-dwim-project` to reuse the first idle buffer from `ghostel-dwim-project-buffers`.
- [ ] 4.2 Make `ghostel-dwim-project` call `ghostel-dwim-project-open` when no idle current-project buffer exists.
- [ ] 4.3 Let no-current-project errors from project discovery propagate as `user-error`.
- [ ] 4.4 Ensure `ghostel-dwim-project` does not prompt with minibuffer completion.
- [ ] 4.5 Ensure `ghostel-dwim-project` does not kill, restart, interrupt, or mutate running Ghostel processes.

## 5. Tests

- [ ] 5.1 Add idle detection tests for non-Ghostel buffers, killed buffers, no live process, exited process, known idle state, running state, and unknown state.
- [ ] 5.2 Add tests for the Ghostel command start/finish hook compatibility boundary.
- [ ] 5.3 Add directory DWIM tests for idle reuse, no-open-on-reuse, create fallback, running skip, running-plus-idle selection, other-directory exclusion, and stable first-idle selection.
- [ ] 5.4 Add project DWIM tests for idle reuse, no-open-on-reuse, create fallback, running skip, running-plus-idle selection, other-project exclusion, no-project error, and stable first-idle selection.
- [ ] 5.5 Add non-regression tests that open commands remain always fresh and switch commands remain switch-only.
- [ ] 5.6 Keep all tests independent from the real Ghostel native module, network, interactive shell, and TRAMP connections.

## 6. Verification

- [ ] 6.1 Run the batch ERT suite with the repository `src` directory on `load-path`.
- [ ] 6.2 Confirm no changes were made to Nix store files or Ghostel package installation files.
- [ ] 6.3 Confirm implementation does not copy Ghostel PTY, native module, process, shell integration, TRAMP, or naming initialization logic.
- [ ] 6.4 Manually verify real Ghostel reuse behavior for directory and project scopes when a real interactive Emacs/Ghostel environment is available.
