#!/usr/bin/perl
# '$Id: 20term.t,v 1.1 2005/01/23 20:23:14 ovid Exp $';
use warnings;
use strict;
use Test::More tests => 56;
#use Test::More 'no_plan';

my $CLASS;
BEGIN
{
    chdir 't' if -d 't';
    unshift @INC => '../lib';
    $CLASS = 'AI::Prolog::Term';
    use_ok($CLASS) or die;
}

# I hate the fact that they're interdependent.  That brings a 
# chickin and egg problem to squashing bugs.
use aliased 'AI::Prolog::Parser';

can_ok $CLASS, 'occurcheck';
is $CLASS->occurcheck, 0, '... and it should return a false value';
$CLASS->occurcheck(1);
is $CLASS->occurcheck, 1, '... but we should be able to set it to a true value';

can_ok $CLASS, 'internalparse';
is $CLASS->internalparse, 0, '... and it should return a false value';
$CLASS->internalparse(1);
is $CLASS->internalparse, 1, '... but we should be able to set it to a true value';

can_ok $CLASS, 'new';

eval { $CLASS->new(1,2,3) };
ok $@, 'Calling new with arguments it does not expect should croak()';
like $@, qr/Unknown arguments to Term->new/,
    '... with an appropriate error message';

# new, unbound term

ok my $term = $CLASS->new, 'Calling it without arguments should succeed';
isa_ok $term, $CLASS, '... and the object it returns';

#diag $term->to_string;
my $term2 = $term->refresh([undef, $term]);
#diag $term2->to_string;
can_ok $term, 'functor';
ok ! defined $term->functor, '... and creating an blank term should not have a functor';

can_ok $term, 'arity';
is $term->arity, 0, '... and the blank term should have an arity (number of args) of 0';

can_ok $term, 'args';
is_deeply $term->args, [], '... and it should have no args';

can_ok $term, 'bound';
ok ! $term->bound, '... nor should it be bound to another term';

can_ok $term, 'varid';
is $term->varid, 1, '... and the first empty term should have the first varid';

can_ok $term, 'deref';
ok ! $term->deref, '... and since it is not bound, we cannot dereference it';

can_ok $term, 'ref';
ok ! defined $term->ref, '... which means it should not reference anything';

can_ok $term, 'to_string';
is $term->to_string, '_1',
    '... and a simple unbound term will just have an _$varnum as its string representation';

# new with id

ok $term = $CLASS->new(7), 'We should be able to create a new term by just specifying an id for it';
ok ! defined $term->functor, '... and creating an blank term should not have a functor';
is $term->arity, 0, '... and the blank term should have an arity of 0';
is_deeply $term->args, [], '... and it should have no args';
ok ! $term->bound, '... nor should it be bound to another term';
is $term->varid, 7, '... and it should have the id we specify';
ok ! $term->deref, '... and since it is not bound, we cannot dereference it';
ok ! defined $term->ref, '... which means it should not reference anything';
is $term->to_string, '_7',
    '... and a simple unbound term will just have an _$varnum as its string representation';

# new with functor and arity

ok $term = $CLASS->new('steals', 2), 
    'Creating a new terms by specifiying its functor and arity';
is $term->functor, 'steals', '... and it should have the functor we specify';
is $term->arity, 2, '... and the blank term should have an arity of 0';
is_deeply $term->args, [], '... and it should have no args';
is $term->bound, 1, '... but it should be bound to a value!';
ok ! defined $term->varid, '... and it should not have an id';
ok ! $term->deref, '... it is bound, but it should not be a reference';
ok ! defined $term->ref, '... which means it should not reference anything';
is $term->to_string, 'steals()',
    '... bound term with no args should show the functor and empty parens';

my $parsed = Parser->new('stuph(VAR)');
ok $term = $CLASS->new($parsed),
    'We should be able to create a new term from a parser object';
is $term->functor, 'stuph', '... and the functor should match the parser functor';
is $term->arity, 1, '... and the arity should match the parser arity';
is @{$term->args}, 1, '... and it should have 1 arg';
is $term->bound, 1, '... but it should be bound to a value!';
ok ! defined $term->varid, '... and it should not have an id';
ok ! $term->deref, '... it is bound, but it should not be a reference';
ok ! defined $term->ref, '... which means it should not reference anything';
is $term->to_string, 'stuph(_0)',
    '... bound term with one arg should show the functor and the arg varid';

can_ok $term, 'refresh';
#diag $term->to_string;
$term2 = $term->refresh([undef, $term]);
#diag $term2->to_string;
