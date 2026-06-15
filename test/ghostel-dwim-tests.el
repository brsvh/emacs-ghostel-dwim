;;; ghostel-dwim-tests.el --- Tests for ghostel-dwim -*- lexical-binding:t -*-

;; Copyright (C) 2026 Bingshan Chang

;; This file is not part of GNU Emacs.

;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'ghostel-dwim)

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

(provide 'ghostel-dwim-tests)

;;; ghostel-dwim-tests.el ends here
