# session-cleanup Specification

## Purpose

Provide scoped cleanup commands for exited, idle, and all Ghostel sessions
within the current directory or current `project.el` project.

## Requirements

### Requirement: Directory Exited Session Cleanup
`ghostel-dwim` SHALL provide a directory-scoped command that kills exited
Ghostel buffers associated with the current directory.

#### Scenario: Exited directory buffer is killed
- **WHEN** a live buffer is derived from `ghostel-mode`
- **AND** the buffer is associated with the current directory
- **AND** the buffer has no live Ghostel process
- **AND** the user invokes `ghostel-dwim-clear-buffers`
- **THEN** that buffer is killed

#### Scenario: Live directory buffer is preserved
- **WHEN** a Ghostel buffer is associated with the current directory
- **AND** the buffer has a live Ghostel process
- **AND** the user invokes `ghostel-dwim-clear-buffers`
- **THEN** that buffer is preserved

#### Scenario: Other directory exited buffer is preserved
- **WHEN** a Ghostel buffer is associated with a directory other than the
  current directory
- **AND** the buffer has no live Ghostel process
- **AND** the user invokes `ghostel-dwim-clear-buffers`
- **THEN** that buffer is preserved

#### Scenario: Non-Ghostel exited buffer is preserved
- **WHEN** a live buffer is not derived from `ghostel-mode`
- **AND** the buffer has no live process
- **AND** the user invokes `ghostel-dwim-clear-buffers`
- **THEN** that buffer is preserved

#### Scenario: No exited directory buffers is a no-op
- **WHEN** no exited Ghostel buffers are associated with the current directory
- **AND** the user invokes `ghostel-dwim-clear-buffers`
- **THEN** no buffer is killed
- **AND** no Ghostel session is created
- **AND** no switch prompt is shown

### Requirement: Directory Idle Session Cleanup
`ghostel-dwim` SHALL provide a directory-scoped command that kills idle
Ghostel buffers associated with the current directory.

#### Scenario: Idle directory buffer is killed
- **WHEN** a Ghostel buffer is associated with the current directory
- **AND** `ghostel-dwim-idle-p` returns non-nil for that buffer
- **AND** the user invokes `ghostel-dwim-clear-idle-buffers`
- **THEN** that buffer is killed

#### Scenario: Running directory buffer is preserved
- **WHEN** a Ghostel buffer is associated with the current directory
- **AND** the buffer has a live Ghostel process
- **AND** Ghostel command state says a foreground command is running
- **AND** the user invokes `ghostel-dwim-clear-idle-buffers`
- **THEN** that buffer is preserved

#### Scenario: Unknown live directory buffer is preserved
- **WHEN** a Ghostel buffer is associated with the current directory
- **AND** the buffer has a live Ghostel process
- **AND** Ghostel command state is unknown
- **AND** the user invokes `ghostel-dwim-clear-idle-buffers`
- **THEN** that buffer is preserved

#### Scenario: Exited directory buffer is preserved by idle cleanup
- **WHEN** a Ghostel buffer is associated with the current directory
- **AND** the buffer has no live Ghostel process
- **AND** the user invokes `ghostel-dwim-clear-idle-buffers`
- **THEN** that buffer is preserved

#### Scenario: Other directory idle buffer is preserved
- **WHEN** a Ghostel buffer is associated with a directory other than the
  current directory
- **AND** `ghostel-dwim-idle-p` returns non-nil for that buffer
- **AND** the user invokes `ghostel-dwim-clear-idle-buffers`
- **THEN** that buffer is preserved

#### Scenario: No idle directory buffers is a no-op
- **WHEN** no idle Ghostel buffers are associated with the current directory
- **AND** the user invokes `ghostel-dwim-clear-idle-buffers`
- **THEN** no buffer is killed
- **AND** no Ghostel session is created
- **AND** no prompt is shown

