#!/usr/local/bin/perl -l

use strict;
use warnings;
use lib ('../lib/', 'lib');
use aliased 'AI::Prolog::Parser';
use aliased 'AI::Prolog::Term';
use aliased 'AI::Prolog::Engine';

my $database = Parser->consult(<<'END_PROLOG');
append([], X, X).
append([W|X],Y,[W|Z]) :- append(X,Y,Z).
END_PROLOG

my $parser = Parser->new("append([a],[b,c,d],Z).");
my $query  = Term->new($parser);
my $engine = Engine->new($query,$database);
$engine->formatted(1);

print "Appending two lists 'append([a],[b,c,d],Z).'";
while (my $result = $engine->results) {
    print $result;
}

$parser = Parser->new("append(X,[b,c,d],[a,b,c,d]).");
$query  = Term->new($parser);
$engine = Engine->new($query,$database);

print "\nWhich lists appends to a known list to form another known list?\n'append(X,[b,c,d],[a,b,c,d]).'";
while (my $result = $engine->results) {
    print $result;
}

$parser = Parser->new("append(X,Y,[a,b,c,d]).");
$query  = Term->new($parser);
$engine = Engine->new($query,$database);

print "\nWhich lists append to form a known list?\n'append(X,Y,[a,b,c,d]).'";
while (my $result = $engine->results) {
    print $result;
}

$parser = Parser->new("append([a,b], Y, Z).");
$query  = Term->new($parser);
$engine = Engine->new($query,$database);

print "\nWhich lists can be appended to a given list and what would the result be?\n'append([a,b], Y, Z).'";
while (my $result = $engine->results) {
    print $result;
}
