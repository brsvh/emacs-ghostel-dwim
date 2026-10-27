;;; ghostel-dwim-tests.el --- Tests -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Bingshan Chang

;; This file is not part of GNU Emacs.

;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'ghostel-dwim)

(defvar ghostel-dwim-test--buffers nil
  "Buffers created by the current ghostel-dwim test.")

(defvar ghostel-dwim-test--processes nil
  "Processes created by the current ghostel-dwim test.")

(defmacro ghostel-dwim-test--with-buffers (&rest body)
  "Run BODY and kill buffers tracked by the test."
  (declare (indent 0) (debug t))
  `(let (ghostel-dwim-test--buffers
         ghostel-dwim-test--processes)
     (unwind-protect
         (progn ,@body)
       (dolist (process ghostel-dwim-test--processes)
         (when (process-live-p process)
           (delete-process process)))
       (dolist (buffer ghostel-dwim-test--buffers)
         (when (buffer-live-p buffer)
           (with-current-buffer buffer
             (let ((kill-buffer-query-functions nil))
               (kill-buffer buffer))))))))

(defmacro ghostel-dwim-test--with-temp-dir (var &rest body)
  "Bind VAR to a temporary directory while running BODY."
  (declare (indent 1) (debug (symbolp body)))
  `(let ((,var (file-name-as-directory
                (make-temp-file "ghostel-dwim-test-" t))))
     (unwind-protect
         (progn ,@body)
       (when (file-directory-p ,var)
         (delete-directory ,var t)))))

(defmacro ghostel-dwim-test--with-project (var &rest body)
  "Bind VAR to a temporary project root while running BODY."
  (declare (indent 1) (debug (symbolp body)))
  `(ghostel-dwim-test--with-temp-dir ,var
     (make-directory (expand-file-name ".git" ,var))
     (let ((project-list-file (expand-file-name "projects" ,var))
           (project--list nil))
       ,@body)))

(defmacro ghostel-dwim-test--with-confirmation
    (result prompts-var &rest body)
  "Run BODY with cleanup confirmation returning RESULT.

Bind PROMPTS-VAR to the prompts received by the confirmation hook."
  (declare (indent 2) (debug (form symbolp body)))
  `(let* ((,prompts-var nil)
          (ghostel-dwim-confirm-kill-running-functions
           (list (lambda (prompt)
                   (push prompt ,prompts-var)
                   ,result))))
     ,@body))

(defmacro ghostel-dwim-test--without-confirmation (&rest body)
  "Run BODY and fail if cleanup confirmation is requested."
  (declare (indent 0) (debug t))
  `(let ((ghostel-dwim-confirm-kill-running-functions
          (list (lambda (&rest _)
                  (error "confirmation should not be requested")))))
     ,@body))

(defun ghostel-dwim-test--make-buffer
    (name directory &optional ghostel-p)
  "Create a test buffer named NAME in DIRECTORY.

When GHOSTEL-P is non-nil, put the buffer in `ghostel-mode'."
  (let ((buffer (generate-new-buffer name)))
    (push buffer ghostel-dwim-test--buffers)
    (with-current-buffer buffer
      (setq default-directory (file-name-as-directory directory))
      (when ghostel-p
        (ghostel-mode)))
    buffer))

