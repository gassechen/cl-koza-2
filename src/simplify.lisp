(defpackage #:gp.simplify
  (:use #:cl)
  (:export #:edit-top-level-sexpression
           #:constant-expression-p
           #:def-edit-rule
           #:replace-sexpression
           ))

(in-package #:gp.simplify)

;;; Editor for simplifying sexpressions

(defun edit-top-level-sexpression (sexpression rule-base)
  "Applies the rules in RULE-BASE to edit SEXPRESSION into
   a simpler form."
  (let ((location (list sexpression)))
    (edit-sexpression rule-base location sexpression)
    location))

(defun edit-sexpression (rule-base location sexpression)
  "Given a rule base (list of rules), an sexpression and the
   location of that sexpression in the containing expression,
   applies the rules to the sexpression and its arguments
   recursively.  The rules are reapplied until a quiescent state
   is achieved."
  ;; Apply the edit rules to each of the arguments.
  ;; If something changes, try again.
  (when (consp sexpression)
    (do* ((args (rest sexpression) (rest args))
          (arg (first args) (first args))
          (arg-location (rest sexpression) (rest arg-location))
          (changed-p
           (edit-sexpression rule-base arg-location arg)
           (edit-sexpression rule-base arg-location arg)))
         ((not args)
          (when changed-p
            (edit-sexpression rule-base location sexpression)))
     nil))
  ;; Apply the edit rules to this expression.  Say that
  ;; something has changed if any rule fires.
  (let ((changed-p nil))
    (dolist (clause rule-base)
      (let ((condition (second clause))
            (action (third clause)))
        (let ((applicable-p (funcall condition sexpression)))
          (when applicable-p
            (funcall action location sexpression)
            (setf changed-p t)))))
    changed-p))

(defun constant-expression-p (sexpression)
  "Is true of an sexpression if it evaluates to a constant.
   Note that this can be a problem domain specific problem."
  (if (consp sexpression)
      (do* ((args (rest sexpression) (rest args))
            (arg (first args) (first args)))
           ((not args) t)
        (unless (constant-expression-p arg)
          (return nil)))
      ;;; Assumes that variable quantities are always symbols
      ;;; and assumes that any symbol that is not self-
      ;;; evaluating is not constant (this will fail for pi)
      ;;; so to solve more general problems some extra
      ;;; convention would be required.
      (or (not (symbolp sexpression))
          (keywordp sexpression)
          (and (boundp sexpression)
               (eq sexpression (symbol-value sexpression))))))

(defmacro def-edit-rule (rule-name
                         rule-base
                         (sexpression-name)
                         &key condition action)
  "Declares an edit rule called RULE-NAME in the RULE-BASE.
   SEXPRESSION-NAME is the local name to be given to the
   sexpression on which this rule is being invokes.  The
   CONDITION clause is evaluated, and if it is true, the
   ACTION clause is evaluated.  The action clause should
   make calls to REPLACE-SEXPRESSION to perform an edit."
  (assert (and condition action) ()
          "Both a condition and an action must be supplied.")
  `(setf ,rule-base
         (cons (list ',rule-name
                     #'(lambda (,sexpression-name) ,condition)
                     #'(lambda (location ,sexpression-name)
                         ,sexpression-name ,action))
               (remove (assoc ',rule-name ,rule-base :test #'eq)
                       ,rule-base))))

(defmacro replace-sexpression (new-sexpression)
  "The form to use in an edit rule that registers an edit.
   For example, if the sexpression being edited is to be
   replaced with the first argument to the function of the
  sexpression then we would say:  (replace-sexpression (second
  the-sexpression)), where the-sexpression is the name of the
  sexpression supplied as an argument to def-edit-rule.  This
  example would be useful if the function in question was an
 identity function.  Thus:
  (def-edit-rule remove-identity-functions *my-rule-base*
                 (the-sexpression)
    :condition (and (consp the-sexpression)
                    (eq (first the-sexpression) 'identity))
    :action (replace-sexpression (second the-sexpression)))"
  `(setf (first location) ,new-sexpression))
