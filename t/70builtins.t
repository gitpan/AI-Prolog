#!/usr/bin/perl
# '$Id: 70builtins.t,v 1.5 2005/02/20 23:56:05 ovid Exp $';
use warnings;
use strict;
use Test::More tests => 33;
#use Test::More qw/no_plan/;
use Test::MockModule;
use Clone qw/clone/;
use Test::Differences;

use aliased 'AI::Prolog';

my $database = <<'END_PROLOG';
thief(badguy).
thief(thug).
steals(PERP,X) :-
  if(thief(PERP), eq(X,rubies), eq(X,nothing)).
p(X) :- call(steals(badguy,rubies)).
q(X) :- call(steals(badguy,X)).
valuable(gold).
valuable(rubies).
END_PROLOG
AI::Prolog::Engine->formatted(1);
#AI::Prolog::Engine->trace(1);
my $prolog = Prolog->new($database);
$prolog->query("p(ovid)");
is $prolog->results, 'p(ovid)', 'call(X) should behave correctly';

#
# I think it's failing because the call contains and if and
# if is defined in terms of once() and once is defined with
# a cut and I don't quite have the cut correct
#

my $boostrap_db = clone($database);
eq_or_diff $database, $boostrap_db,
    '... and the database should not change after its bootstrapped';

$prolog->query("q(X)");
is $prolog->results, 'q(rubies)',
    '... even if called with a variable';
    
$prolog->query('eq(this,this)');
is $prolog->results, "eq(this,this)",
    'eq(X,Y) should succeed if the predicate are equal';

$prolog->query("eq(this,that).");
ok ! $prolog->results, '... and it should fail if the predicate are not equal';
$prolog->query("steals(badguy,X).");
is $prolog->results, 'steals(badguy,rubies)',
    'if(X,Y,Z) should call Y if X is satisfied';
ok ! $prolog->results, '... and it should only provide correct results';

$prolog->query("steals(ovid,X).");
is $prolog->results, 'steals(ovid,nothing)',
    '... and it should call Z if X cannot be satisfied';
ok ! $prolog->results, '... and it should only provide correct results';

my $faux_engine = Test::MockModule->new(AI::Prolog::Engine);
my @stdout;
$faux_engine->mock(_print => sub { push @stdout => @_ });

$prolog->query("nl.");
$prolog->results;
is_deeply \@stdout, ["\n"], "nl should print a newline";

$prolog->query("not(thief(ovid)).");
is $prolog->results, 'not(thief(ovid))',
    'not() should succeed if query cannot be proven';

$prolog->query("not(thief(badguy)).");
ok ! $prolog->results, '... and it should fail if the query can be proven';

$prolog->query("once(valuable(X)).");
is $prolog->results, 'once(valuable(gold))',
    'once should return the first successful goal';
ok ! $prolog->results,
    '... but it should not return more results even if they exist';

$prolog->query("or(thief(badguy),thief(ovid)).");
is $prolog->results, 'or(thief(badguy),thief(ovid))',
    'or should succeed if one of its goals can succeed.';

$prolog->query("or(thief(ovid),thief(badguy)).");
is $prolog->results, 'or(thief(ovid),thief(badguy))',
    '... regardless of the order they are in';

$prolog->query("or(thief(thug),thief(badguy)).");
is $prolog->results, 'or(thief(thug),thief(badguy))',
    '... and it should succeed if both of its goals can succeed';

$prolog->query("or(thief(kudra),thief(ovid)).");
ok ! $prolog->results, '... but it should fail if none of its goals can succeed';

@stdout = ();
$prolog->query("print(badguy).");
$prolog->results;
is_deeply \@stdout, ["badguy"], "print/1 should print what we give it.";

@stdout = ();
$prolog->query("if(steals(ovid,X),print(X),print(false)).");
$prolog->results;
is_deeply \@stdout, ["nothing"], '... even if it is printing a variable';

$prolog->do("assert(loves(ovid,perl)).");
$prolog->query("loves(ovid,X)");
is $prolog->results, "loves(ovid,perl)", 'assert(X) should let us add new facts to the db';

$prolog->do("assert(loves(bob,stuff))");
$prolog->query('loves(bob,Y)');
is $prolog->results, 'loves(bob,stuff)',
    '... and we should be able to add more than one fact';
