;;; etaf-md-components.el --- The site component catalog for etaf-md -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;;
;; The second half of the container catalog: the blocks a documentation site
;; writes around its prose rather than inside it.  A hero, an image card, a
;; link card, a package badge, a bar plot, a QR code, a slide deck, a source
;; tree and a package-manager command group share the same machinery as the
;; prose containers in `etaf-md-nodes': one definition per type, a thin view
;; that translates document attributes into existing `etaf-ui' components.
;;
;; Two of them need more than a translation.  `qrcode' asks an external
;; `qrencode' for the module matrix and caches it; `npm-to' rewrites one npm
;; command into the other package managers before showing the group as code
;; tabs.  Neither runs during a render: the QR is filled by
;; `etaf-md-qrcode-request' after a publish, and the rewrite is a pure
;; function of the block's single code fence.

;;; Code:

(require 'cl-lib)
(require 'subr-x)

(require 'etaf-md-node)
(require 'etaf-md-env)
(require 'etaf-ui)

(declare-function etaf-md--tabs-view "etaf-md-nodes" (env &optional page-view label-fn))
(declare-function etaf-md--code-tab-page "etaf-md-nodes" (env page))
(declare-function etaf-md--child-view "etaf-md-nodes" (env child))
(declare-function etaf-md--media-card "etaf-md-views" (url alt env))
(declare-function etaf-md-qrcode-view "etaf-md-qrcode" (env))
(declare-function etaf-md-qrcode-cached-p "etaf-md-qrcode" (env))
(declare-function etaf-md-qrcode-available-p "etaf-md-qrcode" ())

;;; ---------------------------------------------------------------------------
;;; Shared pieces
;;; ---------------------------------------------------------------------------

(defun etaf-md--component-card (env title description href extra)
  "Return the card-shaped frame used by the site's cards.
TITLE and DESCRIPTION become the card's named slots, HREF makes the whole
card follow the target, and EXTRA is a list of views painted under it."
  (etaf-view
    (etaf-card :title title
               :description description
               :on-press (when href
                           (lambda () (etaf-md-follow-link env href)))
      (expr (when extra
              (etaf-node 'column (list :width 'stretch :item-gap '(lh 0))
                         extra))))))

(declare-function etaf-md--open-file "etaf-md-model" (path))

(defun etaf-md--component-view-env (env)
  "Return the plist the shared view helpers read, built from ENV's definition.
A definition's environment carries the page services; the views that draw
prose take the plain plist they were written for, so the two are bridged
here once instead of in every card."
  (list :theme (etaf-md-env-theme env)
        :palette (etaf-md-env-palette env)
        :width (etaf-md-env-width env)
        :dir (plist-get (etaf-md-env-session env) :dir)
        :open-url (lambda (url) (etaf-md-follow-link env url))
        :open-file #'etaf-md--open-file))

(defun etaf-md--component-image (src alt env)
  "Return SRC as a media card with ALT for ENV.
SRC may be relative to the page; a remote source stays a placeholder that
opens in the browser, the same fallback the prose image uses."
  (etaf-md--media-card src alt (etaf-md--component-view-env env)))

(defun etaf-md--component-ink (env key)
  "Return the theme ink for KEY on ENV's page.
The palette carries the page's own keys; a definition falls back to the same
Theme tokens the rest of the catalog uses, so a component keeps its contrast
in both palettes."
  (let ((palette (etaf-md-env-palette env)))
    (or (etaf-md--palette-value palette key)
        (etaf-md--palette-value palette :ink))))

(defun etaf-md--component-lines (text)
  "Return TEXT split into lines, or nil when it is blank."
  (when (and text (not (string-blank-p text)))
    (split-string text "\n")))

;;; ---------------------------------------------------------------------------
;;; The hero
;;; ---------------------------------------------------------------------------

(defun etaf-md--home-box-view (env)
  "Paint a hero block: an accent title, its summary, and the content."
  (let ((title (etaf-md-attr env :title))
        (description (etaf-md-attr env :description))
        (href (etaf-md-attr env :href))
        (surface (etaf-md-surface env (etaf-md-attr env :background))))
    (etaf-view
      (box :width 'stretch
           :background-color surface
           :border (etaf-md--hairline env)
           :padding '((lh 1) (ch 3))
        (column :width 'stretch :item-gap '(lh 0)
          (expr
           (append
            (when title
              (list (etaf-node 'text
                               (list :color (etaf-md-accent env
                                                            (etaf-md-attr env :accent))
                                     :font-weight 'bold)
                               (list title))))
            (when description
              (list (etaf-node 'text
                               (list :color (etaf-md--component-ink env :muted))
                               (list description))))
            (when href
              (list (etaf-node 'text
                               (list :color (etaf-md-accent env 'primary)
                                     :font-weight 'bold
                                     :role 'link :tab-index 0
                                     :on-press (lambda () (etaf-md-follow-link env href)))
                               (list (format "→ %s" href)))))
            (when (or title description href)
              (list (etaf-node 'text (list :color (etaf-md--component-ink env :faint))
                               (list " "))))
            (list (etaf-md-content env)))))))))

(etaf-md--define-shipped 'home-box
  :name "home-box"
  :summary "首屏大块：标题、摘要、行动链接与正文"
  :attrs '((title       :type string :doc "主标题")
           (description :type string :doc "标题下的摘要")
           (href        :type string :doc "行动链接地址")
           (accent      :type accent :default primary :doc "标题的强调色")
           (background  :type surface :default raised :doc "底色"))
  :view #'etaf-md--home-box-view)

;;; ---------------------------------------------------------------------------
;;; Cards
;;; ---------------------------------------------------------------------------

(etaf-md--define-shipped 'image-card
  :name "image-card"
  :summary "一张带图片的卡片"
  :attrs '((src         :type string :required t :doc "图片路径，相对路径按文档解析")
           (title       :type string :doc "图片下的标题")
           (description :type string :doc "标题下的说明")
           (href        :type string :doc "整张卡片可点，跳到这个地址")
           (width       :type number :doc "卡片宽度（列），默认 46"))
  :view
  (lambda (env)
    (let* ((src (etaf-md-attr env :src))
           (title (etaf-md-attr env :title))
           (description (etaf-md-attr env :description))
           (href (etaf-md-attr env :href))
           (width (min (or (etaf-md-attr env :width) 46)
                       (max 20 (- (etaf-md-env-width env) 2))))
           (inner (max 8 (- width 4)))
           (view-env (etaf-md--component-view-env env)))
      (etaf-view
        (column :width (list 'ch width)
                :background-color (etaf-md-surface env 'raised)
                :border (etaf-md--hairline env)
                :padding '((lh 1) (ch 2))
                :item-gap '(lh 0)
                :on-press (when href
                            (lambda () (etaf-md-follow-link env href)))
          (expr (list (etaf-md--media-picture src view-env inner 14)))
          (expr
           (when (or title description)
             (append
              (list (etaf-node 'text nil (list " ")))
              (when title
                (list (etaf-node 'text (list :font-weight 'bold) (list title))))
              (when description
                (list (etaf-node 'text
                                 (list :color (etaf-md--component-ink env :muted))
                                 (list description))))))))))))

(etaf-md--define-shipped 'link-card
  :name "link-card"
  :summary "一张整块可点的链接卡片"
  :attrs '((href        :type string :required t :doc "跳转地址")
           (title       :type string :required t :doc "卡片标题")
           (description :type string :doc "标题下的说明"))
  :view
  (lambda (env)
    (let ((href (etaf-md-attr env :href))
          (title (etaf-md-attr env :title))
          (description (etaf-md-attr env :description)))
      (etaf-view
        (column :width 'stretch
                :background-color (etaf-md-surface env 'raised)
                :border (etaf-md--hairline env)
                :padding '((lh 1) (ch 2))
                :item-gap '(lh 0)
                :on-press (lambda () (etaf-md-follow-link env href))
          (expr (list (etaf-node 'text (list :font-weight 'bold) (list title))))
          (expr (list (etaf-node 'text nil (list " "))))
          (expr (when description
                  (list (etaf-node 'text
                                   (list :color (etaf-md--component-ink env :muted))
                                   (list description)))))
          (expr (list (etaf-node 'text
                                 (list :color (etaf-md-accent env 'primary)
                                       :role 'link :tab-index 0)
                                 (list (format "→ %s" href))))))))))

(etaf-md--define-shipped 'npm-badge
  :name "npm-badge"
  :summary "一行静态 npm 徽章：名称、版本与下载量"
  :attrs '((name      :type string :required t :doc "包名")
           (version   :type string :doc "版本号，省略就不画")
           (downloads :type string :doc "下载量文字，省略就不画"))
  :view
  (lambda (env)
    (let ((name (etaf-md-attr env :name))
          (version (etaf-md-attr env :version))
          (downloads (etaf-md-attr env :downloads)))
      (etaf-view
        (row :item-gap '(ch 1) :width 'max-content
          (etaf-badge :text "npm" :variant 'info)
          (etaf-badge :text name :variant 'neutral)
          (expr (when version
                  (list (etaf-view
                          (etaf-badge :text (format "v%s" version)
                                      :variant 'success)))))
          (expr (when downloads
                  (list (etaf-view
                          (etaf-badge :text (format "↓ %s" downloads)
                                      :variant 'neutral))))))))))

;;; ---------------------------------------------------------------------------
;;; A bar plot
;;; ---------------------------------------------------------------------------

(defun etaf-md--plot-values (env)
  "Return ENV's values as a list of numbers, in document order."
  (let ((values (etaf-md-attr env :values)))
    (mapcar #'string-to-number
            (seq-filter (lambda (value) (not (string-empty-p value)))
                        (split-string (or values "") "[, \t\n]+")))))

(defconst etaf-md--plot-bar-width 24
  "Columns the bar of one plot row occupies.")

(defun etaf-md--plot-line (env label value max accent)
  "Return one bar row of LABEL at VALUE out of MAX in ACCENT.
The bar is a run of spaces carrying the fill, drawn inside the row's text:
a text line keeps its own height, and the label, the bar and the value stay
on the same baseline at every width."
  (let* ((percent (if (<= max 0) 0 (max 0 (min 100 (* 100.0 (/ value max))))))
         (filled (if (> value 0)
                     (max 1 (round (* etaf-md--plot-bar-width percent 0.01)))
                   0))
         (empty (max 0 (- etaf-md--plot-bar-width filled)))
         (label-text (truncate-string-to-width (or label "") 10 nil nil "…"))
         (label-pad (concat label-text
                            (make-string (max 0 (- 10 (string-width label-text))) ?\s)
                            " "))
         (fill (etaf-md-accent env accent))
         ;; The track is the page itself: a dark panel behind a whole bar row
         ;; reads as a block, and the length of the bar already tells the value.
         (track (etaf-md-surface env 'page))
         (bar (concat (when (> filled 0)
                        (propertize (make-string filled ?\s)
                                    'face (list :background fill)))
                      (propertize (make-string empty ?\s)
                                  'face (list :background track)))))
    (etaf-view
      (text (expr (concat label-pad bar " "
                          (format "%6s" (format "%.4g" value))))))))

(etaf-md--define-shipped 'plot
  :name "plot"
  :summary "横向条形图，每行一条数值"
  :attrs '((values :type string :required t :doc "逗号或空格分隔的数值")
           (labels :type string :doc "逗号分隔的标签，省略用序号")
           (max    :type number :doc "横轴最大值，省略取数值里的最大者")
           (accent :type accent :default primary :doc "条形的强调色"))
  :view
  (lambda (env)
    (let* ((values (etaf-md--plot-values env))
           (labels (mapcar #'string-trim
                           (seq-filter (lambda (label) (not (string-empty-p label)))
                                       (split-string (or (etaf-md-attr env :labels) "")
                                                     ","))))
           (max (or (etaf-md-attr env :max)
                    (seq-max (or values (list 1)))))
           (max (if (> max 0) max 1))
           (accent (etaf-md-attr env :accent)))
      (etaf-view
        (column :width 'stretch :item-gap '(lh 0)
          (expr
           (seq-map-indexed
            (lambda (value index)
              (etaf-md--plot-line env
                                  (or (nth index labels) (format "%d" (1+ index)))
                                  value max accent))
            values)))))))

;;; ---------------------------------------------------------------------------
;;; The QR code
;;; ---------------------------------------------------------------------------

(etaf-md--define-shipped 'qrcode
  :name "qrcode"
  :summary "把一段文本画成可扫描的二维码"
  :attrs '((text  :type string :required t :doc "要编码的文本")
           (title :type string :doc "二维码上方的说明"))
  :view
  (lambda (env)
    (let ((title (etaf-md-attr env :title)))
      (etaf-view
        (column :width 'stretch :cross-align 'center :item-gap '(lh 0)
          (expr (when title
                  (list (etaf-node 'text
                                   (list :color (etaf-md--component-ink env :muted)
                                         :font-weight 'bold)
                                   (list title)))))
          (box :width 'max-content :background-color "#FFFFFF"
               :padding '((lh 0) (ch 1))
            (text (expr (etaf-md-qrcode-view env))))
          (expr (unless (etaf-md-qrcode-cached-p env)
                  (list (etaf-node 'text
                                   (list :color (etaf-md--component-ink env :faint))
                                   (list (if (etaf-md-qrcode-available-p)
                                             "（二维码生成中）"
                                           "（需要 qrencode 才能画出二维码）")))))))))))

;;; ---------------------------------------------------------------------------
;;; The slide deck
;;; ---------------------------------------------------------------------------

(etaf-md--define-shipped 'swiper
  :name "swiper"
  :summary "轮播：一页一页翻，标题或序号组成下面的切换条"
  :accepts '((slide :attrs ((title    :type string :doc "切换条上的文字")
                            (selected :type boolean :default nil :doc "默认停在这一页"))))
  :child-syntax 'markers
  :view
  (lambda (env)
    (let* ((slides (etaf-md-children env))
           (count (length slides))
           (initial (or (cl-position-if
                         (lambda (slide) (etaf-md-attr env :selected slide))
                         slides)
                        0))
           (active (min (or (etaf-md-block-state env :active initial) 0)
                        (max 0 (1- count))))
           (slide (nth active slides))
           (picture (etaf-md--swiper-slide-picture env slide))
           (view-env (etaf-md--component-view-env env)))
      (etaf-view
        (column :width 'stretch :item-gap '(lh 0)
                :border (etaf-md--hairline env)
          (etaf-tabs
           :items (seq-map-indexed
                   (lambda (slide index)
                     (list :key index
                           :label (or (etaf-md-attr env :title slide)
                                      (format "%d/%d" (1+ index) count))))
                   slides)
           :active active
           :framed nil
           :on-change (lambda (key) (etaf-md-set-block-state env :active key)))
          (box :width 'stretch
               :background-color (etaf-md-surface env 'sunken)
               :border-top (etaf-md--hairline env)
               :padding '((lh 1) (ch 2))
            (expr
             (if picture
                 (list (etaf-node 'column
                                  (list :width 'stretch :cross-align 'center)
                                  (list (etaf-md--media-picture
                                         picture view-env
                                         (max 8 (- (etaf-md-env-width env) 8))
                                         12))))
               (list (etaf-md--child-view env slide))))))))))

(defun etaf-md--swiper-slide-picture (env slide)
  "Return SLIDE's single image URL when the slide holds only that picture.
A slide written as one image line is a picture, not a figure: the stage draws
it without a second frame or caption inside itself."
  (let ((children (etaf-md-children env slide)))
    (when (= 1 (length children))
      (let* ((block (etaf-md-node-block (car children))))
        (when (eq (plist-get block :type) 'paragraph)
          (let ((images (seq-filter (lambda (node)
                                      (eq (plist-get node :type) 'image))
                                    (plist-get block :children))))
            (when (= 1 (length images))
              (plist-get (car images) :url))))))))

(defun etaf-md--code-tree-view (env)
  "Paint a file list beside the selected file's code."
  (let* ((files (etaf-md-children env))
         (count (length files))
         (active (min (or (etaf-md-block-state env :active 0) 0) (max 0 (1- count))))
         (selected (nth active files))
         (width (max 12 (min 30
                             (+ 3 (seq-max (mapcar (lambda (file)
                                                     (length (or (etaf-md-attr env :title file) "")))
                                                   files))))))
         (accent (etaf-md-accent env 'primary))
         (accent-soft (or (etaf-md--palette-value (etaf-md-env-palette env) :accent-soft)
                          (etaf-md-surface env 'raised)))
         (muted (etaf-md--component-ink env :muted)))
    (etaf-view
      (column :width 'stretch :item-gap '(lh 0)
        (expr (when-let* ((title (etaf-md-attr env :title)))
                (list (etaf-node 'text
                                 (list :font-weight 'bold :color muted)
                                 (list title)))))
        (expr (when (etaf-md-attr env :title)
                (list (etaf-node 'text nil (list " ")))))
        (row :width 'stretch :item-gap '(ch 0)
          (column :width (list 'ch width) :item-gap '(lh 0)
            (expr
             (seq-map-indexed
              (lambda (file index)
                (let ((name (or (etaf-md-attr env :title file) "")))
                  (etaf-node 'box
                             (list :width 'stretch
                                   :padding-inline '(ch 1)
                                   :background-color (when (= index active) accent-soft)
                                   :role 'button :tab-index 0
                                   :on-press (lambda ()
                                               (etaf-md-set-block-state env :active index)))
                             (list (etaf-node 'text
                                              (list :color (if (= index active) accent muted)
                                                    :font-weight (if (= index active) 'bold nil))
                                              (list name))))))
              files)))
          (box :width 'stretch
            (expr (when selected (etaf-md--code-tab-page env selected)))))))))

(etaf-md--define-shipped 'code-tree
  :name "code-tree"
  :summary "左边文件列表，右边选中文件的代码"
  :attrs '((title :type string :doc "文件列表上方的标题"))
  :accepts '((file :attrs ((title :type string :required t :doc "文件路径"))))
  :child-syntax 'markers
  :view #'etaf-md--code-tree-view)

;;; ---------------------------------------------------------------------------
;;; npm commands in every package manager
;;; ---------------------------------------------------------------------------

(defconst etaf-md--npm-to-managers
  '((npm . "npm") (pnpm . "pnpm") (yarn . "yarn") (bun . "bun") (deno . "deno"))
  "Package managers `npm-to' can write, in their default order.")

