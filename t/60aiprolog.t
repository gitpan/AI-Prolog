
#!/usr/bin/perl
# '$Id: 60aiprolog.t,v 1.1 2005/01/23 20:23:14 ovid Exp $';
use warnings;
use strict;
use Test::More tests => 3;
use Test::MockModule;
use Test::Differences;
use Clone qw/clone/;

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
