#!/usr/bin/perl
# '$Id: 50engine.t,v 1.1 2005/01/23 20:23:14 ovid Exp $';
use warnings;
use strict;
use Test::More 'no_plan';
use Test::MockModule;
use Test::Differences;
use Clone qw/clone/;

my $CLASS;
BEGIN
{
    chdir 't' if -d 't';
    unshift @INC => '../lib';
    $CLASS = 'AI::Prolog::Engine';
    use_ok($CLASS) or die;
}

# I hate the fact that they're interdependent.  That brings a 
# chicken and egg problem to squashing bugs.
use aliased 'AI::Prolog::TermList';
use aliased 'AI::Prolog::Term';
use aliased 'AI::Prolog::Parser';

my $database = Parser->consult(<<'END_PROLOG');
append([], X, X).
append([W|X],Y,[W|Z]) :- append(X,Y,Z).
END_PROLOG
my @keys = sort keys %$database;
my @expected = qw{append/3-1 append/3-2};
is_deeply \@keys, \@expected,
    'A brand new database should only have the predicates listed in the query';

my $parser = Parser->new("append(X,Y,[a,b,c,d]).");
my $query  = Term->new($parser);

can_ok $CLASS, 'new';
ok my $engine = $CLASS->new($query, $database),
    '... and calling new with a valid query and database should succeed';
isa_ok $engine, $CLASS, '... and the object it returns';

@expected = qw{
    append/3-1
    append/3-2
    call/1-1
    eq/2-1
    fail/0-1
    if/3-1
    nl/0-1
    not/1-1
    once/1-1
    or/2-1
    or/2-2
    print/1-1
    true/0-1
    wprologcase/3-1
    wprologcase/3-2
    wprologtest/2-1
    wprologtest/2-2
};

@keys = sort keys %$database;
is_deeply \@keys, \@expected,
    '... and the basic prolog terms should be bootstrapped';
can_ok $engine, 'results';
is $engine->results, 'append([],[a,b,c,d],[a,b,c,d])',
    '... calling it the first time should provide the first unification';
is $engine->results, 'append([a],[b,c,d],[a,b,c,d])',
    '... and then the second unification';
is $engine->results, 'append([a,b],[c,d],[a,b,c,d])',
    '... and then the third unification';
is $engine->results, 'append([a,b,c],[d],[a,b,c,d])',
    '... and then the fifth unification';
is $engine->results, 'append([a,b,c,d],[],[a,b,c,d])',
    '... and then the last unification unification';
ok ! defined $engine->results,
    '... and it should return undef when there are no more results';

my $bootstrapped_db = clone($database);

#eq_or_diff $database, $bootstrapped_db, ';;;';
