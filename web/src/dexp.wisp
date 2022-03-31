;; -*- mode: wisp; fill-column: 64; -*-
;;
;; SPDX-License-Identifier: AGPL-3.0-or-later


;;; * Basic binding to Incremental DOM

(defun make-callback (symbol)
  (dom-make-callback
   (package-name (symbol-package symbol))
   (symbol-name symbol)))

(defmacro tag (tag-symbol attrs &rest body)
  (let ((tag-name (symbol-name tag-symbol)))
    `(progn
       (idom-open-start! ,tag-name)
       (for-each ,attrs
         (fn (attr)
           (idom-attr! (symbol-name (head attr))
                      (second attr))))
       (idom-open-end!)
       ,@body
       (idom-close! ,tag-name))))

(defun text (text)
  (idom-text! text))


;;; * D-expressions

(defun-noexpand render-sexp (sexp)
  (cond
    ((nil? sexp)
     (tag :div '((:class "list")) nil))
    ((symbol? sexp)
     (tag :span `((:class "symbol")
                  (:data-package-name
                   ,(package-name
                     (symbol-package sexp)))
                  (:data-symbol-name
                   ,(symbol-name sexp))
                  (:data-function-kind
                   ,(if (symbol-function sexp)
                        (if (jet? (symbol-function sexp))
                            "jet" "fun")
                      "")))
       (cond
         ((eq? sexp 'todo)
          (tag :input '((:type "checkbox")) nil))
         ((eq? sexp 'done)
          (tag :input '((:type "checkbox")
                        (:checked "checked")) nil))
         (t
          (progn
            (tag :span '((:class "package-name"))
              (text (package-name (symbol-package sexp))))
            (tag :span '((:class "symbol-name"))
              (text (symbol-name sexp))))))))
    ((pair? sexp)
     (tag :div `((:class "list")
                 (:data-callee ,(if (symbol? (head sexp))
                                    (string-append
                                     (package-name (symbol-package (head sexp)))
                                     ":"
                                     (symbol-name (head sexp)))
                                  "")))
       (render-list-contents sexp)))
    ((string? sexp)
     (tag :span '((:class "string"))
       (text sexp)))
    ((integer? sexp)
     (tag :span '((:class "number"))
       (text (print-to-string sexp))))
    ((eq? 'vector (type-of sexp))
     (tag :div '((:class "vector"))
       (render-vector-contents sexp 0)))
    ((eq? 'function (type-of sexp))
     (tag :i () (text "function")))
    ))

(defun render-list-contents (sexp)
  (unless (nil? sexp)
    (render-sexp (head sexp))
    (let ((tail (tail sexp)))
      (if (list? tail)
          (render-list-contents tail)
        (progn
          (tag :span '((:class "dot"))
            (text "·"))
          (render-sexp tail))))))

(defun vector-each (vector function)
  (vector-each-loop vector function 0))

(defun vector-each-loop (vector function i)
  (when (< i (vector-length vector))
    (call function (vector-get vector i))
    (vector-each-loop vector function (+ i 1))))

(defun render-vector-contents (vector i)
  (vector-each vector #'render-sexp))

(defun draw-app ()
  (tag :style () (text "
    #wisp-app { margin: 10px; }

    .symbol { text-transform: lowercase; }

    .string, .number { font-family: 'DM Mono', monospace; }
    .string:before { content: '“'; }
    .string:after { content: '”'; }

    .list > [data-function-kind=jet]:first-of-type { color: goldenrod; }
    .list > [data-function-kind=fun]:first-of-type { color: lightsalmon; }

    .vector, .list {
      display: flex;
      flex-wrap: wrap;
      gap: 5px;
      align-items: center;
      margin: 0 5px;
      padding: 0 5px;
      max-width: 60ch;
      min-height: 1em;
    }

    .list[data-callee='WISP:COND'] > :not(.cursor) {
      width: 100%;
    }

    .list[data-callee='WISP:DEFUN'] > div:first-of-type ~ :not(.cursor),
    .list[data-callee='WISP:NOTE'] > div:first-of-type ~ :not(.cursor)
    {
      width: 100%;
    }

    .symbol[data-package-name=WISP] > .package-name { display: none; }
    .symbol[data-package-name=KEYWORD] > .package-name { display: none; }

    .package-name:after,
    .symbol[data-package-name=KEYWORD] > .symbol-name:before {
      content: \":\";
      opacity: 0.7;
      padding-right: 1px;
    }

    .list { border-color: #555; border-width: 0 2px; border-radius: 10px; }
    .vector { border-color: #558; border-width: 1px; }

    @keyframes blink {
      0%, 100% { background: #ffa8 } 50% { background: #ffaa }
    }

    .cursor:empty:before {
      content: ' ';
      height: 6px; width: 6px; border-radius: 100%;
      animation: blink 1s infinite;
    }

    .cursor {
      display: inline-flex; flex-wrap: wrap; align-items: center; gap: 5px;
    }

    .cursor:not(:empty) {
      background: #63ffeb40; border-radius: 5px;
      margin: 0 5px; padding: 0 5px;
    }

    ins { text-decoration: none; }

    article {
      display: flex;
      justify-content: space-between;
    }

    header > .list { flex-direction: column; align-items: end; }
  "))
  (tag :article ()
    (tag :main ()
      (tag :div '((:style "display: inline-flex; flex-direction: column; gap: 10px"))
        (tag :ins '((:class "cursor")) nil)
        (render-sexp '(defun foo () (+ 1 2 (* 3 4))))
        (render-sexp
         '(note (:march 31 2022)
           (done implement inserting in structural editor)
           (todo structure to code string)
           (todo evaluating expressions)
           (todo saving file)))
        (render-sexp
         '(note (:march 29 2002)
           (done implement structural editor)
           (done play around)
           (todo buy bananas)))

        (render-sexp
         '(defun toggle (item)
           (cond
             ((eq? item 'todo) 'done)
             ((eq? item 'done) 'todo))))))

    (tag :header '((:id "eval-output")) nil))

  (progn
    (idom-patch!
     (query-selector "#eval-output")
     *render-sexp-callback* *eval-output*)
    (set! *cursor-element* (query-selector ".cursor"))
    (dom-cursor-step! *cursor-element* 0 nil nil)
    (print (list :cursor-element *cursor-element*))))

(defvar *eval-output* '(1 2 3))
(defvar *root-element* (query-selector "#wisp-app"))
(defvar *key-callback* (make-callback 'on-keydown))
(defvar *insert-callback* (make-callback 'on-insert))
(defvar *render-callback* (make-callback 'draw-app))
(defvar *render-sexp-callback* (make-callback 'do-render-sexp))
(defvar *cursor-element* nil)

(defun render-app ()
  (with-simple-error-handler ()
    (idom-patch! *root-element* *render-callback* nil)))

(defun %vector-element-bindings (vector names)
  (let ((i 0))
    (map (fn (name)
           (returning `(,name (vector-get ,vector ,i))
             (set! i (+ i 1)))) names)))