(defun etaf-md--npm-to-rewrite (command manager)
  "Return an npm COMMAND written for MANAGER.
Only the commands the site lists are rewritten; anything else is copied
unchanged, so a mixed script keeps its shape.  The rewrite never inspects
the match data of its caller."
  (save-match-data
    (let* ((no-args (string-match-p "\\`npm +install *\\'" command))
           (install (string-match "\\`npm +\\(?:install\\|i\\|add\\) +\\(.+\\)\\'" command))
           (run (string-match "\\`npm +\\(?:run-script\\|run\\) +\\(.+\\)\\'" command))
           (remove (string-match "\\`npm +\\(?:uninstall\\|remove\\|rm\\|un\\|unlink\\|r\\) +\\(.+\\)\\'" command))
           (create (string-match "\\`npm +create +\\(.+\\)\\'" command))
           (init (string-match-p "\\`npm +init *\\'" command))
           (ci (string-match-p "\\`npm +ci *\\'" command))
           (npx (string-match "\\`npx +\\(.+\\)\\'" command)))
      (cond
       (no-args (pcase manager
                  ('yarn "yarn") ('pnpm "pnpm install")
                  ('bun "bun install") ('deno "deno install")
                  (_ "npm install")))
       (install (let ((args (match-string 1 command)))
                  (pcase manager
                    ('yarn (format "yarn add %s" args))
                    ('pnpm (format "pnpm add %s" args))
                    ('bun (format "bun add %s" args))
                    ('deno (format "deno add %s" args))
                    (_ command))))
       (run (let ((script (match-string 1 command)))
              (pcase manager
                ('yarn (format "yarn %s" script))
                ('pnpm (format "pnpm %s" script))
                ('bun (format "bun run %s" script))
                ('deno (format "deno task %s" script))
                (_ command))))
       (remove (let ((args (match-string 1 command)))
                 (pcase manager
                   ('yarn (format "yarn remove %s" args))
                   ('pnpm (format "pnpm remove %s" args))
                   ('bun (format "bun remove %s" args))
                   ('deno (format "deno remove %s" args))
                   (_ command))))
       (create (let ((args (match-string 1 command)))
                 (pcase manager
                   ('yarn (format "yarn create %s" args))
                   ('pnpm (format "pnpm create %s" args))
                   ('bun (format "bun create %s" args))
                   ('deno (format "deno create %s" args))
                   (_ command))))
       (init (pcase manager
               ('yarn "yarn init") ('pnpm "pnpm init")
               ('bun "bun init") ('deno "deno init")
               (_ "npm init")))
       (ci (pcase manager
             ('yarn "yarn install --immutable")
             ('pnpm "pnpm install --frozen-lockfile")
             ('bun "bun install --frozen-lockfile")
             ('deno "deno install --frozen")
             (_ command)))
       (npx (let ((args (match-string 1 command)))
              (pcase manager
                ('yarn (format "yarn dlx %s" args))
                ('pnpm (format "pnpm dlx %s" args))
                ('bun (format "bunx %s" args))
                ('deno (format "deno run %s" args))
                (_ command))))
       (t command)))))

(defun etaf-md--npm-to-script (text manager)
  "Return the shell TEXT rewritten for MANAGER, command by command."
  (mapconcat
   (lambda (line)
     (mapconcat (lambda (part) (etaf-md--npm-to-rewrite part manager))
                (split-string line "&&" nil " ")
                "&&"))
   (split-string text "\n")
   "\n"))

(defun etaf-md--npm-to-view (env)
  "Paint one npm command as the package managers' code tabs.
The block holds a single fence; the selected manager's rewritten command is
shown under a strip that names every manager the `tabs' attribute lists."
  (let* ((children (etaf-md-children env))
         (block (and children (etaf-md-node-block (car children))))
         (source (or (plist-get block :text) ""))
         (requested (or (etaf-md-attr env :tabs) "npm,pnpm,yarn,bun,deno"))
         (managers (seq-filter
                    (lambda (name) (assoc name etaf-md--npm-to-managers))
                    (mapcar #'intern (split-string requested "," t "[ \t]+"))))
         (managers (or managers (mapcar #'car etaf-md--npm-to-managers)))
         (active (min (or (etaf-md-block-state env :active 0) 0)
                      (max 0 (1- (length managers)))))
         (manager (nth active managers))
         (synthetic (list :type 'code-block
                          :lang (or (plist-get block :lang) "sh")
                          ;; The strip already names the tool; the fence's own
                          ;; language row would name it a second time.
                          :header nil
                          :text (etaf-md--npm-to-script source manager))))
    (etaf-view
      (column :width 'stretch :item-gap '(lh 0)
              :border (etaf-md--hairline env)
        (etaf-tabs
         :items (seq-map-indexed
                 (lambda (name index)
                   (list :key index
                         :label (cdr (assoc name etaf-md--npm-to-managers))))
                 managers)
         :active active
         :framed nil
         :on-change (lambda (key) (etaf-md-set-block-state env :active key)))
        (box :width 'stretch :padding '((lh 1) (ch 2))
             :border-top (etaf-md--hairline env)
          (expr (etaf-ui-markdown-view-block
                 synthetic
                 (list :theme (etaf-md-env-theme env)
                       :palette (etaf-md-env-palette env)
                       :width (etaf-md-env-width env)))))))))

(etaf-md--define-shipped 'npm-to
  :name "npm-to"
  :summary "写一条 npm 命令，换成各包管理器的写法"
  :attrs '((tabs :type string :doc "要显示的包管理器，逗号分隔"))
  :view #'etaf-md--npm-to-view)

(provide 'etaf-md-components)

;;; etaf-md-components.el ends here
