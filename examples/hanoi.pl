#!/usr/bin/perl 
use strict;
use warnings;
use lib ('../lib/', 'lib/');

use aliased 'AI::Prolog';

my $prolog = Prolog->new(<<'END_PROLOG');
hanoi(N) :-
    move(N, left, center, right).

move(0, NULL1, NULL2, NULL3) :- !.

move(N,A,B,C) :-
    is(M, minus(N,1)),
    move(M,A,C,B),
    inform(A,B),
    move(M,C,B,A).

inform(X,Y) :-
    print("Move a disc from the "),
    print(X),
    print(" pole to the "),
    print(Y),
    println(" pole").
END_PROLOG

$prolog->do('hanoi(4)');