(defmacro with-vector-elements (vector names &rest body)
  (let (($vector (fresh-symbol!)))
    `(let ((,$vector ,vector))
       (let ,(%vector-element-bindings $vector names)
         ,(prognify body)))))

(defun on-keydown (key-info)
  (with-simple-error-handler ()
    (with-vector-elements key-info (key control? shift? alt? meta? repeat?)
      (print (list 'keydown key control? shift? alt? meta? repeat?))
      (cond
        ((or (string-equal? key "ArrowRight")
             (string-equal? key "f")
             (string-equal? key "F"))
         (dom-cursor-step! *cursor-element* 0 control? shift?))
        ((or (string-equal? key "ArrowLeft")
             (string-equal? key "b")
             (string-equal? key "B"))
         (dom-cursor-step! *cursor-element* 1 control? shift?))
        ((or (string-equal? key "ArrowUp")
            (string-equal? key "p"))
         (dom-cursor-step! *cursor-element* 2 nil nil))
        ((or (string-equal? key "ArrowDown")
             (string-equal? key "n"))
         (dom-cursor-step! *cursor-element* 3 nil nil))
        ((string-equal? key "t")
         (dom-cursor-step! *cursor-element* 4 nil nil))
        ((string-equal? key "k")
         (dom-cursor-step! *cursor-element* 5 nil nil))
        ((string-equal? key "d")
         (dom-cursor-step! *cursor-element* 6 nil nil))
        ((string-equal? key "Escape")
         (dom-cursor-step! *cursor-element* 7 nil nil))
        ((string-equal? key "i")
         (dom-cursor-step! *cursor-element* 8 nil nil))
        ((string-equal? key "e")
         (dom-cursor-step! *cursor-element* 9 nil nil))
        ((string-equal? key "(")
         (progn
           (on-insert "()")
           (dom-cursor-step! *cursor-element* 1 nil nil)))
        (t t)))))

(defun do-render-sexp (sexp)
  (with-simple-error-handler ()
    (print (list 'render sexp))
    (render-sexp sexp)))

(defun on-insert (code)
  (with-simple-error-handler ()
    (let ((expr (read-from-string code)))
      (progn
        (print (list 'expr expr))
        (dom-remove-children! *cursor-element*)
        (idom-patch! *cursor-element* *render-sexp-callback* expr)
        (dom-cursor-step! *cursor-element* 7 nil nil)))))

(defmacro note (date &rest notes)
  `(quote (note ,date ,@notes)))

(defun do-eval (expr)
  (with-simple-error-handler ()
    (set! *eval-output* (cons (eval expr) *eval-output*))
    (idom-patch!
     (query-selector "#eval-output")
     *render-sexp-callback* *eval-output*)))

(with-simple-error-handler ()
  (dom-on-keydown! *key-callback*)
  (dom-on-window-event! "wisp-insert" *insert-callback*)
  (dom-on-window-event! "wisp-eval" (make-callback 'do-eval))
  (render-app))
