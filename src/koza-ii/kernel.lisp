(in-package #:cl-koza-ii.kernel)

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

(defstruct individual
  program
  (standardized-fitness 0)
  (adjusted-fitness 0)
  (normalized-fitness 0)
  (hits 0))

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
  (assert (or (and (symbolp problem-function)
                   (fboundp problem-function))
              (functionp problem-function))
          (problem-function)
          "Problem-Function must be a function.")
  (assert (numberp seed) (seed)
          "The randomizer seed must be a number.")
  (setf *seed* (coerce seed 'double-float))
  (setf *generation-of-best-of-run-individual* 0)
  (setf *best-of-run-individual* nil)
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
    (multiple-value-bind (adf0-function-set adf0-argument-map)
        (funcall adf0-function-set-creator)
      (multiple-value-bind (adf1-function-set adf1-argument-map)
          (funcall adf1-function-set-creator)
        (multiple-value-bind (rpb-function-set rpb-argument-map)
            (funcall rpb-function-set-creator)
          (funcall parameter-definer)
          (describe-parameters-for-run maximum-generations
                                       size-of-population)
          (let ((adf0-terminal-set (funcall adf0-terminal-set-creator))
                (adf1-terminal-set (funcall adf1-terminal-set-creator))
                (rpb-terminal-set (funcall rpb-terminal-set-creator)))
            (let ((population
                    (create-population size-of-population
                                       adf0-function-set adf0-argument-map
                                       adf0-terminal-set
                                       adf1-function-set adf1-argument-map
                                       adf1-terminal-set
                                       rpb-function-set rpb-argument-map
                                       rpb-terminal-set
                                       seeded-programs)))
              (let ((fitness-cases (funcall fitness-cases-creator))
                    (new-programs (make-array size-of-population)))
                (execute-generations population
                                     new-programs
                                     fitness-cases
                                     maximum-generations
                                     fitness-function
                                     termination-predicate
                                     adf0-function-set adf0-argument-map
                                     adf0-terminal-set
                                     adf1-function-set adf1-argument-map
                                     adf1-terminal-set
                                     rpb-function-set rpb-argument-map
                                     rpb-terminal-set)
                (report-on-run)
                (values population fitness-cases)))))))))

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

(defun describe-parameters-for-run (maximum-generations size-of-population)
  "Lists the parameter settings for this run."
  (format t "~2%Parameters used for this run.~
              ~%=============================")
  (format t "~%Maximum number of Generations:~50T~D"
          maximum-generations)
  (format t "~%Size of Population:~50T~D" size-of-population)
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

(defun create-new-program (individual-index full-cycle-p
                           minimum-depth-of-trees maximum-depth-of-trees
                           adf0-function-set adf0-argument-map
                           adf0-terminal-set
                           adf1-function-set adf1-argument-map
                           adf1-terminal-set
                           rpb-function-set rpb-argument-map
                           rpb-terminal-set)
  "Creates a new individual with ADF structure."
  (make-adf-program
   :adf0 (create-program-branch
          adf0-function-set adf0-argument-map adf0-terminal-set
          minimum-depth-of-trees maximum-depth-of-trees
          individual-index full-cycle-p)
   :adf1 (create-program-branch
          adf1-function-set adf1-argument-map adf1-terminal-set
          minimum-depth-of-trees maximum-depth-of-trees
          individual-index full-cycle-p)
   :rpb (create-program-branch
         rpb-function-set rpb-argument-map rpb-terminal-set
         minimum-depth-of-trees maximum-depth-of-trees
         individual-index full-cycle-p)))

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
   initialized with the respective seeded programs; the rest are random."
  (let ((population (make-array size-of-population))
        (minimum-depth-of-trees 1)
        (attempts-at-this-individual 0)
        (full-cycle-p nil))
    (do ((individual-index 0))
        ((>= individual-index size-of-population))
      (when (zerop (mod individual-index
                        (max 1 (- *max-depth-for-new-individuals*
                                  minimum-depth-of-trees))))
        (setf full-cycle-p (not full-cycle-p)))
      (let ((new-program
              (if (< individual-index (length seeded-programs))
                  (nth individual-index seeded-programs)
                  (create-new-program
                   individual-index full-cycle-p
                   minimum-depth-of-trees
                   (- *max-depth-for-new-individuals* 1)
                   adf0-function-set adf0-argument-map adf0-terminal-set
                   adf1-function-set adf1-argument-map adf1-terminal-set
                   rpb-function-set rpb-argument-map rpb-terminal-set))))
        (let ((program-as-list
                (list (adf-program-adf0 new-program)
                      (adf-program-adf1 new-program)
                      (adf-program-rpb new-program))))
          (cond ((< individual-index (length seeded-programs))
                 (setf (aref population individual-index)
                       (make-individual :program new-program))
                 (incf individual-index))
                ((not (gethash program-as-list
                               *generation-0-uniquifier-table*))
                 (setf (aref population individual-index)
                       (make-individual :program new-program))
                 (setf (gethash program-as-list
                                *generation-0-uniquifier-table*)
                       t)
                 (setf attempts-at-this-individual 0)
                 (incf individual-index))
                ((> attempts-at-this-individual 20)
                 (incf minimum-depth-of-trees)
                 (setf *max-depth-for-new-individuals*
                       (max *max-depth-for-new-individuals*
                            minimum-depth-of-trees)))
                (t
                 (incf attempts-at-this-individual))))))
    (clrhash *generation-0-uniquifier-table*)
    population))

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

(defun execute-generations (population
                            new-programs
                            fitness-cases
                            maximum-generations
                            fitness-function
                            termination-predicate
                            adf0-function-set adf0-argument-map
                            adf0-terminal-set
                            adf1-function-set adf1-argument-map
                            adf1-terminal-set
                            rpb-function-set rpb-argument-map
                            rpb-terminal-set)
  "Loops until the user's termination predicate says to stop."
  (do ((current-generation 0 (+ 1 current-generation)))
      ((let ((best-of-generation (aref population 0)))
         (funcall termination-predicate
                  current-generation
                  maximum-generations
                  (individual-standardized-fitness best-of-generation)
                  (individual-hits best-of-generation))))
    (when (> current-generation 0)
      (breed-new-population
       population new-programs
       adf0-function-set adf0-argument-map adf0-terminal-set
       adf1-function-set adf1-argument-map adf1-terminal-set
       rpb-function-set rpb-argument-map rpb-terminal-set))
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

(defun evaluate-fitness-of-population (population fitness-cases
                                       fitness-function)
  "Evaluates and records the fitness and hits of each individual.

   Evaluation is sequential because the automatically defined functions
   rely on dynamically bound special variables (the ADF bodies and the
   dummy arguments), which are not thread-safe."
  (dotimes (individual-index (length population))
    (let ((individual (aref population individual-index)))
      (multiple-value-bind (standardized-fitness hits)
          (funcall fitness-function (individual-program individual)
                                   fitness-cases)
        (setf (individual-standardized-fitness individual)
              standardized-fitness)
        (setf (individual-hits individual) hits)))))

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
                             adf0-function-set adf0-argument-map
                             adf0-terminal-set
                             adf1-function-set adf1-argument-map
                             adf1-terminal-set
                             rpb-function-set rpb-argument-map
                             rpb-terminal-set)
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
                     (mutate individual-1
                             adf0-function-set adf0-argument-map
                             adf0-terminal-set
                             adf1-function-set adf1-argument-map
                             adf1-terminal-set
                             rpb-function-set rpb-argument-map
                             rpb-terminal-set))
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
  "Returns two values: a keyword in {:ADF0, :ADF1, :RPB} denoting a
   branch selected at random (biased by the number of points in that
   branch), and the subtree of the selected branch."
  (let* ((adf0 (adf-program-adf0 within-program))
         (adf1 (adf-program-adf1 within-program))
         (rpb (adf-program-rpb within-program))
         (adf0-points (count-crossover-points adf0))
         (adf1-points (count-crossover-points adf1))
         (rpb-points (count-crossover-points rpb))
         (selected-point
           (random-integer (+ adf0-points adf1-points rpb-points))))
    (cond ((< selected-point adf0-points)
           (values :adf0 adf0))
          ((< selected-point (+ adf0-points adf1-points))
           (values :adf1 adf1))
          (t
           (values :rpb rpb)))))

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

(defun mutate (program
               adf0-function-set adf0-argument-map adf0-terminal-set
               adf1-function-set adf1-argument-map adf1-terminal-set
               rpb-function-set rpb-argument-map rpb-terminal-set)
  "Mutates PROGRAM by picking a random point in a random branch and
   substituting a brand new subtree created in the same way as the
   initial random population."
  (multiple-value-bind (branch branch-tree) (select-branch program)
    (let ((mutation-point
            (random-integer (count-crossover-points branch-tree)))
          (new-subtree
            (create-individual-subtree
             (case branch
               (:adf0 adf0-function-set)
               (:adf1 adf1-function-set)
               (:rpb rpb-function-set))
             (case branch
               (:adf0 adf0-argument-map)
               (:adf1 adf1-argument-map)
               (:rpb rpb-argument-map))
             (case branch
               (:adf0 adf0-terminal-set)
               (:adf1 adf1-terminal-set)
               (:rpb rpb-terminal-set))
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
