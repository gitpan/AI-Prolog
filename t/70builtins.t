#!/usr/bin/perl
# '$Id: 60aiprolog.t,v 1.1 2005/01/23 20:23:14 ovid Exp $';
use warnings;
use strict;
#use Test::More tests => 3;
use Test::More qw/no_plan/;
use Test::MockModule;
use Clone qw/clone/;
use Test::Differences;

my $CLASS;
BEGIN
{
    chdir 't' if -d 't';
    unshift @INC => '../lib';
    $CLASS = 'AI::Prolog';
    use_ok($CLASS, ':all') or die;
}

my $database = Parser->consult(<<'END_PROLOG');
thief(badguy).
thief(thug).
steals(PERP,X) :-
  if(thief(PERP), eq(X,rubies), eq(X,nothing)).
p(X) :- call(steals(badguy,rubies)).
q(X) :- call(steals(badguy,X)).
valuable(gold).
valuable(rubies).
END_PROLOG

my $query = Term->new("p(ovid).");
my $engine = Engine->new($query,$database);
is $engine->results, 'p(ovid)',
    'call(X) should behave correctly';

my $boostrap_db = clone($database);
eq_or_diff $database, $boostrap_db,
    '... and the database should not change after its bootstrapped';

$query = Term->new("q(X).");
$engine->query($query);
is $engine->results, 'q(rubies)',
    '... even if called with a variable';
    
$query = Term->new("eq(this,this).");
$engine->query($query);
is $engine->results, "eq(this,this)",
    'eq(X,Y) should succeed if the predicate are equal';

$query = Term->new("eq(this,that).");
$engine->query($query);
ok ! $engine->results, '... and it should fail if the predicate are not equal';
$query  = Term->new("steals(badguy,X).");
$engine->query($query);
is $engine->results, 'steals(badguy,rubies)',
    'if(X,Y,Z) should call Y if X is satisfied';
ok ! $engine->results, '... and it should only provide correct results';

$query  = Term->new("steals(ovid,X).");
$engine->query($query);
is $engine->results, 'steals(ovid,nothing)',
    '... and it should call Z if X cannot be satisfied';
ok ! $engine->results, '... and it should only provide correct results';

my $faux_engine = Test::MockModule->new(Engine);
my @stdout;
$faux_engine->mock(_print => sub { push @stdout => @_ });

$query  = Term->new("nl.");
$engine->query($query);
$engine->results;
is_deeply \@stdout, ["\n"], "nl should print a newline";

$query = Term->new("not(thief(ovid)).");
$engine->query($query);
is $engine->results, 'not(thief(ovid))',
    'not() should succeed if query cannot be proven';

$query = Term->new("not(thief(badguy)).");
$engine->query($query);
ok ! $engine->results, '... and it should fail if the query can be proven';

$query = Term->new("once(valuable(X)).");
$engine->query($query);
is $engine->results, 'once(valuable(gold))',
    'once should return the first successful goal';
ok ! $engine->results,
    '... but it should not return more results even if they exist';

$query = Term->new("or(thief(badguy),thief(ovid)).");
$engine->query($query);
is $engine->results, 'or(thief(badguy),thief(ovid))',
    'or should succeed if one of its goals can succeed.';

$query = Term->new("or(thief(ovid),thief(badguy)).");
$engine->query($query);
is $engine->results, 'or(thief(ovid),thief(badguy))',
    '... regardless of the order they are in';

$query = Term->new("or(thief(thug),thief(badguy)).");
$engine->query($query);
is $engine->results, 'or(thief(thug),thief(badguy))',
    '... and it should succeed if both of its goals can succeed';

$query = Term->new("or(thief(kudra),thief(ovid)).");
$engine->query($query);
ok ! $engine->results, '... but it should fail if none of its goals can succeed';

#@stdout = ();
#$query = Term->new("print(badguy).");
#$engine->query($query);
#is_deeply \@stdout, ["ovid"],
#    'printing should print what we tell it to';
