#!/usr/local/bin/perl -l

use strict;
use warnings;
use lib ('../lib/', 'lib/');

use aliased 'AI::Prolog';
my $logic = Prolog->new(thief_prog());
$logic->query('steals("Bad guy", STUFF, VICTIM)');
Prolog->trace(1);
while (my $results = $logic->results) {
    printf "Bad guy steals %s from %s\n",
        $results->STUFF, $results->VICTIM;
}

sub thief_prog {
    return <<'    END_PROG';
    steals(PERP, STUFF, VICTIM) :-
        thief(PERP),
        valuable(STUFF),
        owns(VICTIM,STUFF),
        not(knows(PERP,VICTIM)).
    thief("Bad guy").
    valuable(gold).
    valuable(rubies).
    owns(merlyn,gold).
    owns(ovid,rubies).
    owns(kudra, gold).
    knows(badguy,merlyn).
    END_PROG
}
