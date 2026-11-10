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
                                           (:file "kernel"))))))
  :in-order-to ((test-op (test-op "cl-koza-ii/tests"))))

(defsystem "cl-koza-ii/examples/even-5-parity"
  :description "Koza II example: even-5-parity with two automatically defined functions"
  :version "0.1.0"
  :author "Guillaume MICHEL"
  :license "MIT License (see COPYING)"
  :depends-on ("cl-koza-ii")
  :serial t
  :components ((:module "examples"
                :serial t
                :components ((:file "even-5-parity"))))
  :in-order-to ((test-op (test-op "cl-koza-ii/tests"))))

(defsystem "cl-koza-ii/tests"
  :description "Test suite for cl-koza-ii"
  :version "0.1.0"
  :author "Guillaume MICHEL"
  :license "MIT License (see COPYING)"
  :depends-on ("cl-koza-ii" "cl-koza-ii/examples/even-5-parity" "fiveam")
  :serial t
  :components ((:module "tests"
                :serial t
                :components ((:file "package")
                             (:file "suite")
                             (:file "helpers")
                             (:file "random-test")
                             (:file "functions-test")
                             (:file "program-test")
                             (:file "kernel-creation-test")
                             (:file "kernel-run-test")
                             (:file "kernel-report-test")
                             (:file "even-5-parity-test")
                             (:file "known-issues-test"))))
  :perform (test-op (op c)
             (unless (uiop:symbol-call :cl-koza-ii.tests :run-tests)
               (error "cl-koza-ii test suite failed"))))
