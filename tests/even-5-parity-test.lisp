(in-package #:cl-koza-ii.tests)

(in-suite cl-koza-ii-tests)

(test even-5-parity-contract
  (with-kernel-defaults
    (multiple-value-bind (adf0-function-set-creator
                          adf1-function-set-creator
                          rpb-function-set-creator
                          adf0-terminal-set-creator
                          adf1-terminal-set-creator
                          rpb-terminal-set-creator
                          fitness-cases-creator
                          fitness-function
                          parameter-definer
                          termination-predicate)
        (cl-koza-ii.examples.even-5-parity:even-5-parity)
      (is (every #'fboundp
                 (list adf0-function-set-creator
                       adf1-function-set-creator
                       rpb-function-set-creator
                       adf0-terminal-set-creator
                       adf1-terminal-set-creator
                       rpb-terminal-set-creator
                       fitness-cases-creator
                       fitness-function
                       parameter-definer
                       termination-predicate)))
      (multiple-value-bind (function-set argument-map)
          (funcall adf0-function-set-creator)
        (is (equal '("AND" "OR" "NAND" "NOR")
                 (symbol-names function-set)))
        (is (equal '(2 2 2 2) argument-map)))
      (multiple-value-bind (function-set argument-map)
          (funcall adf1-function-set-creator)
        (is (equal '("AND" "OR" "NAND" "NOR" "ADF0")
                 (symbol-names function-set)))
        (is (equal '(2 2 2 2 3) argument-map)))
      (multiple-value-bind (function-set argument-map)
          (funcall rpb-function-set-creator)
        (is (equal '("AND" "OR" "NAND" "NOR" "ADF0" "ADF1")
                 (symbol-names function-set)))
        (is (equal '(2 2 2 2 3 3) argument-map)))
      (is (equal '("ARG0" "ARG1" "ARG2")
                 (symbol-names (funcall adf0-terminal-set-creator))))
      (is (equal '("ARG0" "ARG1" "ARG2")
                 (symbol-names (funcall adf1-terminal-set-creator))))
      (is (equal '("D4" "D3" "D2" "D1" "D0")
                 (symbol-names (funcall rpb-terminal-set-creator))))
      (funcall parameter-definer)
      (is (= 32 *number-of-fitness-cases*))
      (is (= 5 *max-depth-for-new-individuals*))
      (is (= 4 *max-depth-for-new-subtrees-in-mutants*))
      (is (= 17 *max-depth-for-individuals-after-crossover*))
      (is (= 0.1 *fitness-proportionate-reproduction-fraction*))
      (is (= 0.2 *crossover-at-any-point-fraction*))
      (is (= 0.7 *crossover-at-function-point-fraction*))
      (is (eq :tournament *method-of-selection*))
      (is (= 7 *tournament-size*))
      (is (eq :ramped-half-and-half *method-of-generation*))
      (let ((fitness-cases (funcall fitness-cases-creator)))
        (is (= 32 (length fitness-cases)))
        (multiple-value-bind (fitness hits)
            (funcall fitness-function
                     (known-correct-even-5-parity-program)
                     fitness-cases)
          (is (zerop fitness))
          (is (= 32 hits)))
        (multiple-value-bind (fitness hits)
            (funcall fitness-function
                     (make-adf-program
                      :adf0 (symbol-by-name
                             "ARG0" (funcall adf0-terminal-set-creator))
                      :adf1 (symbol-by-name
                             "ARG0" (funcall adf1-terminal-set-creator))
                      :rpb (symbol-by-name
                            "D0" (funcall rpb-terminal-set-creator)))
                     fitness-cases)
          (is (= 16 fitness))
          (is (= 16 hits))))
      (is (not (funcall termination-predicate 0 10 16 16)))
      (is (funcall termination-predicate 10 10 16 16))
      (is (funcall termination-predicate 0 10 0 32)))))

(test verify-known-program
  (with-kernel-defaults
    (let (result)
      (let ((output
              (capture-output
               (multiple-value-bind (fitness-ok-p hits-ok-p)
                   (cl-koza-ii.examples.even-5-parity:verify-known-program)
                 (setf result (list fitness-ok-p hits-ok-p))))))
        (is (equal '(t t) result))
        (is (search "Known program" output))))))

(test run-even-5-parity-small
  (with-kernel-defaults
    (let (population fitness-cases)
      (let ((output
              (capture-output
               (multiple-value-setq (population fitness-cases)
                 (cl-koza-ii.examples.even-5-parity:run 1 8 1.0)))))
        (is (= 8 (length population)))
        (is (= 32 (length fitness-cases)))
        (is (typep *best-of-run-individual* 'individual))
        (is (<= 0 (individual-hits *best-of-run-individual*) 32))
        (is (search "Parameters used for this run" output))
        (is (search "best-of-run" output))))))

(test run-even-5-parity-verbose
  (with-kernel-defaults
    (let ((output
            (capture-output
             (cl-koza-ii.examples.even-5-parity:run 1 8 1.0 :verbose t))))
      (is (search "Generation 0" output)))))

(test run-example-small
  (with-kernel-defaults
    (let (population)
      (let ((output
              (capture-output
               (setf population
                     (cl-koza-ii.examples.even-5-parity:run-example
                      :maximum-generations 1
                      :size-of-population 8
                      :seed 1.0)))))
        (is (= 8 (length population)))
        (is (search "best-of-run" output))))))
