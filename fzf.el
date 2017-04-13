;;; fzf.el --- A front-end for fzf.
;;
;; Copyright (C) 2015 by Bailey Ling
;; Author: Bailey Ling
;; URL: https://github.com/bling/fzf.el
;; Package-Version: 20161226.936
;; Filename: fzf.el
;; Description: A front-end for fzf
;; Created: 2015-09-18
;; Version: 0.0.2
;; Package-Requires: ((emacs "24.4"))
;; Keywords: fzf fuzzy search
;;
;; This file is not part of GNU Emacs.
;;
;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 3, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING. If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth
;; Floor, Boston, MA 02110-1301, USA.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Install:
;;
;; Autoloads will be set up automatically if you use package.el.
;;
;; Usage:
;;
;; M-x fzf
;; M-x fzf-directory
;; M-x fzf-projectile-projects
;; M-x fzf-cd
;; M-x fzf-dir-find-file
;; M-x fzf-themes
;;; Code:

(defgroup fzf nil
  "Configuration options for fzf.el"
  :group 'convenience)

(defcustom fzf/window-height 15
  "The window height of the fzf buffer"
  :type 'integer
  :group 'fzf)

(defcustom fzf/executable "fzf"
  "The path to the fzf executable."
  :type 'string
  :group 'fzf)

(defcustom fzf/global-args "-x"
  "Additional arguments to pass into all instances of fzf.
   Example arguments include:
       --margin 1,0
       --color=bw
   Too see more options, find fzf in your terminal and type fzf -h"
  :type 'string
  :group 'fzf)

(defcustom fzf/position-bottom t
  "Set the position of the fzf window. Set to nil to position on top."
  :type 'bool
  :group 'fzf)

(defconst fzf/buffer-name "*fzf*"
  "The name of the buffer that the fzf process runs in")

(defun fzf/after-term-handle-exit (process-name msg)
  "Process result from FZF, once it closes, and send the result to the
   user defined exit handler"
  (advice-remove 'term-handle-exit #'fzf/after-term-handle-exit)
  (let* ((text (buffer-substring-no-properties (point-min) (point-max)))
         (lines (split-string text "\n"))
         (target (nth (- (length lines) 4) lines))
         (current-dir default-directory))
    (jump-to-register :fzf-windows)
    (kill-buffer fzf/buffer-name)
    (when on-term-exit (funcall on-term-exit target current-dir))))

(defun fzf/create-buffer ()
  "Create the bottom split where FZF will go"
  (let ((height (if fzf/position-bottom (- fzf/window-height) fzf/window-height)))
   (get-buffer-create fzf/buffer-name)
   (split-window-vertically height)
   (when fzf/position-bottom (other-window 1))
   (switch-to-buffer fzf/buffer-name)))

(defun fzf/disable-problem-settings ()
  "Various settings that are known to cause artifacts, see #1 for more details."
  (linum-mode 0)
  (setq-local scroll-margin 0)
  (setq-local scroll-conservatively 0)
  (setq-local term-suppress-hard-newline t) ;for paths wider than the window
  (face-remap-add-relative 'mode-line '(:box nil)))

(defun fzf/start-term (&optional args)
  "Starts the term emulator where FZF is run"
  (require 'term)
  (let* ((args-list (concat fzf/global-args args))
         (fzf-with-args (concat fzf/executable " --print-query " args-list))
         (command (if source (concat source " | " fzf-with-args) fzf-with-args)))
    (make-term "fzf" "command" nil "eval" command)
    (term-char-mode)
    (setq mode-line-format mode-line-string)))

(defun fzf/start (source
                  mode-line-string term-exit-handler
                  &optional do-before
                  &optional args)
  "Starts the FZF process. FZF can be used to search anything as long as you
   provide the source by piping its STDOUT as the STDIN to FZF. fzf.el handles
   piping the source into FZF for you. For an example of the use of this function
   look at any of the built in implementations, such as fzf.

   source: A bash command, for instance `find ~/ type -f`
   Note that some commands might not behave as expected. If you have a list

   fzf/list-to-fzf-results function to generate the source.

   mode-line-string: The string that appears at the bottom of FZF to tell you
   what FZF is searching

   term-exit-handler: A function that takes the [results current-dir] arguments.
   This function lets you take the results from FZF and do something with them.

   do-before: A function that lets you specify anything that needs to happen
   before FZF is run.

   args: Additional arguments to be passed into fzf"
  (setq on-term-exit term-exit-handler)
  (window-configuration-to-register :fzf-windows)
  (advice-add 'term-handle-exit :after #'fzf/after-term-handle-exit)

  (fzf/create-buffer)
  (when do-before (funcall do-before))
  (fzf/start-term args)
  (fzf/disable-problem-settings))

(defun fzf/get-directory (directory)
  "Returns the directory that should be used. If a directory is provided,
   just return that, else if directory is nil check for a projectile directory,
   otherwise return the current buffers directory"
  (if directory directory
    (if (fboundp #'projectile-project-root)
        (condition-case err
            (projectile-project-root)
          (error default-directory))
      default-directory)))

(defun fzf/list-to-fzf-results (list)
  "Generates a bash script that can be used as a source from a list"
  (let* ((delimiter ",")
         (list-as-string (s-join delimiter list)))
    (format "IFS='%s' read -a array <<< '%s';
            delimiter='\\n';
            regex=\"$(printf \"%%s${delimiter}\" \"${array[@]}\" )\";
            echo \"$regex\""
            delimiter
            list-as-string)))

;;;###autoload
(defun fzf (&optional directory &optional do-before)
  "Search for a file and then switch to that file in the current buffer"
  (interactive)
  (fzf/start
   nil
   (format "   FZF  %s" (fzf/get-directory directory))
   '(lambda (file current-dir)
      (let ((file-path (expand-file-name file current-dir)))
        (message file-path)
        (when (file-exists-p file-path) (find-file file-path))))
   do-before))

;;;###autoload
(defun fzf-directory (directory)
  "Search for a file in the supplied directory and then switch to that
   file in the current directory"
  (interactive)
  (fzf directory '(lambda () (cd directory))))

;;;###autoload
(defun fzf/find-dir (term-exit-handler &optional directory)
  "Boiler plate function for FZF commands that use FZF to first search
   directories"
  (let ((dir (substring (fzf/get-directory directory) 0 -1)))
    (fzf/start
     (format "find %s -type d" dir)
     (format "   FZF  %s" dir)
     term-exit-handler)))

;;;###autoload
(defun fzf-cd (&optional directory)
  "Search for a directory and then change the default directory to the
   found directory"
  (interactive)
  (fzf/find-dir
   '(lambda (new-dir current-dir)
      (when (file-exists-p new-dir)
        (cd new-dir)
        (message (format "Working directory set to %s" new-dir))))
   directory))

;;;###autoload
(defun fzf-dir-find-file (&optional directory)
  "Search for a directory, then search for a file in that directory, and
   then switch to that file in the current buffer"
  (interactive)
  (fzf/find-dir
   '(lambda (new-dir current-dir)
      (when (file-exists-p new-dir)
        (fzf--directory new-dir)))
   directory))

;;;###autoload
(defun fzf-themes()
  "Search through all installed themes and then switch to them. Note some themes
   may have result in issues with FZF upon switching, such as the base16 themes,
   though your experience may vary. (If you use a base16 theme as a default theme,
   you shouldn't have any issues. The problem only happens when you switch using
   this method)"
  (fzf/start
   (fzf/list-to-fzf-results (map 'list 'symbol-name (custom-available-themes)))
   "   FZF Themes"
   '(lambda (theme) current-dir (load-theme (intern theme)))))

(provide 'fzf)
;;; fzf.el ends here
