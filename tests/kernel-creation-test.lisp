(in-package #:cl-koza-ii.tests)

(in-suite cl-koza-ii-tests)

(test individual-defaults
  (let ((individual (make-individual)))
    (is (typep individual 'individual))
    (is (null (individual-program individual)))
    (is (= 0 (individual-standardized-fitness individual)))
    (is (= 0 (individual-adjusted-fitness individual)))
    (is (= 0 (individual-normalized-fitness individual)))
    (is (= 0 (individual-hits individual)))))

(test individual-accessors
  (let* ((program (make-adf-program :adf0 'a :adf1 'b :rpb 'c))
         (individual (make-individual :program program
                                      :standardized-fitness 3
                                      :adjusted-fitness 0.25
                                      :normalized-fitness 0.5
                                      :hits 7)))
    (is (eq program (individual-program individual)))
    (is (= 3 (individual-standardized-fitness individual)))
    (is (= 0.25 (individual-adjusted-fitness individual)))
    (is (= 0.5 (individual-normalized-fitness individual)))
    (is (= 7 (individual-hits individual)))))

(test copy-individual-behavior
  (let* ((program (make-adf-program :adf0 'a :adf1 'b :rpb 'c))
         (original (make-individual :program program
                                    :standardized-fitness 2
                                    :adjusted-fitness 1/3
                                    :normalized-fitness 0.4
                                    :hits 5))
         (copy (cl-koza-ii.kernel:copy-individual original)))
    (is (not (eq original copy)))
    (is (eq program (individual-program copy)))
    (is (= 2 (individual-standardized-fitness copy)))
    (setf (individual-standardized-fitness copy) 9)
    (is (= 2 (individual-standardized-fitness original)))))

(test create-population-basic
  (with-kernel-defaults
    (with-seed (1)
      (let ((population (create-test-population 20)))
        (is (= 20 (length population)))
        (is (loop for index below 20
                  always (typep (aref population index) 'individual)))
        (is (all-programs-valid-p
             population *max-depth-for-new-individuals*))
        (is (loop for index below 20
                  always (<= (program-depth
                              (individual-program (aref population index)))
                             *max-depth-for-new-individuals*)))))))

(test create-population-unique-generation-zero
  (with-kernel-defaults
    (with-seed (2)
      (let ((population (create-test-population 20))
            (seen (make-hash-table :test #'equal))
            (duplicate-found-p nil))
        (dotimes (index 20)
          (let ((bodies (program-body-list
                         (individual-program (aref population index)))))
            (when (gethash bodies seen)
              (setf duplicate-found-p t))
            (setf (gethash bodies seen) t)))
        (is (not duplicate-found-p))
        (is (= 20 (hash-table-count seen)))))))

(test create-population-seeded-programs
  (with-kernel-defaults
    (with-seed (3)
      (let* ((seed1 (make-adf-program :adf0 '(and arg0 arg1)
                                      :adf1 '(or arg0 arg1)
                                      :rpb '(nand d0 d1)))
             (seed2 (make-adf-program :adf0 '(or arg0 arg1)
                                      :adf1 '(and arg0 arg1)
                                      :rpb '(nor d0 d1)))
             (population (create-test-population
                          5 :seeded-programs (list seed1 seed2))))
        (is (eq seed1 (individual-program (aref population 0))))
        (is (eq seed2 (individual-program (aref population 1))))
        (is (all-programs-valid-p
             population *max-depth-for-new-individuals*))))))

(test create-population-more-seeds-than-population
  (with-kernel-defaults
    (with-seed (4)
      (let* ((seeds (loop repeat 3
                          collect (make-adf-program :adf0 'arg0
                                                    :adf1 'arg0
                                                    :rpb 'd0)))
             (population (create-test-population
                          2 :seeded-programs seeds)))
        (is (= 2 (length population)))
        (is (eq (first seeds) (individual-program (aref population 0))))
        (is (eq (second seeds) (individual-program (aref population 1))))))))

(test create-population-full-method
  (with-kernel-defaults
    (with-seed (5)
      (let* ((*method-of-generation* :full)
             (population (create-test-population 10)))
        (dotimes (index 10)
          (is (= *max-depth-for-new-individuals*
                 (program-depth
                  (individual-program (aref population index))))))))))

(test create-population-grow-method
  (with-kernel-defaults
    (with-seed (6)
      (let* ((*method-of-generation* :grow)
             (population (create-test-population 10)))
        (dotimes (index 10)
          (let ((program (individual-program (aref population index))))
            (is (<= (program-depth program)
                    *max-depth-for-new-individuals*))
            (is (consp (adf-program-adf0 program)))
            (is (consp (adf-program-adf1 program)))
            (is (consp (adf-program-rpb program)))))))))

(test create-population-ramped-half-and-half-method
  (with-kernel-defaults
    (with-seed (7)
      (let* ((*method-of-generation* :ramped-half-and-half)
             (population (create-test-population 20)))
        (is (all-programs-valid-p
             population *max-depth-for-new-individuals*))
        (dotimes (index 20)
          (let ((program (individual-program (aref population index))))
            (is (<= (program-depth program)
                    *max-depth-for-new-individuals*))
            (is (consp (adf-program-adf0 program)))
            (is (consp (adf-program-adf1 program)))
            (is (consp (adf-program-rpb program)))))))))
