(in-package #:cl-koza-ii.program)

(defstruct (adf-program (:print-object print-adf-program))
  adf0
  adf1
  rpb)

(defun print-adf-program (program stream)
  (format stream
          "~&(defun ADF0 (ARG0 ARG1 ARG2)~%  (values ~S))~%~
             (defun ADF1 (ARG0 ARG1 ARG2)~%  (values ~S))~%~
             (defun RPB ()~%  (values ~S))"
          (adf-program-adf0 program)
          (adf-program-adf1 program)
          (adf-program-rpb program)))

(defparameter *branch-names* '(:adf0 :adf1 :rpb)
  "The branch names of an overall program, in the fixed order used by
   appendix E of Genetic Programming II.")

(defun branch-names ()
  "Returns the names of the branches of an overall program."
  *branch-names*)

(defun program-branch (program branch)
  "Returns the body of the branch named BRANCH from PROGRAM."
  (ecase branch
    (:adf0 (adf-program-adf0 program))
    (:adf1 (adf-program-adf1 program))
    (:rpb (adf-program-rpb program))))

(defun replace-program-branch (program branch new-body)
  "Destructively replaces the body of BRANCH in PROGRAM and returns
   PROGRAM."
  (ecase branch
    (:adf0 (setf (adf-program-adf0 program) new-body))
    (:adf1 (setf (adf-program-adf1 program) new-body))
    (:rpb (setf (adf-program-rpb program) new-body)))
  program)

(defun map-program-branches (function program)
  "Calls FUNCTION with each branch name and its body, collecting the
   results in branch order."
  (let ((result nil))
    (dolist (branch (branch-names) (nreverse result))
      (push (funcall function branch (program-branch program branch))
            result))))

(defun copy-individual-substituting-branch (branch new-branch-subtree
                                            program-to-copy)
  "Makes a copy of PROGRAM-TO-COPY, substituting the branch selected by
   BRANCH with NEW-BRANCH-SUBTREE."
  (make-adf-program
   :adf0 (if (eq branch :adf0)
             new-branch-subtree
             (copy-tree (adf-program-adf0 program-to-copy)))
   :adf1 (if (eq branch :adf1)
             new-branch-subtree
             (copy-tree (adf-program-adf1 program-to-copy)))
   :rpb (if (eq branch :rpb)
            new-branch-subtree
            (copy-tree (adf-program-rpb program-to-copy)))))

(defun count-crossover-points (program)
  "Counts the number of points in the tree (program).
   This includes functions as well as terminals."
  (if (consp program)
      (+ 1 (reduce #'+ (mapcar #'count-crossover-points
                               (rest program))))
      1))

(defun count-function-points (program)
  "Counts the number of function (internal) points in the program."
  (if (consp program)
      (+ 1 (reduce #'+ (mapcar #'count-function-points
                               (rest program))))
      0))

(defun max-depth-of-tree (tree)
  "Returns the depth of the deepest branch of the tree (program)."
  (if (consp tree)
      (+ 1 (if (rest tree)
               (apply #'max
                      (mapcar #'max-depth-of-tree (rest tree)))
               0))
      1))

(defun get-subtree (tree pointer-to-tree index)
  "Given a tree or subtree, a pointer to that tree/subtree and an index,
   return the component subtree that is numbered by INDEX.  We number
   left to right, depth first."
  (if (= index 0)
      (values pointer-to-tree (copy-tree tree) index)
      (if (consp tree)
          (do* ((tail (rest tree) (rest tail))
                (argument (first tail) (first tail)))
               ((not tail) (values nil nil index))
            (multiple-value-bind (new-pointer new-tree new-index)
                (get-subtree argument tail (- index 1))
              (if (= new-index 0)
                  (return (values new-pointer new-tree new-index))
                  (setf index new-index))))
          (values nil nil index))))

(defun get-function-subtree (tree pointer-to-tree index)
  "Given a tree or subtree, a pointer to that tree/subtree and an index,
   return the component subtree that is labeled with an internal point
   numbered by INDEX.  We number left to right, depth first."
  (if (= index 0)
      (values pointer-to-tree (copy-tree tree) index)
      (if (consp tree)
          (do* ((tail (rest tree) (rest tail))
                (argument (first tail) (first tail)))
               ((not tail) (values nil nil index))
            (multiple-value-bind (new-pointer new-tree new-index)
                (if (consp argument)
                    (get-function-subtree argument tail (- index 1))
                    (values nil nil index))
              (if (= new-index 0)
                  (return (values new-pointer new-tree new-index))
                  (setf index new-index))))
          (values nil nil index))))