### Requirement: Directory Scoped Session Kill
`ghostel-dwim` SHALL provide a directory-scoped command that kills all Ghostel
buffers associated with the current directory after any required confirmation.

#### Scenario: All current directory Ghostel buffers are killed
- **WHEN** multiple Ghostel buffers are associated with the current directory
- **AND** none of those buffers requires running-session confirmation
- **AND** the user invokes `ghostel-dwim-kill-buffers`
- **THEN** all current-directory Ghostel buffers are killed

#### Scenario: Other directory Ghostel buffer is preserved
- **WHEN** a Ghostel buffer is associated with a directory other than the
  current directory
- **AND** the user invokes `ghostel-dwim-kill-buffers`
- **THEN** that buffer is preserved

#### Scenario: Running directory buffer prompts once before any kill
- **WHEN** at least one Ghostel buffer associated with the current directory
  has a live Ghostel process
- **AND** Ghostel command state says a foreground command is running in that
  buffer
- **AND** the user invokes `ghostel-dwim-kill-buffers`
- **THEN** the user is prompted exactly once before any matching buffer is
  killed

#### Scenario: Unknown live directory buffer requires confirmation
- **WHEN** at least one Ghostel buffer associated with the current directory
  has a live Ghostel process
- **AND** Ghostel command state is unknown for that buffer
- **AND** the user invokes `ghostel-dwim-kill-buffers`
- **THEN** the user is prompted before any matching buffer is killed

#### Scenario: Confirmed directory kill kills all scoped buffers
- **WHEN** at least one Ghostel buffer associated with the current directory
  requires confirmation
- **AND** the user confirms `ghostel-dwim-kill-buffers`
- **THEN** all Ghostel buffers associated with the current directory are
  killed

#### Scenario: Declined directory kill preserves all scoped buffers
- **WHEN** at least one Ghostel buffer associated with the current directory
  requires confirmation
- **AND** the user declines `ghostel-dwim-kill-buffers`
- **THEN** no Ghostel buffers associated with the current directory are killed
- **AND** no bottom windows are explicitly deleted by cleanup

#### Scenario: No current directory Ghostel buffers is a no-op
- **WHEN** no Ghostel buffers are associated with the current directory
- **AND** the user invokes `ghostel-dwim-kill-buffers`
- **THEN** no buffer is killed
- **AND** no confirmation prompt is shown
- **AND** no Ghostel session is created

### Requirement: Project Exited Session Cleanup
`ghostel-dwim` SHALL provide a project-scoped command that kills exited
Ghostel buffers associated with the current project.

#### Scenario: Exited project buffer is killed
- **WHEN** the current buffer belongs to a `project.el` project
- **AND** a Ghostel buffer is associated with the current project
- **AND** the Ghostel buffer has no live Ghostel process
- **AND** the user invokes `ghostel-dwim-project-clear-buffers`
- **THEN** that buffer is killed

#### Scenario: Live project buffer is preserved
- **WHEN** the current buffer belongs to a `project.el` project
- **AND** a Ghostel buffer is associated with the current project
- **AND** the Ghostel buffer has a live Ghostel process
- **AND** the user invokes `ghostel-dwim-project-clear-buffers`
- **THEN** that buffer is preserved

#### Scenario: Other project exited buffer is preserved
- **WHEN** the current buffer belongs to a `project.el` project
- **AND** a Ghostel buffer is associated with another project
- **AND** the Ghostel buffer has no live Ghostel process
- **AND** the user invokes `ghostel-dwim-project-clear-buffers`
- **THEN** that buffer is preserved

#### Scenario: Project exited cleanup outside a project errors
- **WHEN** the current buffer does not belong to a `project.el` project
- **AND** the user invokes `ghostel-dwim-project-clear-buffers`
- **THEN** `ghostel-dwim-project-clear-buffers` signals `user-error`
- **AND** no buffer is killed

### Requirement: Project Idle Session Cleanup
`ghostel-dwim` SHALL provide a project-scoped command that kills idle Ghostel
buffers associated with the current project.

