#!/usr/local/bin/perl -l

use strict;
use warnings;
use lib ('../lib/', 'lib/');
use aliased 'AI::Prolog::Parser';
use aliased 'AI::Prolog::Term';
use aliased 'AI::Prolog::Engine';
use Benchmark;

my $parser = Parser->new("nrev30");
my $query  = Term->new($parser);
my $engine = Engine->new($query,Parser->consult(benchmark()));
$engine->formatted(1);

my $t0 = new Benchmark;
while (my $result = $engine->results) {
    print $result;
}
my $t1 = new Benchmark;
my $td = timediff($t1, $t0);
print "the code took:",timestr($td),"\n";

sub benchmark {
    return <<"    END_BENCHMARK";
    append([],X,X).
    append([X|Xs],Y,[X|Z]) :- 
        append(Xs,Y,Z). 
    nrev([],[]).
    nrev([X|Xs],Zs) :- 
        nrev(Xs,Ys), 
        append(Ys,[X],Zs). 
    nrev30 :- 
        nrev([1,2,3,4,5,6,7,8,9,0,1,2,3,4,5,6,7,8,9,0,1,2,3,4,5,6,7,8,9,0],X).
    END_BENCHMARK
}
