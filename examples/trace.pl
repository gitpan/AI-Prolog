#!/usr/local/bin/perl -l

use strict;
use warnings;
use lib ('../lib/', 'lib/');
use aliased 'AI::Prolog::Parser';
use aliased 'AI::Prolog::Term';
use aliased 'AI::Prolog::Engine';

my $term   = Term->new("steals(badguy,X).");
my $engine = Engine->new(
    $term,
    Parser->consult(
        thief_prog(),
        {},
    )
);
Engine->trace(1);
print $engine->results;

sub thief_prog {
    return <<'    END_PROG';
    steals(PERP, STUFF) :-
        thief(PERP),
        valuable(STUFF),
        owns(VICTIM,STUFF),
        not(knows(PERP,VICTIM)).
    thief(badguy).
    valuable(gold).
    valuable(rubies).
    owns(merlyn,gold).
    owns(ovid,rubies).
    knows(badguy,merlyn).
    END_PROG
}
