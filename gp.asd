(defsystem "gp"
  :description "Genetic Programming"
  :version "0.0.1"
  :author "Guillaume MICHEL"
  :mailto "contact@orilla.fr"
  :homepage "http://orilla.fr"
  :license  "MIT License (see COPYING)"
  :depends-on ("alexandria"
               "cl-cpus"
               "lparallel")
  :components ((:static-file "COPYING")
               (:static-file "README.md")
               (:module "src"
                        :serial t
                        :components ((:file "package")
                                     (:file "random")
                                     ;;(:file "fast_eval")
                                     (:file "functions")
                                     (:file "simplify")
                                     (:file "kernel")
                                     (:file "simplify_rules")))))

(defsystem "gp/examples/majority_on"
  :description "Genetic Programming example: 3-Majority ON"
  :version "0.0.1"
  :author "Guillaume MICHEL"
  :mailto "contact@orilla.fr"
  :homepage "http://orilla.fr"
  :license  "MIT License (see COPYING)"
  :depends-on ("gp")
  :components ((:static-file "COPYING")
               (:static-file "README.md")
               (:module "examples"
                        :serial t
                        :components ((:file "majority_on")))))

(defsystem "gp/examples/regression"
  :description "Genetic Programming example: Regression"
  :version "0.0.1"
  :author "Guillaume MICHEL"
  :mailto "contact@orilla.fr"
  :homepage "http://orilla.fr"
  :license  "MIT License (see COPYING)"
  :depends-on ("gp")
  :components ((:static-file "COPYING")
               (:static-file "README.md")
               (:module "examples"
                        :serial t
                        :components ((:file "regression")))))
