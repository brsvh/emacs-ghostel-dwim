## ADDED Requirements

### Requirement: Idle Ghostel Session Detection

`ghostel-dwim` SHALL provide `ghostel-dwim-idle-p` to distinguish reusable
idle Ghostel sessions from non-Ghostel, exited, unknown, or running buffers.

#### Scenario: Live prompt session is idle

Given a live buffer derived from `ghostel-mode`
And the buffer has a live Ghostel process
And Ghostel command state for the buffer is known to be idle
When `ghostel-dwim-idle-p` is called for that buffer
Then the function returns non-nil

#### Scenario: Running command session is not idle

Given a live buffer derived from `ghostel-mode`
And the buffer has a live Ghostel process
And Ghostel command state for the buffer indicates a foreground command is running
When `ghostel-dwim-idle-p` is called for that buffer
Then the function returns nil

#### Scenario: Exited session is not idle

Given a live buffer derived from `ghostel-mode`
And the buffer has no live Ghostel process
When `ghostel-dwim-idle-p` is called for that buffer
Then the function returns nil

#### Scenario: Non-Ghostel buffer is not idle

Given a live buffer that is not derived from `ghostel-mode`
When `ghostel-dwim-idle-p` is called for that buffer
Then the function returns nil

#### Scenario: Killed or missing buffer is not idle

Given a buffer object or buffer name that does not identify a live buffer
When `ghostel-dwim-idle-p` is called for that value
Then the function returns nil

#### Scenario: Unknown command state is not treated as idle

Given a live buffer derived from `ghostel-mode`
And the buffer has a live Ghostel process
And Ghostel command state for the buffer is unknown or unavailable
When `ghostel-dwim-idle-p` is called for that buffer
Then the function returns nil

#### Scenario: Idle detection does not inspect terminal text

Given any buffer
When `ghostel-dwim-idle-p` checks whether it is reusable
Then it does not parse the buffer name
And it does not parse prompt text
And it does not search terminal buffer contents
And it does not execute shell commands
And it does not read files

### Requirement: Directory DWIM Reuse

`ghostel-dwim` SHALL provide `ghostel-dwim` as a directory-scoped DWIM command
that reuses an idle Ghostel buffer in the current directory before creating a
fresh directory session.

#### Scenario: Reuse idle directory session

Given an idle Ghostel buffer is associated with the current directory
When the user invokes `ghostel-dwim`
Then that buffer is displayed
And no new Ghostel session is created

#### Scenario: Create when no directory session exists

Given no Ghostel buffer is associated with the current directory
When the user invokes `ghostel-dwim`
Then `ghostel-dwim-open` is called

#### Scenario: Create when no idle directory session exists

Given Ghostel buffers are associated with the current directory
And none of those buffers is idle
When the user invokes `ghostel-dwim`
Then `ghostel-dwim-open` is called

#### Scenario: Running directory session is not reused

Given a Ghostel buffer associated with the current directory is running a foreground command
When the user invokes `ghostel-dwim`
Then that running buffer is not displayed for reuse
And that running process is not killed, restarted, interrupted, or mutated
And a fresh Ghostel session is created if no other idle directory session exists

#### Scenario: Idle directory session wins over running directory session

Given a running Ghostel buffer is associated with the current directory
And an idle Ghostel buffer is associated with the current directory
When the user invokes `ghostel-dwim`
Then the idle buffer is displayed
And no new Ghostel session is created

#### Scenario: Other directory idle session is not reused

Given an idle Ghostel buffer is associated with another directory
And no idle Ghostel buffer is associated with the current directory
When the user invokes `ghostel-dwim`
Then the other directory buffer is not displayed for reuse
And `ghostel-dwim-open` is called

#### Scenario: Multiple idle directory sessions use stable discovery order

Given multiple idle Ghostel buffers are associated with the current directory
When the user invokes `ghostel-dwim`
Then the first idle buffer returned by `ghostel-dwim-directory-buffers` is displayed
And no minibuffer completion prompt is shown

