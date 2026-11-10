(in-package #:cl-koza-ii.tests)

(in-suite cl-koza-ii-tests)

(defparameter *even-5-parity-problem-symbol*
  'cl-koza-ii.examples.even-5-parity:even-5-parity)

(test run-argument-validation
  (with-kernel-defaults
    (signals error
      (capture-output
       (run-genetic-programming-system
        *even-5-parity-problem-symbol* 1.0 -1 10)))
    (signals error
      (capture-output
       (run-genetic-programming-system
        *even-5-parity-problem-symbol* 1.0 1.5 10)))
    (signals error
      (capture-output
       (run-genetic-programming-system
        *even-5-parity-problem-symbol* 1.0 1 0)))
    (signals error
      (capture-output
       (run-genetic-programming-system
        *even-5-parity-problem-symbol* 1.0 1 1.5)))
    (signals error
      (capture-output
       (run-genetic-programming-system
        nil 1.0 1 10)))
    (signals error
      (capture-output
       (run-genetic-programming-system
        'not-a-function 1.0 1 10)))
    (signals error
      (capture-output
       (run-genetic-programming-system
        *even-5-parity-problem-symbol* 'not-a-number 1 10)))
    (signals error
      (capture-output
       (run-genetic-programming-system
        *even-5-parity-problem-symbol* 0 1 10)))))

(test run-even-5-parity-basic
  (with-kernel-defaults
    (let (population fitness-cases)
      (capture-output
       (multiple-value-setq (population fitness-cases)
         (run-genetic-programming-system
          *even-5-parity-problem-symbol* 1.0 1 8)))
      (is (vectorp population))
      (is (= 8 (length population)))
      (is (vectorp fitness-cases))
      (is (= 32 (length fitness-cases)))
      (is (typep *best-of-run-individual* 'individual))
      (is (<= 0 *generation-of-best-of-run-individual* 1))
      (is (all-programs-valid-p
           population *max-depth-for-individuals-after-crossover*))
      (is (loop for index below (length population)
                for individual = (aref population index)
                always (and (<= 0
                                (individual-standardized-fitness individual)
                                32)
                            (<= 0 (individual-hits individual) 32)
                            (<= 0
                                (individual-normalized-fitness individual)
                                1))))
      (is (loop for index below (length population)
                for individual = (aref population index)
                always (< (abs (- (individual-adjusted-fitness individual)
                                  (/ 1.0
                                     (+ 1.0
                                        (individual-standardized-fitness
                                         individual)))))
                          1.0d-9)))
      (is (< (abs (- 1.0 (normalized-fitness-sum population))) 1.0d-9))
      (is (loop for index below (1- (length population))
                always (>= (individual-normalized-fitness
                            (aref population index))
                           (individual-normalized-fitness
                            (aref population (1+ index))))))
      (is (<= (individual-standardized-fitness *best-of-run-individual*)
              (loop for index below (length population)
                    minimize (individual-standardized-fitness
                              (aref population index))))))))

(test run-generation-methods
  (with-kernel-defaults
    (dolist (method '(:full :grow :ramped-half-and-half))
      (let (population)
        (capture-output
         (setf population
               (run-with-overrides
                1.0 2 8
                :parameter-overrides
                (list (cons '*method-of-generation* method))
                :fitness-override #'constant-fitness)))
        (is (= 8 (length population)))
        (is (all-programs-valid-p
             population *max-depth-for-individuals-after-crossover*))))))

(test run-selection-methods
  (with-kernel-defaults
    (dolist (method '(:tournament :fitness-proportionate))
      (let (population)
        (capture-output
         (setf population
               (run-with-overrides
                1.0 2 8
                :parameter-overrides
                (list (cons '*method-of-selection* method))
                :fitness-override #'constant-fitness)))
        (is (= 8 (length population)))
        (is (all-programs-valid-p
             population *max-depth-for-individuals-after-crossover*))))))

(test run-over-selection-requires-large-population
  (with-kernel-defaults
    (signals error
      (capture-output
       (run-with-overrides
        1.0 2 10
        :parameter-overrides
        (list (cons '*method-of-selection*
                    :fitness-proportionate-with-over-selection))
        :fitness-override #'constant-fitness)))))

(test run-over-selection-large-population
  (with-kernel-defaults
    (let (population)
      (capture-output
       (setf population
             (run-with-overrides
              1.0 2 1000
              :parameter-overrides
              (list (cons '*method-of-selection*
                          :fitness-proportionate-with-over-selection))
              :fitness-override #'constant-fitness)))
      (is (= 1000 (length population)))
      (is (all-programs-valid-p
           population *max-depth-for-individuals-after-crossover*)))))

(test run-invalid-selection-method
  (with-kernel-defaults
    (signals error
      (capture-output
       (run-with-overrides
        1.0 2 8
        :parameter-overrides
        (list (cons '*method-of-selection* :unknown))
        :fitness-override #'constant-fitness)))))

(test run-operator-fractions
  (with-kernel-defaults
    (dolist (fractions '((1.0 0.0 0.0)
                         (0.0 1.0 0.0)
                         (0.0 0.0 1.0)
                         (0.0 0.0 0.0)))
      (destructuring-bind (reproduction crossover-any crossover-function)
          fractions
        (let (population)
          (capture-output
           (setf population
                 (run-with-overrides
                  1.0 2 8
                  :parameter-overrides
                  (list
                   (cons '*fitness-proportionate-reproduction-fraction*
                         reproduction)
                   (cons '*crossover-at-any-point-fraction*
                         crossover-any)
                   (cons '*crossover-at-function-point-fraction*
                         crossover-function))
                  :fitness-override #'constant-fitness)))
          (is (= 8 (length population)))
          (is (all-programs-valid-p
               population *max-depth-for-individuals-after-crossover*)))))))

(test run-respects-crossover-depth-limit
  (with-kernel-defaults
    (let (population)
      (capture-output
       (setf population
             (run-with-overrides
              1.0 2 8
              :parameter-overrides
              (list (cons '*crossover-at-any-point-fraction* 0.0)
                    (cons '*crossover-at-function-point-fraction* 1.0)
                    (cons '*max-depth-for-individuals-after-crossover* 5))
              :fitness-override #'constant-fitness)))
      (is (all-programs-valid-p population 5)))))

(test run-mutation-with-small-subtrees
  (with-kernel-defaults
    (let (population)
      (capture-output
       (setf population
             (run-with-overrides
              1.0 2 8
              :parameter-overrides
              (list (cons '*fitness-proportionate-reproduction-fraction* 0.0)
                    (cons '*crossover-at-any-point-fraction* 0.0)
                    (cons '*crossover-at-function-point-fraction* 0.0)
                    (cons '*max-depth-for-new-subtrees-in-mutants* 2))
              :fitness-override #'constant-fitness)))
      (is (= 8 (length population)))
      (is (all-programs-valid-p population most-positive-fixnum)))))

(test run-terminates-with-seeded-perfect-program
  (with-kernel-defaults
    (capture-output
     (run-with-overrides
      1.0 100 10
      :seeded-programs
      (list (known-correct-even-5-parity-program))))
    (is (= 0 *generation-of-best-of-run-individual*))
    (is (zerop (individual-standardized-fitness
                *best-of-run-individual*)))
    (is (= 32 (individual-hits *best-of-run-individual*)))))

(test run-is-reproducible-with-same-seed
  (with-kernel-defaults
    (let (first-result second-result)
      (capture-output
       (run-with-overrides 42 2 8)
       (setf first-result
             (list (program-body-list
                    (individual-program *best-of-run-individual*))
                   (individual-standardized-fitness
                    *best-of-run-individual*)
                   (individual-hits *best-of-run-individual*)
                   *generation-of-best-of-run-individual*)))
      (capture-output
       (run-with-overrides 42 2 8)
       (setf second-result
             (list (program-body-list
                    (individual-program *best-of-run-individual*))
                   (individual-standardized-fitness
                    *best-of-run-individual*)
                   (individual-hits *best-of-run-individual*)
                   *generation-of-best-of-run-individual*)))
      (is (equal first-result second-result)))))

(test run-returns-fitness-cases
  (with-kernel-defaults
    (let (population fitness-cases)
      (capture-output
       (multiple-value-setq (population fitness-cases)
         (run-with-overrides 1.0 1 8)))
      (is (= 8 (length population)))
      (is (= 32 (length fitness-cases))))))
