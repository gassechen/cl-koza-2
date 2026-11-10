(in-package #:cl-koza-ii.tests)

(in-suite cl-koza-ii-tests)

(defun make-report-test-population ()
  (let* ((best-program (make-adf-program :adf0 '(and arg0 arg1)
                                         :adf1 '(or arg0 arg1)
                                         :rpb '(nand d0 d1)))
         (other-program (make-adf-program :adf0 '(or arg0 arg1)
                                          :adf1 '(and arg0 arg1)
                                          :rpb '(nor d0 d1)))
         (population (make-array 2)))
    (setf (aref population 0)
          (make-test-individual best-program
                                :standardized-fitness 2
                                :adjusted-fitness 1/3
                                :normalized-fitness 0.6
                                :hits 30))
    (setf (aref population 1)
          (make-test-individual other-program
                                :standardized-fitness 4
                                :adjusted-fitness 0.2
                                :normalized-fitness 0.4
                                :hits 28))
    population))

(test describe-parameters-for-run-output
  (with-kernel-defaults
    (let ((*seed* 1.0d0))
      (let ((output (capture-output
                     (describe-parameters-for-run 10 100))))
        (is (search "Parameters used for this run" output))
        (is (search "Maximum number of Generations:" output))
        (is (search "Size of Population:" output))
        (is (search "Maximum depth of new individuals:" output))
        (is (search "Maximum depth of new subtrees for mutants:" output))
        (is (search "Maximum depth of individuals after crossover:" output))
        (is (search "Fitness-proportionate reproduction fraction:" output))
        (is (search "Crossover at any point fraction:" output))
        (is (search "Crossover at function points fraction:" output))
        (is (search "Number of fitness cases:" output))
        (is (search "Selection method:" output))
        (is (search "Tournament group size:" output))
        (is (search "Generation method:" output))
        (is (search "Randomizer seed:" output))))))

(test report-on-generation-output
  (with-kernel-defaults
    (let ((output (capture-output
                   (report-on-generation 3 (make-report-test-population)))))
      (is (search "Generation 3" output))
      (is (search "Average standardized-fitness" output))
      (is (search "standardized fitness" output))
      (is (search "hits" output))
      (is (search "It was:" output))
      (is (search "(defun ADF0" output)))))

(test report-on-run-output
  (with-kernel-defaults
    (let ((*best-of-run-individual*
            (make-test-individual
             (make-adf-program :adf0 '(and arg0 arg1)
                               :adf1 '(or arg0 arg1)
                               :rpb '(nand d0 d1))
             :standardized-fitness 2
             :adjusted-fitness 1/3
             :normalized-fitness 0.6
             :hits 30))
          (*generation-of-best-of-run-individual* 2))
      (let ((output (capture-output (report-on-run))))
        (is (search "best-of-run individual program" output))
        (is (search "generation 2" output))
        (is (search "standardized fitness" output))
        (is (search "hits" output))
        (is (search "It was:" output))
        (is (search "(defun ADF0" output))))))

(test print-population-output
  (with-kernel-defaults
    (let ((output (capture-output
                   (print-population (make-report-test-population)))))
      (is (search "0" output))
      (is (search "1" output))
      (is (search "2" output))
      (is (search "4" output))
      (is (search "(defun ADF0" output)))))
