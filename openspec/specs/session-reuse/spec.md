# session-reuse Specification

## Purpose

Specify how `ghostel-dwim` detects reusable idle Ghostel sessions and uses
that state to reuse scoped directory or project terminals before creating
fresh sessions.

## Requirements

### Requirement: Idle Ghostel Session Detection

`ghostel-dwim` SHALL provide `ghostel-dwim-idle-p` to distinguish reusable
idle Ghostel sessions from non-Ghostel, exited, unknown, or running buffers.

#### Scenario: Live prompt session is idle

- **WHEN** a live buffer is derived from `ghostel-mode`
- **AND** the buffer has a live Ghostel process
- **AND** Ghostel command state for the buffer is known to be idle
- **THEN** `ghostel-dwim-idle-p` returns non-nil

#### Scenario: Running command session is not idle

- **WHEN** a live buffer is derived from `ghostel-mode`
- **AND** the buffer has a live Ghostel process
- **AND** Ghostel command state for the buffer indicates a foreground command
  is running
- **THEN** `ghostel-dwim-idle-p` returns nil

#### Scenario: Exited session is not idle

- **WHEN** a live buffer is derived from `ghostel-mode`
- **AND** the buffer has no live Ghostel process
- **THEN** `ghostel-dwim-idle-p` returns nil

#### Scenario: Non-Ghostel buffer is not idle

- **WHEN** a live buffer is not derived from `ghostel-mode`
- **THEN** `ghostel-dwim-idle-p` returns nil

#### Scenario: Killed or missing buffer is not idle

- **WHEN** a buffer object or buffer name does not identify a live buffer
- **THEN** `ghostel-dwim-idle-p` returns nil

#### Scenario: Unknown command state is not treated as idle

- **WHEN** a live buffer is derived from `ghostel-mode`
- **AND** the buffer has a live Ghostel process
- **AND** Ghostel command state for the buffer is unknown or unavailable
- **THEN** `ghostel-dwim-idle-p` returns nil

#### Scenario: Fresh session without command markers is not idle

- **WHEN** a newly created Ghostel buffer has a live process
- **AND** Ghostel has not reported command start or finish state for that
  buffer
- **THEN** `ghostel-dwim-idle-p` returns nil

#### Scenario: Idle detection does not inspect terminal text

- **WHEN** `ghostel-dwim-idle-p` checks whether any buffer is reusable
- **THEN** it does not parse the buffer name
- **AND** it does not parse prompt text
- **AND** it does not search terminal buffer contents
- **AND** it does not execute shell commands
- **AND** it does not read files

### Requirement: Directory DWIM Reuse

`ghostel-dwim` SHALL provide `ghostel-dwim` as a directory-scoped DWIM command
that reuses an idle Ghostel buffer in the current directory before creating a
fresh directory session.

#### Scenario: Reuse idle directory session

- **WHEN** an idle Ghostel buffer is associated with the current directory
- **AND** the user invokes `ghostel-dwim`
- **THEN** that buffer is displayed
- **AND** no new Ghostel session is created

#### Scenario: Create when no directory session exists

- **WHEN** no Ghostel buffer is associated with the current directory
- **AND** the user invokes `ghostel-dwim`
- **THEN** `ghostel-dwim-open` is called

#### Scenario: Create when no idle directory session exists

- **WHEN** Ghostel buffers are associated with the current directory
- **AND** none of those buffers is idle
- **AND** the user invokes `ghostel-dwim`
- **THEN** `ghostel-dwim-open` is called

#### Scenario: Running directory session is not reused

- **WHEN** a Ghostel buffer associated with the current directory is running a
  foreground command
- **AND** the user invokes `ghostel-dwim`
- **THEN** that running buffer is not displayed for reuse
- **AND** that running process is not killed, restarted, interrupted, or
  mutated
- **AND** a fresh Ghostel session is created if no other idle directory
  session exists

#### Scenario: Idle directory session wins over running directory session

- **WHEN** a running Ghostel buffer is associated with the current directory
- **AND** an idle Ghostel buffer is associated with the current directory
- **AND** the user invokes `ghostel-dwim`
- **THEN** the idle buffer is displayed
- **AND** no new Ghostel session is created

#### Scenario: Other directory idle session is not reused

- **WHEN** an idle Ghostel buffer is associated with another directory
- **AND** no idle Ghostel buffer is associated with the current directory
- **AND** the user invokes `ghostel-dwim`
- **THEN** the other directory buffer is not displayed for reuse
- **AND** `ghostel-dwim-open` is called

#### Scenario: Multiple idle directory sessions use stable discovery order

- **WHEN** multiple idle Ghostel buffers are associated with the current
  directory
- **AND** the user invokes `ghostel-dwim`
- **THEN** the first idle buffer returned by
  `ghostel-dwim-directory-buffers` is displayed
