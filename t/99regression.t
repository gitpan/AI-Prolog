#!/usr/bin/perl
# '$Id: 80math.t,v 1.4 2005/02/28 02:57:17 ovid Exp $';
use warnings;
use strict;
#use Test::More tests => 33;
use Test::More qw/no_plan/;
use Test::Exception;

BEGIN
{
    chdir 't' if -d 't';
    unshift @INC => '../lib';
}
use aliased 'AI::Prolog';
use aliased 'AI::Prolog::Engine';

Engine->formatted(1);
my $prolog = Prolog->new(<<'END_PROLOG');
i_am_at(top).
down :- retract(i_am_at(top)),assert(i_am_at(bottom)).
END_PROLOG

use Carp;
#$SIG{__DIE__} = \&Carp::confess;
#$prolog->do('trace on.');
$prolog->query('down.');
TODO: {
    local $TODO = 'This is a parsing bug.  We will have to fix it later';
    lives_ok { $prolog->results }
        'retract predicates should have a correct IR';
}
__END__
        {is $prolog->results, 'down', '... and the command should be issued successfully.';
#$prolog->query('i_am_at(X)');
#is $prolog->results, 'i_am_at(bottom)', '... and it should tell us we are in the bed';