#### Scenario: Idle project buffer is killed
- **WHEN** the current buffer belongs to a `project.el` project
- **AND** a Ghostel buffer is associated with the current project
- **AND** `ghostel-dwim-idle-p` returns non-nil for that buffer
- **AND** the user invokes `ghostel-dwim-project-clear-idle-buffers`
- **THEN** that buffer is killed

#### Scenario: Running project buffer is preserved
- **WHEN** the current buffer belongs to a `project.el` project
- **AND** a Ghostel buffer is associated with the current project
- **AND** Ghostel command state says a foreground command is running in that
  buffer
- **AND** the user invokes `ghostel-dwim-project-clear-idle-buffers`
- **THEN** that buffer is preserved

#### Scenario: Unknown live project buffer is preserved
- **WHEN** the current buffer belongs to a `project.el` project
- **AND** a Ghostel buffer is associated with the current project
- **AND** the buffer has a live Ghostel process
- **AND** Ghostel command state is unknown
- **AND** the user invokes `ghostel-dwim-project-clear-idle-buffers`
- **THEN** that buffer is preserved

#### Scenario: Other project idle buffer is preserved
- **WHEN** the current buffer belongs to a `project.el` project
- **AND** a Ghostel buffer is associated with another project
- **AND** `ghostel-dwim-idle-p` returns non-nil for that buffer
- **AND** the user invokes `ghostel-dwim-project-clear-idle-buffers`
- **THEN** that buffer is preserved

#### Scenario: Project idle cleanup outside a project errors
- **WHEN** the current buffer does not belong to a `project.el` project
- **AND** the user invokes `ghostel-dwim-project-clear-idle-buffers`
- **THEN** `ghostel-dwim-project-clear-idle-buffers` signals `user-error`
- **AND** no buffer is killed

### Requirement: Project Scoped Session Kill
`ghostel-dwim` SHALL provide a project-scoped command that kills all Ghostel
buffers associated with the current project after any required confirmation.

#### Scenario: All current project Ghostel buffers are killed
- **WHEN** the current buffer belongs to a `project.el` project
- **AND** multiple Ghostel buffers are associated with the current project
- **AND** none of those buffers requires running-session confirmation
- **AND** the user invokes `ghostel-dwim-project-kill-buffers`
- **THEN** all current-project Ghostel buffers are killed

#### Scenario: Other project Ghostel buffer is preserved
- **WHEN** the current buffer belongs to a `project.el` project
- **AND** a Ghostel buffer is associated with another project
- **AND** the user invokes `ghostel-dwim-project-kill-buffers`
- **THEN** that buffer is preserved

#### Scenario: Running project buffer prompts once before any kill
- **WHEN** the current buffer belongs to a `project.el` project
- **AND** at least one Ghostel buffer associated with the current project has a
  live Ghostel process
- **AND** Ghostel command state says a foreground command is running in that
  buffer
- **AND** the user invokes `ghostel-dwim-project-kill-buffers`
- **THEN** the user is prompted exactly once before any matching buffer is
  killed

#### Scenario: Unknown live project buffer requires confirmation
- **WHEN** the current buffer belongs to a `project.el` project
- **AND** at least one Ghostel buffer associated with the current project has a
  live Ghostel process
- **AND** Ghostel command state is unknown for that buffer
- **AND** the user invokes `ghostel-dwim-project-kill-buffers`
- **THEN** the user is prompted before any matching buffer is killed

#### Scenario: Confirmed project kill kills all scoped buffers
- **WHEN** at least one Ghostel buffer associated with the current project
  requires confirmation
- **AND** the user confirms `ghostel-dwim-project-kill-buffers`
- **THEN** all Ghostel buffers associated with the current project are killed

#### Scenario: Declined project kill preserves all scoped buffers
- **WHEN** at least one Ghostel buffer associated with the current project
  requires confirmation