$prolog->query("loves(ovid,X)");
is $prolog->results, "loves(ovid,perl)", '... and it shoud not interfere with previous facts';

$prolog->do("assert(loves(sally, X))");
$prolog->query('loves(sally,Y)');
is $prolog->results, 'loves(sally,_0)',
    '... and we should be able to assert a fact with a variable';

$prolog->query('loves(sally, food)');
is $prolog->results, 'loves(sally,food)',
    '... and it should behave as expected';
$prolog->query('loves(sally,X)');
is $prolog->results, 'loves(sally,_0)',
    '... and the asserted fact should remain unchanged.';

$prolog->do("retract(loves(ovid,perl)).");
$prolog->query("loves(ovid,X)");
ok ! $prolog->results,
    "retract(X) should remove a fact from the database";

ok $prolog = Prolog->new(<<'END_PROLOG'), 'We should be able to parse a cut (!) operator';
append([], X, X) :- !.
append([W|X],Y,[W|Z]) :- append(X,Y,Z).
END_PROLOG
$prolog->query('append(X,Y,[a,b,c,d])');
is $prolog->results, 'append([],[a,b,c,d],[a,b,c,d])',
    '... and it should return the correct results';
ok ! $prolog->results, '... and halt backtracking appropriately';

$prolog = Prolog->new(<<'END_PROLOG');
test_var(VAR,X) :-
  if(var(VAR), eq(X,is_var), eq(X,not_var)).
END_PROLOG
$prolog->query('test_var(X, Y)');
is $prolog->results, 'test_var(_0,is_var)', 'var(X) should evaluate to true';
$prolog->query('test_var(42, Y)');
is $prolog->results, 'test_var(42,not_var)',
    '... and var(42) should evaluate to not true';
$prolog->query('test_var(ovid, Y)');
is $prolog->results, 'test_var(ovid,not_var)',
    '... and var(ovid) should evaluate to not true';

__END__
#
# Math
#

AI::Prolog::Engine->formatted(1);
my $prolog = Prolog->new(<<'END_PROLOG');
value(rubies, 100).
value(paper, 1).
thief(badguy).
steals(PERP, STUFF) :-
    value(STUFF, DOLLARS),
    gt(DOLLARS, 50).
END_PROLOG

$prolog->query('gt(4,3)');
is $prolog->results, 'gt(4,3)',
    'gt(X,Y) should succeed if the first argument > the second argument.';

$prolog->query('gt(3,34)');
ok ! $prolog->results,
    '... and it should fail if the first argument < the second argument.';

$prolog->query('gt(3,3)');
ok ! $prolog->results,
    '... and it should fail if the first argument = the second argument.';
    
$prolog->query('steals(badguy, X)');
is $prolog->results, 'steals(badguy,rubies)',
    '... and it should succeed as part of a complicated query';
ok ! $prolog->results, '... but it should not return more than the correct results';

$prolog->query('ge(4,3)');
is $prolog->results, 'ge(4,3)',
    'ge(X,Y) should succeed if the first argument > the second argument.';

$prolog->query('ge(3,34)');
ok ! $prolog->results,
    '... and it should fail if the first argument < the second argument.';

$prolog->query('ge(3,3)');
is $prolog->results, 'ge(3,3)',
    '... and it should succeed if the first argument = the second argument.';
    
$prolog->query('lt(3,4)');
is $prolog->results, 'lt(3,4)',
    'lt(X,Y) should succeed if the first argument < the second argument.';

$prolog->query('lt(34,3)');
ok ! $prolog->results,
    '... and it should fail if the first argument < the second argument.';

$prolog->query('lt(3,3)');
ok ! $prolog->results,
    '... and it should fail if the first argument = the second argument.';

$prolog->query('le(3,4)');
is $prolog->results, 'le(3,4)',
    'le(X,Y) should succeed if the first argument < the second argument.';

$prolog->query('le(34,3)');
ok ! $prolog->results,
    '... and it should fail if the first argument < the second argument.';

$prolog->query('le(3,3)');
is $prolog->results, 'le(3,3)',
    '... and it should succeed if the first argument = the second argument.';
