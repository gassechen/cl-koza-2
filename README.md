# gp

## Introduction
Genetic programming inspired by John Koza's Little Lisp: [http://www.genetic-programming.org/gplittlelisp.html]

This is for Academic purpose only (Please read below).

This is a project to learn Common Lisp and Genetic Programming at the same time.
I use John Koza's Little Lisp code as a starting point and try to improve it.
I hope to be able to do some Artificial Intelligence stuff with it.

## John Koza's Notes

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
     Allegro Common LISP (Franz inc.) version 4.1
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

## Little Lisp License 

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

## License
All modifications from the original Little Lisp code are under MIT License.

Copyright (c) Guillaume MICHEL, All rights reserved.

# cl-koza-2
