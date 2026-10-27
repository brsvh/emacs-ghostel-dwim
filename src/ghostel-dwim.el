;;; ghostel-dwim.el --- Ghostel DWIM -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Bingshan Chang

;; Author: Bingshan Chang <chang@bingshan.org>
;; Keywords: extensions
;; Package-Requires: ((emacs "30.1") (ghostel "0.34.0"))
;; Version: 0.2.0

;; This file is not part of GNU Emacs.

;; This file is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published
;; by the Free Software Foundation, either version 3 of the License,
;; or (at your option) any later version.

;; This file is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this file.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; This library extends Ghostel with directory- and project-aware
;; session commands.  It provides helpers for finding, opening, and
;; switching to Ghostel terminal buffers associated with the current
;; `default-directory' or current `project.el' project.
;;
;; Directory membership is based on buffer-local `default-directory',
;; not buffer names, because Ghostel may rename buffers from terminal
;; title or directory updates.  The matching is intentionally light:
;; paths are expanded and normalized with trailing slashes, but
;; symlinks are not resolved and no project lookup or filesystem
;; probing is done.
;;
;; Project membership follows Ghostel's own project buffer semantics,
;; including `ghostel-project-buffer-scope', so `default-directory'
;; and project identity behave the same way as Ghostel's project
;; commands.
;;
;; These layers handle scoped discovery, explicit fresh opening,
;; scoped switching, DWIM reuse of idle sessions, and scoped cleanup
;; of Ghostel buffers.

;;; Code:

(require 'ghostel)
(require 'ghostel-project nil t)
(require 'project)
(require 'seq)

(declare-function ghostel--project-buffers "ghostel" ())
(declare-function ghostel-project-buffer-list "ghostel-project" ())

(defgroup ghostel-dwim nil
  "Directory- and project-aware Ghostel commands."
  :group 'tools
  :prefix "ghostel-dwim-")

(defvar ghostel-dwim--other-window-action
  '(nil . ((inhibit-same-window . t)))
  "Display action expressing intent to avoid the selected window.")

(defcustom ghostel-dwim-confirm-kill-running-functions
  '(yes-or-no-p)
  "Abnormal hook run before killing risky Ghostel buffers.

Each function is called with one PROMPT argument.  Cleanup
proceeds only when every function returns non-nil."
  :type 'hook
  :group 'ghostel-dwim)

(defvar-local ghostel-dwim--command-state nil
  "Known Ghostel command state for the current buffer.

The value is nil when command state is unknown, `idle' when the
session is known to be at a prompt, and `running' while Ghostel
has reported a foreground command running.")

(defun ghostel-dwim--normalize-directory (directory)
  "Return DIRECTORY as an expanded directory name."
  (file-name-as-directory (expand-file-name directory)))

(defun ghostel-dwim--ghostel-buffer-p (buffer)
  "Return non-nil when BUFFER is a live Ghostel buffer."
  (and (buffer-live-p buffer)
       (with-current-buffer buffer
         (derived-mode-p 'ghostel-mode))))

(defun ghostel-dwim--live-ghostel-process-p (buffer)
  "Return non-nil when live Ghostel BUFFER has a live process."
  (let ((process (buffer-local-value 'ghostel--process buffer)))
    (and (processp process) (process-live-p process))))

(defun ghostel-dwim--set-command-state (buffer state)
  "Set Ghostel DWIM command STATE for BUFFER when it is live."
  (when (ghostel-dwim--ghostel-buffer-p buffer)
    (with-current-buffer buffer
      (setq ghostel-dwim--command-state state))))

(defun ghostel-dwim--command-start (buffer)
  "Record that BUFFER has started a foreground command."
  (ghostel-dwim--set-command-state buffer 'running))

(defun ghostel-dwim--command-finish (buffer _exit-status)
  "Record that BUFFER has returned to an idle prompt."
  (ghostel-dwim--set-command-state buffer 'idle))

(defun ghostel-dwim-idle-p (buffer)
  "Return non-nil when BUFFER is a reusable idle Ghostel session.
BUFFER may be a buffer object or a buffer name."
  (let ((target (if (stringp buffer) (get-buffer buffer) buffer)))
    (and (ghostel-dwim--ghostel-buffer-p target)
         (ghostel-dwim--live-ghostel-process-p target)
         (eq (buffer-local-value 'ghostel-dwim--command-state target)
             'idle))))

(defun ghostel-dwim--live-risk-buffer-p (buffer)
  "Return non-nil when BUFFER requires kill confirmation."
  (and (ghostel-dwim--ghostel-buffer-p buffer)
       (ghostel-dwim--live-ghostel-process-p buffer)
       (not (eq (buffer-local-value
                 'ghostel-dwim--command-state buffer)
                'idle))))

(defun ghostel-dwim--exited-buffer-p (buffer)
  "Return non-nil when BUFFER is Ghostel without a live process."
  (and (ghostel-dwim--ghostel-buffer-p buffer)
       (not (ghostel-dwim--live-ghostel-process-p buffer))))

(defun ghostel-dwim--confirm-running-kill (scope buffers)
  "Return non-nil when risky BUFFERS in SCOPE may be killed."
  (let ((count (length buffers)))
    (run-hook-with-args-until-failure
     'ghostel-dwim-confirm-kill-running-functions
     (format (concat
              "Kill %d running or unknown live Ghostel buffer%s "
              "in current %s? ")
             count
             (if (= count 1) "" "s")
             scope))))

(defun ghostel-dwim--buffer-bottom-windows (buffer)
  "Return live bottom windows displaying BUFFER."
  (seq-filter
   (lambda (window)
     (eq (window-parameter window 'window-side) 'bottom))
   (get-buffer-window-list buffer nil t)))

(defun ghostel-dwim--delete-bottom-windows (windows)
  "Delete live bottom WINDOWS.

Ignore windows that cannot be deleted."
  (dolist (window windows)
    (when (and (window-live-p window)
               (eq (window-parameter window 'window-side) 'bottom))
      (ignore-errors
        (delete-window window)))))

(defun ghostel-dwim--kill-buffer (buffer)
  "Kill BUFFER and clean up bottom windows it displayed.

Return non-nil when BUFFER was live before the kill attempt and
is no longer live afterward."
  (when (buffer-live-p buffer)
    (let* ((windows (ghostel-dwim--buffer-bottom-windows buffer))
           (process (buffer-local-value 'ghostel--process buffer))
           (query (and (processp process)
                       (process-query-on-exit-flag process))))
      (unwind-protect
          (with-current-buffer buffer
            ;; Cleanup has already checked state and confirmation.
            (let ((ghostel-query-before-killing nil))
              (when (processp process)
                (set-process-query-on-exit-flag process nil))
              (kill-buffer buffer)))
        (when (and (processp process) (process-live-p process))
          (set-process-query-on-exit-flag process query)))
      (unless (buffer-live-p buffer)
        (ghostel-dwim--delete-bottom-windows windows)
        t))))

(defun ghostel-dwim--cleanup-buffers
    (buffers predicate &optional scope require-confirmation)
  "Kill BUFFERS matching PREDICATE and return the killed count.

SCOPE is used in confirmation prompts.  When REQUIRE-CONFIRMATION
is non-nil, prompt once before killing if any matching buffer is a
live-risk buffer."
  (let* ((candidates (seq-filter predicate buffers))
         (risks (and require-confirmation
                     (seq-filter #'ghostel-dwim--live-risk-buffer-p
                                 candidates))))
    (if (and risks
             (not (ghostel-dwim--confirm-running-kill
                   (or scope "scope")
                   risks)))
        0
      (let ((count 0))
        (dolist (buffer candidates count)
          (when (and (funcall predicate buffer)
                     (ghostel-dwim--kill-buffer buffer))
            (setq count (1+ count))))))))

(defun ghostel-dwim--read-buffer (prompt buffers empty-message)
  "Read a Ghostel buffer name with PROMPT from BUFFERS.

Signal `user-error' with EMPTY-MESSAGE when BUFFERS is nil."
  (unless buffers
    (user-error "%s" empty-message))
  (completing-read prompt (mapcar #'buffer-name buffers)
                   nil t nil nil (buffer-name (car buffers))))

(defun ghostel-dwim--require-buffer (buffer buffers &optional scope)
  "Return BUFFER from BUFFERS after SCOPE membership validation."
  (let ((target (get-buffer buffer)))
    (unless (buffer-live-p target)
      (user-error "Buffer %S does not exist" buffer))
    (unless (ghostel-dwim--ghostel-buffer-p target)
      (user-error "Buffer %s is not a Ghostel buffer"
                  (buffer-name target)))
    (unless (memq target buffers)
      (user-error "Buffer %s is not associated with the current %s"
                  (buffer-name target)
                  (or scope "directory")))
    target))

(defun ghostel-dwim--require-project ()
  "Return the current `project.el' project or signal `user-error'."
  (or (project-current nil)
      (user-error "Current buffer is not in a project")))

(defun ghostel-dwim--reuse-or-open (buffers open-function)
  "Display the first idle buffer in BUFFERS or call OPEN-FUNCTION."
  (let ((buffer (seq-find #'ghostel-dwim-idle-p buffers)))
    (if buffer
        (pop-to-buffer buffer)
      (funcall open-function))))

(defun ghostel-dwim-directory-buffers ()
  "Return Ghostel buffers associated with the current directory."
  (let ((directory
         (ghostel-dwim--normalize-directory default-directory))
        buffers)
    (dolist (buffer (buffer-list) (nreverse buffers))
      (when (and (ghostel-dwim--ghostel-buffer-p buffer)
                 (string= directory
                          (ghostel-dwim--normalize-directory
                           (buffer-local-value
                            'default-directory buffer))))
        (push buffer buffers)))))

(defun ghostel-dwim-project-buffers ()
  "Return Ghostel buffers associated with the current project.

Project membership follows Ghostel's own project buffer discovery,
including `ghostel-project-buffer-scope'."
  (ghostel-dwim--require-project)
  (seq-filter #'ghostel-dwim--ghostel-buffer-p
              (if (fboundp 'ghostel-project-buffer-list)
                  (ghostel-project-buffer-list)
                (ghostel--project-buffers))))

;;;###autoload
(defun ghostel-dwim-open ()
  "Start a fresh Ghostel session in the current directory."
  (interactive)
  (ghostel t))

;;;###autoload
(defun ghostel-dwim-open-other-window ()
  "Start a fresh Ghostel session while avoiding the selected window.

The concrete window placement remains controlled by Emacs display
rules such as `display-buffer-alist'."
  (interactive)
  (let ((display-buffer-overriding-action
         ghostel-dwim--other-window-action))
    (ghostel-dwim-open)))

;;;###autoload
(defun ghostel-dwim-project-open ()
  "Start a fresh Ghostel session in the current project root."
  (interactive)
  (ghostel-dwim--require-project)
  (ghostel-project t))

;;;###autoload
(defun ghostel-dwim ()
  "Reuse an idle Ghostel session in the current directory.

Start a fresh session when no reusable session exists."
  (interactive)
  (ghostel-dwim--reuse-or-open (ghostel-dwim-directory-buffers)
                               #'ghostel-dwim-open))

;;;###autoload
(defun ghostel-dwim-project ()
  "Reuse an idle Ghostel session in the current project or start one."
  (interactive)
  (ghostel-dwim--reuse-or-open (ghostel-dwim-project-buffers)
                               #'ghostel-dwim-project-open))

;;;###autoload
(defun ghostel-dwim-clear-buffers ()
  "Kill exited Ghostel buffers associated with the current directory."
  (interactive)
  (ghostel-dwim--cleanup-buffers
   (ghostel-dwim-directory-buffers)
   #'ghostel-dwim--exited-buffer-p
   "directory"))

;;;###autoload
(defun ghostel-dwim-clear-idle-buffers ()
  "Kill idle Ghostel buffers associated with the current directory."
  (interactive)
  (ghostel-dwim--cleanup-buffers
   (ghostel-dwim-directory-buffers)
   #'ghostel-dwim-idle-p
   "directory"))

;;;###autoload
(defun ghostel-dwim-kill-buffers ()
  "Kill all Ghostel buffers associated with the current directory."
  (interactive)
  (ghostel-dwim--cleanup-buffers
   (ghostel-dwim-directory-buffers)
   #'ghostel-dwim--ghostel-buffer-p
   "directory"
   t))

;;;###autoload
(defun ghostel-dwim-project-clear-buffers ()
  "Kill exited Ghostel buffers associated with the current project."
  (interactive)
  (ghostel-dwim--cleanup-buffers
   (ghostel-dwim-project-buffers)
   #'ghostel-dwim--exited-buffer-p
   "project"))

;;;###autoload
(defun ghostel-dwim-project-clear-idle-buffers ()
  "Kill idle Ghostel buffers associated with the current project."
  (interactive)
  (ghostel-dwim--cleanup-buffers
   (ghostel-dwim-project-buffers)
   #'ghostel-dwim-idle-p
   "project"))

;;;###autoload
(defun ghostel-dwim-project-kill-buffers ()
  "Kill all Ghostel buffers associated with the current project."
  (interactive)
  (ghostel-dwim--cleanup-buffers
   (ghostel-dwim-project-buffers)
   #'ghostel-dwim--ghostel-buffer-p
   "project"
   t))

;;;###autoload
(defun ghostel-dwim-project-open-other-window ()
  "Start a fresh project session while avoiding the selected window.

The concrete window placement remains controlled by Emacs display
rules such as `display-buffer-alist'."
  (interactive)
  (let ((display-buffer-overriding-action
         ghostel-dwim--other-window-action))
    (ghostel-dwim-project-open)))

;;;###autoload
(defun ghostel-dwim-switch (&optional buffer)
  "Switch to a Ghostel BUFFER associated with the current directory.

BUFFER, when non-nil, is the buffer object or buffer name to
validate and display.  Interactively, prompt among Ghostel buffers
associated with the current directory."
  (interactive
   (list
    (ghostel-dwim--read-buffer
     "Switch to Ghostel buffer: "
     (ghostel-dwim-directory-buffers)
     (concat "No Ghostel buffers are associated with "
             "the current directory"))))
  (let ((buffers (ghostel-dwim-directory-buffers)))
    (pop-to-buffer
     (if buffer
         (ghostel-dwim--require-buffer buffer buffers)
       (or (car buffers)
           (user-error
            (concat "No Ghostel buffers are associated with "
                    "the current directory")))))))

;;;###autoload
(defun ghostel-dwim-project-switch (&optional buffer)
  "Switch to a Ghostel BUFFER associated with the current project.

BUFFER, when non-nil, is the buffer object or buffer name to
validate and display.  Interactively, prompt among Ghostel buffers
associated with the current project."
  (interactive
   (list
    (ghostel-dwim--read-buffer
     "Switch to project Ghostel buffer: "
     (ghostel-dwim-project-buffers)
     (concat "No Ghostel buffers are associated with "
             "the current project"))))
  (let ((buffers (ghostel-dwim-project-buffers)))
    (pop-to-buffer
     (if buffer
         (ghostel-dwim--require-buffer buffer buffers "project")
       (or (car buffers)
           (user-error
            (concat "No Ghostel buffers are associated with "
                    "the current project")))))))

(defun ghostel-dwim-unload-function ()
  "Remove Ghostel DWIM hooks before unloading the package."
  (remove-hook 'ghostel-command-start-functions
               #'ghostel-dwim--command-start)
  (remove-hook 'ghostel-command-finish-functions
               #'ghostel-dwim--command-finish)
  nil)

(add-hook 'ghostel-command-start-functions
          #'ghostel-dwim--command-start)
(add-hook 'ghostel-command-finish-functions
          #'ghostel-dwim--command-finish)

(provide 'ghostel-dwim)
;;; ghostel-dwim.el ends here
