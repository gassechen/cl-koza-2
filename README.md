# cl-koza-2

Common Lisp implementations of John Koza's genetic programming systems.

This repository contains two independent systems:

- **`cl-koza-ii`** — the Koza II kernel with automatically defined functions
  (ADFs), based on *Genetic Programming II*.
- **`gp`** — the legacy Koza I implementation based on Koza's Little Lisp.
  It is kept for reference and is not required by `cl-koza-ii`.

The `cl-koza-ii` system is self-contained and does not depend on `gp`.

## cl-koza-ii

### Status

Phase 3 is complete:

- ADF kernel with an arbitrary architecture of
  **ADF0 … ADF(N-1) + RPB** (result-producing branch), where `N >= 0`.
  With `N = 0`, a program consists only of the result-producing branch.
- The legacy two-ADF program API and `run-genetic-programming-system`
  remain supported as compatibility layers.
- Generic tree interpreter with explicit terminal environments and no
  dependency on dynamically bound ADF variables.
- Examples: **even-5-parity** with two ADFs and **even-5-parity-3-adfs**
  with three hierarchical ADFs.
- FiveAM test suite integrated with ASDF.

### Requirements

- A Common Lisp implementation (tested with SBCL).
- ASDF.
- Quicklisp for `fiveam` when running the test suite.

### Installation

Place the repository in a directory known to ASDF, for example:

```text
~/quicklisp/local-projects/cl-koza-2
```

Then load the system:

```lisp
(asdf:load-system "cl-koza-ii")
```

### Quick start

Load the example system and verify the known correct program from
*Genetic Programming II*:

```lisp
(asdf:load-system "cl-koza-ii/examples/even-5-parity")

(cl-koza-ii.examples.even-5-parity:verify-known-program)
```

This prints the standardized fitness and number of hits, and returns two
values: `T` when the known program has fitness 0, and `T` when it solves all
32 fitness cases.

Run a small smoke test:

```lisp
(cl-koza-ii.examples.even-5-parity:run-example
 :maximum-generations 1
 :size-of-population 8
 :seed 1.0)
```

`run-example` defaults to the book-sized run of 51 generations and a
population of 4000 individuals:

```lisp
(cl-koza-ii.examples.even-5-parity:run-example)
```

The same run can be started directly with `run`:

```lisp
(cl-koza-ii.examples.even-5-parity:run 51 4000 1.0 :verbose t)
```

The three-ADF version uses the generalized `run-adf-system` entry point:

```lisp
(asdf:load-system "cl-koza-ii/examples/even-5-parity-3-adfs")

(cl-koza-ii.examples.even-5-parity-3-adfs:verify-known-program)

(cl-koza-ii.examples.even-5-parity-3-adfs:run-example
 :maximum-generations 1
 :size-of-population 8
 :seed 1.0)
```

### Architecture

An overall program is an `adf-program` with `N` automatically defined
function branches followed by the result-producing branch:

| Branch | Purpose |
| --- | --- |
| `ADF0 … ADF(N-1)` | Automatically defined functions |
| `RPB` | Result-producing branch, the program's output |

`N` may be zero, in which case the program contains only `RPB`. The kernel
does not restrict which ADF a branch calls; that is determined by the
problem's function sets. In the original even-5-parity example, there are two
ADFs. ADF0 and ADF1 each take three arguments (`ARG0`, `ARG1`, `ARG2`), ADF1
may call ADF0, and the result-producing branch may call both ADFs. ADF0 does
not call another ADF. The three-ADF example adds ADF2, which may call ADF0
and ADF1, and lets the result-producing branch call all three ADFs.

The main program operations are exported from `cl-koza-ii.program`:

- `make-adf-program`, `adf-program-adfs`, `adf-program-adf`,
  `adf-program-branch-count`, `adf-program-rpb`
- Legacy accessors: `adf-program-adf0`, `adf-program-adf1`
- `branch-index`, `branch-names`, `program-branch`,
  `replace-program-branch`, `map-program-branches`
- `copy-individual-substituting-branch`
- `count-crossover-points`, `count-function-points`, `max-depth-of-tree`
- `get-subtree`, `get-function-subtree`

`make-adf-program` accepts `:adfs` (a list of branch bodies) together with
`:rpb`. The legacy keywords `:adf0` and `:adf1` remain supported when
`:adfs` is omitted; calling it with no arguments still creates a program with
two `NIL` ADFs.

