(in-package #:cl-koza-2.kernel)

(defvar *verbose* nil
  "When non-NIL, print a report at the end of every generation.")

(defvar *number-of-fitness-cases* :unbound
  "The number of fitness cases.")

(defvar *max-depth-for-new-individuals* :unbound
  "The maximum depth for individuals of the initial random generation.")

(defvar *max-depth-for-individuals-after-crossover* :unbound
  "The maximum depth of new individuals created by crossover.")

(defvar *fitness-proportionate-reproduction-fraction* :unbound
  "The fraction of the population that will experience fitness
   proportionate reproduction (with reselection) during each
   generation.")

(defvar *crossover-at-any-point-fraction* :unbound
  "The fraction of the population that will experience crossover at
   any point in the tree (including terminals) during each generation.")

(defvar *crossover-at-function-point-fraction* :unbound
  "The fraction of the population that will experience crossover at a
   function (internal) point in the tree during each generation.")

(defvar *max-depth-for-new-subtrees-in-mutants* :unbound
  "The maximum depth of new subtrees created by mutation.")

(defvar *method-of-selection* :unbound
  "The method of selecting individuals in the population.  Either
   :fitness-proportionate, :tournament or
   :fitness-proportionate-with-over-selection.")

(defvar *method-of-generation* :unbound
  "Can be any one of :grow, :full, :ramped-half-and-half.")

(defparameter *tournament-size* 7
  "The group size to use when doing tournament selection.")

(defvar *best-of-run-individual* :unbound
  "The best individual found during this run.")

(defvar *generation-of-best-of-run-individual* :unbound
  "The generation at which the best-of-run individual was found.")

(defvar *parallel-evaluation-p* t
  "When non-NIL, evaluate population fitness with lparallel.")

(defvar *parallel-generation-p* t
  "When non-NIL, create the initial population with lparallel.")

(defstruct individual
  program
  (standardized-fitness 0)
  (adjusted-fitness 0)
  (normalized-fitness 0)
  (hits 0))

(defstruct branch-spec
  function-set-creator
  terminal-set-creator)

(defstruct resolved-branch
  function-set
  argument-map
  terminal-set
  terminal-set-creator)

(defun funcallable-designator-p (object)
  (or (functionp object)
      (and (symbolp object) (fboundp object))))

(defun validate-run-arguments (problem-function
                               seed
                               maximum-generations
                               size-of-population)
  (assert (and (integerp maximum-generations)
               (not (minusp maximum-generations)))
          (maximum-generations)
          "Maximum-generations must be a non-negative integer, not ~S"
          maximum-generations)
  (assert (and (integerp size-of-population)
               (plusp size-of-population))
          (size-of-population)
          "Size-Of-Population must be a positive integer, not ~S"
          size-of-population)
  (assert (funcallable-designator-p problem-function)
          (problem-function)
          "Problem-Function must be a function.")
  (assert (and (numberp seed) (not (zerop seed))) (seed)
          "The randomizer seed must be a non-zero number."))

(defun ensure-parallel-kernel ()
  "Creates the lparallel kernel if it does not already exist."
  (unless lparallel:*kernel*
    (setf lparallel:*kernel*
          (lparallel:make-kernel
           (max 1 (cpus:get-number-of-processors)))))
  lparallel:*kernel*)

(defun derive-generation-seed (seed index)
  "Returns a deterministic Park-Miller seed for population INDEX."
  (let* ((modulus (- (expt 2 31) 1))
         (limit (1- modulus))
         (base (mod (abs (truncate (coerce seed 'double-float))) limit))
         (mixed (mod (+ (* base 16807)
                        (* (1+ index) 2654435761))
                     limit)))
    (coerce (1+ mixed) 'double-float)))

(defun initialize-run (seed)
  (setf *seed* (coerce seed 'double-float))
  (setf *generation-of-best-of-run-individual* 0)
  (setf *best-of-run-individual* nil)
  (when (or *parallel-evaluation-p* *parallel-generation-p*)
    (ensure-parallel-kernel)))

(defun validate-branch-spec (spec description)
  (unless (branch-spec-p spec)
    (error "~A must be a BRANCH-SPEC, not ~S." description spec))
  (unless (funcallable-designator-p
           (branch-spec-function-set-creator spec))
    (error "~A function-set creator must be a function designator."
           description))
  (unless (funcallable-designator-p
           (branch-spec-terminal-set-creator spec))
    (error "~A terminal-set creator must be a function designator."
           description))
  spec)

(defun validate-branch-specs (adf-specs rpb-spec)
  (unless (listp adf-specs)
    (error "ADF specs must be a list, not ~S." adf-specs))
  (loop for spec in adf-specs
        for index from 0
        do (validate-branch-spec spec (format nil "ADF~D" index)))
  (validate-branch-spec rpb-spec "RPB"))

(defun run-genetic-programming-system (problem-function
                                       seed
                                       maximum-generations
                                       size-of-population
                                       &rest seeded-programs)
  "Runs the genetic programming system with automatically defined
   functions.  PROBLEM-FUNCTION must return ten values:

     1. creator of the ADF0 function set
     2. creator of the ADF1 function set
     3. creator of the result-producing branch function set
     4. creator of the ADF0 terminal set
     5. creator of the ADF1 terminal set
     6. creator of the result-producing branch terminal set
     7. creator of the fitness cases
     8. fitness function
     9. parameter definer
    10. termination predicate

   The function-set creators return two values: the function set and its
   associated argument map.  The fitness function receives an
   ADF-PROGRAM and the fitness cases and returns two values: the
   standardized fitness and the number of hits."
  (validate-run-arguments problem-function
                          seed
                          maximum-generations
                          size-of-population)
  (initialize-run seed)
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
      (funcall problem-function)
    (run-system
     (list (make-branch-spec
            :function-set-creator adf0-function-set-creator
            :terminal-set-creator adf0-terminal-set-creator)
           (make-branch-spec
            :function-set-creator adf1-function-set-creator
            :terminal-set-creator adf1-terminal-set-creator))
     (make-branch-spec
      :function-set-creator rpb-function-set-creator
      :terminal-set-creator rpb-terminal-set-creator)
     maximum-generations
     size-of-population
     seeded-programs
     fitness-cases-creator
     fitness-function
     parameter-definer
     termination-predicate)))

(defun run-adf-system (problem-function
                       seed
                       maximum-generations
                       size-of-population
                       &rest seeded-programs)
  "Runs the genetic programming system with an arbitrary number of ADFs.

   PROBLEM-FUNCTION must return six values:

     1. a list of BRANCH-SPEC objects for ADF0 ... ADF(N-1)
     2. a BRANCH-SPEC object for the result-producing branch
     3. creator of the fitness cases
     4. fitness function
     5. parameter definer
     6. termination predicate

   The number of ADFs is the length of the first value.  A NIL first
   value creates a program with no ADFs, only the result-producing
   branch.  The fitness function receives an ADF-PROGRAM and the
   fitness cases and returns two values: the standardized fitness and
   the number of hits."
  (validate-run-arguments problem-function
                          seed
                          maximum-generations
                          size-of-population)
  (initialize-run seed)
  (multiple-value-bind (adf-specs
                        rpb-spec
                        fitness-cases-creator
                        fitness-function
                        parameter-definer
                        termination-predicate)
      (funcall problem-function)
    (validate-branch-specs adf-specs rpb-spec)
    (run-system adf-specs
                rpb-spec
                maximum-generations
                size-of-population
                seeded-programs
                fitness-cases-creator
                fitness-function
                parameter-definer
                termination-predicate)))

(defun resolve-branch-spec (spec)
  (multiple-value-bind (function-set argument-map)
      (funcall (branch-spec-function-set-creator spec))
    (make-resolved-branch
     :function-set function-set
     :argument-map argument-map
     :terminal-set-creator (branch-spec-terminal-set-creator spec))))

(defun resolve-branch-specs (adf-specs rpb-spec)
  (values (mapcar #'resolve-branch-spec adf-specs)
          (resolve-branch-spec rpb-spec)))

(defun resolve-terminal-sets (adf-branches rpb-branch)
  (dolist (branch adf-branches)
    (setf (resolved-branch-terminal-set branch)
          (funcall (resolved-branch-terminal-set-creator branch))))
  (setf (resolved-branch-terminal-set rpb-branch)
        (funcall (resolved-branch-terminal-set-creator rpb-branch)))
  (values adf-branches rpb-branch))

(defun run-system (adf-specs
                   rpb-spec
                   maximum-generations
                   size-of-population
                   seeded-programs
                   fitness-cases-creator
                   fitness-function
                   parameter-definer
                   termination-predicate)
  (multiple-value-bind (adf-branches rpb-branch)
      (resolve-branch-specs adf-specs rpb-spec)
    (funcall parameter-definer)
    (describe-parameters-for-run maximum-generations
                                 size-of-population
                                 (length adf-branches))
    (resolve-terminal-sets adf-branches rpb-branch)
    (let ((population
            (create-population-with-branches size-of-population
                                             adf-branches
                                             rpb-branch
                                             seeded-programs)))
      (let ((fitness-cases (funcall fitness-cases-creator))
            (new-programs (make-array size-of-population)))
        (execute-generations population
                             new-programs
                             fitness-cases
                             maximum-generations
                             fitness-function
                             termination-predicate
                             adf-branches
                             rpb-branch)
        (report-on-run)
        (values population fitness-cases)))))

(defun report-on-run ()
  "Prints out the best-of-run individual."
  (let ((*print-pretty* t))
    (format t "~5%The best-of-run individual program for this run was ~
               found on~%generation ~D and had a standardized fitness ~
               measure of ~D and ~D hit~P.~%It was:~%~S"
            *generation-of-best-of-run-individual*
            (individual-standardized-fitness *best-of-run-individual*)
            (individual-hits *best-of-run-individual*)
            (individual-hits *best-of-run-individual*)
            (individual-program *best-of-run-individual*))))

(defun report-on-generation (generation-number population)
  "Prints out the best individual at the end of each generation."
  (let ((best-individual (aref population 0))
        (size-of-population (length population))
        (sum 0.0)
        (*print-pretty* t))
    (dotimes (index size-of-population)
      (incf sum (individual-standardized-fitness
                 (aref population index))))
    (format t "~2%Generation ~D:  Average standardized-fitness = ~S.~
               ~%The best individual program of the population had a~
               ~%standardized fitness measure of ~D and ~D hit~P.~
               ~%It was: ~%~S"
            generation-number (/ sum (length population))
            (individual-standardized-fitness best-individual)
            (individual-hits best-individual)
            (individual-hits best-individual)
            (individual-program best-individual))))

(defun print-population (population)
  "Given a population, this prints it out (for debugging)."
  (let ((*print-pretty* t))
    (dotimes (index (length population))
      (let ((individual (aref population index)))
        (format t "~&~D   ~S    ~S"
                index
                (individual-standardized-fitness individual)
                (individual-program individual))))))

(defun describe-parameters-for-run (maximum-generations
                                    size-of-population
                                    &optional number-of-adfs)
  "Lists the parameter settings for this run."
  (format t "~2%Parameters used for this run.~
              ~%=============================")
  (format t "~%Maximum number of Generations:~50T~D"
          maximum-generations)
  (format t "~%Size of Population:~50T~D" size-of-population)
  (when number-of-adfs
    (format t "~%Number of ADFs:~50T~D" number-of-adfs))
  (format t "~%Maximum depth of new individuals:~50T~D"
          *max-depth-for-new-individuals*)
  (format t "~%Maximum depth of new subtrees for mutants:~50T~D"
          *max-depth-for-new-subtrees-in-mutants*)
  (format t "~%Maximum depth of individuals after crossover:~50T~D"
          *max-depth-for-individuals-after-crossover*)
  (format t "~%Fitness-proportionate reproduction fraction:~50T~D"
          *fitness-proportionate-reproduction-fraction*)
  (format t "~%Crossover at any point fraction:~50T~D"
          *crossover-at-any-point-fraction*)
  (format t "~%Crossover at function points fraction:~50T~D"
          *crossover-at-function-point-fraction*)
  (format t "~%Number of fitness cases:~50T~D"
          *number-of-fitness-cases*)
  (format t "~%Selection method: ~50T~A" *method-of-selection*)
  (format t "~%Tournament group size: ~50T~D" *tournament-size*)
  (format t "~%Generation method: ~50T~A" *method-of-generation*)
  (format t "~%Randomizer seed: ~50T~D~%" *seed*))

(defvar *generation-0-uniquifier-table*
  (make-hash-table :test #'equal)
  "Used to guarantee that all generation 0 individuals are unique.")

(defun choose-from-terminal-set (terminal-set)
  "Chooses a random terminal from the terminal set.  The ephemeral
   :floating-point-random-constant and :integer-random-constant
   terminals are instantiated here."
  (let ((choice (nth (random-integer (length terminal-set))
                     terminal-set)))
    (case choice
      (:floating-point-random-constant
       (coerce (- (random-floating-point-number 10.0) 5.0)
               'single-float))
      (:integer-random-constant
       (- (random-integer 21) 10))
      (otherwise choice))))

(defun create-individual-subtree (function-set argument-map terminal-set
                                  allowable-depth top-node-p full-p)
  "Creates a subtree recursively using the specified functions and
   terminals."
  (cond ((<= allowable-depth 0)
         (choose-from-terminal-set terminal-set))
        ((or full-p top-node-p)
         (let ((choice (random-integer (length function-set))))
           (let ((function (nth choice function-set))
                 (number-of-arguments (nth choice argument-map)))
             (cons function
                   (create-arguments-for-function
                    number-of-arguments function-set argument-map
                    terminal-set (- allowable-depth 1) full-p)))))
        (t
         (let ((choice (random-integer (+ (length terminal-set)
                                          (length function-set)))))
           (if (< choice (length function-set))
               (let ((function (nth choice function-set))
                     (number-of-arguments (nth choice argument-map)))
                 (cons function
                       (create-arguments-for-function
                        number-of-arguments function-set argument-map
                        terminal-set (- allowable-depth 1) full-p)))
               (choose-from-terminal-set terminal-set))))))

(defun create-arguments-for-function (number-of-arguments
                                      function-set argument-map
                                      terminal-set allowable-depth full-p)
  "Creates the argument list for a node in the tree."
  (if (= number-of-arguments 0)
      nil
      (cons (create-individual-subtree function-set argument-map
                                       terminal-set allowable-depth
                                       nil full-p)
            (create-arguments-for-function
             (- number-of-arguments 1) function-set argument-map
             terminal-set allowable-depth full-p))))

(defun create-program-branch (function-set argument-map terminal-set
                              minimum-depth-of-trees maximum-depth-of-trees
                              individual-index full-cycle-p)
  "Creates a complete branch for an ADF-containing program."
  (create-individual-subtree
   function-set argument-map terminal-set
   (ecase *method-of-generation*
     ((:full :grow) maximum-depth-of-trees)
     (:ramped-half-and-half
      (+ minimum-depth-of-trees
         (mod individual-index
              (max 1 (- maximum-depth-of-trees
                        minimum-depth-of-trees))))))
   t
   (ecase *method-of-generation*
     (:full t)
     (:grow nil)
     (:ramped-half-and-half full-cycle-p))))

(defun create-new-program (individual-index
                           full-cycle-p
                           minimum-depth-of-trees
                           maximum-depth-of-trees
                           adf-branches
                           rpb-branch)
  "Creates a new individual with an arbitrary number of ADFs."
  (flet ((create-branch (branch)
           (create-program-branch
            (resolved-branch-function-set branch)
            (resolved-branch-argument-map branch)
            (resolved-branch-terminal-set branch)
            minimum-depth-of-trees
            maximum-depth-of-trees
            individual-index
            full-cycle-p)))
    (make-adf-program
     :adfs (map 'vector #'create-branch adf-branches)
     :rpb (create-branch rpb-branch))))

(defun program-uniquifier-key (program)
  (append (coerce (adf-program-adfs program) 'list)
          (list (adf-program-rpb program))))

(defun create-population-with-branches (size-of-population
                                        adf-branches
                                        rpb-branch
                                        seeded-programs)
  "Creates the population with an arbitrary number of ADF branches.

   Random programs are generated from deterministic per-individual
   seeds, so the initial population is reproducible regardless of the
   number of worker threads."
  (let* ((population (make-array size-of-population))
         (seeded-count (min size-of-population (length seeded-programs)))
         (minimum-depth-of-trees 1)
         (full-cycle-p nil)
         (generation-flags (make-array size-of-population))
         (candidates (make-array size-of-population))
         (states (make-array size-of-population))
         (base-seed *seed*)
         (generation-maximum-depth *max-depth-for-new-individuals*)
         (generation-method *method-of-generation*))
    (dotimes (individual-index seeded-count)
      (setf (aref population individual-index)
            (make-individual :program (nth individual-index
                                           seeded-programs))))
    (dotimes (individual-index size-of-population)
      (when (zerop (mod individual-index
                        (max 1 (- *max-depth-for-new-individuals*
                                  minimum-depth-of-trees))))
        (setf full-cycle-p (not full-cycle-p)))
      (setf (aref generation-flags individual-index) full-cycle-p))
    (labels ((generate (individual-index)
               (let ((*seed* (derive-generation-seed
                              base-seed individual-index))
                     (*max-depth-for-new-individuals*
                       generation-maximum-depth)
                     (*method-of-generation* generation-method))
                 (setf (aref candidates individual-index)
                       (create-new-program
                        individual-index
                        (aref generation-flags individual-index)
                        minimum-depth-of-trees
                        (- *max-depth-for-new-individuals* 1)
                        adf-branches
                        rpb-branch))
                 (setf (aref states individual-index) *seed*))))
      (let ((random-count (- size-of-population seeded-count)))
        (cond ((zerop random-count))
              ((and *parallel-generation-p* (> random-count 1))
               (ensure-parallel-kernel)
               (lparallel:pdotimes (offset random-count)
                 (generate (+ seeded-count offset))))
              (t
               (dotimes (offset random-count)
                 (generate (+ seeded-count offset))))))
    (let ((attempts-at-this-individual 0)
          (last-state base-seed))
      (clrhash *generation-0-uniquifier-table*)
      (loop for individual-index from seeded-count below size-of-population
            do (let ((new-program (aref candidates individual-index))
                     (state (aref states individual-index)))
                 (setf attempts-at-this-individual 0)
                 (loop
                   (let ((program-as-list
                           (program-uniquifier-key new-program)))
                     (cond ((not (gethash program-as-list
                                          *generation-0-uniquifier-table*))
                            (setf (aref population individual-index)
                                  (make-individual :program new-program))
                            (setf (gethash program-as-list
                                           *generation-0-uniquifier-table*)
                                  t)
                            (return))
                           ((> attempts-at-this-individual 20)
                            (incf minimum-depth-of-trees)
                            (setf *max-depth-for-new-individuals*
                                  (max *max-depth-for-new-individuals*
                                       minimum-depth-of-trees))
                            (let ((*seed* state))
                              (setf new-program
                                    (create-new-program
                                     individual-index
                                     (aref generation-flags individual-index)
                                     minimum-depth-of-trees
                                     (- *max-depth-for-new-individuals* 1)
                                     adf-branches
                                     rpb-branch))
                              (setf state *seed*)))
                           (t
                            (incf attempts-at-this-individual)
                            (let ((*seed* state))
                              (setf new-program
                                    (create-new-program
                                     individual-index
                                     (aref generation-flags individual-index)
                                     minimum-depth-of-trees
                                     (- *max-depth-for-new-individuals* 1)
                                     adf-branches
                                     rpb-branch))
                              (setf state *seed*))))))
                 (setf (aref candidates individual-index) new-program
                       (aref states individual-index) state
                       last-state state)))
      (clrhash *generation-0-uniquifier-table*)
      (setf *seed* last-state))
    population)))

(defun create-population (size-of-population
                          adf0-function-set adf0-argument-map
                          adf0-terminal-set
                          adf1-function-set adf1-argument-map
                          adf1-terminal-set
                          rpb-function-set rpb-argument-map
                          rpb-terminal-set
                          seeded-programs)
  "Creates the population.  This is an array of size SIZE-OF-POPULATION
   initialized with individual records.  The first N individuals are
   initialized with the respective seeded programs; the rest are random.

   This is the legacy two-ADF entry point."
  (create-population-with-branches
   size-of-population
   (list (make-resolved-branch
          :function-set adf0-function-set
          :argument-map adf0-argument-map
          :terminal-set adf0-terminal-set)
         (make-resolved-branch
          :function-set adf1-function-set
          :argument-map adf1-argument-map
          :terminal-set adf1-terminal-set))
   (make-resolved-branch
    :function-set rpb-function-set
    :argument-map rpb-argument-map
    :terminal-set rpb-terminal-set)
   seeded-programs))

(defun execute-generations (population
                            new-programs
                            fitness-cases
                            maximum-generations
                            fitness-function
                            termination-predicate
                            adf-branches
                            rpb-branch)
  "Loops until the user's termination predicate says to stop."
  (do ((current-generation 0 (+ 1 current-generation)))
      ((let ((best-of-generation (aref population 0)))
         (funcall termination-predicate
                  current-generation
                  maximum-generations
                  (individual-standardized-fitness best-of-generation)
                  (individual-hits best-of-generation))))
    (when (> current-generation 0)
      (breed-new-population population new-programs
                            adf-branches rpb-branch))
    (zeroize-fitness-measures-of-population population)
    (evaluate-fitness-of-population population fitness-cases
                                    fitness-function)
    (normalize-fitness-of-population population)
    (sort-population-by-fitness population)
    (let ((best-of-generation (aref population 0)))
      (when (or (not *best-of-run-individual*)
                (> (individual-standardized-fitness
                    *best-of-run-individual*)
                   (individual-standardized-fitness best-of-generation)))
        (setf *best-of-run-individual*
              (copy-individual best-of-generation))
        (setf *generation-of-best-of-run-individual*
              current-generation)))
    (when *verbose*
      (report-on-generation current-generation population))))

(defun zeroize-fitness-measures-of-population (population)
  "Cleans out the statistics in each individual in the population."
  (dotimes (individual-index (length population))
    (let ((individual (aref population individual-index)))
      (setf (individual-standardized-fitness individual) 0.0)
      (setf (individual-adjusted-fitness individual) 0.0)
      (setf (individual-normalized-fitness individual) 0.0)
      (setf (individual-hits individual) 0))))

(defun capture-run-parameters ()
  (list (cons '*verbose* *verbose*)
        (cons '*number-of-fitness-cases* *number-of-fitness-cases*)
        (cons '*max-depth-for-new-individuals*
              *max-depth-for-new-individuals*)
        (cons '*max-depth-for-individuals-after-crossover*
              *max-depth-for-individuals-after-crossover*)
        (cons '*fitness-proportionate-reproduction-fraction*
              *fitness-proportionate-reproduction-fraction*)
        (cons '*crossover-at-any-point-fraction*
              *crossover-at-any-point-fraction*)
        (cons '*crossover-at-function-point-fraction*
              *crossover-at-function-point-fraction*)
        (cons '*max-depth-for-new-subtrees-in-mutants*
              *max-depth-for-new-subtrees-in-mutants*)
        (cons '*method-of-selection* *method-of-selection*)
        (cons '*method-of-generation* *method-of-generation*)
        (cons '*tournament-size* *tournament-size*)
        (cons '*best-of-run-individual* *best-of-run-individual*)
        (cons '*generation-of-best-of-run-individual*
              *generation-of-best-of-run-individual*)
        (cons '*seed* *seed*)))

(defun evaluate-individual-fitness (individual fitness-cases
                                    fitness-function parameters)
  (let ((*verbose* (cdr (assoc '*verbose* parameters)))
        (*number-of-fitness-cases*
          (cdr (assoc '*number-of-fitness-cases* parameters)))
        (*max-depth-for-new-individuals*
          (cdr (assoc '*max-depth-for-new-individuals* parameters)))
        (*max-depth-for-individuals-after-crossover*
          (cdr (assoc '*max-depth-for-individuals-after-crossover*
                      parameters)))
        (*fitness-proportionate-reproduction-fraction*
          (cdr (assoc '*fitness-proportionate-reproduction-fraction*
                      parameters)))
        (*crossover-at-any-point-fraction*
          (cdr (assoc '*crossover-at-any-point-fraction* parameters)))
        (*crossover-at-function-point-fraction*
          (cdr (assoc '*crossover-at-function-point-fraction*
                      parameters)))
        (*max-depth-for-new-subtrees-in-mutants*
          (cdr (assoc '*max-depth-for-new-subtrees-in-mutants*
                      parameters)))
        (*method-of-selection*
          (cdr (assoc '*method-of-selection* parameters)))
        (*method-of-generation*
          (cdr (assoc '*method-of-generation* parameters)))
        (*tournament-size* (cdr (assoc '*tournament-size* parameters)))
        (*best-of-run-individual*
          (cdr (assoc '*best-of-run-individual* parameters)))
        (*generation-of-best-of-run-individual*
          (cdr (assoc '*generation-of-best-of-run-individual*
                      parameters)))
        (*seed* (cdr (assoc '*seed* parameters))))
    (multiple-value-bind (standardized-fitness hits)
        (funcall fitness-function (individual-program individual)
                                 fitness-cases)
      (setf (individual-standardized-fitness individual)
            standardized-fitness)
      (setf (individual-hits individual) hits))))

(defun evaluate-fitness-of-population (population fitness-cases
                                       fitness-function)
  "Evaluates and records the fitness and hits of each individual.

   When *PARALLEL-EVALUATION-P* is true, individuals are evaluated in
   parallel with lparallel.  Set it to NIL for fitness functions that
   are not thread-safe."
  (let ((size-of-population (length population))
        (parameters (capture-run-parameters)))
    (if *parallel-evaluation-p*
        (progn
          (ensure-parallel-kernel)
          (lparallel:pdotimes (individual-index size-of-population)
            (evaluate-individual-fitness
             (aref population individual-index)
             fitness-cases
             fitness-function
             parameters)))
        (dotimes (individual-index size-of-population)
          (evaluate-individual-fitness
           (aref population individual-index)
           fitness-cases
           fitness-function
           parameters)))))

(defun normalize-fitness-of-population (population)
  "Computes the normalized and adjusted fitness of each individual."
  (let ((sum-of-adjusted-fitnesses 0.0))
    (dotimes (individual-index (length population))
      (let ((individual (aref population individual-index)))
        (setf (individual-adjusted-fitness individual)
              (/ 1.0 (+ 1.0 (individual-standardized-fitness individual))))
        (incf sum-of-adjusted-fitnesses
              (individual-adjusted-fitness individual))))
    (dotimes (individual-index (length population))
      (let ((individual (aref population individual-index)))
        (setf (individual-normalized-fitness individual)
              (/ (individual-adjusted-fitness individual)
                 sum-of-adjusted-fitnesses))))))

(defun sort-population-by-fitness (population)
  "Sorts the population destructively into descending order of
   normalized fitness."
  (let ((sorted (sort population #'>
                      :key #'individual-normalized-fitness)))
    (unless (eq sorted population)
      (replace population sorted)))
  population)

(defun breed-new-population (population new-programs
                             adf-branches rpb-branch)
  "Controls the actual breeding of the new population."
  (let ((population-size (length population)))
    (do ((index 0)
         (fraction 0 (/ index population-size)))
        ((>= index population-size))
      (let ((individual-1 (find-individual population)))
        (cond ((and (< index (- population-size 1))
                    (< fraction
                       (+ *crossover-at-function-point-fraction*
                          *crossover-at-any-point-fraction*)))
               (multiple-value-bind (new-male new-female)
                   (funcall
                    (if (< fraction
                           *crossover-at-function-point-fraction*)
                        'crossover-at-function-points
                        'crossover-at-any-points)
                    individual-1
                    (find-individual population))
                 (setf (aref new-programs index) new-male)
                 (setf (aref new-programs (+ 1 index)) new-female))
               (incf index 2))
              ((< fraction
                  (+ *fitness-proportionate-reproduction-fraction*
                     *crossover-at-function-point-fraction*
                     *crossover-at-any-point-fraction*))
               (setf (aref new-programs index) individual-1)
               (incf index 1))
              (t
               (setf (aref new-programs index)
                     (mutate individual-1 adf-branches rpb-branch))
               (incf index 1)))))
    (dotimes (index population-size)
      (setf (individual-program (aref population index))
            (aref new-programs index)))))

(defun find-individual (population)
  "Finds an individual in the population according to the defined
   selection method."
  (ecase *method-of-selection*
    (:tournament
     (find-individual-using-tournament-selection population))
    (:fitness-proportionate-with-over-selection
     (find-fitness-proportionate-individual
      (random-floating-point-number-with-over-selection population)
      population))
    (:fitness-proportionate
     (find-fitness-proportionate-individual
      (random-floating-point-number 1.0)
      population))))

(defun random-floating-point-number-with-over-selection (population)
  "Picks a random number between 0.0 and 1.0 biased using the
   over-selection method."
  (let ((pop-size (length population)))
    (when (< pop-size 1000)
      (error "A population size of ~D is too small for over-selection."
             pop-size))
    (let ((boundary (/ 320.0 pop-size)))
      (if (< (random-floating-point-number 1.0) 0.8)
          (random-floating-point-number boundary)
          (+ boundary
             (random-floating-point-number (- 1.0 boundary)))))))

(defun pick-k-random-individual-indices (k max)
  "Returns a list of K distinct random numbers between 0 and MAX-1."
  (let ((numbers nil)
        (k (min k max)))
    (loop for number = (random-integer max)
          unless (member number numbers :test #'eql)
            do (push number numbers)
          until (= (length numbers) k))
    numbers))

(defun find-individual-using-tournament-selection (population)
  "Picks *tournament-size* individuals from the population at random
   and returns the best one."
  (let ((numbers (pick-k-random-individual-indices
                  *tournament-size* (length population))))
    (loop with best = (aref population (first numbers))
          with best-fitness = (individual-standardized-fitness best)
          for number in (rest numbers)
          for individual = (aref population number)
          for this-fitness = (individual-standardized-fitness individual)
          when (< this-fitness best-fitness)
            do (setf best individual)
               (setf best-fitness this-fitness)
          finally (return (individual-program best)))))

(defun find-fitness-proportionate-individual (after-this-fitness population)
  "Finds an individual whose normalized fitness is greater than the
   specified value."
  (let ((sum-of-fitness 0.0)
        (population-size (length population)))
    (let ((index-of-selected-individual
            (do ((index 0 (+ index 1)))
                ((or (>= index population-size)
                     (>= sum-of-fitness after-this-fitness))
                 (if (>= index population-size)
                     (- (length population) 1)
                     (- index 1)))
              (incf sum-of-fitness
                    (individual-normalized-fitness
                     (aref population index))))))
      (individual-program
       (aref population index-of-selected-individual)))))

(defun select-branch (within-program)
  "Returns two values: a keyword denoting a branch selected at random
   (biased by the number of points in that branch), and the subtree of
   the selected branch."
  (let* ((adfs (coerce (adf-program-adfs within-program) 'list))
         (names (branch-names within-program))
         (bodies (append adfs
                         (list (adf-program-rpb within-program))))
         (points (mapcar #'count-crossover-points bodies))
         (selected-point (random-integer (reduce #'+ points))))
    (loop for name in names
          for body in bodies
          for branch-points in points
          do (if (< selected-point branch-points)
                 (return (values name body))
                 (decf selected-point branch-points)))))

(defun crossover-selecting-branch (how-to-crossover-function male female)
  "Performs crossover on the programs MALE and FEMALE by calling
   HOW-TO-CROSSOVER-FUNCTION on a compatible pair of branches."
  (let ((branch (select-branch male)))
    (multiple-value-bind (new-male-branch new-female-branch)
        (funcall how-to-crossover-function
                 (program-branch male branch)
                 (program-branch female branch))
      (values (copy-individual-substituting-branch
               branch new-male-branch male)
              (copy-individual-substituting-branch
               branch new-female-branch female)))))

(defun crossover-at-any-points (male female)
  "Performs crossover on the programs at any point in the trees."
  (crossover-selecting-branch
   #'crossover-at-any-points-within-branch male female))

(defun crossover-at-any-points-within-branch (male female)
  "Performs crossover on two program branches at any point in the
   subtrees."
  (let ((male-point (random-integer (count-crossover-points male)))
        (female-point (random-integer (count-crossover-points female))))
    (let ((new-male (list (copy-tree male)))
          (new-female (list (copy-tree female))))
      (multiple-value-bind (male-subtree-pointer male-fragment)
          (get-subtree (first new-male) new-male male-point)
        (multiple-value-bind (female-subtree-pointer female-fragment)
            (get-subtree (first new-female) new-female female-point)
          (setf (first male-subtree-pointer) female-fragment)
          (setf (first female-subtree-pointer) male-fragment)))
      (validate-crossover male new-male female new-female))))

(defun validate-crossover (male new-male female new-female)
  "Checks whether the new individuals have exceeded the maximum allowed
   depth.  If either has, the old individual is used instead."
  (let ((male-depth (max-depth-of-tree (first new-male)))
        (female-depth (max-depth-of-tree (first new-female))))
    (values
     (if (or (= 1 male-depth)
             (>= male-depth
                 *max-depth-for-individuals-after-crossover*))
         male
         (first new-male))
     (if (or (= 1 female-depth)
             (>= female-depth
                 *max-depth-for-individuals-after-crossover*))
         female
         (first new-female)))))

(defun crossover-at-function-points (male female)
  "Performs crossover on the two programs at a function (internal)
   point in a randomly selected branch of the trees."
  (crossover-selecting-branch
   #'crossover-at-function-points-within-branch male female))

(defun crossover-at-function-points-within-branch (male female)
  "Performs crossover on two program branches at a function (internal)
   point in the trees."
  (let ((male-point (random-integer (count-function-points male)))
        (female-point (random-integer (count-function-points female))))
    (let ((new-male (list (copy-tree male)))
          (new-female (list (copy-tree female))))
      (multiple-value-bind (male-subtree-pointer male-fragment)
          (get-function-subtree (first new-male) new-male male-point)
        (multiple-value-bind (female-subtree-pointer female-fragment)
            (get-function-subtree (first new-female) new-female female-point)
          (setf (first male-subtree-pointer) female-fragment)
          (setf (first female-subtree-pointer) male-fragment)))
      (validate-crossover male new-male female new-female))))

(defun mutate (program adf-branches rpb-branch)
  "Mutates PROGRAM by picking a random point in a random branch and
   substituting a brand new subtree created in the same way as the
   initial random population."
  (multiple-value-bind (branch branch-tree) (select-branch program)
    (let* ((index (branch-index branch))
           (selected-branch
             (if (eq index :rpb)
                 rpb-branch
                 (nth index adf-branches)))
           (mutation-point
             (random-integer (count-crossover-points branch-tree)))
           (new-subtree
             (create-individual-subtree
              (resolved-branch-function-set selected-branch)
              (resolved-branch-argument-map selected-branch)
              (resolved-branch-terminal-set selected-branch)
              *max-depth-for-new-subtrees-in-mutants*
              t
              nil)))
      (let ((new-branch (list (copy-tree branch-tree))))
        (multiple-value-bind (subtree-pointer fragment)
            (get-subtree (first new-branch) new-branch mutation-point)
          (declare (ignore fragment))
          (setf (first subtree-pointer) new-subtree))
        (values (copy-individual-substituting-branch
                 branch (first new-branch) program)
                new-subtree)))))
