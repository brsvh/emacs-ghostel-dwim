# project-sessions Specification

## Purpose

TBD - created by archiving change project-sessions. Update Purpose after archive.

## Requirements

### Requirement: Project Ghostel Buffer Discovery

`ghostel-dwim` SHALL provide a function that returns live Ghostel buffers
associated with the current `project.el` project.

#### Scenario: Current project buffer is included

- **WHEN** the current buffer belongs to a project
- **AND** a live buffer is derived from `ghostel-mode`
- **AND** Ghostel project membership semantics associate that buffer with the
  current project
- **THEN** project buffer discovery returns that buffer

#### Scenario: Other project buffer is excluded

- **WHEN** the current buffer belongs to a project
- **AND** a live Ghostel buffer is associated with another project
- **THEN** project buffer discovery does not return that buffer

#### Scenario: Non-Ghostel project buffer is excluded

- **WHEN** the current buffer belongs to a project
- **AND** a live buffer is not derived from `ghostel-mode`
- **AND** that buffer is otherwise associated with the current project
- **THEN** project buffer discovery does not return that buffer

#### Scenario: No current project errors

- **WHEN** the current buffer does not belong to a `project.el` project
- **AND** project buffer discovery is requested
- **THEN** project buffer discovery signals `user-error`

#### Scenario: Buffer rename does not affect membership

- **WHEN** a Ghostel buffer has been renamed
- **AND** Ghostel project membership semantics associate that buffer with the
  current project
- **THEN** project buffer discovery returns that buffer

### Requirement: Ghostel Project Scope Compatibility

`ghostel-dwim` SHALL preserve Ghostel's project buffer membership semantics
when discovering current project buffers.

#### Scenario: Default-directory scope follows terminal directory

- **WHEN** Ghostel project buffer scope is `default-directory`
- **AND** a Ghostel buffer's current buffer-local `default-directory` belongs
  to the current project
- **THEN** project buffer discovery includes that buffer

#### Scenario: Default-directory scope excludes terminals outside the project

- **WHEN** Ghostel project buffer scope is `default-directory`
- **AND** a Ghostel buffer's current buffer-local `default-directory` does not
  belong to the current project
- **THEN** project buffer discovery excludes that buffer

#### Scenario: Identity scope uses creation-time project identity

- **WHEN** Ghostel project buffer scope is `identity`
- **AND** a Ghostel buffer was created with the current project's Ghostel
  project identity
- **THEN** project buffer discovery includes that buffer even if its current
  `default-directory` is outside the project

#### Scenario: Identity scope excludes buffers without project identity

- **WHEN** Ghostel project buffer scope is `identity`
- **AND** a Ghostel buffer does not have the current project's Ghostel project
  identity
- **THEN** project buffer discovery excludes that buffer even if its current
  `default-directory` is inside the project

#### Scenario: Both scope merges directory and identity matches

- **WHEN** Ghostel project buffer scope is `both`
- **AND** one Ghostel buffer matches by `default-directory`
- **AND** another Ghostel buffer matches by project identity
- **THEN** project buffer discovery includes both buffers without duplicate
  entries

#### Scenario: Buffer name is not the authority for membership

- **WHEN** a Ghostel buffer name changes
- **THEN** project buffer discovery bases membership on Ghostel project
  semantics rather than inferring the project from the current buffer name

### Requirement: Fresh Project Session Opening

`ghostel-dwim` SHALL provide a command that opens a fresh Ghostel session at
the current project root.

#### Scenario: Open creates a new session at the project root

- **WHEN** the current buffer belongs to a project rooted at `/tmp/project/`
- **AND** the user invokes `ghostel-dwim-project-open`
- **THEN** a fresh Ghostel project session is requested
- **AND** the session is created with `default-directory` set to
  `/tmp/project/`

#### Scenario: Open uses Ghostel project identity

- **WHEN** the current buffer belongs to a project
- **AND** the user invokes `ghostel-dwim-project-open`
- **THEN** the created session uses Ghostel's project-prefixed naming and
  identity behavior

#### Scenario: Open does not reuse an existing project session

- **WHEN** a Ghostel session already exists for the current project
- **AND** the user invokes `ghostel-dwim-project-open`
- **THEN** a fresh Ghostel project session is requested instead of reusing the
  existing session

#### Scenario: Open outside a project errors

- **WHEN** the current buffer does not belong to a `project.el` project
- **AND** the user invokes `ghostel-dwim-project-open`
- **THEN** `ghostel-dwim-project-open` signals `user-error`

### Requirement: Fresh Project Session Opening In Another Window

