;;; -*- Mode: Lisp; Syntax: ANSI-Common-Lisp; Base: 10; -*-
;;; ============================================================================
;;; OSCILADOR DE DUFFING — KOZA II (2 ADFs de aridad 3)
;;; El programa (RPB + ADF0 + ADF1) produce u directamente.
;;; Comparación con baselines: PID=0.4510, GP-Lineal=0.4408, GP-EML=0.4995.
;;; ============================================================================

(defpackage :cl-koza-2.examples.oscilador
  (:use #:cl #:cl-koza-2)
  (:export #:oscilador-2-adfs
           #:run
           #:run-example))

(in-package :cl-koza-2.examples.oscilador)

;; ============================================================================
;; 1. CONSTANTES (idénticas al oscilador original)
;; ============================================================================
;; --- 1. VARIABLES (Aseguramos que existan para el EVAL) ---
(defvar *current-e* 0.0d0)
(defvar *current-ed* 0.0d0)
(defvar *current-ie* 0.0d0)
(defvar *oscillator-fitness-cases* nil)




(defconstant +dt+ 0.01d0)
(defconstant +damping+ 0.2d0)
(defconstant +stiffness+ 1.5d0)
(defconstant +nonlinearity+ 0.3d0)
(defconstant +u-max+ 10.0d0)
(defconstant +u-min+ -10.0d0)
(defconstant +cost-weight+ 0.01d0)
(defconstant +x0+ 1.0d0)
(defconstant +xd0+ 0.0d0)
(defconstant +num-steps+ 1000)




(defun % (a b) (if (= b 0) 0.0d0 (/ a b)))

;; ============================================================================
;; 2. DINÁMICA DE DUFFING
;; ============================================================================
(defun compute-dynamics (x x-dot u)
  (- u
     (* +damping+ x-dot)
     (* +stiffness+ x)
     (* +nonlinearity+ (* x x x))))

;; ============================================================================
;; 3. ESPECIFICACIÓN DE RAMAS (branch-spec)
;; ============================================================================

;; --- ADF0: funciones aritméticas básicas ---
(defun define-function-set-for-adf0 ()
  (values '(+ - * %)
          '(2 2 2 2)))

;; --- ADF1: aritmética + llamada a ADF0 ---
(defun define-function-set-for-adf1 ()
  (values '(+ - * % adf0)
          '(2 2 2 2 3)))

;; --- RPB: aritmética + llamadas a ADF0 y ADF1 ---
(defun define-function-set-for-rpb ()
  (values '(+ - * % adf0 adf1)
          '(2 2 2 2 3 3)))

;; --- Terminales de las ADFs: argumentos + constantes ---
(defun define-terminal-set-for-adf ()
  (values '(arg0 arg1 arg2
            0.0d0 0.5d0 1.0d0 -0.5d0 -1.0d0)))

;; --- Terminales de la RPB: estado + constantes ---
(defun define-terminal-set-for-rpb ()
  (values '(e ed ie
            0.0d0 0.5d0 1.0d0 2.0d0 5.0d0
            -0.5d0 -1.0d0 -2.0d0 -5.0d0)))

;; ============================================================================
;; 4. FITNESS CASES (un solo caso: la simulación completa)
;; ============================================================================

(defun generate-random-fitness-cases (number)
  (setf *oscillator-fitness-cases* (make-array number :initial-element 1.0d0))
  *oscillator-fitness-cases*)


(defun define-fitness-cases-for-oscilador ()
  ;; La simulación entera es un único caso. El kernel necesita un array non-nil.
  (make-array 1 :initial-element nil))

;; ============================================================================
;; 5. FUNCIÓN DE FITNESS
;; ============================================================================

(defun evaluate-standardized-fitness-for-oscilador (program fitness-cases)
  (declare (ignore fitness-cases))
  (handler-case
      (let ((x +x0+) (xd +xd0+) (ie 0.0d0) (j 0.0d0))
        (dotimes (n +num-steps+)
          (let* ((e (- 0.0d0 x))
                 (ed (- 0.0d0 xd))
                 (u-raw (evaluate-adf-program
                         program
                         :environment (list (cons 'e e)
                                            (cons 'ed ed)
                                            (cons 'ie ie))))
                 (u-clean (cond ((not (numberp u-raw)) 0.0d0)
                                ((sb-ext:float-nan-p u-raw) 0.0d0)
                                ((sb-ext:float-infinity-p u-raw) 0.0d0)
                                (t (float u-raw 0.0d0))))
                 (u (max +u-min+ (min +u-max+ u-clean))))
            (incf j (* +dt+ (+ (* e e) (* +cost-weight+ (* u u)))))
            (let ((xdd (compute-dynamics x xd u)))
              (incf x (* xd +dt+))
              (incf xd (* xdd +dt+)))
            (incf ie (* e +dt+))))
        (values (float j 0.0d0)
                (if (< j 0.4510d0) 1 0)))
    (floating-point-overflow () (values 10000.0d0 0))
    (floating-point-invalid-operation () (values 10000.0d0 0))
    (division-by-zero () (values 10000.0d0 0))
    (error () (values 10000.0d0 0))))


;; ============================================================================
;; 6. PARÁMETROS DEL GP
;; ============================================================================
(defun define-parameters-for-oscilador ()
  (setf *number-of-fitness-cases* 1)
  (setf *max-depth-for-new-individuals* 8)
  (setf *max-depth-for-new-subtrees-in-mutants* 4)
  (setf *max-depth-for-individuals-after-crossover* 17)
  (setf *fitness-proportionate-reproduction-fraction* 0.05)
  (setf *crossover-at-any-point-fraction* 0.20)
  (setf *crossover-at-function-point-fraction* 0.50)
  (setf *method-of-selection* :tournament)
  (setf *tournament-size* 7)
  (setf *method-of-generation* :ramped-half-and-half)
  (values))

;; ============================================================================
;; 7. CRITERIO DE TERMINACIÓN
;; ============================================================================
(defun define-termination-criterion-for-oscilador
    (current-generation maximum-generations best-standardized-fitness best-hits)
  (declare (ignore best-standardized-fitness))
  (values (or (>= current-generation maximum-generations)
              (>= best-hits *number-of-fitness-cases*))))

;; ============================================================================
;; 8. PROBLEM FUNCTION (devuelve los 6 valores que espera run-adf-system)
;; ============================================================================
(defun oscilador-2-adfs ()
  (values
   ;; 1. Lista de branch-specs para las ADFs
   (list (make-branch-spec
          :function-set-creator 'define-function-set-for-adf0
          :terminal-set-creator 'define-terminal-set-for-adf)
         (make-branch-spec
          :function-set-creator 'define-function-set-for-adf1
          :terminal-set-creator 'define-terminal-set-for-adf))
   ;; 2. branch-spec para la RPB
   (make-branch-spec
    :function-set-creator 'define-function-set-for-rpb
    :terminal-set-creator 'define-terminal-set-for-rpb)
   ;; 3. Creador de fitness cases
   'define-fitness-cases-for-oscilador
   ;; 4. Función de fitness
   'evaluate-standardized-fitness-for-oscilador
   ;; 5. Definidor de parámetros
   'define-parameters-for-oscilador
   ;; 6. Criterio de terminación
   'define-termination-criterion-for-oscilador))

;; ============================================================================
;; 9. EJECUCIÓN
;; ============================================================================
(defun run (maximum-generations size-of-population seed
            &key verbose (filename nil))
  (let ((*verbose* (if verbose :verbose nil)))
    (if filename
        (with-open-file (*standard-output* filename
                                          :direction :output
                                          :if-exists :supersede
                                          :if-does-not-exist :create)
          (format t "--- INICIANDO RUN DE GP ---~%")
          (let ((results
                  (multiple-value-list
                   (run-adf-system 'oscilador-2-adfs
                                   seed
                                   maximum-generations
                                   size-of-population))))
            (format t "~%--- FIN DEL RUN ---~%")
            (apply #'values results)))
        (run-adf-system 'oscilador-2-adfs
                        seed
                        maximum-generations
                        size-of-population))))


(defun run-example (&key
                      (maximum-generations 50)
                      (size-of-population 1000)
                      (seed 1.0)
                      (verbose nil)
                      (filename nil))
  (run maximum-generations
       size-of-population
       seed
       :verbose verbose
       :filename filename))


(defun bench (&key (filename "duffin-koza-2-results.txt"))
  (format t "~%--- INICIANDO BENCHMARK ---~%")
  (time (run 100 10000 777 :filename filename))
  (format t "~%--- BENCHMARK FINALIZADO ---~%"))
