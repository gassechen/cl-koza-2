(defpackage #:cl-koza-ii.random
  (:use #:cl)
  (:export
   #:*seed*
   #:park-miller-randomizer
   #:random-integer
   #:random-floating-point-number))

(defpackage #:cl-koza-ii.functions
  (:use #:cl)
  (:export
   #:%))

(defpackage #:cl-koza-ii.program
  (:use #:cl)
  (:export
   #:adf-program
   #:make-adf-program
   #:copy-adf-program
   #:adf-program-p
   #:adf-program-adf0
   #:adf-program-adf1
   #:adf-program-adfs
   #:adf-program-adf
   #:adf-program-branch-count
   #:adf-program-rpb
   #:branch-index
   #:branch-names
   #:program-branch
   #:replace-program-branch
   #:map-program-branches
   #:copy-individual-substituting-branch
   #:count-crossover-points
   #:count-function-points
   #:max-depth-of-tree
   #:get-subtree
   #:get-function-subtree))

(defpackage #:cl-koza-ii.interpreter
  (:use #:cl
        #:cl-koza-ii.program)
  (:export
   #:evaluate-adf-tree
   #:evaluate-adf-branch
   #:evaluate-adf-program))

(defpackage #:cl-koza-ii.kernel
  (:use #:cl
        #:cl-koza-ii.random
        #:cl-koza-ii.program)
  (:export
   #:*verbose*
   #:*number-of-fitness-cases*
   #:*max-depth-for-new-individuals*
   #:*max-depth-for-individuals-after-crossover*
   #:*fitness-proportionate-reproduction-fraction*
   #:*crossover-at-any-point-fraction*
   #:*crossover-at-function-point-fraction*
   #:*max-depth-for-new-subtrees-in-mutants*
   #:*method-of-selection*
   #:*method-of-generation*
   #:*tournament-size*
   #:*best-of-run-individual*
   #:*generation-of-best-of-run-individual*
   #:run-genetic-programming-system
   #:run-adf-system
   #:branch-spec
   #:make-branch-spec
   #:branch-spec-function-set-creator
   #:branch-spec-terminal-set-creator
   #:individual
   #:make-individual
   #:copy-individual
   #:individual-program
   #:individual-standardized-fitness
   #:individual-adjusted-fitness
   #:individual-normalized-fitness
   #:individual-hits
   #:create-population
   #:report-on-run
   #:report-on-generation
   #:print-population
   #:describe-parameters-for-run))

(defpackage #:cl-koza-ii
  (:use #:cl
        #:cl-koza-ii.kernel
        #:cl-koza-ii.program
        #:cl-koza-ii.interpreter)
  (:export
   #:*verbose*
   #:*number-of-fitness-cases*
   #:*max-depth-for-new-individuals*
   #:*max-depth-for-individuals-after-crossover*
   #:*fitness-proportionate-reproduction-fraction*
   #:*crossover-at-any-point-fraction*
   #:*crossover-at-function-point-fraction*
   #:*max-depth-for-new-subtrees-in-mutants*
   #:*method-of-selection*
   #:*method-of-generation*
   #:*tournament-size*
   #:*best-of-run-individual*
   #:*generation-of-best-of-run-individual*
   #:run-genetic-programming-system
   #:run-adf-system
   #:branch-spec
   #:make-branch-spec
   #:branch-spec-function-set-creator
   #:branch-spec-terminal-set-creator
   #:individual
   #:make-individual
   #:individual-program
   #:individual-standardized-fitness
   #:individual-adjusted-fitness
   #:individual-normalized-fitness
   #:individual-hits
   #:adf-program
   #:make-adf-program
   #:adf-program-adf0
   #:adf-program-adf1
   #:adf-program-adfs
   #:adf-program-adf
   #:adf-program-branch-count
   #:adf-program-rpb
   #:evaluate-adf-tree
   #:evaluate-adf-branch
   #:evaluate-adf-program
   #:create-population
   #:report-on-run
   #:report-on-generation
   #:print-population
   #:describe-parameters-for-run))
