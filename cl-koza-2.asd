(defsystem "cl-koza-2"
  :description "Koza II genetic programming kernel with automatically defined functions (ADFs)"
  :version "0.1.0"
  :author "Gastón Novita"
  :license "MIT License (see COPYING)"
  :depends-on ("cl-cpus" "lparallel")
  :serial t
  :components ((:module "src"
                :serial t
                :components ((:file "package")
                             (:file "random")
                             (:file "functions")
                             (:file "program")
                             (:file "interpreter")
                             (:file "kernel"))))
  :in-order-to ((test-op (test-op "cl-koza-2/tests"))))

(defsystem "cl-koza-2/examples/even-5-parity"
  :description "Koza II example: even-5-parity with two automatically defined functions"
  :version "0.1.0"
  :author "Gastón Novita"
  :license "MIT License (see COPYING)"
  :depends-on ("cl-koza-2")
  :serial t
  :components ((:module "examples"
                :serial t
                :components ((:file "even-5-parity"))))
  :in-order-to ((test-op (test-op "cl-koza-2/tests"))))

(defsystem "cl-koza-2/examples/even-5-parity-3-adfs"
  :description "Koza II example: even-5-parity with three automatically defined functions"
  :version "0.1.0"
  :author "Gastón Novita"
  :license "MIT License (see COPYING)"
  :depends-on ("cl-koza-2")
  :serial t
  :components ((:module "examples"
                :serial t
                :components ((:file "even-5-parity-3-adfs"))))
  :in-order-to ((test-op (test-op "cl-koza-2/tests"))))

(defsystem "cl-koza-2/examples/even-5-parity-n-adfs"
  :description "Koza II example: even-5-parity with a configurable number of ADFs"
  :version "0.1.0"
  :author "Gastón Novita"
  :license "MIT License (see COPYING)"
  :depends-on ("cl-koza-2")
  :serial t
  :components ((:module "examples"
                :serial t
                :components ((:file "even-5-parity-n-adfs"))))
  :in-order-to ((test-op (test-op "cl-koza-2/tests"))))

(defsystem "cl-koza-2/examples/duffin-koza-2"
  :description "Koza II example: Duffing oscillator control"
  :version "0.1.0"
  :author "Gastón Novita"
  :license "MIT License (see COPYING)"
  :depends-on ("cl-koza-2")
  :serial t
  :components ((:module "examples"
                :serial t
                :components ((:file "duffin-koza-2"))))
  :in-order-to ((test-op (test-op "cl-koza-2/tests"))))

(defsystem "cl-koza-2/tests"
  :description "Test suite for cl-koza-2"
  :version "0.1.0"
  :author "Gastón Novita"
  :license "MIT License (see COPYING)"
  :depends-on ("cl-koza-2"
               "cl-koza-2/examples/even-5-parity"
               "cl-koza-2/examples/even-5-parity-3-adfs"
               "cl-koza-2/examples/even-5-parity-n-adfs"
               "fiveam")
  :serial t
  :components ((:module "tests"
                :serial t
                :components ((:file "package")
                             (:file "suite")
                             (:file "helpers")
                             (:file "random-test")
                             (:file "functions-test")
                             (:file "program-test")
                             (:file "interpreter-test")
                             (:file "n-adf-test")
                             (:file "kernel-creation-test")
                             (:file "kernel-run-test")
                             (:file "kernel-report-test")
                             (:file "parallel-test")
                             (:file "even-5-parity-test")
                             (:file "even-5-parity-3-adfs-test")
                             (:file "even-5-parity-n-adfs-test")
                             (:file "known-issues-test"))))
  :perform (test-op (op c)
             (unless (uiop:symbol-call :cl-koza-2.tests :run-tests)
               (error "cl-koza-2 test suite failed"))))
