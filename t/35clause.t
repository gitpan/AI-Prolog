#!/usr/bin/perl
# '$Id: 35clause.t,v 1.1 2005/02/20 18:27:55 ovid Exp $';
use warnings;
use strict;
#use Test::More 'no_plan';
use Test::More tests => 14;

my $CLASS;
BEGIN
{
    chdir 't' if -d 't';
    unshift @INC => '../lib';
    $CLASS = 'AI::Prolog::TermList::Clause';
    use_ok($CLASS) or die;
}

# I hate the fact that they're interdependent.  That brings a 
# chickin and egg problem to squashing bugs.
use aliased 'AI::Prolog::Parser';
use aliased 'AI::Prolog::Term';

can_ok $CLASS, 'new';
my $parser = Parser->new("p(X,p(X,Y)).");
ok my $clause = $CLASS->new($parser),
    '... and creating a new clause from a parser object should succeed';
isa_ok $clause, $CLASS, '... and the object it creates';

can_ok $clause, 'to_string';
is $clause->to_string, 'p(_0,p(_0,_1)) :- null',
    '... and its to_string representation should be correct';

can_ok $clause, 'term';
ok my $term = $clause->term, '... and calling it should succeed';
isa_ok $term, Term, '... and the object it returns';
is $term->functor, 'p', '... and it should have the correct functor';
is $term->arity, 2, '... and the correct arity';

my $db = Parser->consult('p(this,that).');
can_ok $clause, 'resolve';
$clause->resolve($db);
is $clause->to_string, 'p(_0,p(_0,_1)) :- null',
    '... and its to_string representation should reflect this';

$db = Parser->consult('p(this,that).');
$clause = $CLASS->new(Parser->new('p(X,p(X,Y)).'));
$clause->{definer}[0] = 'anything';
$clause->resolve($db);

$clause = $CLASS->new(Parser->new(<<'END_PROLOG'));
father(Parent, Child) :-
  male(Parent),
  parent(Parent, Child).
END_PROLOG
is $clause->to_string, 'father(_0,_1) :- male(_0) :- parent(_0,_1) :- null',
    'Building a complex clause should succeed';
