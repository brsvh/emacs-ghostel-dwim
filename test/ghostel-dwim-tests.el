;;; ghostel-dwim-tests.el --- Tests for ghostel-dwim -*- lexical-binding:t -*-

;; Copyright (C) 2026 Bingshan Chang

;; This file is not part of GNU Emacs.

;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'ghostel-dwim)

(let ((project-list-path (make-temp-file "ghostel-dwim-projects-")))
  (delete-file project-list-path)
  (setq project-list-file project-list-path))

(when (boundp 'project--list)
  (setq project--list nil))

(defvar ghostel-dwim-test--buffers nil
  "Buffers created by the current ghostel-dwim test.")

(defmacro ghostel-dwim-test--with-buffers (&rest body)
  "Run BODY and kill buffers tracked by the test."
  (declare (indent 0))
  `(let (ghostel-dwim-test--buffers)
     (unwind-protect
         (progn ,@body)
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

(provide 'ghostel-dwim-tests)

;;; ghostel-dwim-tests.el ends here
