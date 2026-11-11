;;; etaf-md-preview-typeset.el --- Draw diagrams and formulas with a program  -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Two block kinds carry a picture rather than prose: a fenced `mermaid' block
;; and a `$$' display formula.  The parser and the shared renderer keep them as
;; source, which is what a reader sees when nothing else is installed.  When
;; mermaid-cli is present this module draws them: the diagram through `mmdc',
;; the formula through KaTeX and the Chromium mmdc already brings.
;;
;; A render is asynchronous and cached by what it depends on, so a repaint of
;; the same block costs one file check.  Until the picture exists the block
;; keeps its source, and a finished render repaints the page in place.

;;; Code:

(require 'cl-lib)
(require 'subr-x)

(require 'etaf-md-preview-model)
(require 'etaf-md-preview-views)

(declare-function image-size "image.c" (spec &optional pixels frame))

(defgroup etaf-md-preview-typeset nil
  "Diagrams and display formulas drawn by an external program."
  :group 'etaf-md-preview)

(defcustom etaf-md-preview-typeset t
  "Whether the preview draws a diagram and a display formula with a program.
When nil, or when mermaid-cli is not installed, a mermaid block and a display
formula keep the source and the plain-text rendering the shared renderer
paints.  A page never waits for a program either way: a picture that is not
cached yet appears on the repaint that follows its render."
  :type 'boolean)

(defconst etaf-md-preview-typeset--cache-directory
  (expand-file-name "etaf-md-preview/typeset/"
                    (or (getenv "XDG_CACHE_HOME")
                        (expand-file-name "~/.cache")))
  "Directory holding one PNG per rendered block.")

(defconst etaf-md-preview-typeset--scale 2
  "Pixels per point a picture is drawn at, so it stays sharp when it is placed.")

(defconst etaf-md-preview-typeset--formula-scale 1.15
  "A display formula is set this much larger than the page's body text.
A formula is a line of the sentence above it, so it takes the reader's own body
size with a little air; typesetting it at a heading's size made one equation
claim half the page.")

(defun etaf-md-preview--typeset-pixels ()
  "Return the pixel size to typeset a formula at.
The page's body size comes from the frame's own default font, so a reader who
changes their font size gets a formula that still matches the text."
  (max 12 (round (* (etaf-md-preview--base-pixels)
                    etaf-md-preview-typeset--formula-scale))))

(defvar etaf-md-preview-typeset--running (make-hash-table :test #'equal)
  "Render in flight by block key, so one block never renders twice.")

(defvar etaf-md-preview-typeset--missing nil
  "Non-nil once the programs were looked for and not found.")

(defun etaf-md-preview-typeset--script ()
  "Return the formula renderer's path, or nil when this checkout lacks it."
  (when-let* ((entry (locate-library "etaf-md-preview"))
              ((not (string-suffix-p ".eln" entry)))
              (script (expand-file-name "scripts/typeset-math.mjs"
                                        (file-name-directory entry)))
              ((file-exists-p script)))
    script))

(defun etaf-md-preview-typeset-available-p ()
  "Return non-nil when this system can draw diagrams and formulas.
Both need mermaid-cli: the diagram calls `mmdc', and the formula uses the
Chromium and KaTeX that package installs."
  (and etaf-md-preview-typeset
       (not etaf-md-preview-typeset--missing)
       (or (executable-find "mmdc")
           (setq etaf-md-preview-typeset--missing t))))

