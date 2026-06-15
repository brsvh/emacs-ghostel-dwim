;;; ghostel-dwim-tests.el --- Tests -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Bingshan Chang

;; This file is not part of GNU Emacs.

;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'ghostel-dwim)
(require 'subr-x)

(let ((project-list-path (make-temp-file "ghostel-dwim-projects-")))
  (delete-file project-list-path)
  (setq project-list-file project-list-path))

(when (boundp 'project--list)
  (setq project--list nil))

(defvar ghostel-dwim-test--buffers nil
  "Buffers created by the current ghostel-dwim test.")

(defvar ghostel-dwim-test--processes nil
  "Processes created by the current ghostel-dwim test.")

(defmacro ghostel-dwim-test--with-buffers (&rest body)
  "Run BODY and kill buffers tracked by the test."
  (declare (indent 0))
  `(let (ghostel-dwim-test--buffers
         ghostel-dwim-test--processes)
     (unwind-protect
         (progn ,@body)
       (dolist (process ghostel-dwim-test--processes)
         (when (process-live-p process)
           (delete-process process)))
       (dolist (buffer ghostel-dwim-test--buffers)
         (when (buffer-live-p buffer)
           (kill-buffer buffer))))))

(defmacro ghostel-dwim-test--with-temp-dir (var &rest body)
  "Bind VAR to a temporary directory while running BODY."
  (declare (indent 1))
  `(let ((,var (file-name-as-directory
                (make-temp-file "ghostel-dwim-test-" t))))
     (unwind-protect
         (progn ,@body)
       (when (file-directory-p ,var)
         (delete-directory ,var t)))))

(defmacro ghostel-dwim-test--with-project (var &rest body)
  "Bind VAR to a temporary project root while running BODY."
  (declare (indent 1))
  `(ghostel-dwim-test--with-temp-dir ,var
     (make-directory (expand-file-name ".git" ,var))
     ,@body))

(defmacro ghostel-dwim-test--without-project (&rest body)
  "Run BODY while making `project-current' report no project."
  (declare (indent 0))
  `(cl-letf (((symbol-function 'project-current)
              (lambda (&rest _)
                nil)))
     ,@body))

(defmacro ghostel-dwim-test--with-confirmation
    (result prompts-var &rest body)
  "Run BODY with cleanup confirmation returning RESULT.

Bind PROMPTS-VAR to the prompts received by the confirmation hook."
  (declare (indent 2))
  `(let* ((,prompts-var nil)
          (ghostel-dwim-confirm-kill-running-functions
           (list (lambda (prompt)
                   (push prompt ,prompts-var)
                   ,result))))
     ,@body))

(defmacro ghostel-dwim-test--without-confirmation (&rest body)
  "Run BODY and fail if cleanup confirmation is requested."
  (declare (indent 0))
  `(let ((ghostel-dwim-confirm-kill-running-functions
          (list (lambda (&rest _)
                  (error "confirmation should not be requested")))))
     ,@body))

(defmacro ghostel-dwim-test--with-window-state (&rest body)
  "Run BODY and restore the current window configuration afterward."
  (declare (indent 0))
  `(let ((configuration (current-window-configuration)))
     (unwind-protect
         (progn ,@body)
       (set-window-configuration configuration))))

(defun ghostel-dwim-test--track-buffer (buffer)
  "Track BUFFER for cleanup and return it."
  (push buffer ghostel-dwim-test--buffers)
  buffer)

(defun ghostel-dwim-test--make-buffer (name directory &optional ghostel-p)
  "Create a test buffer named NAME in DIRECTORY.

When GHOSTEL-P is non-nil, put the buffer in `ghostel-mode'."
  (let ((buffer (generate-new-buffer name)))
    (with-current-buffer buffer
      (setq default-directory (file-name-as-directory directory))
      (when ghostel-p
        (ghostel-mode)))
    (ghostel-dwim-test--track-buffer buffer)))

(defun ghostel-dwim-test--make-process (&optional exited)
  "Create and track a process for Ghostel session tests.

When EXITED is non-nil, return a non-live process object."
  (let ((process (make-pipe-process :name "ghostel-dwim-test"
                                    :noquery t)))
    (push process ghostel-dwim-test--processes)
    (when exited
      (delete-process process))
    process))

(defun ghostel-dwim-test--make-ghostel-session
    (name directory state &optional process-state)
  "Create a Ghostel buffer named NAME in DIRECTORY with command STATE.

PROCESS-STATE may be `live', `exited', or nil for no process."
  (let ((buffer (ghostel-dwim-test--make-buffer name directory t)))
    (with-current-buffer buffer
      (setq-local ghostel-dwim--command-state state)
      (pcase process-state
        ('live
         (setq-local ghostel--process
                     (ghostel-dwim-test--make-process)))
        ('exited
         (setq-local ghostel--process
                     (ghostel-dwim-test--make-process t)))))
    buffer))

(defun ghostel-dwim-test--buffer-names (buffers)
  "Return the sorted names of BUFFERS."
  (sort (mapcar #'buffer-name buffers) #'string<))

(defun ghostel-dwim-test--make-subdir (directory name)
  "Create a subdirectory NAME inside DIRECTORY and return it."
  (let ((subdir (file-name-as-directory
                 (expand-file-name name directory))))
    (make-directory subdir)
    subdir))

(defun ghostel-dwim-test--current-project-identity ()
  "Return Ghostel's project identity for the current project."
  (let ((ghostel-buffer-name
         (project-prefixed-buffer-name
          (string-trim ghostel-buffer-name "*" "*"))))
    ghostel-buffer-name))

(ert-deftest ghostel-dwim-idle-p-returns-nil-for-non-ghostel-buffer ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-buffers
      (let ((plain (ghostel-dwim-test--make-buffer "plain" dir)))
        (should-not (ghostel-dwim-idle-p plain))))))

(ert-deftest ghostel-dwim-idle-p-returns-nil-for-killed-buffer ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-buffers
      (let ((buffer (ghostel-dwim-test--make-ghostel-session
                     "ghostel-killed" dir 'idle 'live)))
        (kill-buffer buffer)
        (should-not (ghostel-dwim-idle-p buffer))
        (should-not (ghostel-dwim-idle-p "ghostel-killed"))))))

(ert-deftest ghostel-dwim-idle-p-returns-nil-without-live-process ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-buffers
      (let ((buffer (ghostel-dwim-test--make-ghostel-session
                     "ghostel-no-process" dir 'idle)))
        (should-not (ghostel-dwim-idle-p buffer))))))

(ert-deftest ghostel-dwim-idle-p-returns-nil-for-exited-process ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-buffers
      (let ((buffer (ghostel-dwim-test--make-ghostel-session
                     "ghostel-exited" dir 'idle 'exited)))
        (should-not (ghostel-dwim-idle-p buffer))))))

(ert-deftest ghostel-dwim-idle-p-returns-non-nil-for-known-idle ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-buffers
      (let ((buffer (ghostel-dwim-test--make-ghostel-session
                     "ghostel-idle" dir 'idle 'live)))
        (should (ghostel-dwim-idle-p buffer))))))

(ert-deftest ghostel-dwim-idle-p-returns-nil-for-running-command ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-buffers
      (let ((buffer (ghostel-dwim-test--make-ghostel-session
                     "ghostel-running" dir 'running 'live)))
        (should-not (ghostel-dwim-idle-p buffer))))))

