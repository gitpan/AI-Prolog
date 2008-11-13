#!/usr/bin/perl
use warnings;
use strict;
use Test::More;
BEGIN
{
    my $fixture_ok = eval q{
        use Test::MockModule;
        use Test::Differences;

        1;
    };
    if ( ! $fixture_ok ) {
        plan skip_all => 'Test::MockModule, Test::Differences required for this';
        exit 0;
    }
    else {
        plan tests => 4;
    }
}

my $CLASS;
BEGIN
{
    chdir 't' if -d 't';
    unshift @INC => '../lib';
    $CLASS = 'AI::Prolog';
    use_ok($CLASS, ':all') or die;
}

my $database = Parser->consult(<<'END_PROLOG');
append([], X, X).
append([W|X],Y,[W|Z]) :- append(X,Y,Z).
END_PROLOG

my $query  = Term->new("append(X,Y,[a,b,c,d]).");
my $engine = Engine->new($query,$database);

isa_ok $query,  Term,   '... and the Term shortcut';
isa_ok $engine, Engine, '... and the Engine shortcut';

my $prolog = AI::Prolog->new(<<'END_PROLOG');
member(X,[X|Xs]).
member(X,[_|Tail]) :- member(X,Tail).
END_PROLOG

$prolog->query('member(3, [1,2,3,4]).');
ok $prolog->results, '... and unifying with anonymous variables should succeed';


$prolog = AI::Prolog->new(<<'END_PROLOG');
member(X,[X|Xs]).
member(X,[_|Tail]) :- member(X,Tail).

thief(alan).
steals(bob, _, _) :- thief(bob).
thief(bob).
END_PROLOG

$prolog->query('steals(bob,X,Y).');
ok $prolog->results, '... even if we have multiple anonymous variables';
