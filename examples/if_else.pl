#!/usr/local/bin/perl -l
use strict;
use lib qw(../lib/ lib/);
use AI::Prolog qw/:all/;

my $database = Parser->consult(<<'END_PROLOG');
thief(badguy).
steals(PERP, X) :-
 if(thief(PERP), eq(X,rubies), eq(X,nothing)).
END_PROLOG
my $query = Term->new("steals(badguy,X).");
my $engine = Engine->new($query, $database);
$engine->formatted(1);
print $engine->results;

$query = Term->new("steals(ovid, X).");
$engine = Engine->new($query, $database);
print $engine->results;
