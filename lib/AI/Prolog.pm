package AI::Prolog;
$REVISION = '$Id: Prolog.pm,v 1.2 2005/01/23 20:23:14 ovid Exp $';
$VERSION  = '0.02';

use Exporter::Tidy
    shortcuts => [qw/Parser Term Engine/];

use aliased 'AI::Prolog::Parser';
use aliased 'AI::Prolog::Term';
use aliased 'AI::Prolog::Engine';

1;
__END__

=head1 NAME

AI::Prolog - Perl extension for logic programming.

=head1 SYNOPSIS

 use AI::Prolog ':all';
 my $database = Parser->consult(<<'END_PROLOG');
 append([], X, X).
 append([W|X],Y,[W|Z]) :- append(X,Y,Z).
 END_PROLOG

 my $query  = Term->new("append(X,Y,[a,b,c,d]).");
 my $engine = Engine->new($query,$database);

 print "Which lists append to form a known list?\n";
 print "'append(X,Y,[a,b,c,d]).'\n";
 while (my $result = $engine->results) {
     print "$result\n";
 }

=head1 ABSTRACT

 AI::Prolog is merely a convenient wrapper for a pure Perl Prolog compiler.
 Regrettably, at the current time, this requires you to know Prolog.  That
 will change in the future.

=head1 DESCRIPTION

A pure Perl predicate logic engine.

In predicate logic, instead of telling the computer how to do something, you
tell the computer what something is and let it figure out how to do it.
Conceptually this is similar to regexes:

 my @matches = $string =~ /XX(YY?)ZZ/g

If the string contains data that will satisfy the pattern, C<@matches> will
contain a bunch of "YY" and "Y"s.  Note that you're not telling the program
how to find those matches.  Instead, you supply it with a pattern and it goes
off and does its thing.

To learn more about Prolog, see Roman BartE<225>k's "Guide to Prolog Programming."
http://kti.ms.mff.cuni.cz/~bartak/prolog/index.html.  Amongst other things, 
his course uses the Java applet that C<AI::Prolog> was ported from, so his
examples will generally work with this module.

Fortunately, Prolog is fairly easy to learn.  Mastering it, on the other hand,
can be a challenge.

=head1 USING AI::Prolog

There are three basic steps to using C<AI::Prolog>.

=over 4

=item Create the Prolog program.

=item Create a query.

=item Run the query.

=back

For quick examples of how that works, see the C<examples/> directory with this
distribution.  Feel free to contribute more.

=head2 Creating a Prolog program

This module is actually remarkable easy to use.  To create a Prolog program,
you simply C<Parser-E<gt>consult($prolog_code)>.  Note that in Prolog, the
result is what is known as a database.

 my $database = Parser->consult(<<'END_PROLOG');
    steals(PERP, STUFF) :-
        thief(PERP),
        valuable(STUFF),
        owns(VICTIM,STUFF),
        not(knows(PERP,VICTIM)).
    thief(badguy).
    valuable(gold).
    valuable(rubies).
    owns(merlyn,gold).
    owns(ovid,rubies).
    knows(badguy,merlyn).
 END_PROLOG

=head2 Creating a query

To create a query for the database, use C<Term>.

  my $query = Term->new("steals(badguy,X).");

=head2 Running a query

  my $engine = Engine->new($query, $database);
  while (my $result = $engine->results) {
      print "$result\n";
  }

=head1 RATIONALE

You can skip this if you already know logic programming.

In Perl, generally you can append one list to another with this:

 my @Z = (@X, @Y);

In Prolog, it looks like this:

 append([], X, X).
 append([W|X],Y,[W|Z]) :- append(X,Y,Z).

