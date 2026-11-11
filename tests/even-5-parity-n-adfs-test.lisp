(in-package #:cl-koza-ii.tests)

(in-suite cl-koza-ii-tests)

(defun call-n-adf-problem (&optional (count
                                       cl-koza-ii.examples.even-5-parity-n-adfs:*number-of-adfs*))
  (let ((cl-koza-ii.examples.even-5-parity-n-adfs:*number-of-adfs* count))
    (cl-koza-ii.examples.even-5-parity-n-adfs:even-5-parity-n-adfs)))

(test even-5-parity-n-adfs-contract
  (with-kernel-defaults
    (multiple-value-bind (adf-specs
                          rpb-spec
                          fitness-cases-creator
                          fitness-function
                          parameter-definer
                          termination-predicate)
        (call-n-adf-problem 4)
      (is (= 4 (length adf-specs)))
      (is (every (lambda (spec) (typep spec 'branch-spec)) adf-specs))
      (is (typep rpb-spec 'branch-spec))
      (is (every #'fboundp
                 (list fitness-cases-creator
                       fitness-function
                       parameter-definer
                       termination-predicate)))
      (multiple-value-bind (function-set argument-map)
          (funcall (branch-spec-function-set-creator (fourth adf-specs)))
        (is (equal '("AND" "OR" "NAND" "NOR" "ADF0" "ADF1" "ADF2")
                   (symbol-names function-set)))
        (is (equal '(2 2 2 2 3 3 3) argument-map)))
      (multiple-value-bind (function-set argument-map)
          (funcall (branch-spec-function-set-creator rpb-spec))
        (is (equal '("AND" "OR" "NAND" "NOR" "ADF0" "ADF1" "ADF2" "ADF3")
                   (symbol-names function-set)))
        (is (equal '(2 2 2 2 3 3 3 3) argument-map)))
      (is (every (lambda (spec)
                   (equal '("ARG0" "ARG1" "ARG2")
                          (symbol-names
                           (funcall
                            (branch-spec-terminal-set-creator spec)))))
                 adf-specs))
      (is (equal '("D4" "D3" "D2" "D1" "D0")
                 (symbol-names
                  (funcall (branch-spec-terminal-set-creator rpb-spec)))))
      (funcall parameter-definer)
      (is (= 32 (length (funcall fitness-cases-creator))))
      (is (= 32 *number-of-fitness-cases*))
      (is (eq :tournament *method-of-selection*))
      (is (eq :ramped-half-and-half *method-of-generation*))
      (is (not (funcall termination-predicate 0 10 0 0)))
      (is (funcall termination-predicate 10 10 0 0))
      (is (funcall termination-predicate 0 10 0 32)))))

(test even-5-parity-n-adfs-variable-branch-counts
  (with-kernel-defaults
    (dolist (count '(0 1 2 5))
      (multiple-value-bind (adf-specs rpb-spec)
          (call-n-adf-problem count)
        (is (= count (length adf-specs)))
        (multiple-value-bind (function-set argument-map)
            (funcall (branch-spec-function-set-creator rpb-spec))
          (is (= (+ 4 count) (length function-set)))
          (is (= (+ 4 count) (length argument-map)))
          (is (equal (make-list count :initial-element 3)
                     (nthcdr 4 argument-map)))))))
  (signals error (call-n-adf-problem -1)))

(test even-5-parity-n-adfs-verify-known-program
  (with-kernel-defaults
    (dolist (count '(2 3 4))
      (let (result)
        (let ((output
                (capture-output
                 (multiple-value-bind (fitness-ok-p hits-ok-p)
                     (cl-koza-ii.examples.even-5-parity-n-adfs:verify-known-program
                      count)
                   (setf result (list fitness-ok-p hits-ok-p))))))
          (is (equal '(t t) result))
          (is (search "standardized-fitness=0" output))
          (is (search "hits=32" output)))))))

(test run-even-5-parity-n-adfs-small
  (with-kernel-defaults
    (dolist (count '(0 1 4))
      (let (population fitness-cases)
        (let ((output
                (capture-output
                 (multiple-value-setq (population fitness-cases)
                   (cl-koza-ii.examples.even-5-parity-n-adfs:run
                    1 8 1.0 :number-of-adfs count)))))
          (is (= 8 (length population)))
          (is (= 32 (length fitness-cases)))
          (is (= count
                 (adf-program-branch-count
                  (individual-program (aref population 0)))))
          (is (typep *best-of-run-individual* 'individual))
          (is (<= 0 (individual-hits *best-of-run-individual*) 32))
          (is (all-n-adf-programs-valid-p
               population count
               *max-depth-for-individuals-after-crossover*))
          (is (search "Parameters used for this run" output))
          (is (search "best-of-run" output)))))))

(test run-example-even-5-parity-n-adfs-small
  (with-kernel-defaults
    (let (population)
      (let ((output
              (capture-output
               (setf population
                     (cl-koza-ii.examples.even-5-parity-n-adfs:run-example
                      :number-of-adfs 3
                      :maximum-generations 1
                      :size-of-population 8
                      :seed 1.0)))))
        (is (= 8 (length population)))
        (is (= 3
               (adf-program-branch-count
                (individual-program (aref population 0)))))
        (is (search "best-of-run" output))))))