- **AND** no minibuffer completion prompt is shown

### Requirement: Project DWIM Reuse

`ghostel-dwim` SHALL provide `ghostel-dwim-project` as a project-scoped DWIM
command that reuses an idle Ghostel buffer in the current project before
creating a fresh project session.

#### Scenario: Reuse idle project session

- **WHEN** an idle Ghostel buffer is associated with the current project
- **AND** the user invokes `ghostel-dwim-project`
- **THEN** that buffer is displayed
- **AND** no new Ghostel project session is created

#### Scenario: Create when no project session exists

- **WHEN** the current buffer belongs to a project
- **AND** no Ghostel buffer is associated with the current project
- **AND** the user invokes `ghostel-dwim-project`
- **THEN** `ghostel-dwim-project-open` is called

#### Scenario: Create when no idle project session exists

- **WHEN** the current buffer belongs to a project
- **AND** Ghostel buffers are associated with the current project
- **AND** none of those buffers is idle
- **AND** the user invokes `ghostel-dwim-project`
- **THEN** `ghostel-dwim-project-open` is called

#### Scenario: Running project session is not reused

- **WHEN** a Ghostel buffer associated with the current project is running a
  foreground command
- **AND** the user invokes `ghostel-dwim-project`
- **THEN** that running buffer is not displayed for reuse
- **AND** that running process is not killed, restarted, interrupted, or
  mutated
- **AND** a fresh Ghostel project session is created if no other idle project
  session exists

#### Scenario: Idle project session wins over running project session

- **WHEN** a running Ghostel buffer is associated with the current project
- **AND** an idle Ghostel buffer is associated with the current project
- **AND** the user invokes `ghostel-dwim-project`
- **THEN** the idle buffer is displayed
- **AND** no new Ghostel project session is created

#### Scenario: Other project idle session is not reused

- **WHEN** an idle Ghostel buffer is associated with another project
- **AND** no idle Ghostel buffer is associated with the current project
- **AND** the user invokes `ghostel-dwim-project`
- **THEN** the other project buffer is not displayed for reuse
- **AND** `ghostel-dwim-project-open` is called

#### Scenario: No current project errors

- **WHEN** the current buffer does not belong to any project
- **AND** the user invokes `ghostel-dwim-project`
- **THEN** a `user-error` is signaled
- **AND** no directory-scope fallback session is created

#### Scenario: Multiple idle project sessions use stable discovery order

- **WHEN** multiple idle Ghostel buffers are associated with the current
  project
- **AND** the user invokes `ghostel-dwim-project`
- **THEN** the first idle buffer returned by `ghostel-dwim-project-buffers`
  is displayed
- **AND** no minibuffer completion prompt is shown

### Requirement: Reuse Command Boundaries

DWIM reuse SHALL preserve the behavior of existing open, switch, discovery, and
creation commands.

#### Scenario: Directory open remains always fresh

- **WHEN** any directory Ghostel buffers already exist
- **AND** the user invokes `ghostel-dwim-open`
- **THEN** a fresh Ghostel session is created
- **AND** no existing idle buffer is reused by that command

#### Scenario: Directory switch remains switch-only

- **WHEN** no Ghostel buffer is associated with the current directory
- **AND** the user invokes `ghostel-dwim-switch`
- **THEN** a `user-error` is signaled
- **AND** no fresh Ghostel session is created by that command

#### Scenario: Project open remains always fresh

- **WHEN** any project Ghostel buffers already exist
- **AND** the user invokes `ghostel-dwim-project-open`
- **THEN** a fresh Ghostel project session is created
- **AND** no existing idle buffer is reused by that command

#### Scenario: Project switch remains switch-only

- **WHEN** the current buffer belongs to a project
- **AND** no Ghostel buffer is associated with the current project
- **AND** the user invokes `ghostel-dwim-project-switch`
- **THEN** a `user-error` is signaled
- **AND** no fresh Ghostel project session is created by that command

#### Scenario: Reuse uses existing scoped discovery

- **WHEN** `ghostel-dwim` or `ghostel-dwim-project` is invoked
- **THEN** directory candidates come from `ghostel-dwim-directory-buffers`
- **AND** project candidates come from `ghostel-dwim-project-buffers`
- **AND** DWIM reuse does not mutate directory or project membership metadata

#### Scenario: Reuse uses existing creation commands

- **WHEN** no idle scoped Ghostel buffer is available
- **AND** a DWIM command needs to create a session
- **THEN** directory creation goes through `ghostel-dwim-open`
- **AND** project creation goes through `ghostel-dwim-project-open`
- **AND** Ghostel PTY, native module, process, shell integration, TRAMP, and
  naming initialization are not copied into the DWIM command implementation
