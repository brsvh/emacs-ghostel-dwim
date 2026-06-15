;;; ghostel-dwim.el --- Let Ghostel Do What I Mean -*- lexical-binding:t -*-

;; Copyright (C) 2026 Bingshan Chang

;; Author: Bingshan Chang <chang@bingshan.org>
;; Keywords: extensions
;; Package-Requires: ((emacs "30.1") (ghostel "0.34.0"))
;; Version: 0.1.0

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
;; paths are expanded and normalized with trailing slashes, but symlinks
;; are not resolved and no project lookup or filesystem probing is done.
;;
;; Project membership follows Ghostel's own project buffer semantics,
;; including `ghostel-project-buffer-scope', so `default-directory' and
;; project identity behave the same way as Ghostel's project commands.
;;
;; These layers only handle scoped discovery, explicit fresh opening,
;; and scoped switching.  They do not decide whether a terminal is idle,
;; reuse idle sessions, or clean up buffers.

;;; Code:

(require 'ghostel)
(require 'project)

(declare-function ghostel--project-buffers "ghostel" ())

(defconst ghostel-dwim--other-window-action
  '(nil . ((inhibit-same-window . t)))
  "Display action expressing intent to avoid the selected window.")

(defun ghostel-dwim--normalize-directory (directory)
  "Return DIRECTORY as an expanded directory name.

Signal `user-error' when DIRECTORY cannot be normalized."
  (unless (and (stringp directory)
               (not (string= directory "")))
    (user-error "Invalid directory: %S" directory))
  (condition-case err
      (file-name-as-directory (expand-file-name directory))
    (error
     (user-error "Invalid directory %S: %s"
                 directory
                 (error-message-string err)))))

(defun ghostel-dwim--buffer-directory (buffer)
  "Return the normalized `default-directory' for BUFFER."
  (with-current-buffer buffer
    (ghostel-dwim--normalize-directory default-directory)))

(defun ghostel-dwim--ghostel-buffer-p (buffer)
  "Return non-nil when BUFFER is a live Ghostel buffer."
  (and (buffer-live-p buffer)
       (with-current-buffer buffer
         (derived-mode-p 'ghostel-mode))))

(defun ghostel-dwim--buffer-names (buffers)
  "Return the names of BUFFERS."
  (mapcar #'buffer-name buffers))

(defun ghostel-dwim--read-buffer (prompt buffers empty-message)
  "Read a Ghostel buffer with PROMPT from BUFFERS.

Signal `user-error' with EMPTY-MESSAGE when BUFFERS is nil."
  (unless buffers
    (user-error "%s" empty-message))
  (get-buffer
   (completing-read prompt
                    (ghostel-dwim--buffer-names buffers)
                    nil
                    t
                    nil
                    nil
                    (buffer-name (car buffers)))))

(defun ghostel-dwim--require-buffer (buffer buffers &optional scope)
  "Return BUFFER from BUFFERS after validating current SCOPE membership."
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

(defun ghostel-dwim--project-buffers ()
  "Return current project Ghostel buffers using Ghostel project semantics."
  (ghostel-dwim--require-project)
  (let (buffers)
    (dolist (buffer (ghostel--project-buffers) (nreverse buffers))
      (when (ghostel-dwim--ghostel-buffer-p buffer)
        (push buffer buffers)))))

(defun ghostel-dwim--display-buffer (buffer)
  "Display BUFFER using normal Emacs buffer display behavior."
  (pop-to-buffer buffer)
  buffer)

(defun ghostel-dwim-directory-buffers ()
  "Return Ghostel buffers associated with the current directory."
  (let ((directory (ghostel-dwim--normalize-directory default-directory))
        buffers)
    (dolist (buffer (buffer-list) (nreverse buffers))
      (when (and (ghostel-dwim--ghostel-buffer-p buffer)
                 (string= directory
                          (ghostel-dwim--buffer-directory buffer)))
        (push buffer buffers)))))

(defun ghostel-dwim-project-buffers ()
  "Return Ghostel buffers associated with the current project.

Project membership follows Ghostel's own project buffer discovery,
including `ghostel-project-buffer-scope'."
  (ghostel-dwim--project-buffers))

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
(defun ghostel-dwim-project-open-other-window ()
  "Start a fresh project Ghostel session while avoiding the selected window.

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
   (list (ghostel-dwim--read-buffer "Switch to Ghostel buffer: "
                                    (ghostel-dwim-directory-buffers)
                                    "No Ghostel buffers are associated with the current directory")))
  (let ((buffers (ghostel-dwim-directory-buffers)))
    (ghostel-dwim--display-buffer
     (if buffer
         (ghostel-dwim--require-buffer buffer buffers)
       (or (car buffers)
           (user-error
            "No Ghostel buffers are associated with the current directory"))))))

;;;###autoload
(defun ghostel-dwim-project-switch (&optional buffer)
  "Switch to a Ghostel BUFFER associated with the current project.

BUFFER, when non-nil, is the buffer object or buffer name to
validate and display.  Interactively, prompt among Ghostel buffers
associated with the current project."
  (interactive
   (list (ghostel-dwim--read-buffer "Switch to project Ghostel buffer: "
                                    (ghostel-dwim-project-buffers)
                                    "No Ghostel buffers are associated with the current project")))
  (let ((buffers (ghostel-dwim-project-buffers)))
    (ghostel-dwim--display-buffer
     (if buffer
         (ghostel-dwim--require-buffer buffer buffers "project")
       (or (car buffers)
           (user-error
            "No Ghostel buffers are associated with the current project"))))))

(provide 'ghostel-dwim)
;;; ghostel-dwim.el ends here
