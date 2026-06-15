## Context

`ghostel-dwim` already has the primitives needed to scope cleanup safely:

- directory membership through `ghostel-dwim-directory-buffers`
- project membership through `ghostel-dwim-project-buffers`
- session idleness through `ghostel-dwim-idle-p`
- Ghostel process access through the existing compatibility boundary
- display and open behavior that is intentionally separate from cleanup

The missing behavior is destructive buffer cleanup. Cleanup has a different
risk profile from discovery, open, switch, and reuse because it can kill
process-backed buffers. The design therefore keeps the candidate set scoped,
the predicates conservative, and confirmation atomic.

## Goals / Non-Goals

**Goals:**

- Add directory cleanup commands for exited, idle, and all scoped Ghostel
  buffers.
- Add project cleanup commands equivalent to the directory cleanup commands.
- Preserve project no-context behavior: project cleanup commands signal
  `user-error` outside a `project.el` project.
- Reuse existing scoped discovery instead of reimplementing directory or
  project membership.
- Reuse `ghostel-dwim-idle-p` for idle cleanup.
- Add a running or live-risk predicate that stays behind the existing Ghostel
  state compatibility boundary.
- Prompt once before killing any scoped buffers when running or unknown live
  sessions are present.
- Keep cancellation atomic: if the user refuses confirmation, no matching
  buffers are killed.
- Delete bottom windows that displayed buffers killed by cleanup.
- Return the number of buffers actually killed, so commands are scriptable and
  easy to test.

**Non-Goals:**

- Do not add automatic cleanup timers, idle timeouts, or background cleanup.
- Do not add global or cross-scope cleanup.
- Do not add a completion UI for choosing buffers to kill.
- Do not add session restart or shell-command based exit behavior.
- Do not interrupt processes or implement a custom process signal strategy.
- Do not change existing open, switch, reuse, directory discovery, or project
  discovery semantics.
- Do not modify `ghostel.el`, copy Ghostel terminal creation internals, or
  start real Ghostel sessions in CI tests.

## Decisions

### Candidate Source

Directory cleanup will call `ghostel-dwim-directory-buffers`. Project cleanup
will call `ghostel-dwim-project-buffers`.

Rationale: these helpers already encode the accepted membership rules,
including directory normalization, Ghostel buffer checks, Ghostel buffer rename
compatibility, and `ghostel-project-buffer-scope`.

Alternative considered: scan all buffers again inside cleanup. That would
duplicate scope rules and risk future drift from discovery behavior.

### Cleanup Predicates

Exited cleanup will kill scoped Ghostel buffers without a live Ghostel process.
Idle cleanup will kill scoped Ghostel buffers for which `ghostel-dwim-idle-p`
returns non-nil. Kill-all cleanup will kill every scoped Ghostel buffer after
any required confirmation.

Rationale: each command maps to one clear predicate and the idle predicate is
shared with reuse. Exited buffers are not idle, and unknown live buffers are not
idle.

Alternative considered: define idle as "has a live process". That is unsafe
because a foreground command also has a live process.

### Running And Live-Risk Confirmation

Kill-all cleanup will confirm once before killing if any scoped candidate is
known running. It will also treat unknown live sessions as requiring
confirmation.

Rationale: unknown live sessions may be running foreground commands when shell
integration markers are unavailable. Prompting for them is more conservative
than silently killing them, and it is consistent with the session-reuse
decision that unknown state must not be considered idle.

Alternative considered: confirm only known running sessions. That satisfies the
minimum running-session requirement, but it can still kill an unsupported-shell
session without warning.

### Atomic Cancellation

The cleanup orchestrator will compute candidates and determine whether
confirmation is required before killing any buffer. If confirmation is declined,
it returns zero and performs no kill or bottom-window deletion.

Rationale: users expect "no" to mean no matching terminal buffers are changed.

Alternative considered: kill exited or idle buffers first and prompt only when a
running candidate is reached. That makes cancellation surprising and harder to
reason about.

### Buffer Killing

Cleanup will use `kill-buffer` for buffer deletion. Before killing, the helper
will capture bottom windows displaying the target buffer. After a successful
kill, it will delete only those captured bottom windows that are still live.

Rationale: `kill-buffer` is the normal Emacs buffer API, and capturing windows
before the kill avoids relying on the killed buffer remaining displayed.

Alternative considered: delete windows first. That would alter layout even if
`kill-buffer` later failed or was vetoed by hooks.

### Bottom Window Detection

Bottom-window cleanup will detect windows whose `window-side` parameter is
`bottom`. It will not explicitly delete ordinary windows or non-bottom side
windows.

Rationale: this targets the layout artifact called out by the change without
claiming ownership of normal Emacs window replacement behavior.

Alternative considered: delete every window displaying the killed Ghostel
buffer. That is too aggressive and can destroy normal user layouts.

### Error And Race Handling

Project cleanup will rely on `ghostel-dwim-project-buffers`, so the existing
no-project `user-error` behavior propagates. Dead buffers encountered during
cleanup will be skipped. Predicate-based commands will recheck their predicate
immediately before killing to avoid killing buffers that no longer match.

Rationale: cleanup should be robust when process state changes between
candidate collection and execution.

Alternative considered: trust the initial candidate snapshot completely for
all cleanup modes. That is acceptable for kill-all after confirmation, but too
loose for exited and idle cleanup.

## Risks / Trade-offs

- [Risk] Unknown live sessions now trigger confirmation in kill-all cleanup,
  which can prompt even when the session is merely sitting at a prompt.
  Mitigation: only kill-all prompts; clear-idle stays non-interactive and
  conservative.
- [Risk] `kill-buffer` can run hooks that change buffers or windows.
  Mitigation: count only buffers that are no longer live after the kill attempt,
  and skip dead windows during cleanup.
- [Risk] Bottom-window behavior depends on Emacs window parameters.
  Mitigation: isolate detection in one helper and cover it with ERT window
  primitive tests.
- [Risk] Private Ghostel process storage may change in future Ghostel releases.
  Mitigation: reuse the existing process compatibility helper and avoid adding
  new scattered reads of Ghostel internals.

## Migration Plan

This change only adds new commands and internal helpers. Existing users keep
the same open, switch, reuse, directory discovery, and project discovery
behavior.

Rollback is straightforward: remove the new cleanup commands/helpers and their
tests. No persisted data migration is required.

## Open Questions

None for the first implementation. More advanced policies, such as idle
timeouts, recency-based cleanup, or user selection before kill, should be
specified separately.
