;;; etaf-md-preview-live.el --- Keep a preview in step with its source  -*- lexical-binding: t; -*-

;;; Commentary:

;; A preview is a rendering of a markdown file, so it is read-only: the file is
;; edited in its own buffer, with every Emacs command the reader already has,
;; and this module keeps the page in step with it.  A change repaints the page
;; from the edited text on the next frame, block by block: the blocks that did
;; not change keep their published instance, so typing in the source costs the
;; block under the caret rather than the whole document.
;;
;; What the projection adds is the way back: which range of the file each
;; painted block came from, so a caller can answer for a position on the page
;; in terms of the markdown behind it.

;;; Code:

(require 'cl-lib)
(require 'etaf)
(require 'etaf-md-preview-app)
(require 'etaf-md-preview-model)
(require 'etaf-md-preview-views)

;;;; What markdown alone knows

(defun etaf-md-preview--block-marker-length (block text)
  "Return how many characters BLOCK's painted marker covers in TEXT.
An empty block paints its source skeleton, and the caret belongs after it:
typing in front of the hashes would turn the heading into a paragraph."
  (if (etaf-md-preview--block-empty-p block text)
      (length (etaf-md-preview--block-marker block))
    0))

(defun etaf-md-preview--entries-around (entries offset)
  "Return the entries of ENTRIES that answer for source OFFSET.
That is the block holding OFFSET -- or the nearest one, since a position
between two blocks belongs to whichever the page puts the caret on -- together
with the blocks on either side of it, because a block's painted range can reach
past its own source and only the neighbouring runs show which cell the caret
really stands on."
  (let ((chosen 0)
        (distance nil))
    (cl-loop for entry in entries
             for index from 0
             for range = (cdr entry)
             for begin = (car range)
             for end = (cdr range)
             for behind = (cond ((< offset begin) (- begin offset))
                                ((>= offset end) (1+ (- offset end)))
                                (t 0))
             do (when (and (or (null distance) (< behind distance))
                           (or (> behind 0) (null distance)))
                  (setq chosen index distance behind)))
    (when entries
      (let ((from (max 0 (1- chosen)))
            (to (min (length entries) (+ chosen 2))))
        (seq-subseq entries from to)))))

(defun etaf-md-preview--projection-entries (session &optional offset)
  "Return the source range each painted block of SESSION stands for.
A block's range is the text it renders: its marker is skipped, because the
render folds it away, and its trailing newline is dropped, because the line
break belongs between blocks rather than to either of them.

With OFFSET, return only the block that answers for it: a caret move lands in
one block, and a page of a thousand blocks would otherwise be mapped on every
key."
  (let* ((text (etaf-md-preview--session-text session))
         (by-key (make-hash-table :test #'equal))
         (entries nil))
    ;; The session records each entry's box reference against its key, so a
    ;; block found by key resolves to the Host the projection reads.
    (let ((refs (plist-get session :block-refs)))
      (when refs
        (maphash (lambda (ref key) (puthash key ref by-key)) refs)))
    (when text
      (maphash
       (lambda (key entry)
         (let* ((block (plist-get entry :block))
                (begin (plist-get block :begin))
                (end (plist-get block :end))
                (blank (eq (plist-get block :type) 'blank))
                (marker (etaf-md-preview--block-marker-length block text)))
           ;; A blank row paints one cell for a line whose only character is its
           ;; newline; an empty document paints that cell for the start of an
           ;; empty file, so this range is the one place it may name no text.
           (cond
            (blank
             (when-let* ((ref (gethash key by-key)))
               (push (cons ref (cons begin end)) entries)))
            ((and (integerp begin) (integerp end) (< begin end) (<= end (length text)))
             (let* ((start (+ begin marker))
                    (stop (if (and (> end start) (eq (aref text (1- end)) ?\n))
                             (1- end)
                           end)))
               (when (< start stop)
                 (when-let* ((ref (gethash key by-key)))
                   (push (cons ref (cons start stop)) entries))))))))
       (or (plist-get session :published) (make-hash-table :test #'equal))))
    (nreverse (if (null offset)
                  entries
                (etaf-md-preview--entries-around entries offset)))))

(defun etaf-md-preview-projection (session)
  "Return SESSION's painted preview as ranges of its markdown source."
  (when-let* ((buffer (plist-get session :buffer))
              (runtime (and (buffer-live-p buffer)
                            (etaf-runtime-for-buffer buffer)))
              (text (etaf-md-preview--session-text session)))
    (etaf-projection runtime (etaf-md-preview--projection-entries session) text)))

;;;; Repainting the page

(defun etaf-md-preview--live-repaint (session)
  "Redraw SESSION's page from its markdown, now."
  (let ((text (etaf-md-preview--session-text session)))
    (etaf-md-preview--publish session text)
    ;; The text this page now shows, so a scheduled follow that finds the same
    ;; text knows there is nothing left to draw.
    (plist-put session :live-text text))
  (when-let* ((buffer (plist-get session :buffer))
              (runtime (and (buffer-live-p buffer)
                            (etaf-runtime-for-buffer buffer))))
    (etaf-runtime-flush runtime)))

(defun etaf-md-preview--live-refresh (session text)
  "Redraw SESSION from TEXT, the current markdown."
  (unless (plist-get session :source-buffer)
    (plist-put session :text text))
  (etaf-md-preview--live-repaint session))

(provide 'etaf-md-preview-live)

;;; etaf-md-preview-live.el ends here