`ghostel-dwim` SHALL provide a command that opens a fresh Ghostel project
session while expressing same-window avoidance as display intent.

#### Scenario: Open other window requests same-window avoidance

- **WHEN** the current buffer belongs to a project
- **AND** the user invokes `ghostel-dwim-project-open-other-window`
- **THEN** a fresh Ghostel project session is requested
- **AND** the command requests that Emacs avoid reusing the selected window

#### Scenario: Open other window does not guarantee placement

- **WHEN** the user invokes `ghostel-dwim-project-open-other-window`
- **THEN** the final displayed window is determined by Emacs display-buffer
  rules
- **AND** `ghostel-dwim` does not require a specific bottom, side, or split
  window layout

#### Scenario: Open other window outside a project errors

- **WHEN** the current buffer does not belong to a `project.el` project
- **AND** the user invokes `ghostel-dwim-project-open-other-window`
- **THEN** `ghostel-dwim-project-open-other-window` signals `user-error`

### Requirement: Project Session Switching

`ghostel-dwim` SHALL provide a command that switches to a Ghostel buffer
associated with the current project.

#### Scenario: Switch prompts only among current project Ghostel buffers

- **WHEN** the current buffer belongs to a project
- **AND** the user invokes `ghostel-dwim-project-switch` interactively
- **THEN** the completion candidates are limited to Ghostel buffers associated
  with the current project

#### Scenario: Switch displays the selected project buffer

- **WHEN** the user selects a Ghostel buffer associated with the current
  project
- **THEN** `ghostel-dwim-project-switch` displays that buffer

#### Scenario: Switch errors when no project buffers exist

- **WHEN** the current buffer belongs to a project
- **AND** no Ghostel buffers are associated with the current project
- **AND** the user invokes `ghostel-dwim-project-switch`
- **THEN** `ghostel-dwim-project-switch` signals `user-error`

#### Scenario: Switch outside a project errors

- **WHEN** the current buffer does not belong to a `project.el` project
- **AND** the user invokes `ghostel-dwim-project-switch`
- **THEN** `ghostel-dwim-project-switch` signals `user-error`

#### Scenario: Switch does not create sessions

- **WHEN** no Ghostel buffers are associated with the current project
- **AND** the user invokes `ghostel-dwim-project-switch`
- **THEN** no new Ghostel session is created

### Requirement: Explicit Project Switch Target Validation

`ghostel-dwim-project-switch` SHALL validate explicit non-interactive switch
targets against the current project scope.

#### Scenario: Missing target errors

- **WHEN** `ghostel-dwim-project-switch` is called with a buffer name that does
  not identify a live buffer
- **THEN** `ghostel-dwim-project-switch` signals `user-error`

#### Scenario: Non-Ghostel target errors

- **WHEN** `ghostel-dwim-project-switch` is called with a live buffer that is
  not derived from `ghostel-mode`
- **THEN** `ghostel-dwim-project-switch` signals `user-error`

#### Scenario: Out-of-project target errors

- **WHEN** `ghostel-dwim-project-switch` is called with a Ghostel buffer that
  is not associated with the current project
- **THEN** `ghostel-dwim-project-switch` signals `user-error`

#### Scenario: In-project target is displayed

- **WHEN** `ghostel-dwim-project-switch` is called with a Ghostel buffer that
  is associated with the current project
- **THEN** `ghostel-dwim-project-switch` displays that buffer

#### Scenario: Explicit target outside a project errors

- **WHEN** the current buffer does not belong to a `project.el` project
- **AND** `ghostel-dwim-project-switch` is called with an explicit target
- **THEN** `ghostel-dwim-project-switch` signals `user-error`

### Requirement: Project Integration Boundaries

`ghostel-dwim` SHALL implement project sessions without reimplementing
Ghostel terminal internals or mutating unrelated terminal state.

#### Scenario: Project open delegates terminal creation to Ghostel

- **WHEN** `ghostel-dwim-project-open` creates a terminal session
- **THEN** terminal creation is delegated to Ghostel project creation behavior
- **AND** `ghostel-dwim` does not copy Ghostel PTY, shell integration, TRAMP,
  native module, or process initialization logic

#### Scenario: Discovery does not execute shell commands

- **WHEN** project buffer discovery scans project Ghostel buffers
- **THEN** it does not execute shell commands or parse terminal text

#### Scenario: Switch does not mutate processes

- **WHEN** `ghostel-dwim-project-switch` displays a project Ghostel buffer
- **THEN** it does not kill, restart, or otherwise mutate any Ghostel process

#### Scenario: Ghostel package remains unchanged

- **WHEN** project session behavior is implemented
- **THEN** the installed `ghostel.el` package is not modified