The generic tree interpreter is exported from `cl-koza-ii.interpreter` and
re-exported from `cl-koza-ii`:

- `evaluate-adf-program` evaluates the result-producing branch.
- `evaluate-adf-branch` evaluates a selected branch.
- `evaluate-adf-tree` evaluates an arbitrary tree in the context of a
  program.

Each evaluator accepts an `:environment` alist of terminal or argument
bindings. ADF calls are resolved against the program's branch vector, so the
interpreter does not use dynamically bound ADF variables. It supports
`AND`, `OR`, `IF`, and `PROGN` as special forms and calls other symbols as
Common Lisp functions.

The generalized kernel entry point is exported from `cl-koza-ii`:

```lisp
(run-adf-system problem-function
                seed
                maximum-generations
                size-of-population
                &rest seeded-programs)
```

The legacy entry point remains available:

```lisp
(run-genetic-programming-system problem-function
                                seed
                                maximum-generations
                                size-of-population
                                &rest seeded-programs)
```

#### Problem-function contract

`run-adf-system` expects `problem-function` to return six values:

1. A list of branch specs for `ADF0 … ADF(N-1)`
2. A branch spec for the result-producing branch
3. Fitness-cases creator
4. Fitness function
5. Parameter definer
6. Termination predicate

A branch spec is created with:

```lisp
(make-branch-spec :function-set-creator #'creator
                  :terminal-set-creator #'creator)
```

The length of the first value determines the number of ADFs. `NIL` creates a
program with no ADFs. The fitness function receives an `adf-program` and the
fitness cases, and returns two values: the standardized fitness and the
number of hits.

`run-genetic-programming-system` is the compatibility wrapper for the
legacy two-ADF contract. Its `problem-function` returns ten values:

1. ADF0 function-set creator
2. ADF1 function-set creator
3. Result-producing branch function-set creator
4. ADF0 terminal-set creator
5. ADF1 terminal-set creator
6. Result-producing branch terminal-set creator
7. Fitness-cases creator
8. Fitness function
9. Parameter definer
10. Termination predicate

A function-set creator returns two values: the function set and its argument
map (the number of arguments expected by each function). A terminal-set
creator returns the terminal set.

The parameter definer sets the kernel's dynamic variables, including:

- `*number-of-fitness-cases*`
- `*max-depth-for-new-individuals*`
- `*max-depth-for-new-subtrees-in-mutants*`
- `*max-depth-for-individuals-after-crossover*`
- `*fitness-proportionate-reproduction-fraction*`
- `*crossover-at-any-point-fraction*`
- `*crossover-at-function-point-fraction*`
- `*method-of-selection*`, `*tournament-size*`
- `*method-of-generation*`
- `*verbose*`

Fitness evaluation in the legacy two-ADF example is sequential because its
evaluator relies on dynamically bound special variables and is not
thread-safe. The generic interpreter uses explicit environments and does not
depend on those dynamic variables.

### Example: even-5-parity

The `even-5-parity` example defines the Boolean function sets, terminal sets,
fitness cases, fitness function, parameters, and termination criterion used
by the book. Its known correct program is:

```lisp
(make-adf-program
 :adf0 '(or (and arg0 arg1)
            (and (nand arg0 arg0) (nand arg1 arg1)))
 :adf1 '(nand (or (and arg0 arg1)
                  (and (nand arg0 arg0) (nand arg1 arg1)))
              (or (and arg0 arg1)
                  (and (nand arg0 arg0) (nand arg1 arg1))))
 :rpb '(adf1 (adf0 (adf0 d0 d1 d0) (adf0 d2 d3 d0) d0)
             d4 d0))
```

`verify-known-program` evaluates it and reports:

```text
Known program: standardized-fitness=0 hits=32
```

### Example: even-5-parity with three ADFs

The `even-5-parity-3-adfs` example keeps the same fitness cases and Boolean
function sets, but uses a hierarchical three-ADF architecture: ADF2 may call
ADF0 and ADF1, and the result-producing branch may call all three ADFs. Its
known correct program reuses the two-ADF solution and wraps the original
ADF1 call through ADF2:

```lisp
(make-adf-program
 :adfs (list
        '(or (and arg0 arg1)
             (and (nand arg0 arg0) (nand arg1 arg1)))
        '(nand (or (and arg0 arg1)
                   (and (nand arg0 arg0) (nand arg1 arg1)))
               (or (and arg0 arg1)
                   (and (nand arg0 arg0) (nand arg1 arg1))))
        '(adf1 arg0 arg1 arg2))
 :rpb '(adf2 (adf0 (adf0 d0 d1 d0) (adf0 d2 d3 d0) d0)
             d4 d0))
```

