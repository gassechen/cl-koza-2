(defsystem "cl-koza-ii"
  :description "Koza II genetic programming kernel with automatically defined functions (ADFs)"
  :version "0.1.0"
  :author "Guillaume MICHEL"
  :license "MIT License (see COPYING)"
  :serial t
  :components ((:module "src"
                :serial t
                :components ((:module "koza-ii"
                              :serial t
                              :components ((:file "package")
                                           (:file "random")
                                           (:file "functions")
                                           (:file "program")
                                           (:file "kernel")))))))

(defsystem "cl-koza-ii/examples/even-5-parity"
  :description "Koza II example: even-5-parity with two automatically defined functions"
  :version "0.1.0"
  :author "Guillaume MICHEL"
  :license "MIT License (see COPYING)"
  :depends-on ("cl-koza-ii")
  :serial t
  :components ((:module "examples"
                :serial t
                :components ((:file "even-5-parity")))))
