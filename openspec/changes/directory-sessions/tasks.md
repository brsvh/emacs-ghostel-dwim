## 1. Package Skeleton

- [x] 1.1 Create `ghostel-dwim.el` with package header, lexical binding, `require` declarations, and `(provide 'ghostel-dwim)`.
- [x] 1.2 Add public autoloaded command stubs for `ghostel-dwim-open`, `ghostel-dwim-open-other-window`, and `ghostel-dwim-switch`.
- [x] 1.3 Add the public helper `ghostel-dwim-directory-buffers`.

## 2. Directory Discovery

- [x] 2.1 Implement lightweight directory normalization using expanded directory names and consistent trailing slashes.
- [x] 2.2 Implement Ghostel buffer detection using `derived-mode-p` with `ghostel-mode`.
- [x] 2.3 Implement current-directory buffer discovery by scanning `buffer-list` and comparing normalized buffer-local `default-directory` values.
- [x] 2.4 Ensure discovery does not call filesystem probes, project lookup, or external commands.

## 3. Opening Commands

- [x] 3.1 Implement `ghostel-dwim-open` so it requests a fresh Ghostel session in the caller's current `default-directory`.
- [x] 3.2 Implement `ghostel-dwim-open-other-window` so it requests a fresh Ghostel session and expresses same-window avoidance as display intent.
- [x] 3.3 Keep session creation delegated to Ghostel's public command path instead of private Ghostel creation internals.

## 4. Switching Command

- [x] 4.1 Implement candidate reading for current-directory Ghostel buffers.
- [x] 4.2 Implement explicit target validation for missing buffers, non-Ghostel buffers, and out-of-directory Ghostel buffers.
- [x] 4.3 Implement display of the selected or validated Ghostel buffer with normal Emacs buffer display behavior.
- [x] 4.4 Ensure `ghostel-dwim-switch` signals `user-error` when no current-directory Ghostel buffers exist.

## 5. Unit Tests

- [x] 5.1 Add ERT tests for discovery including same-directory inclusion, different-directory exclusion, non-Ghostel exclusion, trailing slash normalization, and renamed Ghostel buffers.
- [x] 5.2 Add ERT tests for switch validation including missing target, non-Ghostel target, out-of-directory target, and valid in-directory target.
- [x] 5.3 Add ERT tests proving `ghostel-dwim-open` requests Ghostel fresh creation and preserves the caller's `default-directory`.
- [x] 5.4 Add ERT tests proving `ghostel-dwim-open-other-window` expresses same-window avoidance without asserting a concrete window layout.
- [x] 5.5 Keep tests independent of real Ghostel native module startup, networking, and interactive shell processes.

## 6. Documentation And Verification

- [x] 6.1 Document the directory-scoped commands and their non-goals in README or package commentary.
- [x] 6.2 Run batch unit tests.
- [x] 6.3 Manually verify two-directory behavior with real Ghostel sessions when the Ghostel native module is available.
- [x] 6.4 Confirm no implementation changes were made to the installed `ghostel.el` package.