`verify-known-program` reports:

```text
Known program: standardized-fitness=0.0 hits=32
```

The example uses the generic `run-adf-system` entry point and the
`evaluate-adf-program` interpreter.

### Tests

The test suite uses FiveAM and is registered as `cl-koza-ii/tests`:

```lisp
(asdf:test-system "cl-koza-ii")
```

At the time of writing the suite reports:

```text
Pass: 2936 (99%)
Skip: 2 ( 0%)
Fail: 0 ( 0%)
```

The two skipped tests document known issues:

- `run-genetic-programming-system` accepts `maximum-generations` equal to
  zero, but `report-on-run` later signals an error because
  `*best-of-run-individual*` remains `NIL`.
- `(random-integer 0)` returns `0` instead of signaling an error, even
  though the documented range `0..N-1` is empty for `N = 0`.

### Roadmap

- **Phase 1 (done):** kernel with ADF0, ADF1 and RPB; even-5-parity example;
  FiveAM test suite.
- **Phase 2 (done):** generalized program representation, problem contract,
  and kernel to an arbitrary number of ADFs (`ADF0 … ADF(N-1) + RPB`,
  including `N = 0`), while keeping the two-ADF API as a compatibility
  layer. Kernel tests cover zero, one, two, three, and four ADFs.
- **Phase 3 (done):** generic tree interpreter with explicit environments and
  an even-5-parity example with three hierarchical ADFs.
- **Future work:** more N-ADF examples, architecture-selection experiments,
  and optional parallel fitness evaluation.

### Project layout

```text
cl-koza-ii.asd          ASDF systems
src/koza-ii/            Koza II kernel
examples/               Koza II examples
tests/                  FiveAM test suite
src/                    Legacy Koza I implementation (`gp`)
doc/                    Koza II reference material
```

### References

- John R. Koza, *Genetic Programming II: Automatic Discovery of Reusable
  Programs*.
- The reference PDF is available at
  `doc/koza_jr_ed_genetic_programming_ii_automatic_discovery_of_reu.pdf`.
- Multiple function-defining branches: section 6.7.
- Retrospective even-5-parity architecture experiments, including three-ADF
  architectures: section 7.4.
- Koza's Little Lisp: <http://www.genetic-programming.org/gplittlelisp.html>

## Legacy Koza I (`gp`)

The original project documentation is preserved below. It describes the
legacy `gp` system in `src/`, `gp.asd`, and related files.

### Introduction

Genetic programming inspired by John Koza's Little Lisp: [http://www.genetic-programming.org/gplittlelisp.html]

This is for Academic purpose only (Please read below).

This is a project to learn Common Lisp and Genetic Programming at the same time.
I use John Koza's Little Lisp code as a starting point and try to improve it.
I hope to be able to do some Artificial Intelligence stuff with it.

### John Koza's Notes

 The following is a pure (CLtL2) Common Lisp implementation
 of the Genetic Programming Paradigm.  Great care has been
 taken to ensure that the code below both works and is identical
 to the code shown in the book.  The exception to this is the
 set of "top-level" forms that are shown in the appendix as
 examples, for instance, of calls that would fire off the GPP.
 These have not been included in-line in the code so as to
 prevent execution of the system during the compile/load
 cycle.  All of these test expressions haven been included
 in one test function, however, which is discussed below.

 If you are interested in genetic programming, you may want
 to subscribe to the genetic programming mailing list.
 The list is called genetic-programming@cs.stanford.edu
 To subscribe to it, you should send mail to
 genetic-programming-request@cs.stanford.edu
                    ^^^^^^^^
 clearly giving the address you with to have mail sent to.

 The code is split into a number of parts, each delimited
 by the comment line:

===================================================


1) The first component is the Kernel of the Genetic
Programming implementation.  This is the domain-independent
code which can be used to execute a variety of different
problems, three of which are provided.

2) The second component concerns optimizations for the evaluation
of individuals.  These include the function Fast-Eval, which
can be used in your fitness functions to speed things up.
Also shown are the "pseudo-macro"s shown in the book.
The instalation of this form of optimization is not portable
between different Common Lisp implementations.
Source conditionalizations have been provided so that
this code should work without alteration under:
     Texas Instruments Common Lisp version 6.1
     Macintosh Common LISP (Allegro/Coral) versions 1.3.2 and 2.0b1
     Lucid Common LISP version 4.0.x, 4.1
     Allegro Common Lisp (Franz inc.) version 4.1
