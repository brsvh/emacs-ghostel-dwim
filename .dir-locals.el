;;; Directory Local Variables            -*- no-byte-compile: t -*-
;;; For more information see (info "(emacs) Directory Variables")

((emacs-lisp-mode
  .
  ((eval
    .
    (let* ((root (locate-dominating-file
                  default-directory ".dir-locals.el"))
           (source (expand-file-name "src/" root)))
      (setq-local elisp-flymake-byte-compile-load-path
                  (cons source elisp-flymake-byte-compile-load-path)
                  load-path (cons source load-path))))))

 (nil . ((sentence-end-double-space . t))))