(defun etaf-md-preview--typeset-colors (env)
  "Return (DIAGRAM-THEME . INK) drawn for ENV's page.
The diagram theme follows the page it is placed on, which a named palette sets
even when the frame is the other way round: a light page keeps light diagrams.
A page with no background of its own is read in the frame's appearance.  A
formula is inked in the page's own text colour, so both sit on whatever surface
the page paints instead of carrying a palette of their own."
  (let* ((background (plist-get env :background))
         (dark (if (and background (stringp background))
                   ;; A dark page is the one with little contrast against
                   ;; black, since the ratio against white would be large.
                   (<= (etaf-ui-color-contrast background "#000000") 1.5)
                 (eq (etaf-appearance) 'dark))))
    (cons (if dark 'dark 'default)
          (etaf-md-preview--env-color env :ink))))

(defun etaf-md-preview--typeset-key (kind source env)
  "Return the cache key of KIND drawn from SOURCE for ENV's surface.
The key holds what the picture depends on, so a theme switch draws a new one
instead of reusing the colours of the old surface."
  (secure-hash 'sha1
               (format "%s\n%s\n%s\n%s\n%d"
                       kind source
                       (car (etaf-md-preview--typeset-colors env))
                       (cdr (etaf-md-preview--typeset-colors env))
                       ;; A formula drawn for another body size is another
                       ;; picture, not a cache hit.
                       (if (eq kind 'math) (etaf-md-preview--typeset-pixels) 0))))

(defun etaf-md-preview--typeset-path (key)
  "Return the PNG path of KEY."
  (expand-file-name (concat key ".png") etaf-md-preview-typeset--cache-directory))

(defun etaf-md-preview-typeset-attach (block env)
  "Return BLOCK carrying the picture already rendered for it in ENV.
The block gains `:picture', the PNG path, when one exists; the renderer draws
that and leaves a block without one as its source.  Publishing compares the
block's content, so a picture that arrived makes the block different and the
page paints it without any other bookkeeping.  Reading the cache is all this
does: a render never starts a program, because a render is also the pass a
keystroke pays for."
  (let ((kind (pcase (plist-get block :type)
                ('code-block (and (equal (plist-get block :lang) "mermaid") 'mermaid))
                ('math (and (plist-get block :display) 'math)))))
    (if (not kind)
        block
      (if-let* ((source (plist-get block :text))
                ((not (string-blank-p source)))
                ((etaf-md-preview-typeset-available-p))
                (path (etaf-md-preview--typeset-path
                       (etaf-md-preview--typeset-key kind source env)))
                ((file-exists-p path)))
          (plist-put (copy-sequence block) :picture path)
        block))))

(defun etaf-md-preview--typeset-figure (kind path env)
  "Return the View of the picture at PATH for KIND in ENV.
A diagram keeps a frame and a caption that opens the file, the way an image
card does; a formula is its own line with no frame, because it belongs to the
sentence above it."
  (let* ((width (max 24 (or (plist-get env :width) 92)))
         ;; The picture is drawn at `--scale' device pixels per point, so its
         ;; own pixel size is that many times the size it should occupy; the
         ;; grid it is placed in comes from the size on the page, not the file.
         (pixels (when-let* ((natural (ignore-errors
                                        (etaf-md-preview--image-pixels path))))
                   (cons (/ (car natural) (float etaf-md-preview-typeset--scale))
                         (/ (cdr natural) (float etaf-md-preview-typeset--scale)))))
         (grid (or (etaf-md-preview--media-grid-for-pixels pixels (- width 2))
                   (cons width 8)))
         (image (etaf-node 'image
                           (list :src path
                                 :columns (car grid)
                                 :rows (cdr grid)
                                 :adapter 'auto)
                           nil)))
    (if (eq kind 'math)
        (etaf-node 'column
                   (list :width 'stretch :cross-align 'center
                         :padding '((lh 0.5) (ch 0)))
                   (list image))
      (let ((open-file (plist-get env :open-file))
            (caption (format "%s（按 RET 打开）" (file-name-nondirectory path))))
        (etaf-node 'column
                   (list :width 'stretch :cross-align 'center :item-gap '(lh 0))
                   (list
                    (etaf-node 'box
                               (list :border (list '(px 1) 'solid
                                                   (etaf-md-preview--env-color env :border))
                                     :on-press (lambda () (when open-file (funcall open-file path)))
                                     :role 'button :tab-index 0 :pointer 'hand
                                     :help-echo caption)
                               (list image))
                    (etaf-md-preview--caption-view "▲ mermaid" env)))))))

(defun etaf-md-preview--typeset-start (key kind source env done)
  "Start rendering SOURCE of KIND for KEY, and return the process.
The program writes the picture; the process sentinel calls DONE, which
republishes the page so the next paint finds the file."
  (let ((directory etaf-md-preview-typeset--cache-directory)
        (path (etaf-md-preview--typeset-path key))
        (colors (etaf-md-preview--typeset-colors env))
        (inhibit-message t))
    (make-directory directory t)
    (condition-case error
        (let ((input (expand-file-name (concat key (if (eq kind 'math) ".tex" ".mmd"))
                                       directory))
              (arguments nil))
          (with-temp-file input (insert source))
          (setq arguments
                (pcase kind
                  ('math
                   (let ((script (etaf-md-preview-typeset--script)))
                     (unless script (error "No formula renderer in this checkout"))
                     (list "node" script input path (cdr colors)
                           (number-to-string (etaf-md-preview--typeset-pixels)))))
                  (_ (list "mmdc" "-i" input "-o" path
                           "-t" (symbol-name (car colors))
                           "-b" "transparent"
                           "-s" (number-to-string etaf-md-preview-typeset--scale)
                           "-q"))))
          (let ((process (funcall #'make-process
                                :name (format "etaf-md-preview-%s" kind)
                                :command arguments
                                :connection-type 'pipe
                                :noquery t
                                :filter #'ignore
                                :sentinel
                                (lambda (process _event)
                                  (when (memq (process-status process) '(exit signal))
                                    (remhash key etaf-md-preview-typeset--running)
                                    (when (and (eq (process-status process) 'exit)
                                               (zerop (process-exit-status process)))
                                      (etaf-md-preview--typeset-finished
                                       key path done)))))))
            (puthash key process etaf-md-preview-typeset--running)
            (ignore input)
            process))
      (error
       (message "Preview kept the source of a %s block: %s"
                kind (error-message-string error))
       nil))))

(defun etaf-md-preview--typeset-finished (_key path done)
  "Call DONE after a render left PATH.
A render that left no file is a failure the caller sees as the source still
painted, so nothing repaints then."
  (when (and (file-exists-p path) done)
    (run-at-time 0 nil done)))

(defun etaf-md-preview-typeset-request (session)
  "Start the renders SESSION's page needs and does not show yet.
The blocks are read from the published document, and a block whose picture is
already on disk, or already rendering, is skipped.  The programs start on a
timer, so asking costs the publish pass one comparison per picture block and
never a program launch."
  (when (etaf-md-preview-typeset-available-p)
    (let ((env (etaf-md-preview--env session))
          (wanted nil))
      (dolist (entry (plist-get (etaf-md-preview--read session :document) :children))
        (let* ((block (plist-get entry :block))
               (kind (pcase (plist-get block :type)
                      ('code-block (and (equal (plist-get block :lang) "mermaid") 'mermaid))
                      ('math (and (plist-get block :display) 'math)))))
          (when-let* ((source (and kind (plist-get block :text)))
                      ((not (string-blank-p source)))
                      (key (etaf-md-preview--typeset-key kind source env))
                      ((not (file-exists-p (etaf-md-preview--typeset-path key))))
                      ((not (gethash key etaf-md-preview-typeset--running))))
            (push (list kind source key) wanted))))
      (when wanted
        (run-at-time 0 nil
                     (lambda ()
                       (dolist (entry (nreverse wanted))
                         (let ((kind (nth 0 entry))
                               (source (nth 1 entry))
                               (key (nth 2 entry)))
                           (unless (or (file-exists-p (etaf-md-preview--typeset-path key))
                                       (gethash key etaf-md-preview-typeset--running))
                             (etaf-md-preview--typeset-start
                              key kind source env
                              (lambda () (etaf-md-preview--typeset-changed session))))))))))))

(defun etaf-md-preview--typeset-changed (session)
  "Repaint SESSION once, however many pictures arrive together.
Two diagrams of one page finish within a frame of each other, and one paint
after both is what a reader sees; a pending flag keeps the second arrival from
starting a publish the first already asked for."
  (unless (plist-get session :typeset-pending)
    (plist-put session :typeset-pending t)
    (run-at-time 0 nil
                 (lambda ()
                   (plist-put session :typeset-pending nil)
                   (etaf-md-preview--typeset-repaint session)))))

(defun etaf-md-preview--typeset-repaint (session)
  "Publish SESSION's document again so the page paints its new pictures.
A session whose file is not being visited has no source text of its own, so it
reads the file; one that is being edited republishes the buffer's text."
  (when (buffer-live-p (plist-get session :buffer))
    (if (and (plist-get session :file)
             (not (buffer-live-p (plist-get session :source-buffer))))
        (etaf-md-preview-refresh session)
      (etaf-md-preview--publish session (etaf-md-preview--session-text session)))))

(defun etaf-md-preview--render-code-block (block env)
  "Return BLOCK drawn as its picture, or nil to keep its source.
Only a `mermaid' fence has a program behind it; every other language keeps the
renderer's own painting."
  (when-let* ((path (and (equal (plist-get block :lang) "mermaid")
                         (plist-get block :picture))))
    (etaf-md-preview--typeset-figure 'mermaid path env)))

(defun etaf-md-preview--render-math (block env)
  "Return display formula BLOCK typeset, or nil to keep the text rendering.
An inline formula is part of a sentence and keeps its text: a picture inside a
line would change the line's height."
  (when-let* ((path (and (plist-get block :display)
                         (plist-get block :picture))))
    (etaf-md-preview--typeset-figure 'math path env)))

(provide 'etaf-md-preview-typeset)
;;; etaf-md-preview-typeset.el ends here