(ert-deftest ghostel-dwim-idle-p-returns-nil-for-unknown-state ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-buffers
      (let ((buffer (ghostel-dwim-test--make-ghostel-session
                     "ghostel-unknown" dir nil 'live)))
        (should-not (ghostel-dwim-idle-p buffer))))))

(ert-deftest ghostel-dwim-idle-hooks-are-registered ()
  (should (memq #'ghostel-dwim--command-start
                ghostel-command-start-functions))
  (should (memq #'ghostel-dwim--command-finish
                ghostel-command-finish-functions)))

(ert-deftest ghostel-dwim-idle-hooks-update-command-state ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-buffers
      (let ((buffer (ghostel-dwim-test--make-ghostel-session
                     "ghostel-hooked" dir 'idle 'live)))
        (ghostel-dwim--command-start buffer)
        (should (eq (buffer-local-value 'ghostel-dwim--command-state
                                        buffer)
                    'running))
        (should-not (ghostel-dwim-idle-p buffer))
        (ghostel-dwim--command-finish buffer 0)
        (should (eq (buffer-local-value 'ghostel-dwim--command-state
                                        buffer)
                    'idle))
        (should (ghostel-dwim-idle-p buffer))))))

(ert-deftest ghostel-dwim-idle-p-avoids-terminal-inspection ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-buffers
      (let ((buffer (ghostel-dwim-test--make-ghostel-session
                     "ghostel-idle-no-inspection" dir 'idle 'live)))
        (cl-letf (((symbol-function 'buffer-substring)
                   (lambda (&rest _)
                     (error "buffer text should not be inspected")))
                  ((symbol-function 'buffer-substring-no-properties)
                   (lambda (&rest _)
                     (error "buffer text should not be inspected")))
                  ((symbol-function 'search-forward)
                   (lambda (&rest _)
                     (error "buffer text should not be searched")))
                  ((symbol-function 'shell-command)
                   (lambda (&rest _)
                     (error "shell-command should not be called")))
                  ((symbol-function 'insert-file-contents)
                   (lambda (&rest _)
                     (error "files should not be read"))))
          (should (ghostel-dwim-idle-p buffer)))))))

(ert-deftest ghostel-dwim-directory-buffers-includes-current-directory ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-buffers
      (let ((current (ghostel-dwim-test--make-buffer "current" dir))
            (ghostel-buffer
             (ghostel-dwim-test--make-buffer "ghostel-current" dir t)))
        (with-current-buffer current
          (should (memq ghostel-buffer
                        (ghostel-dwim-directory-buffers))))))))

(ert-deftest ghostel-dwim-directory-buffers-excludes-other-directory ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-temp-dir other-dir
      (ghostel-dwim-test--with-buffers
        (let ((current (ghostel-dwim-test--make-buffer "current" dir))
              (other (ghostel-dwim-test--make-buffer "ghostel-other"
                                                     other-dir t)))
          (with-current-buffer current
            (should-not (memq other
                              (ghostel-dwim-directory-buffers)))))))))

(ert-deftest ghostel-dwim-directory-buffers-excludes-non-ghostel-buffer ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-buffers
      (let ((current (ghostel-dwim-test--make-buffer "current" dir))
            (plain (ghostel-dwim-test--make-buffer "plain" dir)))
        (with-current-buffer current
          (should-not (memq plain
                            (ghostel-dwim-directory-buffers))))))))

(ert-deftest ghostel-dwim-directory-buffers-normalizes-trailing-slash ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-buffers
      (let ((current (ghostel-dwim-test--make-buffer "current" dir))
            (ghostel-buffer
             (ghostel-dwim-test--make-buffer "ghostel-no-slash" dir t)))
        (with-current-buffer ghostel-buffer
          (setq default-directory (directory-file-name dir)))
        (with-current-buffer current
          (should (memq ghostel-buffer
                        (ghostel-dwim-directory-buffers))))))))

(ert-deftest ghostel-dwim-directory-buffers-ignores-buffer-rename ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-buffers
      (let ((current (ghostel-dwim-test--make-buffer "current" dir))
            (ghostel-buffer
             (ghostel-dwim-test--make-buffer "ghostel-before-rename" dir t)))
        (with-current-buffer ghostel-buffer
          (rename-buffer "ghostel-after-rename"))
        (with-current-buffer current
          (should (memq ghostel-buffer
                        (ghostel-dwim-directory-buffers))))))))

