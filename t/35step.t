#!/usr/bin/perl
# '$Id: 35step.t,v 1.1 2005/02/20 18:27:55 ovid Exp $';
use warnings;
use strict;
#use Test::More 'no_plan';
use Test::More tests => 12;

my $CLASS;
BEGIN
{
    chdir 't' if -d 't';
    unshift @INC => '../lib';
    $CLASS = 'AI::Prolog::TermList::Step';
    use_ok($CLASS) or die;
}

# XXX These are mostly stub tests.  I'm going to have to
# come back and flesh these out more

use aliased 'AI::Prolog::Parser';
use aliased 'AI::Prolog::TermList';
use aliased 'AI::Prolog::Term';
use aliased 'AI::Prolog::TermList::Primitive';

my $parser = Parser->new("p(X,p(X,Y)).");
my $tls    = TermList->new($parser);
#$tls->next(Primitive->new(7)); # doesn't have to be a primitive.  Just for testing
can_ok $CLASS, 'new';
ok my $step = $CLASS->new($tls),
    '... and creating a new step from a parser object should succeed';
isa_ok $step, $CLASS, '... and the object it creates';

can_ok $step, 'to_string';
is $step->to_string, '[STEP]',
    '... and its to_string representation should be correct';

can_ok $step, 'term';
ok my $term = $step->term, '... and calling it should succeed';
isa_ok $term, Term, '... and the object it returns';
is $term->functor, 'STEP', '... and it should have the correct functor';
is $term->arity, 0, '... and the correct arity';

can_ok $step, 'next';

diag "Flesh out the Step tests when we start using this more";
__END__
ok my $termlist = $step->next, '... and calling it should succeed';
isa_ok $termlist, TermList, '... and the object it returns';
is_deeply $termlist, $tls, '... and it should be the termlist we instantiated the Step with';
