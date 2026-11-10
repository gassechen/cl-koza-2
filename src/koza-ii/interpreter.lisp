(in-package #:cl-koza-ii.interpreter)

(declaim (ftype (function (t t &key (:environment t)) t)
                evaluate-adf-tree))

(defun binding-key-name (key)
  (etypecase key
    (symbol (symbol-name key))
    (string key)))

(defun environment-value (symbol environment)
  (let ((entry (or (assoc symbol environment :test #'eq)
                   (assoc (symbol-name symbol)
                          environment
                          :test #'string=
                          :key #'binding-key-name))))
    (if entry
        (values (cdr entry) t)
        (values nil nil))))

(defun adf-call-index (operator program)
  (if (symbolp operator)
      (let ((name (symbol-name operator)))
        (when (and (> (length name) 3)
                   (string-equal "ADF" name :end1 3 :end2 3)
                   (every #'digit-char-p (subseq name 3)))
          (let ((index (parse-integer name :start 3)))
            (unless (< index (adf-program-branch-count program))
              (error "Program has no ADF~D." index))
            (values index t))))
      (values nil nil)))

(defun argument-bindings (values)
  (loop for value in values
        for index from 0
        collect (cons (format nil "ARG~D" index) value)))

(defun evaluate-and (arguments environment program)
  (let ((result t))
    (dolist (argument arguments result)
      (setf result (evaluate-adf-tree argument program
                                      :environment environment))
      (unless result
        (return nil)))))

(defun evaluate-or (arguments environment program)
  (dolist (argument arguments nil)
    (let ((result (evaluate-adf-tree argument program
                                     :environment environment)))
      (when result
        (return result)))))

(defun evaluate-if (arguments environment program)
  (let ((test (evaluate-adf-tree (first arguments) program
                                 :environment environment)))
    (cond ((and test (second arguments))
           (evaluate-adf-tree (second arguments) program
                              :environment environment))
          ((and (not test) (third arguments))
           (evaluate-adf-tree (third arguments) program
                              :environment environment))
          (t nil))))

(defun evaluate-progn (arguments environment program)
  (let ((result nil))
    (dolist (argument arguments result)
      (setf result (evaluate-adf-tree argument program
                                      :environment environment)))))

(defun evaluate-function-call (operator arguments environment program)
  (case operator
    ((and) (evaluate-and arguments environment program))
    ((or) (evaluate-or arguments environment program))
    ((if) (evaluate-if arguments environment program))
    ((progn) (evaluate-progn arguments environment program))
    (otherwise
     (unless (fboundp operator)
       (error "~S is not a bound function." operator))
     (apply (symbol-function operator)
            (mapcar (lambda (argument)
                      (evaluate-adf-tree argument program
                                         :environment environment))
                    arguments)))))

(defun evaluate-adf-tree (tree program &key environment)
  "Evaluates TREE in the context of PROGRAM.

   ENVIRONMENT is an alist of terminal or argument bindings.  ADF calls
   are resolved against PROGRAM by branch index, so no dynamically bound
   ADF variables are used."
  (cond
    ((consp tree)
     (let ((operator (first tree))
           (arguments (rest tree)))
       (multiple-value-bind (adf-index adf-call-p)
           (adf-call-index operator program)
         (if adf-call-p
             (let* ((argument-values
                      (mapcar (lambda (argument)
                                (evaluate-adf-tree argument program
                                                   :environment environment))
                              arguments))
                    (adf-environment
                      (append (argument-bindings argument-values)
                              environment)))
               (evaluate-adf-tree (adf-program-adf program adf-index)
                                  program
                                  :environment adf-environment))
             (evaluate-function-call operator arguments environment program)))))
    ((symbolp tree)
     (cond ((eq tree t) t)
           ((eq tree nil) nil)
           (t
            (multiple-value-bind (value found-p)
                (environment-value tree environment)
              (unless found-p
                (error "No binding for terminal ~S." tree))
              value))))
    (t tree)))

(defun evaluate-adf-branch (program branch &key environment)
  "Evaluates BRANCH of PROGRAM in ENVIRONMENT."
  (evaluate-adf-tree (program-branch program branch)
                     program
                     :environment environment))

(defun evaluate-adf-program (program &key environment)
  "Evaluates the result-producing branch of PROGRAM in ENVIRONMENT."
  (evaluate-adf-branch program :rpb :environment environment))