(ert-deftest ghostel-dwim-directory-buffers-avoids-probes ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-buffers
      (let ((current (ghostel-dwim-test--make-buffer "current" dir)))
        (ghostel-dwim-test--make-buffer "ghostel-current" dir t)
        (with-current-buffer current
          (cl-letf (((symbol-function 'file-truename)
                     (lambda (&rest _)
                       (error "file-truename should not be called")))
                    ((symbol-function 'file-directory-p)
                     (lambda (&rest _)
                       (error "file-directory-p should not be called")))
                    ((symbol-function 'project-current)
                     (lambda (&rest _)
                       (error "project-current should not be called")))
                    ((symbol-function 'shell-command)
                     (lambda (&rest _)
                       (error "shell-command should not be called"))))
            (should (= 1 (length (ghostel-dwim-directory-buffers))))))))))

(ert-deftest ghostel-dwim-switch-errors-with-no-directory-buffers ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-buffers
      (let ((current (ghostel-dwim-test--make-buffer "current" dir)))
        (with-current-buffer current
          (should-error (ghostel-dwim-switch) :type 'user-error))))))

(ert-deftest ghostel-dwim-switch-errors-for-missing-target ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-buffers
      (let ((current (ghostel-dwim-test--make-buffer "current" dir)))
        (with-current-buffer current
          (should-error (ghostel-dwim-switch "missing-buffer")
                        :type 'user-error))))))

(ert-deftest ghostel-dwim-switch-errors-for-non-ghostel-target ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-buffers
      (let ((current (ghostel-dwim-test--make-buffer "current" dir))
            (plain (ghostel-dwim-test--make-buffer "plain" dir)))
        (with-current-buffer current
          (should-error (ghostel-dwim-switch plain)
                        :type 'user-error))))))

(ert-deftest ghostel-dwim-switch-errors-for-out-of-directory-target ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-temp-dir other-dir
      (ghostel-dwim-test--with-buffers
        (let ((current (ghostel-dwim-test--make-buffer "current" dir))
              (other (ghostel-dwim-test--make-buffer "ghostel-other"
                                                     other-dir t)))
          (with-current-buffer current
            (should-error (ghostel-dwim-switch other)
                          :type 'user-error)))))))

(ert-deftest ghostel-dwim-switch-displays-valid-target ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-buffers
      (let ((current (ghostel-dwim-test--make-buffer "current" dir))
            (target (ghostel-dwim-test--make-buffer "ghostel-target" dir t))
            displayed)
        (cl-letf (((symbol-function 'ghostel-dwim--display-buffer)
                   (lambda (buffer)
                     (setq displayed buffer)
                     buffer)))
          (with-current-buffer current
            (should (eq target (ghostel-dwim-switch target)))))
        (should (eq displayed target))))))

(ert-deftest ghostel-dwim-switch-interactive-candidates-are-scoped ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-temp-dir other-dir
      (ghostel-dwim-test--with-buffers
        (let ((current (ghostel-dwim-test--make-buffer "current" dir))
              (first (ghostel-dwim-test--make-buffer "ghostel-first" dir t))
              (second (ghostel-dwim-test--make-buffer "ghostel-second" dir t))
              (_other (ghostel-dwim-test--make-buffer "ghostel-other"
                                                      other-dir t))
              candidates
              displayed)
          (cl-letf (((symbol-function 'completing-read)
                     (lambda (_prompt collection &rest _)
                       (setq candidates collection)
                       (buffer-name second)))
                    ((symbol-function 'ghostel-dwim--display-buffer)
                     (lambda (buffer)
                       (setq displayed buffer)
                       buffer)))
            (with-current-buffer current
              (call-interactively #'ghostel-dwim-switch)))
          (should (equal (ghostel-dwim-test--buffer-names
                          (list first second))
                         (sort candidates #'string<)))
          (should (eq displayed second)))))))

(ert-deftest ghostel-dwim-switch-does-not-create-session ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-buffers
      (let ((current (ghostel-dwim-test--make-buffer "current" dir)))
        (cl-letf (((symbol-function 'ghostel)
                   (lambda (&rest _)
                     (error "ghostel should not be called")))
                  ((symbol-function 'ghostel-project)
                   (lambda (&rest _)
                     (error "ghostel-project should not be called"))))
          (with-current-buffer current
            (should-error (ghostel-dwim-switch)
                          :type 'user-error)))))))

(ert-deftest ghostel-dwim-open-requests-fresh-session-in-current-directory ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-buffers
      (let ((current (ghostel-dwim-test--make-buffer "current" dir))
            call-arg
            call-directory)
        (cl-letf (((symbol-function 'ghostel)
                   (lambda (&optional arg)
                     (setq call-arg arg)
                     (setq call-directory default-directory)
                     'created)))
          (with-current-buffer current
            (should (eq 'created (ghostel-dwim-open)))))
        (should (eq call-arg t))
        (should (equal call-directory dir))))))

(ert-deftest ghostel-dwim-open-repeatedly-requests-fresh-session ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-buffers
      (let ((current (ghostel-dwim-test--make-buffer "current" dir))
            calls)
        (cl-letf (((symbol-function 'ghostel)
                   (lambda (&optional arg)
                     (push arg calls)
                     'created)))
          (with-current-buffer current
            (ghostel-dwim-open)
            (ghostel-dwim-open)))
        (should (equal calls '(t t)))))))

(ert-deftest ghostel-dwim-open-preserves-unknown-command-state ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-buffers
      (let* ((current (ghostel-dwim-test--make-buffer "current" dir))
             (created (ghostel-dwim-test--make-ghostel-session
                       "ghostel-created-directory" dir nil 'live)))
        (cl-letf (((symbol-function 'ghostel)
                   (lambda (&optional _arg)
                     created)))
          (with-current-buffer current
            (should (eq created (ghostel-dwim-open)))))
        (should-not (buffer-local-value 'ghostel-dwim--command-state
                                        created))
        (should-not (ghostel-dwim-idle-p created))))))

(ert-deftest ghostel-dwim-open-other-window-expresses-display-intent ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-buffers
      (let ((current (ghostel-dwim-test--make-buffer "current" dir))
            call-arg
            call-directory
            display-action)
        (cl-letf (((symbol-function 'ghostel)
                   (lambda (&optional arg)
                     (setq call-arg arg)
                     (setq call-directory default-directory)
                     (setq display-action display-buffer-overriding-action)
                     'created)))
          (with-current-buffer current
            (should (eq 'created (ghostel-dwim-open-other-window)))))
        (should (eq call-arg t))
        (should (equal call-directory dir))
        (should (equal display-action
                       ghostel-dwim--other-window-action))))))

(ert-deftest ghostel-dwim-reuses-idle-directory-session ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-buffers
      (let ((current (ghostel-dwim-test--make-buffer "current" dir))
            (target (ghostel-dwim-test--make-ghostel-session
                     "ghostel-idle-directory" dir 'idle 'live))
            opened
            displayed)
        (cl-letf (((symbol-function 'ghostel-dwim-open)
                   (lambda ()
                     (setq opened t)
                     'opened))
                  ((symbol-function 'ghostel-dwim--display-buffer)
                   (lambda (buffer)
                     (setq displayed buffer)
                     buffer)))
          (with-current-buffer current
            (should (eq target (ghostel-dwim)))))
        (should (eq displayed target))
        (should-not opened)))))

(ert-deftest ghostel-dwim-creates-directory-session-with-no-candidates ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-buffers
      (let ((current (ghostel-dwim-test--make-buffer "current" dir))
            opened)
        (cl-letf (((symbol-function 'ghostel-dwim-open)
                   (lambda ()
                     (setq opened t)
                     'opened))
                  ((symbol-function 'ghostel-dwim--display-buffer)
                   (lambda (&rest _)
                     (error "No buffer should be displayed"))))
          (with-current-buffer current
            (should (eq 'opened (ghostel-dwim)))))
        (should opened)))))

(ert-deftest ghostel-dwim-does-not-reuse-unknown-directory-session ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-buffers
      (let ((current (ghostel-dwim-test--make-buffer "current" dir))
            (_unknown (ghostel-dwim-test--make-ghostel-session
                       "ghostel-unknown-directory" dir nil 'live))
            opened
            displayed)
        (cl-letf (((symbol-function 'ghostel-dwim-open)
                   (lambda ()
                     (setq opened t)
                     'opened))
                  ((symbol-function 'ghostel-dwim--display-buffer)
                   (lambda (buffer)
                     (setq displayed buffer)
                     buffer)))
          (with-current-buffer current
            (should (eq 'opened (ghostel-dwim)))))
        (should opened)
        (should-not displayed)))))

(ert-deftest ghostel-dwim-skips-running-directory-session ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-buffers
      (let* ((current (ghostel-dwim-test--make-buffer "current" dir))
             (running (ghostel-dwim-test--make-ghostel-session
                       "ghostel-running-directory" dir 'running 'live))
             (process (buffer-local-value 'ghostel--process running))
             opened
             displayed)
        (cl-letf (((symbol-function 'ghostel-dwim-open)
                   (lambda ()
                     (setq opened t)
                     'opened))
                  ((symbol-function 'ghostel-dwim--display-buffer)
                   (lambda (buffer)
                     (setq displayed buffer)
                     buffer)))
          (with-current-buffer current
            (should (eq 'opened (ghostel-dwim)))))
        (should opened)
        (should-not displayed)
        (should (process-live-p process))
        (should (eq (buffer-local-value 'ghostel-dwim--command-state
                                        running)
                    'running))))))

(ert-deftest ghostel-dwim-reuses-idle-directory-before-creating ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-buffers
      (let ((current (ghostel-dwim-test--make-buffer "current" dir))
            (_running (ghostel-dwim-test--make-ghostel-session
                       "ghostel-running-directory" dir 'running 'live))
            (idle (ghostel-dwim-test--make-ghostel-session
                   "ghostel-idle-directory" dir 'idle 'live))
            opened
            displayed)
        (cl-letf (((symbol-function 'ghostel-dwim-open)
                   (lambda ()
                     (setq opened t)
                     'opened))
                  ((symbol-function 'ghostel-dwim--display-buffer)
                   (lambda (buffer)
                     (setq displayed buffer)
                     buffer)))
          (with-current-buffer current
            (should (eq idle (ghostel-dwim)))))
        (should (eq displayed idle))
        (should-not opened)))))

(ert-deftest ghostel-dwim-does-not-reuse-other-directory-session ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-temp-dir other-dir
      (ghostel-dwim-test--with-buffers
        (let ((current (ghostel-dwim-test--make-buffer "current" dir))
              (_other (ghostel-dwim-test--make-ghostel-session
                       "ghostel-other-directory" other-dir 'idle 'live))
              opened)
          (cl-letf (((symbol-function 'ghostel-dwim-open)
                     (lambda ()
                       (setq opened t)
                       'opened))
                    ((symbol-function 'ghostel-dwim--display-buffer)
                     (lambda (&rest _)
                       (error "Other directory should not be displayed"))))
            (with-current-buffer current
              (should (eq 'opened (ghostel-dwim)))))
          (should opened))))))

(ert-deftest ghostel-dwim-uses-first-idle-directory-candidate ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-buffers
      (let ((current (ghostel-dwim-test--make-buffer "current" dir))
            (first (ghostel-dwim-test--make-ghostel-session
                    "ghostel-first-idle" dir 'idle 'live))
            (second (ghostel-dwim-test--make-ghostel-session
                     "ghostel-second-idle" dir 'idle 'live))
            displayed)
        (cl-letf (((symbol-function 'ghostel-dwim-directory-buffers)
                   (lambda ()
                     (list first second)))
                  ((symbol-function 'ghostel-dwim-open)
                   (lambda ()
                     (error "ghostel-dwim-open should not be called")))
                  ((symbol-function 'ghostel-dwim--display-buffer)
                   (lambda (buffer)
                     (setq displayed buffer)
                     buffer))
                  ((symbol-function 'completing-read)
                   (lambda (&rest _)
                     (error "completing-read should not be called"))))
          (with-current-buffer current
            (should (eq first (ghostel-dwim)))))
        (should (eq displayed first))
        (should-not (eq displayed second))))))

(ert-deftest ghostel-dwim-project-buffers-includes-current-project ()
  (ghostel-dwim-test--with-project project-dir
    (ghostel-dwim-test--with-buffers
      (let ((current (ghostel-dwim-test--make-buffer "current"
                                                     project-dir))
            (ghostel-buffer
             (ghostel-dwim-test--make-buffer "ghostel-project"
                                             project-dir t)))
        (with-current-buffer current
          (should (memq ghostel-buffer
                        (ghostel-dwim-project-buffers))))))))

(ert-deftest ghostel-dwim-project-buffers-excludes-other-project ()
  (ghostel-dwim-test--with-project project-dir
    (ghostel-dwim-test--with-project other-project-dir
      (ghostel-dwim-test--with-buffers
        (let ((current (ghostel-dwim-test--make-buffer "current"
                                                       project-dir))
              (other (ghostel-dwim-test--make-buffer "ghostel-other-project"
                                                     other-project-dir t)))
          (with-current-buffer current
            (should-not (memq other
                              (ghostel-dwim-project-buffers)))))))))

(ert-deftest ghostel-dwim-project-buffers-excludes-non-ghostel-buffer ()
  (ghostel-dwim-test--with-project project-dir
    (ghostel-dwim-test--with-buffers
      (let ((current (ghostel-dwim-test--make-buffer "current"
                                                     project-dir))
            (plain (ghostel-dwim-test--make-buffer "plain-project"
                                                   project-dir)))
        (with-current-buffer current
          (should-not (memq plain
                            (ghostel-dwim-project-buffers))))))))

(ert-deftest ghostel-dwim-project-buffers-errors-with-no-project ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-buffers
      (let ((current (ghostel-dwim-test--make-buffer "current" dir)))
        (ghostel-dwim-test--without-project
          (with-current-buffer current
            (should-error (ghostel-dwim-project-buffers)
                          :type 'user-error)))))))

(ert-deftest ghostel-dwim-project-buffers-ignores-buffer-rename ()
  (ghostel-dwim-test--with-project project-dir
    (ghostel-dwim-test--with-buffers
      (let ((current (ghostel-dwim-test--make-buffer "current"
                                                     project-dir))
            (ghostel-buffer
             (ghostel-dwim-test--make-buffer "ghostel-before-rename"
                                             project-dir t)))
        (with-current-buffer ghostel-buffer
          (rename-buffer "ghostel-after-rename"))
        (with-current-buffer current
          (should (memq ghostel-buffer
                        (ghostel-dwim-project-buffers))))))))

(ert-deftest ghostel-dwim-project-buffers-default-directory-scope ()
  (ghostel-dwim-test--with-project project-dir
    (ghostel-dwim-test--with-project other-project-dir
      (ghostel-dwim-test--with-buffers
        (let ((ghostel-project-buffer-scope 'default-directory)
              (current (ghostel-dwim-test--make-buffer "current"
                                                       project-dir))
              (inside (ghostel-dwim-test--make-buffer "ghostel-inside"
                                                      project-dir t))
              (outside (ghostel-dwim-test--make-buffer "ghostel-outside"
                                                       other-project-dir t)))
          (with-current-buffer current
            (let ((buffers (ghostel-dwim-project-buffers)))
              (should (memq inside buffers))
              (should-not (memq outside buffers)))))))))

(ert-deftest ghostel-dwim-project-buffers-identity-scope ()
  (ghostel-dwim-test--with-project project-dir
    (ghostel-dwim-test--with-project other-project-dir
      (ghostel-dwim-test--with-buffers
        (let* ((ghostel-project-buffer-scope 'identity)
               (current (ghostel-dwim-test--make-buffer "current"
                                                        project-dir))
               (identity
                (with-current-buffer current
                  (ghostel-dwim-test--current-project-identity)))
               (identity-match
                (ghostel-dwim-test--make-buffer "ghostel-identity-match"
                                                other-project-dir t))
               (directory-only
                (ghostel-dwim-test--make-buffer "ghostel-directory-only"
                                                project-dir t)))
          (with-current-buffer identity-match
            (setq-local ghostel--buffer-identity identity))
          (with-current-buffer directory-only
            (setq-local ghostel--buffer-identity "other-project-identity"))
          (with-current-buffer current
            (let ((buffers (ghostel-dwim-project-buffers)))
              (should (memq identity-match buffers))
              (should-not (memq directory-only buffers)))))))))

(ert-deftest ghostel-dwim-project-buffers-both-scope ()
  (ghostel-dwim-test--with-project project-dir
    (ghostel-dwim-test--with-project other-project-dir
      (ghostel-dwim-test--with-buffers
        (let* ((ghostel-project-buffer-scope 'both)
               (current (ghostel-dwim-test--make-buffer "current"
                                                        project-dir))
               (identity
                (with-current-buffer current
                  (ghostel-dwim-test--current-project-identity)))
               (directory-match
                (ghostel-dwim-test--make-buffer "ghostel-directory-match"
                                                project-dir t))
               (identity-match
                (ghostel-dwim-test--make-buffer "ghostel-identity-match"
                                                other-project-dir t))
               (both-match
                (ghostel-dwim-test--make-buffer "ghostel-both-match"
                                                project-dir t)))
          (with-current-buffer identity-match
            (setq-local ghostel--buffer-identity identity))
          (with-current-buffer both-match
            (setq-local ghostel--buffer-identity identity))
          (with-current-buffer current
            (let ((buffers (ghostel-dwim-project-buffers)))
              (should (memq directory-match buffers))
              (should (memq identity-match buffers))
              (should (memq both-match buffers))
              (should (= (length buffers)
                         (length (delete-dups (copy-sequence buffers))))))))))))

(ert-deftest ghostel-dwim-project-buffers-avoids-extra-side-effects ()
  (ghostel-dwim-test--with-project project-dir
    (ghostel-dwim-test--with-buffers
      (let ((current (ghostel-dwim-test--make-buffer "current"
                                                     project-dir)))
        (ghostel-dwim-test--make-buffer "ghostel-current" project-dir t)
        (with-current-buffer current
          (cl-letf (((symbol-function 'shell-command)
                     (lambda (&rest _)
                       (error "shell-command should not be called"))))
            (should (= 1 (length (ghostel-dwim-project-buffers))))))))))

(ert-deftest ghostel-dwim-project-switch-errors-with-no-project-buffers ()
  (ghostel-dwim-test--with-project project-dir
    (ghostel-dwim-test--with-buffers
      (let ((current (ghostel-dwim-test--make-buffer "current"
                                                     project-dir)))
        (with-current-buffer current
          (should-error (ghostel-dwim-project-switch)
                        :type 'user-error))))))

(ert-deftest ghostel-dwim-project-switch-errors-with-no-project ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-buffers
      (let ((current (ghostel-dwim-test--make-buffer "current" dir)))
        (ghostel-dwim-test--without-project
          (with-current-buffer current
            (should-error (ghostel-dwim-project-switch)
                          :type 'user-error)))))))

(ert-deftest ghostel-dwim-project-switch-errors-for-missing-target ()
  (ghostel-dwim-test--with-project project-dir
    (ghostel-dwim-test--with-buffers
      (let ((current (ghostel-dwim-test--make-buffer "current"
                                                     project-dir)))
        (with-current-buffer current
          (should-error (ghostel-dwim-project-switch "missing-buffer")
                        :type 'user-error))))))

(ert-deftest ghostel-dwim-project-switch-errors-for-non-ghostel-target ()
  (ghostel-dwim-test--with-project project-dir
    (ghostel-dwim-test--with-buffers
      (let ((current (ghostel-dwim-test--make-buffer "current"
                                                     project-dir))
            (plain (ghostel-dwim-test--make-buffer "plain" project-dir)))
        (with-current-buffer current
          (should-error (ghostel-dwim-project-switch plain)
                        :type 'user-error))))))

(ert-deftest ghostel-dwim-project-switch-errors-for-out-of-project-target ()
  (ghostel-dwim-test--with-project project-dir
    (ghostel-dwim-test--with-project other-project-dir
      (ghostel-dwim-test--with-buffers
        (let ((current (ghostel-dwim-test--make-buffer "current"
                                                       project-dir))
              (other (ghostel-dwim-test--make-buffer "ghostel-other"
                                                     other-project-dir t)))
          (with-current-buffer current
            (should-error (ghostel-dwim-project-switch other)
                          :type 'user-error)))))))

(ert-deftest ghostel-dwim-project-switch-displays-valid-target ()
  (ghostel-dwim-test--with-project project-dir
    (ghostel-dwim-test--with-buffers
      (let ((current (ghostel-dwim-test--make-buffer "current"
                                                     project-dir))
            (target (ghostel-dwim-test--make-buffer "ghostel-target"
                                                    project-dir t))
            displayed)
        (cl-letf (((symbol-function 'ghostel-dwim--display-buffer)
                   (lambda (buffer)
                     (setq displayed buffer)
                     buffer)))
          (with-current-buffer current
            (should (eq target
                        (ghostel-dwim-project-switch target)))))
        (should (eq displayed target))))))

(ert-deftest ghostel-dwim-project-switch-interactive-candidates-are-scoped ()
  (ghostel-dwim-test--with-project project-dir
    (ghostel-dwim-test--with-project other-project-dir
      (ghostel-dwim-test--with-buffers
        (let ((current (ghostel-dwim-test--make-buffer "current"
                                                       project-dir))
              (first (ghostel-dwim-test--make-buffer "ghostel-first"
                                                     project-dir t))
              (second (ghostel-dwim-test--make-buffer "ghostel-second"
                                                      project-dir t))
              (_other (ghostel-dwim-test--make-buffer "ghostel-other"
                                                      other-project-dir t))
              candidates
              displayed)
          (cl-letf (((symbol-function 'completing-read)
                     (lambda (_prompt collection &rest _)
                       (setq candidates collection)
                       (buffer-name second)))
                    ((symbol-function 'ghostel-dwim--display-buffer)
                     (lambda (buffer)
                       (setq displayed buffer)
                       buffer)))
            (with-current-buffer current
              (call-interactively #'ghostel-dwim-project-switch)))
          (should (equal (ghostel-dwim-test--buffer-names
                          (list first second))
                         (sort candidates #'string<)))
          (should (eq displayed second)))))))

(ert-deftest ghostel-dwim-project-switch-explicit-target-with-no-project ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-buffers
      (let ((current (ghostel-dwim-test--make-buffer "current" dir))
            (target (ghostel-dwim-test--make-buffer "ghostel-target"
                                                    dir t)))
        (ghostel-dwim-test--without-project
          (with-current-buffer current
            (should-error (ghostel-dwim-project-switch target)
                          :type 'user-error)))))))

(ert-deftest ghostel-dwim-project-switch-does-not-create-session ()
  (ghostel-dwim-test--with-project project-dir
    (ghostel-dwim-test--with-buffers
      (let ((current (ghostel-dwim-test--make-buffer "current"
                                                     project-dir)))
        (cl-letf (((symbol-function 'ghostel)
                   (lambda (&rest _)
                     (error "ghostel should not be called")))
                  ((symbol-function 'ghostel-project)
                   (lambda (&rest _)
                     (error "ghostel-project should not be called"))))
          (with-current-buffer current
            (should-error (ghostel-dwim-project-switch)
                          :type 'user-error)))))))

(ert-deftest ghostel-dwim-project-open-requests-fresh-session-at-root ()
  (ghostel-dwim-test--with-project project-dir
    (ghostel-dwim-test--with-buffers
      (let* ((subdir (ghostel-dwim-test--make-subdir project-dir "src"))
             (current (ghostel-dwim-test--make-buffer "current" subdir))
             (expected-name
              (with-current-buffer current
                (ghostel-dwim-test--current-project-identity)))
             call-arg
             call-directory
             call-name)
        (cl-letf (((symbol-function 'ghostel)
                   (lambda (&optional arg)
                     (setq call-arg arg)
                     (setq call-directory default-directory)
                     (setq call-name ghostel-buffer-name)
                     'created)))
          (with-current-buffer current
            (should (eq 'created (ghostel-dwim-project-open)))))
        (should (eq call-arg t))
        (should (equal call-directory project-dir))
        (should (equal call-name expected-name))))))

(ert-deftest ghostel-dwim-project-open-repeatedly-requests-fresh-session ()
  (ghostel-dwim-test--with-project project-dir
    (ghostel-dwim-test--with-buffers
      (let ((current (ghostel-dwim-test--make-buffer "current"
                                                     project-dir))
            calls)
        (cl-letf (((symbol-function 'ghostel)
                   (lambda (&optional arg)
                     (push arg calls)
                     'created)))
          (with-current-buffer current
            (ghostel-dwim-project-open)
            (ghostel-dwim-project-open)))
        (should (equal calls '(t t)))))))

(ert-deftest ghostel-dwim-project-open-preserves-unknown-command-state ()
  (ghostel-dwim-test--with-project project-dir
    (ghostel-dwim-test--with-buffers
      (let* ((current (ghostel-dwim-test--make-buffer "current"
                                                      project-dir))
             (created (ghostel-dwim-test--make-ghostel-session
                       "ghostel-created-project"
                       project-dir nil 'live)))
        (cl-letf (((symbol-function 'ghostel)
                   (lambda (&optional _arg)
                     created)))
          (with-current-buffer current
            (should (eq created (ghostel-dwim-project-open)))))
        (should-not (buffer-local-value 'ghostel-dwim--command-state
                                        created))
        (should-not (ghostel-dwim-idle-p created))))))

(ert-deftest ghostel-dwim-project-open-errors-with-no-project ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-buffers
      (let ((current (ghostel-dwim-test--make-buffer "current" dir)))
        (ghostel-dwim-test--without-project
          (with-current-buffer current
            (should-error (ghostel-dwim-project-open)
                          :type 'user-error)))))))

(ert-deftest ghostel-dwim-project-open-other-window-expresses-display-intent ()
  (ghostel-dwim-test--with-project project-dir
    (ghostel-dwim-test--with-buffers
      (let* ((subdir (ghostel-dwim-test--make-subdir project-dir "src"))
             (current (ghostel-dwim-test--make-buffer "current" subdir))
             call-arg
             call-directory
             display-action)
        (cl-letf (((symbol-function 'ghostel)
                   (lambda (&optional arg)
                     (setq call-arg arg)
                     (setq call-directory default-directory)
                     (setq display-action display-buffer-overriding-action)
                     'created)))
          (with-current-buffer current
            (should (eq 'created
                        (ghostel-dwim-project-open-other-window)))))
        (should (eq call-arg t))
        (should (equal call-directory project-dir))
        (should (equal display-action
                       ghostel-dwim--other-window-action))))))

(ert-deftest ghostel-dwim-project-open-other-window-errors-with-no-project ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-buffers
      (let ((current (ghostel-dwim-test--make-buffer "current" dir)))
        (ghostel-dwim-test--without-project
          (with-current-buffer current
            (should-error (ghostel-dwim-project-open-other-window)
                          :type 'user-error)))))))

(ert-deftest ghostel-dwim-project-reuses-idle-session ()
  (ghostel-dwim-test--with-project project-dir
    (ghostel-dwim-test--with-buffers
      (let ((current (ghostel-dwim-test--make-buffer "current"
                                                     project-dir))
            (target (ghostel-dwim-test--make-ghostel-session
                     "ghostel-idle-project" project-dir 'idle 'live))
            opened
            displayed)
        (cl-letf (((symbol-function 'ghostel-dwim-project-open)
                   (lambda ()
                     (setq opened t)
                     'opened))
                  ((symbol-function 'ghostel-dwim--display-buffer)
                   (lambda (buffer)
                     (setq displayed buffer)
                     buffer)))
          (with-current-buffer current
            (should (eq target (ghostel-dwim-project)))))
        (should (eq displayed target))
        (should-not opened)))))

(ert-deftest ghostel-dwim-project-creates-session-with-no-candidates ()
  (ghostel-dwim-test--with-project project-dir
    (ghostel-dwim-test--with-buffers
      (let ((current (ghostel-dwim-test--make-buffer "current"
                                                     project-dir))
            opened)
        (cl-letf (((symbol-function 'ghostel-dwim-project-open)
                   (lambda ()
                     (setq opened t)
                     'opened))
                  ((symbol-function 'ghostel-dwim--display-buffer)
                   (lambda (&rest _)
                     (error "No buffer should be displayed"))))
          (with-current-buffer current
            (should (eq 'opened (ghostel-dwim-project)))))
        (should opened)))))

(ert-deftest ghostel-dwim-project-does-not-reuse-unknown-session ()
  (ghostel-dwim-test--with-project project-dir
    (ghostel-dwim-test--with-buffers
      (let ((current (ghostel-dwim-test--make-buffer "current"
                                                     project-dir))
            (_unknown (ghostel-dwim-test--make-ghostel-session
                       "ghostel-unknown-project"
                       project-dir nil 'live))
            opened
            displayed)
        (cl-letf (((symbol-function 'ghostel-dwim-project-open)
                   (lambda ()
                     (setq opened t)
                     'opened))
                  ((symbol-function 'ghostel-dwim--display-buffer)
                   (lambda (buffer)
                     (setq displayed buffer)
                     buffer)))
          (with-current-buffer current
            (should (eq 'opened (ghostel-dwim-project)))))
        (should opened)
        (should-not displayed)))))

(ert-deftest ghostel-dwim-project-skips-running-session ()
  (ghostel-dwim-test--with-project project-dir
    (ghostel-dwim-test--with-buffers
      (let* ((current (ghostel-dwim-test--make-buffer "current"
                                                      project-dir))
             (running (ghostel-dwim-test--make-ghostel-session
                       "ghostel-running-project"
                       project-dir 'running 'live))
             (process (buffer-local-value 'ghostel--process running))
             opened
             displayed)
        (cl-letf (((symbol-function 'ghostel-dwim-project-open)
                   (lambda ()
                     (setq opened t)
                     'opened))
                  ((symbol-function 'ghostel-dwim--display-buffer)
                   (lambda (buffer)
                     (setq displayed buffer)
                     buffer)))
          (with-current-buffer current
            (should (eq 'opened (ghostel-dwim-project)))))
        (should opened)
        (should-not displayed)
        (should (process-live-p process))
        (should (eq (buffer-local-value 'ghostel-dwim--command-state
                                        running)
                    'running))))))

(ert-deftest ghostel-dwim-project-reuses-idle-before-creating ()
  (ghostel-dwim-test--with-project project-dir
    (ghostel-dwim-test--with-buffers
      (let ((current (ghostel-dwim-test--make-buffer "current"
                                                     project-dir))
            (_running (ghostel-dwim-test--make-ghostel-session
                       "ghostel-running-project"
                       project-dir 'running 'live))
            (idle (ghostel-dwim-test--make-ghostel-session
                   "ghostel-idle-project" project-dir 'idle 'live))
            opened
            displayed)
        (cl-letf (((symbol-function 'ghostel-dwim-project-open)
                   (lambda ()
                     (setq opened t)
                     'opened))
                  ((symbol-function 'ghostel-dwim--display-buffer)
                   (lambda (buffer)
                     (setq displayed buffer)
                     buffer)))
          (with-current-buffer current
            (should (eq idle (ghostel-dwim-project)))))
        (should (eq displayed idle))
        (should-not opened)))))

(ert-deftest ghostel-dwim-project-does-not-reuse-other-project-session ()
  (ghostel-dwim-test--with-project project-dir
    (ghostel-dwim-test--with-project other-project-dir
      (ghostel-dwim-test--with-buffers
        (let ((current (ghostel-dwim-test--make-buffer "current"
                                                       project-dir))
              (_other (ghostel-dwim-test--make-ghostel-session
                       "ghostel-other-project"
                       other-project-dir 'idle 'live))
              opened)
          (cl-letf (((symbol-function 'ghostel-dwim-project-open)
                     (lambda ()
                       (setq opened t)
                       'opened))
                    ((symbol-function 'ghostel-dwim--display-buffer)
                     (lambda (&rest _)
                       (error "Other project should not be displayed"))))
            (with-current-buffer current
              (should (eq 'opened (ghostel-dwim-project)))))
          (should opened))))))

(ert-deftest ghostel-dwim-project-errors-with-no-project ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-buffers
      (let ((current (ghostel-dwim-test--make-buffer "current" dir))
            opened)
        (ghostel-dwim-test--without-project
          (cl-letf (((symbol-function 'ghostel-dwim-project-open)
                     (lambda ()
                       (setq opened t)
                       'opened)))
            (with-current-buffer current
              (should-error (ghostel-dwim-project)
                            :type 'user-error))))
        (should-not opened)))))

(ert-deftest ghostel-dwim-project-uses-first-idle-candidate ()
  (ghostel-dwim-test--with-project project-dir
    (ghostel-dwim-test--with-buffers
      (let ((current (ghostel-dwim-test--make-buffer "current"
                                                     project-dir))
            (first (ghostel-dwim-test--make-ghostel-session
                    "ghostel-first-project-idle"
                    project-dir 'idle 'live))
            (second (ghostel-dwim-test--make-ghostel-session
                     "ghostel-second-project-idle"
                     project-dir 'idle 'live))
            displayed)
        (cl-letf (((symbol-function 'ghostel-dwim-project-buffers)
                   (lambda ()
                     (list first second)))
                  ((symbol-function 'ghostel-dwim-project-open)
                   (lambda ()
                     (error "ghostel-dwim-project-open should not be called")))
                  ((symbol-function 'ghostel-dwim--display-buffer)
                   (lambda (buffer)
                     (setq displayed buffer)
                     buffer))
                  ((symbol-function 'completing-read)
                   (lambda (&rest _)
                     (error "completing-read should not be called"))))
          (with-current-buffer current
            (should (eq first (ghostel-dwim-project)))))
        (should (eq displayed first))
        (should-not (eq displayed second))))))

(ert-deftest ghostel-dwim-clear-buffers-kills-directory-exited-only ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-temp-dir other-dir
      (ghostel-dwim-test--with-buffers
        (let ((current (ghostel-dwim-test--make-buffer "current" dir))
              (exited (ghostel-dwim-test--make-ghostel-session
                       "ghostel-exited-directory" dir nil))
              (live (ghostel-dwim-test--make-ghostel-session
                     "ghostel-live-directory" dir 'idle 'live))
              (other (ghostel-dwim-test--make-ghostel-session
                      "ghostel-other-exited-directory" other-dir nil))
              (plain (ghostel-dwim-test--make-buffer
                      "plain-exited-directory" dir)))
          (with-current-buffer current
            (should (= 1 (ghostel-dwim-clear-buffers))))
          (should-not (buffer-live-p exited))
          (should (buffer-live-p live))
          (should (buffer-live-p other))
          (should (buffer-live-p plain)))))))

(ert-deftest ghostel-dwim-clear-buffers-no-op-without-directory-exited ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-buffers
      (let ((current (ghostel-dwim-test--make-buffer "current" dir))
            (live (ghostel-dwim-test--make-ghostel-session
                   "ghostel-live-directory" dir 'idle 'live)))
        (cl-letf (((symbol-function 'ghostel)
                   (lambda (&rest _)
                     (error "ghostel should not be called")))
                  ((symbol-function 'ghostel-project)
                   (lambda (&rest _)
                     (error "ghostel-project should not be called"))))
          (with-current-buffer current
            (should (= 0 (ghostel-dwim-clear-buffers)))))
        (should (buffer-live-p live))))))

(ert-deftest ghostel-dwim-clear-idle-buffers-kills-directory-idle-only ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-temp-dir other-dir
      (ghostel-dwim-test--with-buffers
        (let ((current (ghostel-dwim-test--make-buffer "current" dir))
              (idle (ghostel-dwim-test--make-ghostel-session
                     "ghostel-idle-directory-cleanup" dir 'idle 'live))
              (running (ghostel-dwim-test--make-ghostel-session
                        "ghostel-running-directory-cleanup"
                        dir 'running 'live))
              (unknown (ghostel-dwim-test--make-ghostel-session
                        "ghostel-unknown-directory-cleanup" dir nil 'live))
              (exited (ghostel-dwim-test--make-ghostel-session
                       "ghostel-exited-directory-cleanup" dir nil))
              (other (ghostel-dwim-test--make-ghostel-session
                      "ghostel-other-idle-directory-cleanup"
                      other-dir 'idle 'live)))
          (ghostel-dwim-test--without-confirmation
            (with-current-buffer current
              (should (= 1 (ghostel-dwim-clear-idle-buffers)))))
          (should-not (buffer-live-p idle))
          (should (buffer-live-p running))
          (should (buffer-live-p unknown))
          (should (buffer-live-p exited))
          (should (buffer-live-p other)))))))

(ert-deftest ghostel-dwim-clear-idle-buffers-no-op-without-directory-idle ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-buffers
      (let ((current (ghostel-dwim-test--make-buffer "current" dir))
            (running (ghostel-dwim-test--make-ghostel-session
                      "ghostel-running-directory" dir 'running 'live)))
        (ghostel-dwim-test--without-confirmation
          (with-current-buffer current
            (should (= 0 (ghostel-dwim-clear-idle-buffers)))))
        (should (buffer-live-p running))))))

(ert-deftest ghostel-dwim-kill-buffers-kills-directory-without-prompt ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-temp-dir other-dir
      (ghostel-dwim-test--with-buffers
        (let ((current (ghostel-dwim-test--make-buffer "current" dir))
              (exited (ghostel-dwim-test--make-ghostel-session
                       "ghostel-exited-directory-kill" dir nil))
              (idle (ghostel-dwim-test--make-ghostel-session
                     "ghostel-idle-directory-kill" dir 'idle 'live))
              (other (ghostel-dwim-test--make-ghostel-session
                      "ghostel-other-directory-kill"
                      other-dir 'idle 'live)))
          (ghostel-dwim-test--without-confirmation
            (with-current-buffer current
              (should (= 2 (ghostel-dwim-kill-buffers)))))
          (should-not (buffer-live-p exited))
          (should-not (buffer-live-p idle))
          (should (buffer-live-p other)))))))

(ert-deftest ghostel-dwim-kill-buffers-prompts-on-running-once ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-buffers
      (let ((current (ghostel-dwim-test--make-buffer "current" dir))
            (running (ghostel-dwim-test--make-ghostel-session
                      "ghostel-running-directory-kill"
                      dir 'running 'live))
            (idle (ghostel-dwim-test--make-ghostel-session
                   "ghostel-idle-directory-kill" dir 'idle 'live)))
        (ghostel-dwim-test--with-confirmation t prompts
          (with-current-buffer current
            (should (= 2 (ghostel-dwim-kill-buffers))))
          (should (= 1 (length prompts))))
        (should-not (buffer-live-p running))
        (should-not (buffer-live-p idle))))))

(ert-deftest ghostel-dwim-kill-buffers-prompts-on-unknown-live ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-buffers
      (let ((current (ghostel-dwim-test--make-buffer "current" dir))
            (unknown (ghostel-dwim-test--make-ghostel-session
                      "ghostel-unknown-directory-kill" dir nil 'live)))
        (ghostel-dwim-test--with-confirmation t prompts
          (with-current-buffer current
            (should (= 1 (ghostel-dwim-kill-buffers))))
          (should (= 1 (length prompts))))
        (should-not (buffer-live-p unknown))))))

(ert-deftest ghostel-dwim-kill-buffers-decline-preserves-directory ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-buffers
      (let ((current (ghostel-dwim-test--make-buffer "current" dir))
            (running (ghostel-dwim-test--make-ghostel-session
                      "ghostel-running-directory-decline"
                      dir 'running 'live))
            (exited (ghostel-dwim-test--make-ghostel-session
                     "ghostel-exited-directory-decline" dir nil)))
        (ghostel-dwim-test--with-confirmation nil prompts
          (with-current-buffer current
            (should (= 0 (ghostel-dwim-kill-buffers))))
          (should (= 1 (length prompts))))
        (should (buffer-live-p running))
        (should (buffer-live-p exited))))))

(ert-deftest ghostel-dwim-kill-buffers-no-op-without-directory-buffers ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-buffers
      (let ((current (ghostel-dwim-test--make-buffer "current" dir)))
        (ghostel-dwim-test--without-confirmation
          (with-current-buffer current
            (should (= 0 (ghostel-dwim-kill-buffers)))))))))

(ert-deftest ghostel-dwim-project-clear-buffers-kills-exited-only ()
  (ghostel-dwim-test--with-project project-dir
    (ghostel-dwim-test--with-project other-project-dir
      (ghostel-dwim-test--with-buffers
        (let ((current (ghostel-dwim-test--make-buffer "current"
                                                       project-dir))
              (exited (ghostel-dwim-test--make-ghostel-session
                       "ghostel-exited-project" project-dir nil))
              (live (ghostel-dwim-test--make-ghostel-session
                     "ghostel-live-project" project-dir 'idle 'live))
              (other (ghostel-dwim-test--make-ghostel-session
                      "ghostel-other-exited-project" other-project-dir nil)))
          (with-current-buffer current
            (should (= 1 (ghostel-dwim-project-clear-buffers))))
          (should-not (buffer-live-p exited))
          (should (buffer-live-p live))
          (should (buffer-live-p other)))))))

(ert-deftest ghostel-dwim-project-clear-buffers-errors-with-no-project ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-buffers
      (let ((current (ghostel-dwim-test--make-buffer "current" dir))
            (exited (ghostel-dwim-test--make-ghostel-session
                     "ghostel-no-project-exited" dir nil)))
        (ghostel-dwim-test--without-project
          (with-current-buffer current
            (should-error (ghostel-dwim-project-clear-buffers)
                          :type 'user-error)))
        (should (buffer-live-p exited))))))

(ert-deftest ghostel-dwim-project-clear-idle-buffers-kills-idle-only ()
  (ghostel-dwim-test--with-project project-dir
    (ghostel-dwim-test--with-project other-project-dir
      (ghostel-dwim-test--with-buffers
        (let ((current (ghostel-dwim-test--make-buffer "current"
                                                       project-dir))
              (idle (ghostel-dwim-test--make-ghostel-session
                     "ghostel-idle-project-cleanup"
                     project-dir 'idle 'live))
              (running (ghostel-dwim-test--make-ghostel-session
                        "ghostel-running-project-cleanup"
                        project-dir 'running 'live))
              (unknown (ghostel-dwim-test--make-ghostel-session
                        "ghostel-unknown-project-cleanup"
                        project-dir nil 'live))
              (other (ghostel-dwim-test--make-ghostel-session
                      "ghostel-other-idle-project-cleanup"
                      other-project-dir 'idle 'live)))
          (ghostel-dwim-test--without-confirmation
            (with-current-buffer current
              (should (= 1 (ghostel-dwim-project-clear-idle-buffers)))))
          (should-not (buffer-live-p idle))
          (should (buffer-live-p running))
          (should (buffer-live-p unknown))
          (should (buffer-live-p other)))))))

(ert-deftest ghostel-dwim-project-clear-idle-buffers-errors-no-project ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-buffers
      (let ((current (ghostel-dwim-test--make-buffer "current" dir))
            (idle (ghostel-dwim-test--make-ghostel-session
                   "ghostel-no-project-idle" dir 'idle 'live)))
        (ghostel-dwim-test--without-project
          (with-current-buffer current
            (should-error (ghostel-dwim-project-clear-idle-buffers)
                          :type 'user-error)))
        (should (buffer-live-p idle))))))

(ert-deftest ghostel-dwim-project-kill-buffers-kills-without-prompt ()
  (ghostel-dwim-test--with-project project-dir
    (ghostel-dwim-test--with-project other-project-dir
      (ghostel-dwim-test--with-buffers
        (let ((current (ghostel-dwim-test--make-buffer "current"
                                                       project-dir))
              (exited (ghostel-dwim-test--make-ghostel-session
                       "ghostel-exited-project-kill" project-dir nil))
              (idle (ghostel-dwim-test--make-ghostel-session
                     "ghostel-idle-project-kill" project-dir 'idle 'live))
              (other (ghostel-dwim-test--make-ghostel-session
                      "ghostel-other-project-kill"
                      other-project-dir 'idle 'live)))
          (ghostel-dwim-test--without-confirmation
            (with-current-buffer current
              (should (= 2 (ghostel-dwim-project-kill-buffers)))))
          (should-not (buffer-live-p exited))
          (should-not (buffer-live-p idle))
          (should (buffer-live-p other)))))))

(ert-deftest ghostel-dwim-project-kill-buffers-prompts-on-running-once ()
  (ghostel-dwim-test--with-project project-dir
    (ghostel-dwim-test--with-buffers
      (let ((current (ghostel-dwim-test--make-buffer "current" project-dir))
            (running (ghostel-dwim-test--make-ghostel-session
                      "ghostel-running-project-kill"
                      project-dir 'running 'live))
            (idle (ghostel-dwim-test--make-ghostel-session
                   "ghostel-idle-project-kill" project-dir 'idle 'live)))
        (ghostel-dwim-test--with-confirmation t prompts
          (with-current-buffer current
            (should (= 2 (ghostel-dwim-project-kill-buffers))))
          (should (= 1 (length prompts))))
        (should-not (buffer-live-p running))
        (should-not (buffer-live-p idle))))))

(ert-deftest ghostel-dwim-project-kill-buffers-prompts-on-unknown-live ()
  (ghostel-dwim-test--with-project project-dir
    (ghostel-dwim-test--with-buffers
      (let ((current (ghostel-dwim-test--make-buffer "current" project-dir))
            (unknown (ghostel-dwim-test--make-ghostel-session
                      "ghostel-unknown-project-kill"
                      project-dir nil 'live)))
        (ghostel-dwim-test--with-confirmation t prompts
          (with-current-buffer current
            (should (= 1 (ghostel-dwim-project-kill-buffers))))
          (should (= 1 (length prompts))))
        (should-not (buffer-live-p unknown))))))

(ert-deftest ghostel-dwim-project-kill-buffers-decline-preserves-project ()
  (ghostel-dwim-test--with-project project-dir
    (ghostel-dwim-test--with-buffers
      (let ((current (ghostel-dwim-test--make-buffer "current" project-dir))
            (running (ghostel-dwim-test--make-ghostel-session
                      "ghostel-running-project-decline"
                      project-dir 'running 'live))
            (exited (ghostel-dwim-test--make-ghostel-session
                     "ghostel-exited-project-decline" project-dir nil)))
        (ghostel-dwim-test--with-confirmation nil prompts
          (with-current-buffer current
            (should (= 0 (ghostel-dwim-project-kill-buffers))))
          (should (= 1 (length prompts))))
        (should (buffer-live-p running))
        (should (buffer-live-p exited))))))

(ert-deftest ghostel-dwim-project-kill-buffers-errors-with-no-project ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-buffers
      (let ((current (ghostel-dwim-test--make-buffer "current" dir))
            (target (ghostel-dwim-test--make-ghostel-session
                     "ghostel-no-project-kill" dir nil)))
        (ghostel-dwim-test--without-project
          (with-current-buffer current
            (should-error (ghostel-dwim-project-kill-buffers)
                          :type 'user-error)))
        (should (buffer-live-p target))))))

(ert-deftest ghostel-dwim-cleanup-deletes-bottom-window-after-kill ()
  (ghostel-dwim-test--with-window-state
    (ghostel-dwim-test--with-temp-dir dir
      (ghostel-dwim-test--with-buffers
        (let* ((current (ghostel-dwim-test--make-buffer "current" dir))
               (target (ghostel-dwim-test--make-ghostel-session
                        "ghostel-bottom-cleanup" dir nil))
               (window (display-buffer-in-side-window
                        target '((side . bottom)))))
          (with-current-buffer current
            (should (= 1 (ghostel-dwim-clear-buffers))))
          (should-not (buffer-live-p target))
          (should-not (window-live-p window)))))))

(ert-deftest ghostel-dwim-cleanup-deletes-multiple-bottom-windows ()
  (ghostel-dwim-test--with-window-state
    (ghostel-dwim-test--with-temp-dir dir
      (ghostel-dwim-test--with-buffers
        (let* ((current (ghostel-dwim-test--make-buffer "current" dir))
               (target (ghostel-dwim-test--make-ghostel-session
                        "ghostel-multiple-bottom-cleanup" dir nil))
               (first (display-buffer-in-side-window
                       target '((side . bottom) (slot . 0))))
               (second (display-buffer-in-side-window
                        target '((side . bottom) (slot . 1)))))
          (with-current-buffer current
            (should (= 1 (ghostel-dwim-clear-buffers))))
          (should-not (buffer-live-p target))
          (should-not (window-live-p first))
          (should-not (window-live-p second)))))))

(ert-deftest ghostel-dwim-cleanup-preserves-ordinary-window ()
  (ghostel-dwim-test--with-window-state
    (ghostel-dwim-test--with-temp-dir dir
      (ghostel-dwim-test--with-buffers
        (let* ((current (ghostel-dwim-test--make-buffer "current" dir))
               (target (ghostel-dwim-test--make-ghostel-session
                        "ghostel-ordinary-window-cleanup" dir nil))
               (window (split-window-right)))
          (set-window-buffer window target)
          (with-current-buffer current
            (should (= 1 (ghostel-dwim-clear-buffers))))
          (should-not (buffer-live-p target))
          (should (window-live-p window)))))))

(ert-deftest ghostel-dwim-cleanup-preserves-non-bottom-side-window ()
  (ghostel-dwim-test--with-window-state
    (ghostel-dwim-test--with-temp-dir dir
      (ghostel-dwim-test--with-buffers
        (let* ((current (ghostel-dwim-test--make-buffer "current" dir))
               (target (ghostel-dwim-test--make-ghostel-session
                        "ghostel-right-side-window-cleanup" dir nil))
               (window (display-buffer-in-side-window
                        target '((side . right))))
               deleted)
          (cl-letf (((symbol-function 'ghostel-dwim--delete-bottom-windows)
                     (lambda (windows)
                       (setq deleted windows))))
            (with-current-buffer current
              (should (= 1 (ghostel-dwim-clear-buffers)))))
          (should-not (buffer-live-p target))
          (should-not (memq window deleted)))))))

(ert-deftest ghostel-dwim-cleanup-decline-preserves-bottom-window ()
  (ghostel-dwim-test--with-window-state
    (ghostel-dwim-test--with-temp-dir dir
      (ghostel-dwim-test--with-buffers
        (let* ((current (ghostel-dwim-test--make-buffer "current" dir))
               (target (ghostel-dwim-test--make-ghostel-session
                        "ghostel-bottom-decline" dir 'running 'live))
               (window (display-buffer-in-side-window
                        target '((side . bottom)))))
          (ghostel-dwim-test--with-confirmation nil prompts
            (with-current-buffer current
              (should (= 0 (ghostel-dwim-kill-buffers))))
            (should (= 1 (length prompts))))
          (should (buffer-live-p target))
          (should (window-live-p window)))))))

(ert-deftest ghostel-dwim-cleanup-does-not-create-sessions ()
  (ghostel-dwim-test--with-project project-dir
    (ghostel-dwim-test--with-buffers
      (let ((current (ghostel-dwim-test--make-buffer "current" project-dir))
            (directory-target (ghostel-dwim-test--make-ghostel-session
                               "ghostel-directory-no-create"
                               project-dir nil))
            (project-target (ghostel-dwim-test--make-ghostel-session
                             "ghostel-project-no-create"
                             project-dir nil)))
        (cl-letf (((symbol-function 'ghostel)
                   (lambda (&rest _)
                     (error "ghostel should not be called")))
                  ((symbol-function 'ghostel-project)
                   (lambda (&rest _)
                     (error "ghostel-project should not be called"))))
          (with-current-buffer current
            (should (= 2 (ghostel-dwim-clear-buffers)))))
        (should-not (buffer-live-p directory-target))
        (should-not (buffer-live-p project-target))))))

(ert-deftest ghostel-dwim-cleanup-avoids-shell-text-and-file-inspection ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-buffers
      (let ((current (ghostel-dwim-test--make-buffer "current" dir)))
        (ghostel-dwim-test--make-ghostel-session
         "ghostel-no-inspection-cleanup" dir nil)
        (cl-letf (((symbol-function 'buffer-substring)
                   (lambda (&rest _)
                     (error "buffer text should not be inspected")))
                  ((symbol-function 'buffer-substring-no-properties)
                   (lambda (&rest _)
                     (error "buffer text should not be inspected")))
                  ((symbol-function 'search-forward)
                   (lambda (&rest _)
                     (error "buffer text should not be searched")))
                  ((symbol-function 'shell-command)
                   (lambda (&rest _)
                     (error "shell-command should not be called")))
                  ((symbol-function 'insert-file-contents)
                   (lambda (&rest _)
                     (error "files should not be read"))))
          (with-current-buffer current
            (should (= 1 (ghostel-dwim-clear-buffers)))))))))

(ert-deftest ghostel-dwim-directory-cleanup-uses-discovery-results ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-temp-dir other-dir
      (ghostel-dwim-test--with-buffers
        (let ((current (ghostel-dwim-test--make-buffer "current" dir))
              (target (ghostel-dwim-test--make-ghostel-session
                       "ghostel-discovery-directory" other-dir nil))
              calls)
          (cl-letf (((symbol-function 'ghostel-dwim-directory-buffers)
                     (lambda ()
                       (setq calls (1+ (or calls 0)))
                       (list target))))
            (with-current-buffer current
              (should (= 1 (ghostel-dwim-clear-buffers)))))
          (should (= calls 1))
          (should-not (buffer-live-p target)))))))

(ert-deftest ghostel-dwim-project-cleanup-uses-discovery-results ()
  (ghostel-dwim-test--with-project project-dir
    (ghostel-dwim-test--with-project other-project-dir
      (ghostel-dwim-test--with-buffers
        (let ((current (ghostel-dwim-test--make-buffer "current"
                                                       project-dir))
              (target (ghostel-dwim-test--make-ghostel-session
                       "ghostel-discovery-project" other-project-dir nil))
              calls)
          (cl-letf (((symbol-function 'ghostel-dwim-project-buffers)
                     (lambda ()
                       (setq calls (1+ (or calls 0)))
                       (list target))))
            (with-current-buffer current
              (should (= 1 (ghostel-dwim-project-clear-buffers)))))
          (should (= calls 1))
          (should-not (buffer-live-p target)))))))

(provide 'ghostel-dwim-tests)

;;; ghostel-dwim-tests.el ends here
