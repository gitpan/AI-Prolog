#!/usr/bin/perl
# '$Id: 10choicepoint.t,v 1.1 2005/01/23 20:23:14 ovid Exp $';
use warnings;
use strict;
use Test::More tests => 9;

my $CLASS;
BEGIN
{
    chdir 't' if -d 't';
    unshift @INC => '../lib';
    $CLASS = 'AI::Prolog::ChoicePoint';
    use_ok($CLASS) or die;
}

my $to_string_called = 0;
{
    package Goal;
    sub new       { bless {}=> shift }
    sub to_string { $to_string_called++; "some goal" }
}

can_ok $CLASS, 'new';
ok my $cpoint = $CLASS->new(3, Goal->new), '... and calling it should succeed';
isa_ok $cpoint, $CLASS, '... and the object it returns';

can_ok $cpoint, 'clausenum';
is $cpoint->clausenum, 3, '... and it should return the clausenum it was supplied';

can_ok $cpoint, 'to_string';
is $cpoint->to_string, '<< 3 : some goal>>',
    '... and it should return the right value';
ok $to_string_called, "... and call the goal's to_string method";