### Requirement: Project DWIM Reuse

`ghostel-dwim` SHALL provide `ghostel-dwim-project` as a project-scoped DWIM
command that reuses an idle Ghostel buffer in the current project before
creating a fresh project session.

#### Scenario: Reuse idle project session

Given an idle Ghostel buffer is associated with the current project
When the user invokes `ghostel-dwim-project`
Then that buffer is displayed
And no new Ghostel project session is created

#### Scenario: Create when no project session exists

Given the current buffer belongs to a project
And no Ghostel buffer is associated with the current project
When the user invokes `ghostel-dwim-project`
Then `ghostel-dwim-project-open` is called

#### Scenario: Create when no idle project session exists

Given the current buffer belongs to a project
And Ghostel buffers are associated with the current project
And none of those buffers is idle
When the user invokes `ghostel-dwim-project`
Then `ghostel-dwim-project-open` is called

#### Scenario: Running project session is not reused

Given a Ghostel buffer associated with the current project is running a foreground command
When the user invokes `ghostel-dwim-project`
Then that running buffer is not displayed for reuse
And that running process is not killed, restarted, interrupted, or mutated
And a fresh Ghostel project session is created if no other idle project session exists

#### Scenario: Idle project session wins over running project session

Given a running Ghostel buffer is associated with the current project
And an idle Ghostel buffer is associated with the current project
When the user invokes `ghostel-dwim-project`
Then the idle buffer is displayed
And no new Ghostel project session is created

#### Scenario: Other project idle session is not reused

Given an idle Ghostel buffer is associated with another project
And no idle Ghostel buffer is associated with the current project
When the user invokes `ghostel-dwim-project`
Then the other project buffer is not displayed for reuse
And `ghostel-dwim-project-open` is called

#### Scenario: No current project errors

Given the current buffer does not belong to any project
When the user invokes `ghostel-dwim-project`
Then a `user-error` is signaled
And no directory-scope fallback session is created

#### Scenario: Multiple idle project sessions use stable discovery order

Given multiple idle Ghostel buffers are associated with the current project
When the user invokes `ghostel-dwim-project`
Then the first idle buffer returned by `ghostel-dwim-project-buffers` is displayed
And no minibuffer completion prompt is shown

### Requirement: Reuse Command Boundaries

DWIM reuse SHALL preserve the behavior of existing open, switch, discovery, and
creation commands.

#### Scenario: Directory open remains always fresh

Given any existing directory Ghostel buffers
When the user invokes `ghostel-dwim-open`
Then a fresh Ghostel session is created
And no existing idle buffer is reused by that command

#### Scenario: Directory switch remains switch-only

Given no Ghostel buffer is associated with the current directory
When the user invokes `ghostel-dwim-switch`
Then a `user-error` is signaled
And no fresh Ghostel session is created by that command

#### Scenario: Project open remains always fresh

Given any existing project Ghostel buffers
When the user invokes `ghostel-dwim-project-open`
Then a fresh Ghostel project session is created
And no existing idle buffer is reused by that command

#### Scenario: Project switch remains switch-only

Given the current buffer belongs to a project
And no Ghostel buffer is associated with the current project
When the user invokes `ghostel-dwim-project-switch`
Then a `user-error` is signaled
And no fresh Ghostel project session is created by that command

#### Scenario: Reuse uses existing scoped discovery

Given `ghostel-dwim` or `ghostel-dwim-project` is invoked
When candidate buffers are collected
Then directory candidates come from `ghostel-dwim-directory-buffers`
And project candidates come from `ghostel-dwim-project-buffers`
And DWIM reuse does not mutate directory or project membership metadata

#### Scenario: Reuse uses existing creation commands

Given no idle scoped Ghostel buffer is available
When a DWIM command needs to create a session
Then directory creation goes through `ghostel-dwim-open`
And project creation goes through `ghostel-dwim-project-open`
And Ghostel PTY, native module, process, shell integration, TRAMP, and naming initialization are not copied into the DWIM command implementation
