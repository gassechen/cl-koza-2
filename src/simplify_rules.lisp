(defpackage #:gp.simplify-rules
  (:use #:cl
        #:gp.functions
        #:gp.simplify
        )
  (:export #:*boolean-rules*
           #:*algebraic-rules*
           ))

(in-package #:gp.simplify-rules)

;;; Boolean Rule base.

(defvar *boolean-rules* nil
  "The rule base for Boolean problems.")

;;; Transforms expressions of the form (not (not <xxx>)) into ;;; <xxx>.
(def-edit-rule not-not-x->-x *boolean-rules* (sexpression)
               :condition (and (consp sexpression)
                               (consp (second sexpression))
                               (eq (first sexpression) 'not)
                               (eq (first (second sexpression)) 'not))
               :action (replace-sexpression (second (second sexpression))))

;;; Transforms expressions of the form (or <xxx> t) into t.
(def-edit-rule or-t->-t *boolean-rules* (sexpression)
               :condition (and (consp sexpression)
                               (eq 'or (first sexpression))
                               (dolist (arg (rest sexpression) nil)
                                 (when (and (constant-expression-p arg)
                                            (eval arg))
                                   (return t))))
               :action (replace-sexpression t))

;;; Transforms expressions of the form (and nil <xxx>) into nil.
(def-edit-rule and-nil->-nil *boolean-rules* (sexpression)
               :condition (and (consp sexpression)
                               (eq 'and (first sexpression))
                               (dolist (arg (rest sexpression) nil)
                                 (when (and (constant-expression-p arg)
                                            (not (eval arg)))
                                   (return t))))
               :action (replace-sexpression nil))

;;; Transforms expressions of the form (and t <xxx>) into <xxx>.
(def-edit-rule and-t->-x *boolean-rules* (sexpression)
               :condition (and (consp sexpression)
                               (eq 'and (first sexpression))
                               (dolist (arg (rest sexpression) nil)
                                 (when (and (constant-expression-p arg)
                                            (eval arg))
                                   (return t))))
               :action (let ((remaining-args
                              (remove-if #'(lambda (arg)
                                             (and (constant-expression-p arg)
                                                  (eval arg)))
                                         (rest sexpression))))
                         (replace-sexpression
                          (case (length remaining-args)
                            (0 t)
                            (1 (first remaining-args))
                            (otherwise (cons 'and remaining-args))))))

;;; Transforms expressions of the form (or <xxx> nil) into
;;; <xxx>.
(def-edit-rule or-nil->-x *boolean-rules* (sexpression)
               :condition (and (consp sexpression)
                               (eq 'or (first sexpression))
                               (dolist (arg (rest sexpression) nil)
                                 (when (and (constant-expression-p arg)
                                            (not (eval arg)))
                                   (return t))))
               :action (let ((remaining-args
                              (remove-if #'(lambda (arg)
                                             (and (constant-expression-p arg)
                                                  (not (eval arg))))
                                         (rest sexpression))))
                         (replace-sexpression
                          (case (length remaining-args)
                            (0 nil)
                            (1 (first remaining-args))
                            (otherwise (cons 'or remaining-args))))))

;;; Combines calls to AND and OR into their polyadic forms, so
;;; (and (and <xxx> <yyy>) <zzz>) will be transformed into (and
;;; <xxx> <yyy> <zzz>).
(def-edit-rule polyadicize *boolean-rules* (sexpression)
               :condition (and (consp sexpression)
                               (member (first sexpression) '(and or)
                                       :test #'eq)
                               (dolist (arg (rest sexpression) nil)
                                 (when (and (consp arg)
                                            (eq (first arg)
                                                (first sexpression)))
                                   (return t))))
               :action (let ((interesting-arg
                              (dolist (arg (rest sexpression) nil)
                                (when (and (consp arg)
                                           (eq (first arg)
                                               (first sexpression)))
                                  (return arg)))))
                         (replace-sexpression
                          (cons (first sexpression)
                                (append (rest interesting-arg)
                                        (remove interesting-arg
                                                (rest sexpression)))))))

;;; Transforms expressions of the form (and <xxx> <xxx>) into
;;; <xxx>.
;;; Rule added by GM
(def-edit-rule and-x-x->-x *boolean-rules* (sexpression)
               :condition (and (consp sexpression)
                               (eq 'and (first sexpression))
                               (= (length sexpression) 3)
                               (symbolp (second sexpression))
                               (symbolp (third sexpression))
                               (eq (second sexpression) (third sexpression)))
               :action (replace-sexpression (second sexpression)))

;;; Transforms expressions of the form (and <xxx> <xxx> <yyy>) into
;;; (and <xxx> <yyy>).
(def-edit-rule and-dedup *boolean-rules* (sexpression)
               :condition (and (consp sexpression)
                               (eq 'and (first sexpression)))
               :action (replace-sexpression (cons 'and (remove-duplicates (rest sexpression)))))

;;; Transforms expressions of the form (or <xxx> <xxx> <yyy>) into
;;; (or <xxx> <yyy>).
(def-edit-rule or-dedup *boolean-rules* (sexpression)
               :condition (and (consp sexpression)
                               (eq 'or (first sexpression)))
               :action (replace-sexpression (cons 'or (remove-duplicates (rest sexpression) :from-end t))))

;;; Algebraic Rule base.

(defvar *algebraic-rules* nil
  "The rule base for Algebraic problems.")

;;; Transforms expressions of the form (+ <xxx> 0) into <xxx>.
(def-edit-rule x+0->x *algebraic-rules* (sexpression)
               :condition (and (consp sexpression)
                               (eq '+ (first sexpression))
                               (dolist (arg (rest sexpression) nil)
                                 (when (and (constant-expression-p arg)
                                            (eq arg 0))
                                   (return t))))
               :action (let ((remaining-args
                              (remove-if #'(lambda (arg)
                                             (and (constant-expression-p arg)
                                                  (eq arg 0)))
                                         (rest sexpression))))
                         (replace-sexpression
                          (case (length remaining-args)
                            (0 0)
                            (1 (first remaining-args))
                            (otherwise (cons '+ remaining-args))))))

;;; Transforms expressions of the form (* 0 <xxx>) into ;;; 0.
(def-edit-rule 0*x->0 *algebraic-rules* (sexpression)
               :condition (and (consp sexpression)
                               (eq '* (first sexpression))
                               (dolist (arg (rest sexpression) nil)
                                 (when (and (constant-expression-p arg)
                                            (eq arg 0))
                                   (return t))))
               :action (replace-sexpression 0))

;;; Transforms expressions of the form (* 1 <xxx>) into ;;; <xxx>.
(def-edit-rule 1*x->x *algebraic-rules* (sexpression)
               :condition (and (consp sexpression)
                               (eq '* (first sexpression))
                               (dolist (arg (rest sexpression) nil)
                                 (when (and (constant-expression-p arg)
                                            (eq arg 1))
                                   (return t))))
               :action (let ((remaining-args
                              (remove-if #'(lambda (arg)
                                             (and (constant-expression-p arg)
                                                  (eq arg 1)))
                                         (rest sexpression))))
                         (replace-sexpression
                          (case (length remaining-args)
                            (0 1)
                            (1 (first remaining-args))
                            (otherwise (cons '* remaining-args))))))

;;; Transforms expressions of the form (% <xxx> <xxx>) into ;;; 1.
(def-edit-rule x%x->1 *algebraic-rules* (sexpression)
               :condition (and (consp sexpression)
                               (eq '% (first sexpression))
                               (= (length sexpression) 3)
                               (symbolp (second sexpression))
                               (symbolp (third sexpression))
                               (eq (second sexpression) (third sexpression)))
               :action (replace-sexpression 1))

;;; Combines calls to + and * into their polyadic forms, so
;;; (* (* <xxx> <yyy>) <zzz>) will be transformed into (* <xxx> <yyy> <zzz>).
(def-edit-rule polyadicize *algebraic-rules* (sexpression)
               :condition (and (consp sexpression)
                               (member (first sexpression) '(* +)
                                       :test #'eq)
                               (dolist (arg (rest sexpression) nil)
                                 (when (and (consp arg)
                                            (eq (first arg)
                                                (first sexpression)))
                                   (return t))))
               :action (let ((interesting-arg
                              (dolist (arg (rest sexpression) nil)
                                (when (and (consp arg)
                                           (eq (first arg)
                                               (first sexpression)))
                                  (return arg)))))
                         (replace-sexpression
                          (cons (first sexpression)
                                (append (rest interesting-arg)
                                        (remove interesting-arg
                                                (rest sexpression)))))))

;;; Transforms expressions of the form (- <xxx> <xxx>) into ;;; 0.
(def-edit-rule x-x->0 *algebraic-rules* (sexpression)
               :condition (and (consp sexpression)
                               (eq '- (first sexpression))
                               (= (length sexpression) 3)
                               (symbolp (second sexpression))
                               (symbolp (third sexpression))
                               (eq (second sexpression) (third sexpression)))
               :action (replace-sexpression 0))

;;; Transforms expressions of the form (- <xxx> 0) into ;;; <xxx>.
(def-edit-rule x-0->x *algebraic-rules* (sexpression)
               :condition (and (consp sexpression)
                               (eq '- (first sexpression))
                               (= (length sexpression) 3)
                               (symbolp (second sexpression))
                               (numberp (third sexpression))
                               (eq 0 (third sexpression)))
               :action (replace-sexpression (second sexpression)))

;;; Transforms expressions of the form (- <xxx> 0) into ;;; <xxx>.
(def-edit-rule x+x->2*x *algebraic-rules* (sexpression)
               :condition (and (consp sexpression)
                               (eq '+ (first sexpression))
                               (= (length sexpression) 3)
                               (symbolp (second sexpression))
                               (symbolp (third sexpression))
                               (eq (second sexpression) (third sexpression)))
               :action (replace-sexpression (list '* 2 (second sexpression))))

;;; Transforms expressions of the form (op number number) into ;;; result.
(def-edit-rule num-op-num->result *algebraic-rules* (sexpression)
               :condition (and (consp sexpression)
                               (member (first sexpression) '(% * + -)
                                       :test #'eq)
                               (= (length sexpression) 3)
                               (numberp (second sexpression))
                               (numberp (third sexpression)))
               :action (replace-sexpression (eval sexpression)))

;;; Transforms expressions of the form (% <xxx> (% <yyy> <zzz>)) into ;;; (% (* <xxx> <zzz>) <yyy>)
;; (def-edit-rule %-x-%-y-z->res *algebraic-rules* (sexpression)
;;                :condition (and (consp sexpression)
;;                                (eq '% (first sexpression))
;;                                (= (length sexpression) 3)
;;                                (consp (third sexpression))
;;                                (eq '% (first (third sexpression)))
;;                                (= (length (third sexpression)) 3))
;;                :action (replace-sexpression (list '%
;;                                                   (list '*
;;                                                         (second sexpression)
;;                                                         (third (third sexpression)))
;;                                                   (second (third sexpression)))))
