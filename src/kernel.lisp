(defpackage #:gp.kernel
  (:use #:cl
        #:gp.random
        #:gp.simplify)
  (:export *verbose*
           *rules*
           *number-of-fitness-cases*
           *max-depth-for-new-individuals*
           *max-depth-for-individuals-after-crossover*
           *fitness-proportionate-reproduction-fraction*
           *crossover-at-any-point-fraction*
           *crossover-at-function-point-fraction*
           *max-depth-for-new-subtrees-in-mutants*
           *method-of-selection*
           *method-of-generation*
           *best-of-run-individual*
           #:run-genetic-programming-system
           #:individual
           #:compile-program
   ))

(in-package #:gp.kernel)

(defstruct individual
  program
  (standardized-fitness 0)
  (adjusted-fitness 0)
  (normalized-fitness 0)
  (hits 0))

(defvar *verbose* :unbound
  "Run in verbose mode with :verbose")

(defvar *rules* :unbound
  "simplification rules")

(defvar *number-of-fitness-cases* :unbound
  "The number of fitness cases")

(defvar *max-depth-for-new-individuals* :unbound
  "The maximum depth for individuals of the initial
   random generation")

(defvar *max-depth-for-individuals-after-crossover* :unbound
  "The maximum depth of new individuals created by crossover")

(defvar *fitness-proportionate-reproduction-fraction* :unbound
  "The fraction of the population that will experience fitness
   proportionate reproduction (with reselection)
   during each generation")

(defvar *crossover-at-any-point-fraction* :unbound
  "The fraction of the population that will experience
   crossover at any point in the tree (including terminals)
   during each generation")

(defvar *crossover-at-function-point-fraction* :unbound
  "The fraction of the population that will experience
   crossover at a function (internal) point in the tree
   during each generation.")

(defvar *max-depth-for-new-subtrees-in-mutants* :unbound
  "The maximum depth of new subtrees created by mutation")

(defvar *method-of-selection* :unbound
  "The method of selecting individuals in the population.
   Either :fitness-proportionate, :tournament or
   :fitness-proportionate-with-over-selection.")

(defvar *method-of-generation* :unbound
  "Can be any one of :grow, :full, :ramped-half-and-half")

(defvar *best-of-run-individual* :unbound
  "The best individual found during this run.")

(defvar *generation-of-best-of-run-individual* :unbound
  "The generation at which the best-of-run individual was found.")

(defun run-genetic-programming-system (problem-function
                                       seed
                                       maximum-generations
                                       size-of-population
                                       &rest seeded-programs)
  ;; Check validity of some arguments
  (assert (and (integerp maximum-generations)
               (not (minusp maximum-generations)))
          (maximum-generations)
          "Maximum-generations must be a non-negative ~
           integer, not ~S" maximum-generations)
  (assert (and (integerp size-of-population)
               (plusp size-of-population))
          (size-of-population)
          "Size-Of-Population must be a positive integer, ~
           not ~S" size-of-population)
  (assert (or (and (symbolp problem-function)
                   (fboundp problem-function))
              (functionp problem-function))
          (problem-function)
          "Problem-Function must be a function.")
  (assert (numberp seed) (seed)
          "The randomizer seed must be a number")
  (setf lparallel:*kernel* (lparallel:make-kernel (1+ (cpus:get-number-of-processors))))
  ;; Set the global randomizer seed.
  (setf *seed* (coerce seed 'double-float))
  ;; Initialize best-of-run recording variables
  (setf *generation-of-best-of-run-individual* 0)
  (setf *best-of-run-individual* nil)
  ;; Get the six problem-specific functions needed to
  ;; specify this problem as returned by a call to
  ;; problem-function
  (multiple-value-bind (function-set-creator
                        terminal-set-creator
                        fitness-cases-creator
                        fitness-function
                        parameter-definer
                        termination-predicate)
      (funcall problem-function)
    ;; Get the function set and its associated
    ;; argument map
    (multiple-value-bind (function-set argument-map)
        (funcall function-set-creator)
      ;; Set up the parameters using parameter-definer
      (funcall parameter-definer)
      ;; Print out parameters report
      (describe-parameters-for-run maximum-generations
                                   size-of-population)
      ;; Set up the terminal-set using terminal-set-creator
      (let ((terminal-set (funcall terminal-set-creator)))
        ;; Create the population
        (let ((population (create-population size-of-population
                                             function-set
                                             argument-map
                                             terminal-set
                                             seeded-programs)))
          ;; Define the fitness cases using the
          ;; fitness-cases-creator function
          (let ((fitness-cases (funcall fitness-cases-creator))
                ;; New-Programs is used in the breeding of the
                ;; new population.  Create it here to reduce
                ;; consing.
                (new-programs (make-array size-of-population)))
            ;; Now run the Genetic Programming Paradigm using
            ;; the fitness-function and termination-predicate provided
            (execute-generations population new-programs
                                 fitness-cases
                                 maximum-generations
                                 fitness-function
                                 termination-predicate
                                 function-set
                                 argument-map
                                 terminal-set)
            ;; Finally print out a report
            (report-on-run)
            ;; Return the population and fitness cases
            ;; (for debugging)
            (values population fitness-cases)))))))

(defun report-on-run ()
  "Prints out the best-of-run individual."
  (let ((*print-pretty* t))
    (format t "~5%The best-of-run individual program ~
               for this run was found on ~%generation ~D and had a ~
               standardized fitness measure ~
               of ~D and ~D hit~P.  ~%It was:~%~S ~
               ~%which simplifies to:~%~S"
            *generation-of-best-of-run-individual*
            (individual-standardized-fitness *best-of-run-individual*)
            (individual-hits *best-of-run-individual*)
            (individual-hits *best-of-run-individual*)
            (individual-program *best-of-run-individual*)
            (car (edit-top-level-sexpression (copy-tree (individual-program *best-of-run-individual*)) *rules*)))))

(defun report-on-generation (generation-number population)
  "Prints out the best individual at the end of each generation"
  (let ((best-individual (aref population 0))
        (size-of-population (length population))
        (sum 0.0)
        (*print-pretty* t))
    ;; Add up all of the standardized fitnesses to get average
    (dotimes (index size-of-population)
      (incf sum (individual-standardized-fitness
                 (aref population index))))
    (format t "~2%Generation ~D:  Average standardized-fitness ~
               = ~S.  ~%~
               The best individual program of the population ~
               had a ~%standardized fitness measure of ~D ~
               and ~D hit~P. ~%It was: ~%~S"
            generation-number (/ sum (length population))
            (individual-standardized-fitness best-individual)
            (individual-hits best-individual)
            (individual-hits best-individual)
            (individual-program best-individual))))

(defun print-population (population)
  "Given a population, this prints it out (for debugging) "
  (let ((*print-pretty* t))
    (dotimes (index (length population))
      (let ((individual (aref population index)))
        (format t "~&~D   ~S    ~S"
                index
                (individual-standardized-fitness individual)
                (individual-program individual))))))

(defun describe-parameters-for-run
    (maximum-generations size-of-population)
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
  (format t
          "~%Maximum depth of individuals after crossover:~50T~D"
          *max-depth-for-individuals-after-crossover*)
  (format t
          "~%Fitness-proportionate reproduction fraction:~50T~D"
          *fitness-proportionate-reproduction-fraction*)
  (format t "~%Crossover at any point fraction:~50T~D"
          *crossover-at-any-point-fraction*)
  (format t "~%Crossover at function points fraction:~50T~D"
          *crossover-at-function-point-fraction*)
  (format t "~%Number of fitness cases:~50T~D"
          *number-of-fitness-cases*)
  (format t "~%Selection method: ~50T~A" *method-of-selection*)
  (format t "~%Generation method: ~50T~A" *method-of-generation*)
  (format t "~%Randomizer seed: ~50T~D~%" *seed*))

(defvar *generation-0-uniquifier-table*
  (make-hash-table :test #'equal)
  "Used to guarantee that all generation 0 individuals
   are unique")

(defun create-population (size-of-population
                          function-set
                          argument-map
                          terminal-set
                          seeded-programs)
  "Creates the population.  This is an array of size
   size-of-population that is initialized to contain individual
   records.  The Program slot of each individual is initialized
   to a suitable random program except for the first N programs,
   where N = (length seeded-programs).  For these first N
   individuals the individual is initialized with the respective
   seeded program.  This is very useful in debugging."
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
                 ;; Pick a seeded individual
                 (nth individual-index seeded-programs)
                 ;; Create a new random program.
                 (create-individual-program
                  function-set argument-map terminal-set
                  (ecase *method-of-generation*
                    ((:full :grow) *max-depth-for-new-individuals*)
                    (:ramped-half-and-half
                     (+ minimum-depth-of-trees
                        (mod individual-index
                             (- *max-depth-for-new-individuals*
                                minimum-depth-of-trees)))))
                  t
                  (ecase *method-of-generation*
                    (:full t)
                    (:grow nil)
                    (:ramped-half-and-half
                     full-cycle-p))))))
        ;; Check if we have already created this program.
        ;; If not then store it and move on.
        ;; If we have then try again.
        (cond ((< individual-index (length seeded-programs))
               (setf (aref population individual-index)
                     (make-individual :program new-program))
               (incf individual-index))
              ((not (gethash new-program
                             *generation-0-uniquifier-table*))
               (setf (aref population individual-index)
                     (make-individual :program new-program))
               (setf (gethash new-program
                              *generation-0-uniquifier-table*)
                     t)
               (setf attempts-at-this-individual 0)
               (incf individual-index))
              ((> attempts-at-this-individual 20)
               ;; Then this depth has probably filled up, so
               ;; bump the depth counter.
               (incf minimum-depth-of-trees)
               ;; Bump the max depth too to keep in line with new minimum.
               (setf *max-depth-for-new-individuals*
                     (max *max-depth-for-new-individuals*
                          minimum-depth-of-trees)))
              (:otherwise (incf attempts-at-this-individual)))))
    ;; Flush out uniquifier table to that no pointers
    ;; are kept to generation 0 individuals.
    (clrhash *generation-0-uniquifier-table*)
    ;; Return the population that we've just created.
    population))

(defun choose-from-terminal-set (terminal-set)
  "Chooses a random terminal from the terminal set.
   If the terminal chosen is the ephemeral
   :Floating-Point-Random-Constant,
   then a floating-point single precision random constant
   is created in the range -5.0->5.0.
   If :Integer-Random-Constant is chosen then an integer random
   constant is generated in the range -10 to +10."
  (let ((choice (nth (random-integer (length terminal-set))
                     terminal-set)))
    (case choice
      (:floating-point-random-constant
       ;; pick a random number in the range -5.0 ---> +5.0.
       ;; Coerce it to be single precision floating-point.
       ;; Double precision is more expensive
       ;; A similar clause to this could be used to coerce it
       ;; to double prevision if you really need
       ;; double precision.
       ;; This is also the place to modify if you need a range
       ;; other than -5.0 ---> +5.0.
       (coerce (- (random-floating-point-number 10.0) 5.0)
               'single-float))
      (:integer-random-constant
       ;; pick a random integer in the range -10 ---> +10.
       (- (random-integer 21) 10))
      (otherwise choice))))

(defun create-individual-program (function-set
                                  argument-map
                                  terminal-set
                                  allowable-depth
                                  top-node-p
                                  full-p)
  "Creates a program recursively using the specified functions
   and terminals.  Argument map is used to determine how many
   arguments each function in the function set is supposed to
   have if it is selected.  Allowable depth is the remaining
   depth of the tree we can create, when we hit zero we will
   only select terminals.  Top-node-p is true only when we
   are being called as the top node in the tree.  This allows
   us to make sure that we always put a function at the top
   of the tree.  Full-p indicates whether this individual
   is to be maximally bushy or not."
  (cond ((<= allowable-depth 0)
         ;; We've reached maxdepth, so just pack a terminal.
         (choose-from-terminal-set terminal-set))
        ((or full-p top-node-p)
         ;; We are the top node or are a full tree,
         ;; so pick only a function.
         (let ((choice (random-integer (length function-set))))
           (let ((function (nth choice function-set))
                 (number-of-arguments (nth choice argument-map)))
             (cons function
                   (create-arguments-for-function number-of-arguments
                                                  function-set
                                                  argument-map
                                                  terminal-set
                                                  (- allowable-depth 1)
                                                  full-p)))))
        (:otherwise
         ;; choose one from the bag of functions and terminals.
         (let ((choice (random-integer (+ (length terminal-set)
                                          (length function-set)))))
           (if (< choice (length function-set))
               ;; We chose a function, so pick it out and go
               ;; on creating the tree down from here.
               (let ((function (nth choice function-set))
                     (number-of-arguments (nth choice argument-map)))
                 (cons function
                       (create-arguments-for-function number-of-arguments
                                                      function-set
                                                      argument-map
                                                      terminal-set
                                                      (- allowable-depth 1)
                                                      full-p)))
               ;; We chose an atom, so pick it out.
               (choose-from-terminal-set terminal-set))))))

(defun create-arguments-for-function (number-of-arguments
                                      function-set
                                      argument-map
                                      terminal-set
                                      allowable-depth
                                      full-p)
  "Creates the argument list for a node in the tree.
   Number-Of-Arguments is the number of arguments still
   remaining to be created.  Each argument is created
   in the normal way using Create-Individual-Program."
  (if (= number-of-arguments 0)
      nil
      (cons (create-individual-program function-set
                                       argument-map
                                       terminal-set
                                       allowable-depth
                                       nil
                                       full-p)
            (create-arguments-for-function (- number-of-arguments 1)
                                           function-set
                                           argument-map
                                           terminal-set
                                           allowable-depth
                                           full-p))))

(defun execute-generations (population
                            new-programs
                            fitness-cases
                            maximum-generations
                            fitness-function
                            termination-predicate
                            function-set
                            argument-map
                            terminal-set)
  "Loops until the user's termination predicate says to stop."
  (do ((current-generation 0 (+ 1 current-generation)))
      ;; loop incrementing current generation until
      ;; termination-predicate succeeds.
      ((let ((best-of-generation (aref population 0)))
         (funcall termination-predicate current-generation
                                        maximum-generations
                                        (individual-standardized-fitness best-of-generation)
                                        (individual-hits best-of-generation))))
    (when (> current-generation 0)
      ;; Breed the new population to use on this generation
      ;; (except gen 0, of course).
      (breed-new-population population
                            new-programs
                            function-set
                            argument-map
                            terminal-set))
    ;; Clean out the fitness measures.
    (zeroize-fitness-measures-of-population population)
    ;; Measure the fitness of each individual.  Fitness values
    ;; are stored in the individuals themselves.
    (evaluate-fitness-of-population population
                                    fitness-cases
                                    fitness-function)
    ;; Normalize fitness in preparation for crossover, etc.
    (normalize-fitness-of-population population)
    ;; Sort the population so that the roulette wheel is easy.
    (sort-population-by-fitness population)
    ;; Keep track of best-of-run individual
    (let ((best-of-generation (aref population 0)))
      (when (or (not *best-of-run-individual*)
                (> (individual-standardized-fitness *best-of-run-individual*)
                   (individual-standardized-fitness best-of-generation)))
        (setf *best-of-run-individual* (copy-individual best-of-generation))
        (setf *generation-of-best-of-run-individual* current-generation)))
    ;; Print out the results for this generation.
    (when (eq *verbose* :verbose)
      (report-on-generation current-generation population))))

(defun zeroize-fitness-measures-of-population (population)
  "Clean out the statistics in each individual in the
   population.  This is not strictly necessary, but it helps to
   avoid confusion that might be caused if, for some reason, we
   land in the debugger and there are fitness values associated
   with the individual records that actually matched the program
   that used to occupy this individual record."
  (dotimes (individual-index (length population))
    (let ((individual (aref population individual-index)))
      (setf (individual-standardized-fitness individual) 0.0)
      (setf (individual-adjusted-fitness individual) 0.0)
      (setf (individual-normalized-fitness individual) 0.0)
      (setf (individual-hits individual) 0))))

(defun evaluate-fitness-of-population (population
                                       fitness-cases
                                       fitness-function)
  "Loops over the individuals in the population evaluating and
   recording the fitness and hits."
  (lparallel:pdotimes (individual-index (length population))
    (let ((individual (aref population individual-index)))
      (multiple-value-bind (standardized-fitness hits)
          (funcall fitness-function (individual-program individual)
                                    fitness-cases)
        ;; Record fitness and hits for this individual.
        (setf (individual-standardized-fitness individual) standardized-fitness)
        (setf (individual-hits individual) hits)))))

(defun normalize-fitness-of-population (population)
  "Computes the normalized and adjusted fitness of each
   individual in the population."
  (let ((sum-of-adjusted-fitnesses 0.0))
    (dotimes (individual-index (length population))
      (let ((individual (aref population individual-index)))
        ;; Set the adjusted fitness.
        (setf (individual-adjusted-fitness individual)
              (/ 1.0 (+ 1.0 (individual-standardized-fitness individual))))
        ;; Add up the adjusted fitnesses so that we can
        ;; normalize them.
        (incf sum-of-adjusted-fitnesses
              (individual-adjusted-fitness individual))))
    ;; Loop through population normalizing the adjusted fitness.
    (dotimes (individual-index (length population))
      (let ((individual (aref population individual-index)))
        (setf (individual-normalized-fitness individual)
              (/ (individual-adjusted-fitness individual)
                 sum-of-adjusted-fitnesses))))))

(defun sort-population-by-fitness (population &optional (low 0) (high (length population)))
  "Uses a trivial quicksort to sort the population destructively
   into descending order of normalized fitness."
  (unless (>= (+ low 1) high)
    (let ((pivot (individual-normalized-fitness (aref population low)))
          (index1 (+ low 1))
          (index2 (- high 1)))
      (loop (do () ((or (>= index1 high)
                        (<= (individual-normalized-fitness (aref population index1)) pivot)))
              (incf index1))
         (do () ((or (>= low index2)
                     (>= (individual-normalized-fitness (aref population index2)) pivot)))
           (decf index2))
         (when (>= index1 index2) (return nil))
         (rotatef (aref population index1) (aref population index2))
         (decf index2))
      (rotatef (aref population low) (aref population (- index1 1)))
      (sort-population-by-fitness population
                                  low
                                  index1)
      (sort-population-by-fitness population
                                  index1
                                  high)))
  population)

(defun breed-new-population (population
                             new-programs
                             function-set
                             argument-map
                             terminal-set)
  "Controls the actual breeding of the new population.
   Loops through the population executing each operation
   (e.g., crossover, fitness-proportionate reproduction,
   mutation) until it has reached the specified fraction.
   The new programs that are created are stashed in new-programs
   until we have exhausted the population, then we copy the new
   individuals into the old ones, thus avoiding consing a new
   bunch of individuals."
  (let ((population-size (length population)))
    (do ((index 0)
         (fraction 0 (/ index population-size)))
        ((>= index population-size))
      (let ((individual-1
             (find-individual population)))
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
              (:otherwise
	           (setf (aref new-programs index) (mutate individual-1
                                                       function-set
			                                           argument-map
                                                       terminal-set))
	           (incf index 1)))))
    (dotimes (index population-size)
      (setf (individual-program (aref population index))
            (aref new-programs index)))))

(defun find-individual (population)
  "Finds an individual in the population according to the
   defined selection method."
  (ecase *method-of-selection*
    (:tournament (find-individual-using-tournament-selection population))
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
      (error "A population size of ~D is too small ~
              for over-selection." pop-size))
    (let ((boundary (/ 320.0 pop-size)))
      ;; The boundary between the over and under selected parts.
      (if (< (random-floating-point-number 1.0) 0.8)
          ;; 80% are in the over-selected part
          (random-floating-point-number boundary)
          (+ boundary
	         (random-floating-point-number (- 1.0 boundary)))))))

(defparameter *tournament-size* 7)

(defun pick-k-random-individual-indices (k max)
  (let ((numbers nil))
    (loop for number = (random-integer max)
	   unless (member number numbers :test #'eql)
	   do (push number numbers)
	   until (= (length numbers) k))
    numbers))

(defun find-individual-using-tournament-selection (population)
  "Picks *tournament-size* individuals from the population at random and
   returns the best one."
  (let ((numbers (pick-k-random-individual-indices *tournament-size*
                                                   (length population))))
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
  "Finds an individual in the specified population whose
   normalized fitness is greater than the specified value.
   All we need to do is count along the population from the
   beginning adding up the fitness until we get past the
   specified point."
  (let ((sum-of-fitness 0.0)
        (population-size (length population)))
    (let ((index-of-selected-individual
           (do ((index 0 (+ index 1)))
               ;; Exit condition
               ((or (>= index population-size)
                    (>= sum-of-fitness after-this-fitness))
                (if (>= index population-size)
                    (- (length population) 1)
                    (- index 1)))
             ;; Body.  Sum up the fitness values.
             (incf sum-of-fitness
                   (individual-normalized-fitness (aref population index))))))
      (individual-program (aref population index-of-selected-individual)))))

(defun crossover-at-any-points (male female)
  "Performs crossover on the programs at any point
   in the trees."
  ;; Pick points in the respective trees
  ;; on which to perform the crossover.
  (let ((male-point (random-integer (count-crossover-points male)))
        (female-point (random-integer (count-crossover-points female))))
    ;; First, copy the trees because we destructively modify the
    ;; new individuals to do the crossover.  Reselection is
    ;; allowed in the original population.  Not copying would
    ;; cause the individuals in the old population to
    ;; be modified.
    (let ((new-male   (list (copy-tree male)))
          (new-female (list (copy-tree female))))
      ;; Get the pointers to the subtrees indexed by male-point
      ;; and female-point
      (multiple-value-bind (male-subtree-pointer male-fragment)
          (get-subtree (first new-male) new-male male-point)
        (multiple-value-bind (female-subtree-pointer female-fragment)
            (get-subtree (first new-female) new-female female-point)
          ;; Modify the new individuals by smashing in the
          ;; (copied) subtree from the old individual.
          (setf (first male-subtree-pointer) female-fragment)
          (setf (first female-subtree-pointer) male-fragment)))
      ;; Make sure that the new individuals aren't too big.
      (validate-crossover male
                          new-male
                          female
                          new-female))))

(defun count-crossover-points (program)
  "Counts the number of points in the tree (program).
   This includes functions as well as terminals."
  (if (consp program)
      (+ 1 (reduce #'+ (mapcar #'count-crossover-points
                               (rest program))))
      1))

(defun max-depth-of-tree (tree)
  "Returns the depth of the deepest branch of the
   tree (program)."
  (if (consp tree)
      (+ 1 (if (rest tree)
               (apply #'max
                      (mapcar #'max-depth-of-tree (rest tree)))
               0))
      1))

(defun get-subtree (tree pointer-to-tree index)
  "Given a tree or subtree, a pointer to that tree/subtree and
   an index return the component subtree that is numbered by
   Index.  We number left to right, depth first."
  (if (= index 0)
      (values pointer-to-tree (copy-tree tree) index)
      (if (consp tree)
          (do* ((tail (rest tree) (rest tail))
                (argument (first tail) (first tail)))
               ((not tail) (values nil nil index))
            (multiple-value-bind (new-pointer new-tree new-index)
                (get-subtree argument tail (- index 1))
              (if (= new-index 0)
                  (return (values new-pointer new-tree new-index))
                  (setf index new-index))))
          (values nil nil index))))

(defun validate-crossover (male new-male female new-female)
  "Given the old and new males and females from a crossover
   operation check to see whether we have exceeded the maximum
   allowed depth.  If either of the new individuals has exceeded
   the maxdepth then the old individual is used."
  (let ((male-depth   (max-depth-of-tree (first new-male)))
        (female-depth (max-depth-of-tree (first new-female))))
    (values
     (if (or (= 1 male-depth)
             (> male-depth
                *max-depth-for-individuals-after-crossover*))
         male
         (first new-male))
     (if (or (= 1 female-depth)
             (> female-depth
                *max-depth-for-individuals-after-crossover*))
         female
         (first new-female)))))

(defun crossover-at-function-points (male female)
  "Performs crossover on the two programs at a function
   (internal) point in the trees."
  ;; Pick the function (internal) points in the respective trees
  ;; on which to perform the crossover.
  (let ((male-point (random-integer (count-function-points male)))
        (female-point (random-integer (count-function-points female))))
    ;; Copy the trees because we destructively modify the new
    ;; individuals to do the crossover and Reselection is
    ;; allowed in the original population. Not copying would
    ;; cause the individuals in the old population to
    ;; be modified.
    (let ((new-male (list (copy-tree male)))
          (new-female (list (copy-tree female))))
      ;; Get the pointers to the subtrees indexed by male-point
      ;; and female-point
      (multiple-value-bind (male-subtree-pointer male-fragment)
          (get-function-subtree (first new-male)
                                new-male
                                male-point)
        (multiple-value-bind (female-subtree-pointer female-fragment)
            (get-function-subtree (first new-female)
                                  new-female
                                  female-point)
          ;; Modify the new individuals by smashing in
          ;; the (copied) subtree from the old individual.
          (setf (first male-subtree-pointer) female-fragment)
          (setf (first female-subtree-pointer) male-fragment)))
      ;; Make sure that the new individuals aren't too big.
      (validate-crossover male
                          new-male
                          female
                          new-female))))

(defun count-function-points (program)
  "Counts the number of function (internal) points
   in the program."
  (if (consp program)
      (+ 1 (reduce #'+ (mapcar #'count-function-points
                               (rest program))))
      0))

(defun get-function-subtree (tree pointer-to-tree index)
  "Given a tree or subtree, a pointer to that tree/subtree and
   an index return the component subtree that is labeled with
   an internal point that is numbered by Index.  We number left
   to right, depth first."
  (if (= index 0)
      (values pointer-to-tree (copy-tree tree) index)
      (if (consp tree)
          (do* ((tail (rest tree) (rest tail))
                (argument (first tail) (first tail)))
               ((not tail) (values nil nil index))
            (multiple-value-bind (new-pointer new-tree new-index)
                (if (consp argument)
                    (get-function-subtree
                     argument tail (- index 1))
                    (values nil nil index))
                (if (= new-index 0)
                    (return (values new-pointer new-tree new-index))
                    (setf index new-index))))
          (values nil nil index))))

(defun mutate (program function-set argument-map terminal-set)
  "Mutates the argument program by picking a random point in
   the tree and substituting in a brand new subtree created in
   the same way that we create the initial random population."
  ;; Pick the mutation point.
  (let ((mutation-point (random-integer (count-crossover-points program)))
        ;; Create a brand new subtree.
        (new-subtree (create-individual-program function-set
                                                argument-map
                                                terminal-set
                                                *max-depth-for-new-subtrees-in-mutants*
                                                t
                                                nil)))
    (let ((new-program (list (copy-tree program))))
      (multiple-value-bind (subtree-pointer fragment)
          ;; Get the pointer to the mutation point.
          (get-subtree (first new-program)
                       new-program
                       mutation-point)
        ;; Not interested in what we're snipping out.
        (declare (ignore fragment))
        ;; Smash in the new subtree.
        (setf (first subtree-pointer) new-subtree))
      (values (first new-program) new-subtree))))

(defun compile-program (args program)
  (compile nil `(lambda (,@args)
                  (declare (ignorable ,@args))
                  ,program)))