If you are running under anything other than these you
may be able to use one or other of the implementations
(search for #+), but you may have to hack something new
up for yourself.  The example of the implementations
provided should make life simpler.
It is worth noting that the performance improvement that
can result from the pseudo-macro mechanism is usually
substantial and can sometimes be tenfold.  Thus, if you are
likely to be addressing any problems in which control of
evaluation of arguments is necessary, particularly in problems
that exhibit side-effects as a result of evaluating either
the functions or the terminals in the function/terminal sets
then is is very much worth your while to get this working
on your own particular implementation.

3) The third component is the domain independent part of the
program editing tool.

4) Is the definition of a set of rules for simplifying
Boolean sexpressions.

5) Is the problem-specific code necessary to define and run
the symbolic regression problem for 0.5x**2.

6) Is the code necessary to implement the Boolean 3-Majority-On
problem

7) Is the code necessary to implement the Discrete Non-Hamstrung
Squard Car problem.

8) Is a pair of test functions.  Test-GPP will execute all of the
example test sexpressions shown in the book, printing out the tests
as they are performed.  Time-Test-GPP runs test-GPP, sending the
output from the tests to a log file, printing out the time taken
at the end.

9) Commented out at the bottom you will find all of the forms
provided in the book as examples of how to switch on the pseudo
macro and fast-eval optimizations.  If you want to use these
you need only compile this section out of the editor or remove
the #| and |# marks and recompile the file.




Notes:  When compiling you might get a warning about
there being two definitions for the variable X
and for the functions sort-population-by-fitness and
define-function-set-for-MAJORITY-ON.
This is intentional, so as to make the code below
mirror the book as accurately as possible.  Although
these warnings will not in any way prevent the GPP
from working, you may choose to remove the second
definition of (defvar X) and also whichever of the
definitions of sort-population-by-fitness you do not
want.  The default version of sort-population-by-fitness
that you will get (i.e. the second) is the one which is
likely to be most reproducible in behavior across
platforms, but not necessarily the fastest.  The first
definition of define-function-set-for-MAJORITY-ON is
the more common usage for Boolean problems with each
function represented in the function set just once.

## License

New code and modifications in this repository are under the MIT License
(see `COPYING`).

Copyright (c) Guillaume MICHEL, All rights reserved.

The original Little Lisp code and Koza I material remain under John Koza's
academic license, reproduced below.

### Little Lisp License

Copyright (c) John Koza, All rights reserved.
U.S. Patent #4,935,877.  Other patents pending.

ROYALTY-FREE LICENSE FOR GENETIC PROGRAMMING SOFTWARE FOR ACADEMIC PURPOSES
===========================================================================

As you requested, I am including herewith, FOR YOUR INFORMATION AND
INSPECTION ONLY, a copy of my "SIMPLE LISP" software for genetic
programming.  Please be advised that this software is copyrighted and
is the subject of my United States patents 4,935,877 5,136,686, and
5,148,513, foreign counterparts, and other patents pending.

IF YOU WISH TO USE THIS SOFTWARE, you may have a royalty-free,
non-exclusive license under these proprietary rights, without the
right of sublicense, to use (but not to make or sell) the software
for academic purposes only and only then if you receive no money
or other valuable consideration as a result of its use.
Neither the software (or copies thereof) nor this license is
transferrable for any reason.  This license grants you the right
to make copies of the software which are necessary for your use,
and your use only, provided each copy incorporates this license.

The programs, procedures, and applications presented in this software
have been included for their instructional value.  The publisher and
author offer NO WARRANTY OF FITNESS OR MERCHANTABILITY for any
particular purpose or accept any liability with respect
to these programs, procedures, and applications.

If you wish such a licence under these terms, please indicate so
by signing and dating a copy of this notice and returning it to me
at John Koza, Box K, Los Altos, California 94023 USA.

I would like the above license and hereby agree to the terms set forth above.

LICENSEE:

NAME (Print) ____________________________

Signature _________________________________

Date _______________

PHYSICAL ADDRESS _______________________________

CITY, STATE, ZIP _______________________________

COUNTRY _____________________________

E-MAIL ADDRESS _______________________________________

PHONE ___________________________
