#!/usr/local/bin/perl -l

# see http://www.compapp.dcu.ie/~alex/LOGIC/monkey.html
# This is the classic Monkey/Banana problem
use strict;
use warnings;
use lib ('../lib/', 'lib');
use aliased 'AI::Prolog::Parser';
use aliased 'AI::Prolog::Term';
use aliased 'AI::Prolog::Engine';

my $database = Parser->consult(<<'END_PROLOG');
perform(grasp, 
        state(middle, middle, onbox, hasnot),
        state(middle, middle, onbox, has)).

perform(climb, 
        state(MP, BP, onfloor, H),
        state(MP, BP, onbox, H)).

perform(push(P1,P2), 
        state(P1, P1, onfloor, H),
        state(P2, P2, onfloor, H)).

perform(walk(P1,P2), 
        state(P1, BP, onfloor, H),
        state(P2, BP, onfloor, H)).

/* getfood(state(_,_,_,has)). */
/* I'll have to fix this soonish! */

getfood(state(Bogus1,Bogus2,Bogus3,has)).

getfood(S1) :- perform(Act, S1, S2),
              nl, print(S1), print(Act),
              getfood(S2).
END_PROLOG

my $parser = Parser->new("getfood(state(atdoor,atwindow,onfloor,hasnot)).");
my $query  = Term->new($parser);
my $engine = Engine->new($query,$database);

print $engine->results;
