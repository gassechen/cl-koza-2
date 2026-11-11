(in-package #:cl-koza-2.tests)

(in-suite cl-koza-2-tests)

(test adf-program-basics
  (let ((program (make-adf-program :adf0 'a :adf1 'b :rpb 'c)))
    (is (adf-program-p program))
    (is (eq 'a (adf-program-adf0 program)))
    (is (eq 'b (adf-program-adf1 program)))
    (is (eq 'c (adf-program-rpb program)))))

(test adf-program-defaults
  (let ((program (make-adf-program)))
    (is (null (adf-program-adf0 program)))
    (is (null (adf-program-adf1 program)))
    (is (null (adf-program-rpb program)))))

(test adf-program-copy
  (let* ((program (make-adf-program :adf0 '(and a b)
                                    :adf1 '(or c d)
                                    :rpb '(nand e f)))
         (copy (copy-adf-program program)))
    (is (not (eq program copy)))
    (is (equal (program-body-list program)
               (program-body-list copy)))))

(test branch-names-order
  (is (equal '(:adf0 :adf1 :rpb) (branch-names))))

(test program-branch-access
  (let ((program (make-adf-program :adf0 '(and a b)
                                   :adf1 '(or c d)
                                   :rpb '(nand e f))))
    (is (equal '(and a b) (program-branch program :adf0)))
    (is (equal '(or c d) (program-branch program :adf1)))
    (is (equal '(nand e f) (program-branch program :rpb)))
    (signals error (program-branch program :unknown))))

(test replace-program-branch-behavior
  (let ((program (make-adf-program :adf0 '(and a b)
                                   :adf1 '(or c d)
                                   :rpb '(nand e f))))
    (is (eq program (replace-program-branch program :adf1 '(nor g h))))
    (is (equal '(nor g h) (adf-program-adf1 program)))
    (is (equal '(and a b) (adf-program-adf0 program)))
    (is (equal '(nand e f) (adf-program-rpb program)))))

(test map-program-branches-order
  (let ((program (make-adf-program :adf0 'a :adf1 'b :rpb 'c)))
    (is (equal '((:adf0 a) (:adf1 b) (:rpb c))
               (map-program-branches
                (lambda (branch body) (list branch body))
                program)))))

(test copy-individual-substituting-branch-behavior
  (dolist (branch '(:adf0 :adf1 :rpb))
    (let* ((program (make-adf-program :adf0 '(and a b)
                                      :adf1 '(or c d)
                                      :rpb '(nand e f)))
           (new-subtree '(nor g h))
           (new-program (copy-individual-substituting-branch
                         branch new-subtree program)))
      (is (eq new-subtree (program-branch new-program branch)))
      (dolist (other-branch '(:adf0 :adf1 :rpb))
        (unless (eq branch other-branch)
          (is (equal (program-branch program other-branch)
                     (program-branch new-program other-branch)))
          (is (not (eq (program-branch program other-branch)
                       (program-branch new-program other-branch)))))))))

(test count-crossover-points-cases
  (is (= 1 (count-crossover-points 'a)))
  (is (= 1 (count-crossover-points '(foo))))
  (is (= 3 (count-crossover-points '(and a b))))
  (is (= 4 (count-crossover-points '(a (b c) d)))))

(test count-function-points-cases
  (is (= 0 (count-function-points 'a)))
  (is (= 1 (count-function-points '(foo))))
  (is (= 1 (count-function-points '(and a b))))
  (is (= 2 (count-function-points '(a (b c) d)))))

(test max-depth-of-tree-cases
  (is (= 1 (max-depth-of-tree 'a)))
  (is (= 1 (max-depth-of-tree '(foo))))
  (is (= 2 (max-depth-of-tree '(and a b))))
  (is (= 3 (max-depth-of-tree '(a (b c) d)))))

(test get-subtree-indices
  (let ((tree '(a (b c) d)))
    (multiple-value-bind (pointer subtree index)
        (get-subtree tree tree 0)
      (is (eq tree pointer))
      (is (equal tree subtree))
      (is (= 0 index)))
    (multiple-value-bind (pointer subtree index)
        (get-subtree tree tree 1)
      (is (eq (second tree) (first pointer)))
      (is (equal '(b c) subtree))
      (is (= 0 index)))
    (multiple-value-bind (pointer subtree index)
        (get-subtree tree tree 2)
      (is (eq 'c (first pointer)))
      (is (equal 'c subtree))
      (is (= 0 index)))
    (multiple-value-bind (pointer subtree index)
        (get-subtree tree tree 3)
      (is (eq 'd (first pointer)))
      (is (equal 'd subtree))
      (is (= 0 index)))
    (multiple-value-bind (pointer subtree index)
        (get-subtree tree tree 4)
      (is (null pointer))
      (is (null subtree))
      (is (= 1 index)))))

(test get-subtree-pointer-replacement
  (let ((tree (list 'a (list 'b 'c) 'd)))
    (multiple-value-bind (pointer subtree index)
        (get-subtree tree tree 1)
      (declare (ignore subtree index))
      (setf (first pointer) 'replacement))
    (is (equal '(a replacement d) tree))))

(test get-function-subtree-indices
  (let ((tree '(a (b c) d)))
    (multiple-value-bind (pointer subtree index)
        (get-function-subtree tree tree 0)
      (is (eq tree pointer))
      (is (equal tree subtree))
      (is (= 0 index)))
    (multiple-value-bind (pointer subtree index)
        (get-function-subtree tree tree 1)
      (is (eq (second tree) (first pointer)))
      (is (equal '(b c) subtree))
      (is (= 0 index)))
    (multiple-value-bind (pointer subtree index)
        (get-function-subtree tree tree 2)
      (is (null pointer))
      (is (null subtree))
      (is (not (= 0 index))))))

(test get-function-subtree-skips-terminals
  (let ((tree '(a b c)))
    (multiple-value-bind (pointer subtree index)
        (get-function-subtree tree tree 1)
      (is (null pointer))
      (is (null subtree))
      (is (not (= 0 index))))))

(test adf-program-printing
  (let ((text (prin1-to-string
               (make-adf-program :adf0 '(and arg0 arg1)
                                 :adf1 '(or arg0 arg1)
                                 :rpb '(nand d0 d1)))))
    (is (search "(defun ADF0" text))
    (is (search "(defun ADF1" text))
    (is (search "(defun RPB" text))))