(There's actually often something called a "cut" after the first definition,
but we'll keep this simple.)

What the above code says is "appending an empty list to a non-empty list yields
the non-empty list." This is a boundary condition. Logic programs frequently
require a careful analysis of boundary conditions to avoid infinite loops
(similar to how recursive functions in Perl generally should have a terminating
condition defined in them.)

The second line is where the bulk of the work gets done. In Prolog, to identify
the head (first element) of a list and its tail (all elements except the
first), we use the syntax [head|tail]. Since ":-" is read as "if" in Prolog,
what this says if we want to concatenate (a,b,c) and (d,e,f):

=over 4

=item * Given a list with a head of W and a tail of X:

 @list1 = qw/a b c/; (qw/a/ is W, the head, and qw/b c/ is X, the tail)

=item * If it's appended to list Y:

 @Y = qw/d e f/;

=item * We get a list with a head of W and a tail of Z:

 @list2 = qw/a b c d e f/;

=item * Only if X appended to Y forms Z:

 X is qw/b c/. Y is qw/d e f/. Z is qw/b c d e f/.

=back

But how do we know if X appended to Y forms Z? Well, it's recursive. You see,
the head of X is 'b' and it's tail is 'c'. Let's follow the transformations:

 append([a,b,c],[d,e,f],[a,b,c,d,e,f])
  if append([b,c],[d,e,f],[b,c,d,e,f])
  if append([c],[d,e,f],[c,d,e,f])
  if append([],[d,e,f],[d,e,f])

As you can see, the last line matches our boundary condition, so the program
can determine what the concatenation is.

Now that may seem confusing at first, but so was the Schwartzian transform when
many of us encountered it. After a while, it becomes natural. Sit down and work
it out and you'll see what's going one.

So what does this give us? Well, we can now append lists X and Y to form Z:

 append([a], [b,c,d], Z).

Given Y and Z, we can infer X.

 append(X, [b,c,d], [a,b,c,d]).

And finally, given Z, we can infer all X and Y that combine to form Z (again,
like the regular expression, only easier).

 append(X,Y,[a,b,c,d]).

Note that you get all of that from one definition of how to append two lists.
You also don't have to tell the program how to do it. It just figures it out
for you.

Translating all of this into C<AI::Prolog> looks like this:

 use AI::Prolog qw/:all/;
 my $database = Parser->consult(<<'END_PROLOG');
 append([], X, X).
 append([W|X],Y,[W|Z]) :- append(X,Y,Z).
 END_PROLOG

 my $query  = Term->new("append(X,Y,[a,b,c,d]).");
 my $engine = Engine->new($query,$database);
 while (my $result = $engine->results) {
     print "$result\n";
 }

=head1 GRAMMAR

The language is given by the following simple grammar (pulled directly from Dr.
Winikoff's page):

 Program   ::= Rule | Rule Program
 Query     ::= Term

 Rule      ::= Term . | Term :- Terms .
 Terms     ::= Term   | Term , Terms
 Term      ::= Number | Variable | AtomName | AtomName(Terms)
                 | [] | [Terms] | [Terms | Term]
                 | print(Term) | nl | eq(Term , Term)
                 | if(Term , Term , Term) | or(Term , Term ) | not(Term) | call(Term) | once(Term)
 Number    ::= Digit | Digit Number
 Digit     ::= 0 | ... | 9
 AtomName  ::= LowerCase NameChars
 Variable  ::= UpperCase NameChars
 NameChars ::= NameChar | NameChar NameChars
 NameChar  ::= a | ... | z | A | ... | Z | Digit

Comments begin with a C<%> and terminate at the end of the line or begin with
C</*> and terminate with C<*/>. 

Also, this will not work:

 p(X) :- X. /* does not work */

Use this instead:

 p(X) :- call(X).

=head2 Built-ins.

=over 4

=item * C<call(X)>.

Invokes C<X> as a goal.

=item * C<eq(X, Y).>

Succeeds if C<X> and C<Y> are equal.

=item * C<if(X, Y, Z).>

If C<X> succeeds as a goal, try C<Y> as a goal.  Otherwise, try C<Z>.

 thief(badguy).
 steals(PERP, X) :-
   if(thief(PERP), eq(X,rubies), eq(X,nothing)).

=item * C<nl>

Prints a newline.

=item * C<not(X)>.

Succeeds if C<X> cannot be proven.  This is not negation as we're used to
seeing it in procedural languages.

=item * C<once(X)>

Stop solving for C<X> if C<X> succeeds.  Defined as:

 once(X) :-
   X, !;

=item * C<or(X, Y)>

Succeeds as a goal if either C<X> or C<Y> succeeds.

=item * C<print(Term)>.

Prints the current Term.

=back

=head1 LIMITATIONS

These are known limitations that I am not terribly inclined to fix.  See the
TODO list for those I am inclined to fix.

 IF -> THEN; ELSE not allowed.

Use C<if(IF, THEN, ELSE)> instead.

 = and \= not available.

Use C<eq(X,Y)> and C<not(eq(X,Y))> instead.

=head1 TODO

There are many things on this list.  The core functionality is there, but I do
want you to be aware of what's coming.

=over *

=item * Anonymous variables

 steals(badguy, _).

Currently, that doesn't work.  Make up a variable name and only use it once.

=item * Improve printing.

 print(X).

Currently, you can print variables, but to print strings is cumbersome:

 print(some_data), print(X).

This will print some_data and the current value of X (or an internal
representation of its state if its not bound to a variable.)  There is no way
to print a space.

=item * Math.

Math is hard.  So we don't have it, but we will and we'll probably have it in
the form of system predicates that call out to Perl.  We can define most of
what we need logically, but it's very slow and complicated, so we won't do
that.

=item * Database access

No, we're not talking DBI.  We're talking about C<clause>, C<assert> and
C<retract>.  We don't have that yet.

=item * Add cut.

Currently, we can use C<once(X)> to simulate it.  Think of this predicate as
being equivalent to:

 once(X) :- X, !;

Frankly, I'm not overly worried about this but feel free to convince me I'm
wrong (preferably with a patch :).

=back

Additionally, one can "trace" the program execution by setting this property
to a true value before fetching engine results:

 Engine->trace(1);
 while (my $result = $engine->results) {
     print "$result\n";
 }

This sends trace information to C<STDOUT> and allows you to see how the engine
is trying to satify your goals.  Naturally, this slows things down quite a bit.

=head1 BUGS

I'm sure there are bugs.  I don't know of any right now.  Let me know if (when)
you find them.  See the TODO list before that, though.

=head1 EXPORT

None by default.  However, for convenience, it's recommended that you choose
":all" functions to be exported.  That will provide you with C<Term>, C<Parser>,
and C<Engine>.

If you choose not to export the functions, you may use the fully qualified
package names instead:

 use AI::Prolog;
 my $database = AI::Prolog::Parser->consult(<<'END_PROLOG');
 append([], X, X).
 append([W|X],Y,[W|Z]) :- append(X,Y,Z).
 END_PROLOG

 my $query  = AI::Prolog::Term->new("append(X,Y,[a,b,c,d]).");
 my $engine = AI::Prolog::Engine->new($query,$database);
 while (my $result = $engine->results) {
     print "$result\n";
 }
 
I have no idea why you would want to do this :)

=head1 SEE ALSO

W-Prolog:  L<http://goanna.cs.rmit.edu.au/~winikoff/wp/>

Michael BartE<225>k's online guide to programming Prolog:
L<http://kti.ms.mff.cuni.cz/~bartak/prolog/index.html>

=head1 AUTHOR

Curtis "Ovid" Poe, E<lt>moc tod oohay ta eop_divo_sitrucE<gt>

Reverse the name to email me.

This work is based on W-Prolog, http://goanna.cs.rmit.edu.au/~winikoff/wp/,
by Dr. Michael Winikoff.  Many thanks to Dr. Winikoff for granting me
permission to port this.

=head1 COPYRIGHT AND LICENSE

Copyright 2005 by Curtis "Ovid" Poe

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
