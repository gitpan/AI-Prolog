#!/usr/local/bin/perl -l
use strict;
use warnings;
use lib ('../lib/', 'lib');
use aliased 'AI::Prolog';

# XXX finish later

my $prolog = Prolog->new(<<'END_PROLOG');
member(X,[X|Xs]).
member(X,[Y|Ys]) :- member(X,Ys).

teacher(Person) :- member(Person, [randal,bob,sally]).
classroom(Room) :- member(Room,   [class1,class2,class3]).
classtime(Time) :- member(Time,   [morning_day1,morning_day2,noon_day1,noon_day2]).

schedule(Schedule) :-
    make_schedule(Schedule).

make_schedule([],0) :- !.
make_schedule([course(Teacher,Time,Room)|Rest], N) :-
    teacher(Teacher),
    classroom(Room),
    classtime(Time).
END_PROLOG

AI::Prolog::Engine->formatted(1);
$prolog->query('classroom(X).');

while (my $result = $prolog->results) {
    print $result;
}

$prolog->query('teacher(kudra).');
while (my $result = $prolog->results) {
    print $result;
}
