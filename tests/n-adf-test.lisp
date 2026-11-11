(in-package #:cl-koza-2.tests)

(in-suite cl-koza-2-tests)

(defparameter *n-adf-base-function-set* '(and or nand nor))
(defparameter *n-adf-base-argument-map* '(2 2 2 2))
(defparameter *n-adf-terminal-set* '(arg0 arg1 arg2))
(defparameter *n-adf-rpb-terminal-set* '(d0 d1 d2 d3 d4))

(defun n-adf-symbol (index)
  (intern (format nil "ADF~D" index)))

(defun n-adf-function-set (index)
  (let ((function-set *n-adf-base-function-set*)
        (argument-map *n-adf-base-argument-map*))
    (loop for previous below index
          do (setf function-set
                   (append function-set (list (n-adf-symbol previous))))
             (setf argument-map (append argument-map (list 3))))
    (values function-set argument-map)))

(defun n-adf-rpb-function-set (count)
  (let ((function-set *n-adf-base-function-set*)
        (argument-map *n-adf-base-argument-map*))
    (loop for index below count
          do (setf function-set
                   (append function-set (list (n-adf-symbol index))))
             (setf argument-map (append argument-map (list 3))))
    (values function-set argument-map)))

(defun make-test-adf-branch-spec (index)
  (make-branch-spec
   :function-set-creator (lambda ()
                           (n-adf-function-set index))
   :terminal-set-creator (lambda ()
                           *n-adf-terminal-set*)))

(defun make-test-rpb-branch-spec (count)
  (make-branch-spec
   :function-set-creator (lambda ()
                           (n-adf-rpb-function-set count))
   :terminal-set-creator (lambda ()
                           *n-adf-rpb-terminal-set*)))

(defun n-adf-fitness-cases ()
  (make-array *number-of-fitness-cases*))

(defun define-n-adf-parameters ()
  (setf *number-of-fitness-cases* 32)
  (setf *max-depth-for-new-individuals* 5)
  (setf *max-depth-for-new-subtrees-in-mutants* 4)
  (setf *max-depth-for-individuals-after-crossover* 17)
  (setf *fitness-proportionate-reproduction-fraction* 0.1)
  (setf *crossover-at-any-point-fraction* 0.2)
  (setf *crossover-at-function-point-fraction* 0.7)
  (setf *method-of-selection* :tournament)
  (setf *tournament-size* 7)
  (setf *method-of-generation* :ramped-half-and-half)
  (values))

(defun n-adf-termination (current-generation
                          maximum-generations
                          best-standardized-fitness
                          best-hits)
  (declare (ignore best-standardized-fitness))
  (values (or (>= current-generation maximum-generations)
              (>= best-hits *number-of-fitness-cases*))))

(defun make-n-adf-problem (count
                           &key parameter-overrides
                                (fitness-function #'constant-fitness)
                                (termination-predicate #'n-adf-termination))
  (lambda ()
    (values
     (loop for index below count
           collect (make-test-adf-branch-spec index))
     (make-test-rpb-branch-spec count)
     #'n-adf-fitness-cases
     fitness-function
     (lambda ()
       (define-n-adf-parameters)
       (loop for (name . value) in parameter-overrides
             do (setf (symbol-value name) value)))
     termination-predicate)))

(defun valid-n-adf-branch-p (branch index maximum-depth)
  (multiple-value-bind (function-set argument-map)
      (n-adf-function-set index)
    (valid-tree-p branch function-set argument-map
                  *n-adf-terminal-set* 1 maximum-depth)))

(defun valid-n-adf-rpb-p (branch count maximum-depth)
  (multiple-value-bind (function-set argument-map)
      (n-adf-rpb-function-set count)
    (valid-tree-p branch function-set argument-map
                  *n-adf-rpb-terminal-set* 1 maximum-depth)))

(defun valid-n-adf-program-p (program count maximum-depth)
  (and (= count (adf-program-branch-count program))
       (loop for index below count
             always (valid-n-adf-branch-p
                     (adf-program-adf program index)
                     index maximum-depth))
       (valid-n-adf-rpb-p (adf-program-rpb program)
                          count maximum-depth)))

(defun all-n-adf-programs-valid-p (population count maximum-depth)
  (loop for index below (length population)
        always (valid-n-adf-program-p
                (individual-program (aref population index))
                count maximum-depth)))

(defun n-program-bodies (program)
  (append (coerce (adf-program-adfs program) 'list)
          (list (adf-program-rpb program))))

(test adf-program-n-branches
  (let ((program (make-adf-program :adfs (list 'a 'b 'c) :rpb 'd)))
    (is (= 3 (adf-program-branch-count program)))
    (is (equal '(:adf0 :adf1 :adf2 :rpb) (branch-names program)))
    (is (eq 'a (adf-program-adf0 program)))
    (is (eq 'b (adf-program-adf1 program)))
    (is (eq 'c (adf-program-adf program 2)))
    (is (eq 'c (program-branch program :adf2)))
    (is (eq 'd (program-branch program :rpb)))
    (is (= 2 (branch-index :adf2)))
    (is (eq :rpb (branch-index :rpb)))))

(test adf-program-zero-adfs
  (let ((program (make-adf-program :adfs nil :rpb 'd)))
    (is (zerop (adf-program-branch-count program)))
    (is (equal '(:rpb) (branch-names program)))
    (is (null (adf-program-adf0 program)))
    (is (null (adf-program-adf1 program)))
    (signals error (program-branch program :adf0))
    (let ((text (prin1-to-string program)))
      (is (search "(defun RPB" text))
      (is (not (search "(defun ADF" text))))))

(test adf-program-legacy-compatibility
  (let ((program (make-adf-program :adf0 'a :adf1 'b :rpb 'c)))
    (is (= 2 (adf-program-branch-count program)))
    (is (equal '(:adf0 :adf1 :rpb) (branch-names)))
    (is (eq 'a (adf-program-adf0 program)))
    (is (eq 'b (adf-program-adf1 program)))
    (is (eq 'c (adf-program-rpb program))))
  (let ((program (make-adf-program)))
    (is (= 2 (adf-program-branch-count program)))
    (is (null (adf-program-adf0 program)))
    (is (null (adf-program-adf1 program))))
  (signals error
    (make-adf-program :adfs (list 'a) :adf0 'b :rpb 'c)))

(test adf-program-n-setf-and-copy
  (let* ((program (make-adf-program
                   :adfs (list '(and a b) '(or c d))
                   :rpb '(nand e f)))
         (copy (copy-adf-program program)))
    (setf (adf-program-adf program 0) '(nor x y))
    (is (equal '(and a b) (adf-program-adf copy 0)))
    (setf (adf-program-adf0 copy) '(and z z))
    (is (equal '(and z z) (adf-program-adf0 copy)))
    (is (equal '(nor x y) (adf-program-adf0 program)))
    (setf (adf-program-adf1 copy) '(or q q))
    (is (equal '(or q q) (adf-program-adf1 copy)))))

(test adf-program-n-map-and-substitution
  (let ((program (make-adf-program :adfs (list 'a 'b 'c) :rpb 'd)))
    (is (equal '((:adf0 a) (:adf1 b) (:adf2 c) (:rpb d))
               (map-program-branches
                (lambda (branch body) (list branch body))
                program)))
    (let ((new (copy-individual-substituting-branch
                :adf1 'new program)))
      (is (eq 'new (adf-program-adf new 1)))
      (is (equal 'a (adf-program-adf new 0)))
      (is (equal 'c (adf-program-adf new 2)))
      (is (equal 'd (adf-program-rpb new))))
    (let ((new (copy-individual-substituting-branch
                :rpb 'new-rpb program)))
      (is (eq 'new-rpb (adf-program-rpb new)))
      (is (equal 'a (adf-program-adf new 0)))
      (is (equal 'b (adf-program-adf new 1)))
      (is (equal 'c (adf-program-adf new 2))))))

(test adf-program-n-printing
  (let ((text (prin1-to-string
               (make-adf-program :adfs (list 'a 'b 'c) :rpb 'd))))
    (is (search "(defun ADF0" text))
    (is (search "(defun ADF1" text))
    (is (search "(defun ADF2" text))
    (is (search "(defun RPB" text)))
  (let ((text (prin1-to-string
               (make-adf-program :adf0 'a :adf1 'b :rpb 'c))))
    (is (search "(defun ADF0 (ARG0 ARG1 ARG2)" text))
    (is (search "(defun ADF1 (ARG0 ARG1 ARG2)" text))))

(test run-adf-system-all-branch-counts
  (dolist (count '(0 1 2 3 4))
    (with-kernel-defaults
      (let (population fitness-cases)
        (let ((output
                (capture-output
                 (multiple-value-setq (population fitness-cases)
                   (run-adf-system (make-n-adf-problem count)
                                   10 1 8)))))
          (is (= 8 (length population)))
          (is (= 32 (length fitness-cases)))
          (is (all-n-adf-programs-valid-p
               population count
               *max-depth-for-individuals-after-crossover*))
          (is (loop for index below (length population)
                    always (= count
                              (adf-program-branch-count
                               (individual-program
                                (aref population index))))))
          (is (search "Number of ADFs" output))
          (is (search "best-of-run" output)))))))

(test run-adf-system-crossover-preserves-validity
  (with-kernel-defaults
    (let (population)
      (capture-output
       (setf population
             (run-adf-system
              (make-n-adf-problem
               3
               :parameter-overrides
               '((*fitness-proportionate-reproduction-fraction* . 0.0)
                 (*crossover-at-any-point-fraction* . 0.0)
                 (*crossover-at-function-point-fraction* . 1.0))
               :fitness-function #'constant-fitness)
              1.0 2 10)))
      (is (= 10 (length population)))
      (is (all-n-adf-programs-valid-p
           population 3
           *max-depth-for-individuals-after-crossover*)))))

(test run-adf-system-mutation-preserves-validity
  (with-kernel-defaults
    (let (population)
      (capture-output
       (setf population
             (run-adf-system
              (make-n-adf-problem
               3
               :parameter-overrides
               '((*fitness-proportionate-reproduction-fraction* . 0.0)
                 (*crossover-at-any-point-fraction* . 0.0)
                 (*crossover-at-function-point-fraction* . 0.0)
                 (*max-depth-for-new-subtrees-in-mutants* . 2))
               :fitness-function #'constant-fitness)
              1.0 2 10)))
      (is (all-n-adf-programs-valid-p
           population 3 most-positive-fixnum)))))

(test run-adf-system-seeded-program
  (with-kernel-defaults
    (let* ((seed-program
             (make-adf-program
              :adfs (list 'arg0 'arg0 'arg0)
              :rpb 'd0))
           (population nil))
      (capture-output
       (setf population
             (run-adf-system (make-n-adf-problem 3)
                             42 1 8 seed-program)))
      (is (find seed-program population
                :key #'individual-program :test #'eq))
      (is (all-n-adf-programs-valid-p
           population 3
           *max-depth-for-individuals-after-crossover*)))))

(test run-adf-system-reproducible
  (with-kernel-defaults
    (flet ((result ()
             (let (population)
               (capture-output
                (setf population
                      (run-adf-system (make-n-adf-problem 3)
                                      42 2 8)))
               (list (n-program-bodies
                      (individual-program (aref population 0)))
                     (individual-standardized-fitness
                      (aref population 0))
                     (individual-hits (aref population 0))
                     *generation-of-best-of-run-individual*))))
      (is (equal (result) (result))))))

(test run-adf-system-validation
  (with-kernel-defaults
    (signals error
      (capture-output
       (run-adf-system nil 1.0 1 8)))
    (signals error
      (capture-output
       (run-adf-system
        (lambda ()
          (values (list :not-a-spec)
                  (make-test-rpb-branch-spec 0)
                  #'n-adf-fitness-cases
                  #'constant-fitness
                  #'define-n-adf-parameters
                  #'n-adf-termination))
        1.0 1 8)))))
