(in-package #:cl-koza-ii.tests)

(in-suite cl-koza-ii-tests)

(test protected-division-normal
  (is (= 3 (% 6 2)))
  (is (= 1/2 (% 1 2)))
  (is (= -2 (% -6 3)))
  (is (= -1/2 (% 1 -2))))

(test protected-division-by-zero
  (is (= 1 (% 5 0)))
  (is (= 1 (% 0 0)))
  (is (= 1 (% -3 0))))