- **AND** the user declines `ghostel-dwim-project-kill-buffers`
- **THEN** no Ghostel buffers associated with the current project are killed
- **AND** no bottom windows are explicitly deleted by cleanup

#### Scenario: Project kill outside a project errors
- **WHEN** the current buffer does not belong to a `project.el` project
- **AND** the user invokes `ghostel-dwim-project-kill-buffers`
- **THEN** `ghostel-dwim-project-kill-buffers` signals `user-error`
- **AND** no buffer is killed

### Requirement: Bottom Window Cleanup
`ghostel-dwim` SHALL delete bottom windows that displayed Ghostel buffers
killed by cleanup commands without explicitly deleting non-bottom windows.

#### Scenario: Bottom window is deleted after buffer kill
- **WHEN** a Ghostel buffer is displayed in a bottom window
- **AND** a `ghostel-dwim` cleanup command kills that buffer
- **THEN** the bottom window that displayed that buffer is deleted

#### Scenario: Multiple bottom windows are deleted after buffer kill
- **WHEN** a Ghostel buffer is displayed in multiple bottom windows
- **AND** a `ghostel-dwim` cleanup command kills that buffer
- **THEN** each live bottom window that displayed that buffer is deleted

#### Scenario: Non-bottom window is not explicitly deleted
- **WHEN** a Ghostel buffer is displayed in a non-bottom window
- **AND** a `ghostel-dwim` cleanup command kills that buffer
- **THEN** cleanup does not explicitly delete that non-bottom window

#### Scenario: Non-bottom side window is not explicitly deleted
- **WHEN** a Ghostel buffer is displayed in a side window whose side is not
  bottom
- **AND** a `ghostel-dwim` cleanup command kills that buffer
- **THEN** cleanup does not explicitly delete that side window

#### Scenario: Cancelled cleanup does not delete bottom windows
- **WHEN** a Ghostel buffer is displayed in a bottom window
- **AND** a cleanup command requires confirmation
- **AND** the user declines confirmation
- **THEN** cleanup does not explicitly delete the bottom window

### Requirement: Cleanup Command Boundaries
`ghostel-dwim` SHALL implement cleanup without changing session creation,
switching, discovery, or Ghostel terminal internals.

#### Scenario: Cleanup returns killed count
- **WHEN** a cleanup command completes
- **THEN** it returns the number of buffers killed by that command

#### Scenario: Cleanup does not create sessions
- **WHEN** any `ghostel-dwim` cleanup command is invoked
- **THEN** it does not call `ghostel`
- **AND** it does not call `ghostel-project`
- **AND** it does not create a Ghostel session

#### Scenario: Cleanup does not mutate running processes without confirmation
- **WHEN** `ghostel-dwim-clear-buffers` or
  `ghostel-dwim-clear-idle-buffers` is invoked
- **THEN** it does not kill, restart, interrupt, or otherwise mutate a running
  Ghostel process

#### Scenario: Cleanup does not inspect terminal contents
- **WHEN** any cleanup command determines exited, idle, running, or unknown
  state
- **THEN** it does not parse buffer names
- **AND** it does not scan terminal buffer contents
- **AND** it does not execute shell commands
- **AND** it does not read arbitrary file contents

#### Scenario: Directory cleanup uses existing scoped discovery
- **WHEN** directory cleanup collects candidates
- **THEN** it uses `ghostel-dwim-directory-buffers`
- **AND** it does not implement a second directory membership rule

#### Scenario: Project cleanup uses existing scoped discovery
- **WHEN** project cleanup collects candidates
- **THEN** it uses `ghostel-dwim-project-buffers`
- **AND** it does not implement a second project membership rule

#### Scenario: Ghostel package remains unchanged
- **WHEN** cleanup behavior is implemented
- **THEN** the installed `ghostel.el` package is not modified
- **AND** Ghostel PTY, native module, TRAMP, shell integration, and process
  initialization logic are not copied into `ghostel-dwim`
