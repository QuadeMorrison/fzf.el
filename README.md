# fzf.el [![MELPA](https://melpa.org/packages/fzf-badge.svg)](https://melpa.org/#/fzf)

An Emacs front-end for [fzf][1].

![demo](https://cloud.githubusercontent.com/assets/306502/12380684/ca0a6648-bd46-11e5-9091-841b282874e4.gif)

# installation

fzf.el can be installed through [MELPA][2].

# compatibility
While this package does work with the newest version of FZF, the emulator displays the text much
slower than older versions. Unless there is a newer feature that you require it is recommended that
you use an older version. Version 0.15.6 has been tested and displays results quickly.

# usage

There are several built in functions in fzf.el, such as the following which will let you search for
files in your working directory, or if projectile is installed, fzf will instead search for files
in the projectile directory, if a projectile project is found.

`M-x fzf`

It is simple to provide your own source to FZF. FZF can take bash commands piped in like
`find ~/ type -d | fzf`. This allows you to use FZF to search through the directories
under your `~/` directory. So the following implementation would let you search through your
directories and print the results

```cl
(defun fzf-print-directory ()
  (fzf/start
   "find ~ -type d"
   "   FZF Search Directories"
   '(lambda (result current-dir) (print result))))
```

`(defun fzf-projectile-projects ()
  "Search through the known projectile projects, and the search for a file from
   the selected project to switch to"
  (fzf/start
   (fzf/list-to-fzf-results (sort (projectile-load-known-projects) 'string-lessp))
   "   FZF Projectile Projects"
   '(lambda (project-dir current-dir) (when (file-exists-p project-dir)
                                        (fzf-directory project-dir)))))`

`(defun fzf-buffers ()
  "Search currently open buffers, ignoring things like mini-buffers and helm-buffers"
  (let ((buffer-list
         (cl-remove-if
          '(lambda (str)
             (or (string-match "^\s[*]" str)
                 (string-match "^[*]helm" str)))
          (map 'list 'buffer-name (buffer-list)))))
    (fzf/start
     (fzf/list-to-fzf-results buffer-list)
     "   FZF Buffers"
     '(lambda (buffer current-dir)
        (when (get-buffer buffer)
          (switch-to-buffer buffer))))))`

For more details on how this works, read the documentation found in the doc-string of the fzf/start
function.

# license

GPL3

[1]: https://github.com/junegunn/fzf
[2]: https://melpa.org
