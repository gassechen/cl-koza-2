(in-package #:cl-koza-2.tests)

(in-suite cl-koza-2-tests)

(test parallel-generation-matches-sequential
  (with-kernel-defaults
    (flet ((population-bodies (parallel-p)
             (let ((*parallel-generation-p* parallel-p))
               (with-seed (10)
                 (map 'list
                      (lambda (individual)
                        (program-body-list (individual-program individual)))
                      (create-test-population 16))))))
      (is (equal (population-bodies nil)
                 (population-bodies t))))))

(test parallel-run-matches-sequential
  (with-kernel-defaults
    (flet ((snapshot (parallel-p)
             (let ((*parallel-generation-p* parallel-p)
                   (*parallel-evaluation-p* parallel-p))
               (capture-output
                 (multiple-value-bind (population)
                     (cl-koza-2.examples.even-5-parity-3-adfs:run
                      2 8 1.0)
                   (map 'list
                        (lambda (individual)
                          (list
                           (program-body-list
                            (individual-program individual))
                           (individual-standardized-fitness individual)
                           (individual-hits individual)
                           (individual-adjusted-fitness individual)
                           (individual-normalized-fitness individual)))
                        population))))))
      (is (equal (snapshot nil)
                 (snapshot t))))))
