# directory-sessions Specification

## Purpose
TBD - created by archiving change directory-sessions. Update Purpose after archive.
## Requirements
### Requirement: Directory Ghostel Buffer Discovery

`ghostel-dwim` SHALL provide a function that returns live Ghostel buffers
associated with the current directory.

#### Scenario: Buffer in the current directory is included

- **WHEN** a live buffer is derived from `ghostel-mode`
- **AND** that buffer's `default-directory` matches the current buffer's
  normalized `default-directory`
- **THEN** directory buffer discovery returns that buffer

#### Scenario: Buffer in a different directory is excluded

- **WHEN** a live buffer is derived from `ghostel-mode`
- **AND** that buffer's normalized `default-directory` differs from the current
  buffer's normalized `default-directory`
- **THEN** directory buffer discovery does not return that buffer

#### Scenario: Non-Ghostel buffer is excluded

- **WHEN** a live buffer is not derived from `ghostel-mode`
- **AND** that buffer's `default-directory` matches the current buffer's
  normalized `default-directory`
- **THEN** directory buffer discovery does not return that buffer

#### Scenario: Trailing slash differences are normalized

- **WHEN** a Ghostel buffer has `default-directory` equivalent to `/tmp/work`
- **AND** the current buffer has `default-directory` equivalent to `/tmp/work/`
- **THEN** directory buffer discovery treats the directories as matching

#### Scenario: Buffer rename does not affect membership

- **WHEN** a Ghostel buffer has been renamed
- **AND** that buffer's `default-directory` matches the current buffer's
  normalized `default-directory`
- **THEN** directory buffer discovery returns that buffer

### Requirement: Fresh Directory Session Opening

`ghostel-dwim` SHALL provide a command that opens a fresh Ghostel session in the
current directory.

#### Scenario: Open creates a new session in the current directory

- **WHEN** the user invokes `ghostel-dwim-open`
- **THEN** a fresh Ghostel session is requested
- **AND** the session is created with the caller's current `default-directory`

#### Scenario: Open does not reuse an existing session

- **WHEN** a Ghostel session already exists for the current directory
- **AND** the user invokes `ghostel-dwim-open`
- **THEN** a fresh Ghostel session is requested instead of reusing the existing
  session

### Requirement: Fresh Directory Session Opening In Another Window

`ghostel-dwim` SHALL provide a command that opens a fresh Ghostel session in the
current directory while expressing same-window avoidance as display intent.

#### Scenario: Open other window requests same-window avoidance

- **WHEN** the user invokes `ghostel-dwim-open-other-window`
- **THEN** a fresh Ghostel session is requested with the caller's current
  `default-directory`
- **AND** the command requests that Emacs avoid reusing the selected window

#### Scenario: Open other window does not guarantee placement

- **WHEN** the user invokes `ghostel-dwim-open-other-window`
- **THEN** the final displayed window is determined by Emacs display-buffer
  rules
- **AND** `ghostel-dwim` does not require a specific bottom, side, or split
  window layout

### Requirement: Directory Session Switching

`ghostel-dwim` SHALL provide a command that switches to a Ghostel buffer
associated with the current directory.

#### Scenario: Switch prompts only among current directory Ghostel buffers

- **WHEN** the user invokes `ghostel-dwim-switch` interactively
- **THEN** the completion candidates are limited to Ghostel buffers associated
  with the current directory

#### Scenario: Switch displays the selected directory buffer

- **WHEN** the user selects a Ghostel buffer associated with the current
  directory
- **THEN** `ghostel-dwim-switch` displays that buffer

#### Scenario: Switch errors when no directory buffers exist

- **WHEN** no Ghostel buffers are associated with the current directory
- **AND** the user invokes `ghostel-dwim-switch`
- **THEN** `ghostel-dwim-switch` signals `user-error`

### Requirement: Explicit Switch Target Validation

`ghostel-dwim-switch` SHALL validate explicit non-interactive switch targets
against the current directory scope.

#### Scenario: Missing target errors

- **WHEN** `ghostel-dwim-switch` is called with a buffer name that does not
  identify a live buffer
- **THEN** `ghostel-dwim-switch` signals `user-error`

#### Scenario: Non-Ghostel target errors

- **WHEN** `ghostel-dwim-switch` is called with a live buffer that is not
  derived from `ghostel-mode`
- **THEN** `ghostel-dwim-switch` signals `user-error`

#### Scenario: Out-of-directory target errors

- **WHEN** `ghostel-dwim-switch` is called with a Ghostel buffer whose
  normalized `default-directory` differs from the current buffer's normalized
  `default-directory`
- **THEN** `ghostel-dwim-switch` signals `user-error`

#### Scenario: In-directory target is displayed

- **WHEN** `ghostel-dwim-switch` is called with a Ghostel buffer whose
  normalized `default-directory` matches the current buffer's normalized
  `default-directory`
- **THEN** `ghostel-dwim-switch` displays that buffer

### Requirement: Lightweight Directory Matching

`ghostel-dwim` SHALL match directory scope without filesystem probing or project
lookup.

#### Scenario: Discovery avoids filesystem probes

- **WHEN** directory buffer discovery scans buffers
- **THEN** it does not call external commands, `file-truename`,
  `file-directory-p`, or `project-current`

#### Scenario: Symlink aliases are not resolved

- **WHEN** two directory strings refer to the same filesystem location only
  through a symlink
- **THEN** directory buffer discovery is not required to treat them as matching