(defun ghostel-dwim-test--make-process (&optional exited)
  "Create and track a process for Ghostel session tests.

When EXITED is non-nil, return a non-live process object."
  (let ((process (make-pipe-process :name "ghostel-dwim-test"
                                    :buffer (current-buffer)
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

(ert-deftest ghostel-dwim-idle-p-requires-idle-live-session ()
  (ghostel-dwim-test--with-buffers
    (dolist (case '((idle live t) (running live nil) (nil live nil)
                    (idle exited nil) (idle nil nil)))
      (ert-info ((format "%S" case))
        (let ((buffer (ghostel-dwim-test--make-ghostel-session
                       "ghostel-state" default-directory
                       (nth 0 case) (nth 1 case))))
          (dolist (target (list buffer (buffer-name buffer)))
            (should (eq (not (null (ghostel-dwim-idle-p target)))
                        (nth 2 case)))))))))

(ert-deftest ghostel-dwim-idle-p-rejects-non-session-buffers ()
  (ghostel-dwim-test--with-buffers
    (let* ((plain (ghostel-dwim-test--make-buffer
                   "plain" default-directory))
           (dead (ghostel-dwim-test--make-buffer
                  "ghostel-dead" default-directory t))
           (name (buffer-name dead)))
      (kill-buffer dead)
      (dolist (buffer (list plain dead name nil))
        (should-not (ghostel-dwim-idle-p buffer))))))

(ert-deftest ghostel-dwim-command-hooks-track-session-state ()
  (ghostel-dwim-test--with-buffers
    (let ((buffer (ghostel-dwim-test--make-ghostel-session
                   "ghostel-hooked" default-directory nil 'live)))
      (run-hook-with-args 'ghostel-command-finish-functions buffer 0)
      (should (ghostel-dwim-idle-p buffer))
      (run-hook-with-args 'ghostel-command-start-functions buffer)
      (should-not (ghostel-dwim-idle-p buffer))
      (should (eq (buffer-local-value 'ghostel-dwim--command-state
                                      buffer)
                  'running))
      (run-hook-with-args 'ghostel-command-finish-functions buffer 1)
      (should (ghostel-dwim-idle-p buffer)))))

(ert-deftest ghostel-dwim-unload-removes-command-hooks ()
  (unwind-protect
      (progn
        (unload-feature 'ghostel-dwim t)
        (should-not (featurep 'ghostel-dwim))
        (should-not (memq 'ghostel-dwim--command-start
                          ghostel-command-start-functions))
        (should-not (memq 'ghostel-dwim--command-finish
                          ghostel-command-finish-functions)))
    (require 'ghostel-dwim)))

(ert-deftest ghostel-dwim-directory-buffers-follow-directory ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-temp-dir other-dir
      (ghostel-dwim-test--with-buffers
        (let ((default-directory dir)
              (target (ghostel-dwim-test--make-buffer
                       "ghostel-local" dir t)))
          (ghostel-dwim-test--make-buffer "plain" dir)
          (ghostel-dwim-test--make-buffer "ghostel-other" other-dir t)
          (with-current-buffer target
            (setq default-directory (directory-file-name dir))
            (rename-buffer "renamed-terminal" t))
          (should (equal (ghostel-dwim-directory-buffers)
                         (list target)))
          (with-current-buffer target
            (setq default-directory other-dir))
          (should-not (ghostel-dwim-directory-buffers)))))))

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
                       (error
                        "file-directory-p should not be called")))
                    ((symbol-function 'project-current)
                     (lambda (&rest _)
                       (error
                        "project-current should not be called")))
                    ((symbol-function 'shell-command)
                     (lambda (&rest _)
                       (error "shell-command should not be called"))))
            (should (= 1
                       (length
                        (ghostel-dwim-directory-buffers))))))))))

(ert-deftest ghostel-dwim-project-buffers-use-native-discovery ()
  (ghostel-dwim-test--with-project dir
    (ghostel-dwim-test--with-temp-dir other-dir
      (ghostel-dwim-test--with-buffers
        (let* ((default-directory dir)
               (first (ghostel-dwim-test--make-buffer
                       "ghostel-first" other-dir t))
               (second (ghostel-dwim-test--make-buffer
                        "ghostel-second" dir t))
               (plain (ghostel-dwim-test--make-buffer "plain" dir))
               (dead (ghostel-dwim-test--make-buffer
                      "ghostel-dead" dir t))
               (candidates (list first plain dead second)))
          (kill-buffer dead)
          (dolist (public '(t nil))
            (let (called)
              (cl-letf (((symbol-function
                          'ghostel-project-buffer-list)
                         (and public
                              (lambda ()
                                (setq called 'public)
                                candidates)))
                        ((symbol-function 'ghostel--project-buffers)
                         (lambda ()
                           (setq called 'legacy)
                           candidates)))
                (should (equal (ghostel-dwim-project-buffers)
                               (list first second)))
                (should (eq called
                            (if public 'public 'legacy)))))))))))

(ert-deftest ghostel-dwim-project-buffers-default-directory-scope ()
  (ghostel-dwim-test--with-project project-dir
    (ghostel-dwim-test--with-project other-project-dir
      (ghostel-dwim-test--with-buffers
        (let ((ghostel-project-buffer-scope 'default-directory)
              (current (ghostel-dwim-test--make-buffer "current"
                                                       project-dir))
              (inside (ghostel-dwim-test--make-buffer "ghostel-inside"
                                                      project-dir t))
              (outside (ghostel-dwim-test--make-buffer
                        "ghostel-outside"
                        other-project-dir t)))
          (with-current-buffer current
            (let ((buffers (ghostel-dwim-project-buffers)))
              (should (memq inside buffers))
              (should-not (memq outside buffers)))))))))

(ert-deftest ghostel-dwim-switch-validates-targets ()
  (dolist (command '(ghostel-dwim-switch ghostel-dwim-project-switch))
    (ert-info ((format "%S" command))
      (ghostel-dwim-test--with-project dir
        (ghostel-dwim-test--with-project other-dir
          (ghostel-dwim-test--with-buffers
            (let* ((default-directory dir)
                   (plain (ghostel-dwim-test--make-buffer
                           "plain" dir))
                   (outside (ghostel-dwim-test--make-buffer
                             "ghostel-outside" other-dir t))
                   (dead (ghostel-dwim-test--make-buffer
                          "ghostel-dead" dir t))
                   (name (buffer-name dead)))
              (kill-buffer dead)
              (should-error (funcall command) :type 'user-error)
              (should-error (call-interactively command)
                            :type 'user-error)
              (dolist (target (list plain outside dead name))
                (should-error (funcall command target)
                              :type 'user-error))
              (let ((target (ghostel-dwim-test--make-buffer
                             "ghostel-target" dir t)))
                (save-window-excursion
                  (dolist (argument (list nil target
                                          (buffer-name target)))
                    (should (eq (funcall command argument) target))
                    (should (eq (window-buffer) target))))))))))))

(ert-deftest ghostel-dwim-switch-interactive-candidates-are-scoped ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-temp-dir other-dir
      (ghostel-dwim-test--with-buffers
        (let ((current (ghostel-dwim-test--make-buffer "current" dir))
              (first (ghostel-dwim-test--make-buffer
                      "ghostel-first" dir t))
              (second (ghostel-dwim-test--make-buffer
                       "ghostel-second" dir t))
              (_other (ghostel-dwim-test--make-buffer
                       "ghostel-other"
                       other-dir t))
              candidates
              displayed)
          (cl-letf (((symbol-function 'completing-read)
                     (lambda (_prompt collection &rest _)
                       (setq candidates collection)
                       (buffer-name second)))
                    ((symbol-function 'pop-to-buffer)
                     (lambda (buffer)
                       (setq displayed buffer)
                       buffer)))
            (with-current-buffer current
              (call-interactively #'ghostel-dwim-switch)))
          (should (equal (ghostel-dwim-test--buffer-names
                          (list first second))
                         (sort candidates #'string<)))
          (should (eq displayed second)))))))

(ert-deftest
    ghostel-dwim-project-switch-interactive-candidates-are-scoped ()
  (ghostel-dwim-test--with-project project-dir
    (ghostel-dwim-test--with-project other-project-dir
      (ghostel-dwim-test--with-buffers
        (let ((current (ghostel-dwim-test--make-buffer "current"
                                                       project-dir))
              (first (ghostel-dwim-test--make-buffer "ghostel-first"
                                                     project-dir t))
              (second (ghostel-dwim-test--make-buffer "ghostel-second"
                                                      project-dir t))
              (_other (ghostel-dwim-test--make-buffer
                       "ghostel-other"
                       other-project-dir t))
              candidates
              displayed)
          (cl-letf (((symbol-function 'completing-read)
                     (lambda (_prompt collection &rest _)
                       (setq candidates collection)
                       (buffer-name second)))
                    ((symbol-function 'pop-to-buffer)
                     (lambda (buffer)
                       (setq displayed buffer)
                       buffer)))
            (with-current-buffer current
              (call-interactively #'ghostel-dwim-project-switch)))
          (should (equal (ghostel-dwim-test--buffer-names
                          (list first second))
                         (sort candidates #'string<)))
          (should (eq displayed second)))))))

(ert-deftest ghostel-dwim-switch-rejects-vanished-selection ()
  (dolist (command '(ghostel-dwim-switch ghostel-dwim-project-switch))
    (ert-info ((format "%S" command))
      (ghostel-dwim-test--with-project dir
        (ghostel-dwim-test--with-buffers
          (let* ((default-directory dir)
                 (target (ghostel-dwim-test--make-buffer
                          "ghostel-vanishing" dir t))
                 (name (buffer-name target)))
            (ghostel-dwim-test--make-buffer "ghostel-remaining" dir t)
            (cl-letf (((symbol-function 'completing-read)
                       (lambda (&rest _)
                         (kill-buffer target)
                         name)))
              (should-error (call-interactively command)
                            :type 'user-error))))))))

(ert-deftest ghostel-dwim-open-delegates-fresh-sessions ()
  (ghostel-dwim-test--with-project dir
    (ghostel-dwim-test--with-buffers
      (let* ((default-directory
              (ghostel-dwim-test--make-subdir dir "src"))
             (created (ghostel-dwim-test--make-ghostel-session
                       "ghostel-created" dir nil 'live)))
        (dolist (case '((ghostel-dwim-open ghostel nil)
                        (ghostel-dwim-open-other-window ghostel t)
                        (ghostel-dwim-project-open
                         ghostel-project nil)
                        (ghostel-dwim-project-open-other-window
                         ghostel-project t)))
          (ert-info ((format "%S" (car case)))
            (let ((display-buffer-overriding-action nil)
                  called)
              (cl-letf (((symbol-function (nth 1 case))
                         (lambda (arg)
                           (setq called t)
                           (should (eq arg t))
                           (should (equal default-directory
                                          (expand-file-name
                                           "src/" dir)))
                           (let ((action
                                  (cdr
                                   display-buffer-overriding-action)))
                             (should (eq (alist-get
                                          'inhibit-same-window action)
                                         (nth 2 case))))
                           created)))
                (should (eq (funcall (car case)) created)))
              (should called)
              (should-not (ghostel-dwim-idle-p created)))))))))

(ert-deftest ghostel-dwim-uses-first-idle-directory-candidate ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-buffers
      (let ((current (ghostel-dwim-test--make-buffer "current" dir))
            (first (ghostel-dwim-test--make-ghostel-session
                    "ghostel-first-idle" dir 'idle 'live))
            (second (ghostel-dwim-test--make-ghostel-session
                     "ghostel-second-idle" dir 'idle 'live))
            (running (ghostel-dwim-test--make-ghostel-session
                      "ghostel-running" dir 'running 'live))
            (unknown (ghostel-dwim-test--make-ghostel-session
                      "ghostel-unknown" dir nil 'live))
            (exited (ghostel-dwim-test--make-ghostel-session
                     "ghostel-exited" dir 'idle 'exited))
            displayed)
        (cl-letf (((symbol-function 'ghostel-dwim-directory-buffers)
                   (lambda ()
                     (list running unknown exited first second)))
                  ((symbol-function 'ghostel-dwim-open)
                   (lambda ()
                     (error
                      "ghostel-dwim-open should not be called")))
                  ((symbol-function 'pop-to-buffer)
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

(ert-deftest
    ghostel-dwim-creates-directory-session-with-no-candidates ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-buffers
      (let ((current (ghostel-dwim-test--make-buffer "current" dir))
            opened)
        (cl-letf (((symbol-function 'ghostel-dwim-open)
                   (lambda ()
                     (setq opened t)
                     'opened))
                  ((symbol-function 'pop-to-buffer)
                   (lambda (&rest _)
                     (error "No buffer should be displayed"))))
          (with-current-buffer current
            (should (eq 'opened (ghostel-dwim)))))
        (should opened)))))

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
                  ((symbol-function 'pop-to-buffer)
                   (lambda (buffer)
                     (setq displayed buffer)
                     buffer)))
          (with-current-buffer current
            (should (eq target (ghostel-dwim-project)))))
        (should (eq displayed target))
        (should-not opened)))))

(ert-deftest
    ghostel-dwim-project-creates-session-with-no-candidates ()
  (ghostel-dwim-test--with-project project-dir
    (ghostel-dwim-test--with-buffers
      (let ((current (ghostel-dwim-test--make-buffer "current"
                                                     project-dir))
            opened)
        (cl-letf (((symbol-function 'ghostel-dwim-project-open)
                   (lambda ()
                     (setq opened t)
                     'opened))
                  ((symbol-function 'pop-to-buffer)
                   (lambda (&rest _)
                     (error "No buffer should be displayed"))))
          (with-current-buffer current
            (should (eq 'opened (ghostel-dwim-project)))))
        (should opened)))))

(ert-deftest ghostel-dwim-opens-for-non-idle-sessions ()
  (dolist (state '(nil running))
    (ghostel-dwim-test--with-temp-dir dir
      (ghostel-dwim-test--with-buffers
        (let* ((default-directory dir)
               (buffer (ghostel-dwim-test--make-ghostel-session
                        "ghostel-busy" dir state 'live))
               (process
                (buffer-local-value 'ghostel--process buffer)))
          (cl-letf (((symbol-function 'ghostel-dwim-open)
                     (lambda () 'opened)))
            (should (eq (ghostel-dwim) 'opened)))
          (should (process-live-p process))
          (should (eq (buffer-local-value 'ghostel-dwim--command-state
                                          buffer)
                      state)))))))

(ert-deftest ghostel-dwim-does-not-reuse-other-directory-session ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-temp-dir other-dir
      (ghostel-dwim-test--with-buffers
        (let ((current (ghostel-dwim-test--make-buffer "current" dir))
              (_other (ghostel-dwim-test--make-ghostel-session
                       "ghostel-other-directory"
                       other-dir 'idle 'live))
              opened)
          (cl-letf (((symbol-function 'ghostel-dwim-open)
                     (lambda ()
                       (setq opened t)
                       'opened))
                    ((symbol-function 'pop-to-buffer)
                     (lambda (&rest _)
                       (error
                        "Other directory should not be displayed"))))
            (with-current-buffer current
              (should (eq 'opened (ghostel-dwim)))))
          (should opened))))))

(ert-deftest
    ghostel-dwim-project-does-not-reuse-other-project-session ()
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
                    ((symbol-function 'pop-to-buffer)
                     (lambda (&rest _)
                       (error
                        "Other project should not be displayed"))))
            (with-current-buffer current
              (should (eq 'opened (ghostel-dwim-project)))))
          (should opened))))))

(ert-deftest ghostel-dwim-project-commands-require-project ()
  (ghostel-dwim-test--with-buffers
    (let ((target (ghostel-dwim-test--make-ghostel-session
                   "ghostel-no-project" default-directory 'idle
                   'live)))
      (cl-letf (((symbol-function 'project-current)
                 (lambda (&rest _) nil)))
        (dolist (command '(ghostel-dwim-project-buffers
                           ghostel-dwim-project-switch
                           ghostel-dwim-project-open
                           ghostel-dwim-project-open-other-window
                           ghostel-dwim-project
                           ghostel-dwim-project-clear-buffers
                           ghostel-dwim-project-clear-idle-buffers
                           ghostel-dwim-project-kill-buffers))
          (ert-info ((format "%S" command))
            (should-error (funcall command) :type 'user-error)))
        (should-error (ghostel-dwim-project-switch target)
                      :type 'user-error))
      (should (buffer-live-p target)))))

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

(ert-deftest
    ghostel-dwim-clear-idle-buffers-kills-directory-idle-only ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-temp-dir other-dir
      (ghostel-dwim-test--with-buffers
        (let ((current (ghostel-dwim-test--make-buffer "current" dir))
              (idle (ghostel-dwim-test--make-ghostel-session
                     "ghostel-idle-directory-cleanup"
                     dir 'idle 'live))
              (running (ghostel-dwim-test--make-ghostel-session
                        "ghostel-running-directory-cleanup"
                        dir 'running 'live))
              (unknown (ghostel-dwim-test--make-ghostel-session
                        "ghostel-unknown-directory-cleanup"
                        dir nil 'live))
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

(ert-deftest
    ghostel-dwim-kill-buffers-kills-directory-without-prompt ()
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
                      "ghostel-other-exited-project"
                      other-project-dir nil)))
          (with-current-buffer current
            (should (= 1 (ghostel-dwim-project-clear-buffers))))
          (should-not (buffer-live-p exited))
          (should (buffer-live-p live))
          (should (buffer-live-p other)))))))

(ert-deftest
    ghostel-dwim-project-clear-idle-buffers-kills-idle-only ()
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
              (should (= 1
                         (ghostel-dwim-project-clear-idle-buffers)))))
          (should-not (buffer-live-p idle))
          (should (buffer-live-p running))
          (should (buffer-live-p unknown))
          (should (buffer-live-p other)))))))

(ert-deftest ghostel-dwim-project-kill-buffers-kills-without-prompt ()
  (ghostel-dwim-test--with-project project-dir
    (ghostel-dwim-test--with-project other-project-dir
      (ghostel-dwim-test--with-buffers
        (let ((current (ghostel-dwim-test--make-buffer "current"
                                                       project-dir))
              (exited (ghostel-dwim-test--make-ghostel-session
                       "ghostel-exited-project-kill" project-dir nil))
              (idle (ghostel-dwim-test--make-ghostel-session
                     "ghostel-idle-project-kill"
                     project-dir 'idle 'live))
              (other (ghostel-dwim-test--make-ghostel-session
                      "ghostel-other-project-kill"
                      other-project-dir 'idle 'live)))
          (ghostel-dwim-test--without-confirmation
            (with-current-buffer current
              (should (= 2 (ghostel-dwim-project-kill-buffers)))))
          (should-not (buffer-live-p exited))
          (should-not (buffer-live-p idle))
          (should (buffer-live-p other)))))))

(ert-deftest ghostel-dwim-kill-buffers-confirms-live-risks-once ()
  (dolist (command '(ghostel-dwim-kill-buffers
                     ghostel-dwim-project-kill-buffers))
    (ghostel-dwim-test--with-project dir
      (ghostel-dwim-test--with-buffers
        (let* ((default-directory dir)
               (buffers
                (mapcar
                 (lambda (state)
                   (ghostel-dwim-test--make-ghostel-session
                    "ghostel-cleanup" dir state 'live))
                 '(idle running nil))))
          (dolist (buffer buffers)
            (with-current-buffer buffer
              (setq-local ghostel-query-before-killing t)
              (set-process-query-on-exit-flag ghostel--process t)))
          (let ((ghostel-dwim-confirm-kill-running-functions
                 '(yes-or-no-p))
                prompts)
            (cl-letf (((symbol-function 'yes-or-no-p)
                       (lambda (prompt) (push prompt prompts) t)))
              (with-current-buffer (car buffers)
                (should (= 3 (funcall command)))))
            (should (= 1 (length prompts)))
            (should (string-match-p "Kill 2 running or unknown"
                                    (car prompts))))
          (should-not (seq-some #'buffer-live-p buffers))
          (should-not (seq-some #'process-live-p
                                ghostel-dwim-test--processes)))))))

(ert-deftest ghostel-dwim-cleanup-with-no-candidates ()
  (ghostel-dwim-test--with-project dir
    (let ((default-directory dir))
      (ghostel-dwim-test--without-confirmation
        (dolist (command '(ghostel-dwim-clear-buffers
                           ghostel-dwim-clear-idle-buffers
                           ghostel-dwim-kill-buffers
                           ghostel-dwim-project-clear-buffers
                           ghostel-dwim-project-clear-idle-buffers
                           ghostel-dwim-project-kill-buffers))
          (ert-info ((format "%S" command))
            (should (= 0 (funcall command)))))))))

(ert-deftest ghostel-dwim-cleanup-deletes-multiple-bottom-windows ()
  (save-window-excursion
    (ghostel-dwim-test--with-temp-dir dir
      (ghostel-dwim-test--with-buffers
        (let* ((current (ghostel-dwim-test--make-buffer
                         "current" dir))
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
  (save-window-excursion
    (ghostel-dwim-test--with-temp-dir dir
      (ghostel-dwim-test--with-buffers
        (let* ((current (ghostel-dwim-test--make-buffer
                         "current" dir))
               (target (ghostel-dwim-test--make-ghostel-session
                        "ghostel-ordinary-window-cleanup" dir nil))
               (window (split-window-right)))
          (set-window-buffer window target)
          (with-current-buffer current
            (should (= 1 (ghostel-dwim-clear-buffers))))
          (should-not (buffer-live-p target))
          (should (window-live-p window)))))))

(ert-deftest ghostel-dwim-cleanup-preserves-non-bottom-side-window ()
  (save-window-excursion
    (ghostel-dwim-test--with-temp-dir dir
      (ghostel-dwim-test--with-buffers
        (let* ((current (ghostel-dwim-test--make-buffer
                         "current" dir))
               (target (ghostel-dwim-test--make-ghostel-session
                        "ghostel-right-side-window-cleanup" dir nil))
               (window (display-buffer-in-side-window
                        target '((side . right))))
               deleted)
          (cl-letf (((symbol-function
                      'ghostel-dwim--delete-bottom-windows)
                     (lambda (windows)
                       (setq deleted windows))))
            (with-current-buffer current
              (should (= 1 (ghostel-dwim-clear-buffers)))))
          (should-not (buffer-live-p target))
          (should-not (memq window deleted)))))))

(ert-deftest ghostel-dwim-cleanup-decline-preserves-bottom-window ()
  (save-window-excursion
    (ghostel-dwim-test--with-temp-dir dir
      (ghostel-dwim-test--with-buffers
        (let* ((current (ghostel-dwim-test--make-buffer
                         "current" dir))
               (target (ghostel-dwim-test--make-ghostel-session
                        "ghostel-bottom-decline" dir 'running 'live))
               (exited (ghostel-dwim-test--make-ghostel-session
                        "ghostel-exited-decline" dir nil))
               (window (display-buffer-in-side-window
                        target '((side . bottom)))))
          (ghostel-dwim-test--with-confirmation nil prompts
            (with-current-buffer current
              (should (= 0 (ghostel-dwim-kill-buffers))))
            (should (= 1 (length prompts))))
          (should (buffer-live-p target))
          (should (buffer-live-p exited))
          (should (window-live-p window)))))))

(ert-deftest ghostel-dwim-cleanup-honors-buffer-kill-veto ()
  (save-window-excursion
    (ghostel-dwim-test--with-temp-dir dir
      (ghostel-dwim-test--with-buffers
        (let* ((default-directory dir)
               (target (ghostel-dwim-test--make-ghostel-session
                        "ghostel-veto" dir 'idle 'live))
               (process (buffer-local-value 'ghostel--process target))
               (window (display-buffer-in-side-window
                        target '((side . bottom)))))
          (with-current-buffer target
            (setq-local ghostel-query-before-killing t)
            (set-process-query-on-exit-flag process t)
            (add-hook 'kill-buffer-query-functions
                      (lambda () nil) nil t))
          (cl-letf (((symbol-function 'yes-or-no-p)
                     (lambda (&rest _) (ert-fail "Duplicate query"))))
            (should (= 0 (ghostel-dwim-clear-idle-buffers))))
          (should (buffer-live-p target))
          (should (process-live-p process))
          (should (process-query-on-exit-flag process))
          (should (buffer-local-value 'ghostel-query-before-killing
                                      target))
          (should (window-live-p window))
          (should (eq (window-buffer window) target)))))))

(ert-deftest ghostel-dwim-cleanup-rechecks-idle-before-killing ()
  (ghostel-dwim-test--with-temp-dir dir
    (ghostel-dwim-test--with-buffers
      (let* ((default-directory dir)
             (first (ghostel-dwim-test--make-ghostel-session
                     "ghostel-first" dir 'idle 'live))
             (second (ghostel-dwim-test--make-ghostel-session
                      "ghostel-second" dir 'idle 'live)))
        (with-current-buffer first
          (add-hook 'kill-buffer-hook
                    (lambda ()
                      (ghostel-dwim--command-start second)) nil t))
        (cl-letf (((symbol-function 'ghostel-dwim-directory-buffers)
                   (lambda () (list first second))))
          (should (= 1 (ghostel-dwim-clear-idle-buffers))))
        (should-not (buffer-live-p first))
        (should (buffer-live-p second))
        (should-not (ghostel-dwim-idle-p second))))))

(provide 'ghostel-dwim-tests)
;;; ghostel-dwim-tests.el ends here
