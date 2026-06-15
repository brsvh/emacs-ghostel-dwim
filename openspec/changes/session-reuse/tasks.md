## 1. Ghostel Command State Boundary

- [x] 1.1 Add buffer-local state for Ghostel command running/idle/unknown status.
- [x] 1.2 Add hook handlers for `ghostel-command-start-functions` and `ghostel-command-finish-functions`.
- [x] 1.3 Register the hook handlers when `ghostel-dwim` loads.
- [x] 1.4 Keep any direct Ghostel private state reads inside one compatibility helper.

## 2. Idle Detection

- [x] 2.1 Add `ghostel-dwim-idle-p` as a public predicate.
- [x] 2.2 Make `ghostel-dwim-idle-p` return nil for missing, killed, and non-Ghostel buffers.
- [x] 2.3 Make `ghostel-dwim-idle-p` require a live Ghostel process.
- [x] 2.4 Make `ghostel-dwim-idle-p` return non-nil only for known idle command state.
- [x] 2.5 Make unknown command state conservatively return nil.
- [x] 2.6 Ensure idle detection does not parse buffer names, parse terminal text, run shell commands, or read files.

## 3. Directory DWIM Reuse

- [x] 3.1 Add a helper that returns the first idle buffer from a scoped buffer list.
- [x] 3.2 Add a helper that displays an idle candidate or calls a supplied open function.
- [x] 3.3 Add `ghostel-dwim` to reuse the first idle buffer from `ghostel-dwim-directory-buffers`.
- [x] 3.4 Make `ghostel-dwim` call `ghostel-dwim-open` when no idle current-directory buffer exists.
- [x] 3.5 Ensure `ghostel-dwim` does not prompt with minibuffer completion.
- [x] 3.6 Ensure `ghostel-dwim` does not kill, restart, interrupt, or mutate running Ghostel processes.

## 4. Project DWIM Reuse

- [x] 4.1 Add `ghostel-dwim-project` to reuse the first idle buffer from `ghostel-dwim-project-buffers`.
- [x] 4.2 Make `ghostel-dwim-project` call `ghostel-dwim-project-open` when no idle current-project buffer exists.
- [x] 4.3 Let no-current-project errors from project discovery propagate as `user-error`.
- [x] 4.4 Ensure `ghostel-dwim-project` does not prompt with minibuffer completion.
- [x] 4.5 Ensure `ghostel-dwim-project` does not kill, restart, interrupt, or mutate running Ghostel processes.

## 5. Tests

- [x] 5.1 Add idle detection tests for non-Ghostel buffers, killed buffers, no live process, exited process, known idle state, running state, and unknown state.
- [x] 5.2 Add tests for the Ghostel command start/finish hook compatibility boundary.
- [x] 5.3 Add directory DWIM tests for idle reuse, no-open-on-reuse, create fallback, running skip, running-plus-idle selection, other-directory exclusion, and stable first-idle selection.
- [x] 5.4 Add project DWIM tests for idle reuse, no-open-on-reuse, create fallback, running skip, running-plus-idle selection, other-project exclusion, no-project error, and stable first-idle selection.
- [x] 5.5 Add non-regression tests that open commands remain always fresh and switch commands remain switch-only.
- [x] 5.6 Keep all tests independent from the real Ghostel native module, network, interactive shell, and TRAMP connections.

## 6. Verification

- [x] 6.1 Run the batch ERT suite with the repository `src` directory on `load-path`.
- [x] 6.2 Confirm no changes were made to Nix store files or Ghostel package installation files.
- [x] 6.3 Confirm implementation does not copy Ghostel PTY, native module, process, shell integration, TRAMP, or naming initialization logic.
- [x] 6.4 Record that real Ghostel reuse behavior remains a manual verification item when a real interactive Emacs/Ghostel environment is available.
