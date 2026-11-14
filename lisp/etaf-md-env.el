;;; etaf-md-env.el --- What a node paint may read -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;;
;; A paint receives one argument, the environment of the block being painted:
;; the node itself plus the services the renderer owns.  It reads attributes
;; through `etaf-md-attr', paints children through `etaf-md-content' and
;; `etaf-md-render', and turns `surface' and `accent' words into colours.  It
;; cannot read a file, reach the network or see another block.
;;
;; The environment has one node.  A child is passed back in as the last
;; argument of `etaf-md-attr', `etaf-md-children' or `etaf-md-render', never by
;; mutating the environment.

;;; Code:

(require 'cl-lib)
(require 'etaf-ui)
(require 'etaf-md-node)
(require 'etaf-md-theme)

(declare-function etaf-md--republish "etaf-md-model" (session))

(cl-defstruct (etaf-md-env (:constructor etaf-md-env-create)
                           (:copier nil))
  "The context one block is painted in."
  session
  node
  width
  state
  palette
  theme
  block)

(defun etaf-md--paint (node env)
  "Return the view ENV's definition gives NODE, or a failure line."
  (let* ((type (etaf-md-node-type node))
         (definition (etaf-md-node-definition type))
         (problems (and definition (plist-get definition :view)
                        (etaf-md--all-problems node))))
    (cond
     (problems
      (etaf-md--failure-view
       env (or (etaf-md-node-source node) "") (cadr (car problems))))
     ((and definition (plist-get definition :view))
      (let ((inner (etaf-md-env-create
                    :session (etaf-md-env-session env)
                    :node node
                    :width (etaf-md-env-width env)
                    :state (etaf-md-env-state env)
                    :palette (etaf-md-env-palette env)
                    :theme (etaf-md-env-theme env)
                    :block (etaf-md-node-block node))))
        (funcall (plist-get definition :view) inner)))
     ;; A Markdown block the new model does not define yet keeps the painter
     ;; it has today; only a container with no definition is a failure,
     ;; because a container cannot be painted without one.
     ((and (etaf-md-node-block node)
           (not (eq (plist-get (etaf-md-node-block node) :type) 'container)))
      (etaf-ui-markdown-view-block
       (etaf-md-node-block node)
       (list :theme (etaf-md-env-theme env)
             :palette (etaf-md-env-palette env)
             :width (etaf-md-env-width env))))
     (t
      (etaf-md--failure-view
       env (or (etaf-md-node-source node)
               (format "::: %s" (or (etaf-md-node-type node) "?")))
       (format "没有 %s 的定义" type))))))

(defun etaf-md--failure-view (env source message)
  "Return SOURCE painted as text with MESSAGE under it."
  (etaf-view
   (column :item-gap '(lh 0)
     (text :color (etaf-md--muted env)
       (expr source))
     (text :color (etaf-md--muted env) :font-weight 'bold
       (expr message)))))

(defun etaf-md--muted (env)
  "Return the muted ink of ENV's palette."
  (or (plist-get (etaf-md-env-palette env) :muted) "#9198a1"))

(defun etaf-md--hairline (env)
  "Return a one-pixel border as the Theme ENV's page lives in defines it.
The border token is the theme's own line colour.  Drawing the frame in an
accent instead would reuse the body ink, which is four times heavier than the
hairline the markdown tables already use; an accent is a highlight, not an
edge.  The palette supplies the fallback for a page mounted without a Theme."
  (etaf-theme-token
   :ui-panel-border
   (plist-get (etaf-md-theme-tokens (etaf-md-env-theme env)
                                    (etaf-md-env-palette env))
              :ui-panel-border)
   (lambda (color) (list (list 'px 1) 'solid color))))

;;; The twelve functions

(defun etaf-md-attr (env key &optional node)
  "Return KEY's final value on NODE, or on ENV's own node.
A style rule wins over the document, the document over the declaration's
default, and a derived attribute has only the value the parser or the derive
step wrote."
  (etaf-md--value (or node (etaf-md-env-node env)) key))

(defun etaf-md-type (env)
  "Return the type name of ENV's node."
  (etaf-md-node-type (etaf-md-env-node env)))

(defun etaf-md-children (env &optional node)
  "Return NODE's children, or ENV's own node's children."
  (etaf-md-node-children (or node (etaf-md-env-node env))))

(defun etaf-md-content (env)
  "Return ENV's children painted as one view."
  (etaf-md-render env (etaf-md-children env)))

(defun etaf-md-render (env nodes)
  "Return NODES painted as one view, stacked in document order."
  (etaf-view
   (column :item-gap '(lh 0)
     (expr (mapcar (lambda (node) (etaf-md--paint node env)) nodes)))))

(defun etaf-md-surface (env word)
  "Return surface WORD as a colour for ENV, or nil for none."
  (pcase word
    ('none nil)
    ('page (plist-get (etaf-md-env-palette env) :bg))
    ('raised (or (plist-get (etaf-md-env-palette env) :panel)
                 (plist-get (etaf-md-env-palette env) :panel2)))
    ('sunken (or (plist-get (etaf-md-env-palette env) :panel2)
                 (plist-get (etaf-md-env-palette env) :panel)))
    ('quote (plist-get (etaf-md-env-palette env) :quote-bg))
    ('table-header (plist-get (etaf-md-env-palette env) :table-header))
    ('table-stripe (plist-get (etaf-md-env-palette env) :table-stripe))))

(defun etaf-md-accent (env word)
  "Return accent WORD as a colour for ENV."
  (pcase word
    ('neutral (or (plist-get (etaf-md-env-palette env) :muted) "#9198a1"))
    ('primary (or (plist-get (etaf-md-env-palette env) :accent) "#4493f8"))
    ('success "#2da44e")
    ('warning "#bf8700")
    ('danger "#cf222e")
    ('important (or (plist-get (etaf-md-env-palette env) :heading) "#8250df"))))

(defun etaf-md-default-view (env)
  "Return ENV's node painted with the definition's previous view."
  (let ((definition (etaf-md-node-definition (etaf-md-node-type (etaf-md-env-node env)))))
    (if-let* ((view (plist-get definition :default-view)))
        (funcall view env)
      (etaf-md--paint (etaf-md-env-node env) env))))

(defun etaf-md-follow-link (env target)
  "Open TARGET for ENV's session; return non-nil when it was followed."
  (let ((open (plist-get (etaf-md-env-session env) :open-url)))
    (when (and open target)
      (funcall open target)
      t)))

(defun etaf-md--block-identity (env)
  "Return the identity ENV's block keeps across a repaint.
The parsed block's start offset names it while the document lives; a block
without one falls back to its position in the page."
  (or (plist-get (etaf-md-node-block (etaf-md-env-node env)) :begin) 0))

(defun etaf-md-block-state (env key &optional default)
  "Return KEY's state for ENV's block, or DEFAULT.
The state lives in the session's reactive ref, so a write repaints the
preview."
  (let* ((session (etaf-md-env-session env))
         (ref (and session (plist-get session :block-state)))
         (table (and (etaf-ref-p ref) (etaf-value ref)))
         (identity (etaf-md--block-identity env))
         (entry (and table (assq identity table)))
         (cell (and entry (assq key (cdr entry)))))
    (if cell (cdr cell) default)))

(defun etaf-md-set-block-state (env key value)
  "Store VALUE under KEY for ENV's block and repaint the preview."
  (let* ((session (etaf-md-env-session env))
         (identity (etaf-md--block-identity env))
         (ref (and session (plist-get session :block-state))))
    (when (etaf-ref-p ref)
      (let* ((table (copy-tree (etaf-value ref)))
             (entry (and table (assq identity table))))
        (if entry
            (let ((cell (assq key (cdr entry))))
              (if cell
                  (setcdr cell value)
                (setcdr entry (cons (cons key value) (cdr entry)))))
          (setq table (cons (cons identity (list (cons key value))) table)))
        (etaf-set-value ref table))))
  value)

(defun etaf-md-available-width (env)
  "Return the columns ENV's block may occupy."
  (etaf-md-env-width env))

(provide 'etaf-md-env)
;;; etaf-md-env.el ends here
