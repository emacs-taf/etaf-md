;;; etaf-md-nodes.el --- Shipped node definitions -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;;
;; The definitions the package ships, written the same way a reader writes one:
;; attributes, then a paint.  A paint reads only its environment, so it never
;; touches a session, a file or a global.
;;
;; Order matters: a container's children are painted by the definitions that
;; come before it in this file only at run time, so the file may declare them
;; in any order and it reads best grouped by family.

;;; Code:

(require 'cl-lib)
(require 'seq)
(require 'etaf-md-env)

;;; Structure

(etaf-md--define-shipped 'box
  :name "box"
  :summary "带底色与内边距的容器"
  :attrs '((surface :type surface :default none  :doc "外壳底色")
           (padding :type length  :default "2ch" :doc "左右内边距")
           (width   :type length                 :doc "自身宽度"))
  :view (lambda (env)
          (etaf-view
           (box :width (or (etaf-md-attr env :width) 'stretch)
                :padding (list '(lh 1) (etaf-md-attr env :padding))
                :background-color (etaf-md-surface env (etaf-md-attr env :surface))
             (expr (etaf-md-content env))))))

(etaf-md--define-shipped 'card
  :name "card"
  :summary "带标题与摘要的卡片"
  :attrs '((title       :type string :required t :pattern "[^[:space:]]" :doc "卡片标题")
           (description :type string                          :doc "标题下的一行")
           (href        :type string                          :doc "整张卡片可点")
           (accent      :type accent  :default neutral        :doc "标题的强调色")
           (text-align  :type align   :default start          :doc "内容的水平位置")
           (width       :type length                          :doc "自身宽度"))
  :view (lambda (env)
          (etaf-view
           (box :width (or (etaf-md-attr env :width) 'stretch)
                :text-align (etaf-md-attr env :text-align)
                :padding '((lh 1) (ch 2))
                :background-color (etaf-md-surface env 'raised)
                :border-left (list '(ch 1) 'solid
                                   (etaf-md-accent env (etaf-md-attr env :accent)))
             (column :item-gap '(lh 1)
               (text :font-weight 'bold
                     :color (etaf-md-accent env (etaf-md-attr env :accent))
                 (expr (etaf-md-attr env :title)))
               (expr (when-let* ((description (etaf-md-attr env :description)))
                       (etaf-view
                        (text :color (etaf-md-accent env 'neutral)
                          (expr description)))))
               (expr (etaf-md-content env)))))))

(etaf-md--define-shipped 'columns
  :name "columns"
  :summary "等宽分栏，窄窗减栏"
  :attrs '((columns :type number :default 2 :min 1 :max 6 :integer t
             :doc "一行几栏")
           (gap     :type length :default "2ch" :doc "栏间距"))
  :accepts '((col :attrs ((grow :type number :default 1 :doc "宽度份数"))))
  :view (lambda (env)
          (let* ((count (max 1 (etaf-md-attr env :columns)))
                 (gap (etaf-md-attr env :gap))
                 (width (etaf-md-available-width env))
                 (per (max 1 (min count (/ width 24))))
                 (rows (seq-partition (etaf-md-children env) per)))
            ;; The number of rows is only known while painting, so the rows are
            ;; built as nodes instead of being written out in the DSL.
            (etaf-node 'column
                       (list :width 'stretch :item-gap '(lh 1))
                       (mapcar
                        (lambda (row)
                          (etaf-node 'flex
                                     (list :width 'stretch
                                           :gap (list '(lh 0) gap))
                                     (mapcar
                                      (lambda (col)
                                        ;; A column is a declared child, not a
                                        ;; type of its own, so the parent paints
                                        ;; its content instead of asking for a
                                        ;; definition the child never has.
                                        (etaf-node 'column
                                                   (list :width 'stretch
                                                         :item-gap '(lh 0))
                                                   (list (etaf-md-render
                                                          env
                                                          (etaf-md-children env col)))))
                                      row)))
                        rows)))))


;;; Callouts

(defun etaf-md--callout-accent (type)
  "Return the accent word a callout TYPE fixes."
  (pcase type
    ('note 'primary)
    ('tip 'success)
    ('important 'important)
    ('warning 'warning)
    ('caution 'danger)
    (_ 'neutral)))

(defconst etaf-md--callout-titles
  '((note . "Note") (tip . "Tip") (important . "Important")
    (warning . "Warning") (caution . "Caution"))
  "The fixed title each callout name draws when the document gives none.")

(defun etaf-md--callout-view (env)
  "Paint a callout; the five names share this view."
  (let* ((type (etaf-md-type env))
         (accent (etaf-md--callout-accent type))
         (title (or (etaf-md-attr env :title)
                    (alist-get type etaf-md--callout-titles))))
    (etaf-view
     (box :width 'stretch
          :padding '((lh 1) (ch 2))
          :background-color (etaf-md-surface env (etaf-md-attr env :background))
          :border-left (list (etaf-md-attr env :border-left-width) 'solid
                             (etaf-md-accent env accent))
       (column :item-gap '(lh 1)
         (text :font-weight 'bold
               :color (etaf-md-accent env accent)
           (expr title))
         (expr (unless (and (etaf-md-attr env :collapsible)
                            (not (etaf-md-attr env :open)))
                 (etaf-md-content env))))))))

(dolist (type '(note tip important warning caution))
  (etaf-md--define-shipped type
    :name (symbol-name type)
    :summary "提示块，一个名字一个固定强调色"
    :attrs '((title            :type string  :doc "提示块的标题，省略用固定标题")
             (collapsible      :type boolean :default nil   :doc "允许收起")
             (open             :type boolean :default t     :doc "收起时默认展开")
             (background       :type surface :default quote :doc "底色")
             (border-left-width :type length :default "1ch" :doc "左侧竖条宽度"))
    :view #'etaf-md--callout-view))

;; Reader definitions load after the shipped ones, so :extends can rely
;; on them and a plain definition may still add a new type.
(etaf-md-load-node-directory)

(provide 'etaf-md-nodes)
;;; etaf-md-nodes.el ends here
