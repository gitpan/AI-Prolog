#!/usr/local/bin/perl
use strict;
use warnings;
#use Test::More 'no_plan';
use Test::More tests => 6;

my $CLASS;
BEGIN
{
    chdir 't' if -d 't';
    unshift @INC => '../lib';
}

use lib '../lib/';
use aliased 'AI::Prolog::Parser';
use aliased 'AI::Prolog::Term';
use aliased 'AI::Prolog::Engine';

my $parser = Parser->new("append(X,Y,[a,b,c,d]).");
my $query  = Term->new($parser);
my $engine = Engine->new($query,Parser->consult(append_prog()));
$engine->formatted(1);

is $engine->results,  'append([],[a,b,c,d],[a,b,c,d])', 'Running the engine should work';
is $engine->results, 'append([a],[b,c,d],[a,b,c,d])', '... as should fetching more results';
is $engine->results, 'append([a,b],[c,d],[a,b,c,d])', '... as should fetching more results';
is $engine->results, 'append([a,b,c],[d],[a,b,c,d])', '... as should fetching more results';
is $engine->results, 'append([a,b,c,d],[],[a,b,c,d])', '... as should fetching more results';
ok ! $engine->results, '... and we should return false when we have no more results';

sub append_prog {
    "append([], X, X)."
   ."append([W|X],Y,[W|Z]) :- append(X,Y,Z).";
}
