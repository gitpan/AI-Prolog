#!/usr/bin/perl
# '$Id: 40parser.t,v 1.1 2005/01/23 20:23:14 ovid Exp $';
use warnings;
use strict;
use Test::More tests => 56;
#use Test::More 'no_plan';
use Test::MockModule;

my $CLASS;
BEGIN
{
    chdir 't' if -d 't';
    unshift @INC => '../lib';
    $CLASS = 'AI::Prolog::Parser';
    use_ok($CLASS) or die;
}

# I hate the fact that they're interdependent.  That brings a 
# chicken and egg problem to squashing bugs.
use aliased 'AI::Prolog::TermList';
use aliased 'AI::Prolog::Term';

can_ok $CLASS, 'new';
ok my $parser = $CLASS->new('p(x)'), '...and calling new with a string should succeed';
isa_ok $parser, $CLASS, '... and the object it returns';

can_ok $parser, '_str';
is $parser->_str, 'p(x)', '... and it should return the string we created the parser with.';

can_ok $parser, '_posn';
is $parser->_posn, 0,
    '... and it should return the current position of where we are parsing the string';

can_ok $parser, '_start';
is $parser->_start, 0, '... and it should return the current starting point in the string';

can_ok $parser, '_varnum';
is $parser->_varnum, 0, '... and it should return the current variable number';

can_ok $parser, '_vardict';
is_deeply $parser->_vardict, {}, '... and it should be empty.';

can_ok $parser, 'to_string';
is $parser->to_string, '{ ^ p(x) | {} }',
    '... and it should show the parser string, the position in the string and an empty vardict';

$parser = $CLASS->new('   p(x)');
can_ok $parser, 'current';
is $parser->current, ' ', '... and it should return the current character the parser is pointing at';

can_ok $parser, 'advance';
$parser->advance;
is $parser->_posn, 1, '... and calling advance will move the parser forward one character';

can_ok $parser, 'skipspace';
$parser->skipspace;
is $parser->current, 'p', '... and calling skipspace will move the parser to the next non-whitespace character';
is $parser->_start, 0, '... and it will not change the starting position';
is $parser->_posn, 3, '... but the position will indicate the new position';

$parser = $CLASS->new('  /* comment */ p(x)');
$parser->skipspace;
is $parser->current, 'p', 
    'skipspace() should ignore multiline comments';
is $parser->_start, 0, '... and it will not change the starting position';
is $parser->_posn, 16, '... but the position will indicate the new position';

eval {$CLASS->new('/* this is an unterminated comment')->skipspace};
ok $@, 'skipspace() should die if it encounters a comment with no end';
like $@, qr{Expecting terminating '/' on comment},
    '... with an appropriate error message';

eval {$CLASS->new('/ * this is an unterminated comment')->skipspace};
ok $@, 'skipspace() should die if it encounters a poorly formed comment';
like $@, qr{Expecting '\*' after '/'},
    '... with an appropriate error message';

$parser = $CLASS->new(<<'END_PROLOG');
    % this is a comment
    flies(pig, 789).
END_PROLOG
$parser->skipspace;
is $parser->current, 'f', 
    'skipspace() should ignore single line comments';
is $parser->_start, 0, '... and it will not change the starting position';
is $parser->_posn, 28, '... but the position will indicate the new position';

can_ok $parser, 'getname';
is $parser->getname, 'flies', 
    '... and it should return the name  we are pointing at';
is $parser->current, '(',
    '... and the current character should be the first one after the name';
is $parser->_start, 28, '... and have the parser start at that name';
is $parser->_posn, 33, 
    '... and have the posn point to the first char after the name';

$parser->advance;   # skip '('
$parser->getname;   # skip 'flies'
$parser->advance;   # skip ','
$parser->skipspace; # you know what this does :)

can_ok $parser, 'getnum';
is $parser->getnum, 789, 
    '... and it should return the number the parser is pointing at';
is $parser->current, ')',
    '... and the parser should point to the current character';
is $parser->_start, 39, '... and the new starting point is where the number begins';
is $parser->_posn, 42, '... and the new posn is the first character after the number';

can_ok $parser, 'empty';
ok ! $parser->empty, '... and it should return false if there is more stuff to parse';
$parser->advance; # skip ')'
$parser->advance; # skip '.'
$parser->skipspace;
ok $parser->empty, '... and return true when there is nothing left to parse.  How sad.';

can_ok $parser, 'resolve';
my $termlist = Test::MockModule->new(TermList);
my $resolve = 0;
$termlist->mock('resolve', sub {$resolve++});
my %db = map { $_ => TermList->new } 1 .. 3;
$parser->resolve(\%db);
is $resolve, 3, '... and TermList->resolve should be called once for each termlist in the db';

can_ok $CLASS, 'consult';
my $db = $CLASS->consult(<<'END_PROLOG');
owns(merlyn, gold).
owns(ovid, rubies).
END_PROLOG
is ref $db, 'HASH', '... and it should return a database in the form of a hashref';
is keys %$db, 2, '... with one key for each term';
my @keys = sort keys %$db;
is_deeply \@keys, ['owns/2-1', 'owns/2-2'],
    '... and the keys should be in the form $functor/$arity-$clausenum';
my $tls = $db->{$keys[0]};
isa_ok $tls, TermList, '... and object the keys point to';
is $tls->to_string, '[owns(merlyn,gold)(0 clauses)]',
    '... and the termlist should show the correct term(s)';
$tls = $db->{$keys[1]};
is $tls->to_string, '[owns(ovid,rubies)(0 clauses)]',
    '... and the termlist should show the correct term(s)';
