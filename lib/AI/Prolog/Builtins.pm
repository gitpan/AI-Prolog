package AI::Prolog::Builtins;
$REVISION = '$Id: Prolog.pm,v 1.4 2005/01/29 16:44:47 ovid Exp $';
$VERSION  = '0.01';

1;
__END__

=head1 NAME

AI::Prolog::Builtins - Builtin predicates that AI::Prolog supports

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
                 | if(Term , Term , Term) | or(Term , Term ) 
                 | not(Term) | call(Term) | once(Term)
 Number    ::= Digit | Digit Number
 Digit     ::= 0 | ... | 9
 AtomName  ::= LowerCase NameChars
 Variable  ::= UpperCase NameChars
 NameChars ::= NameChar | NameChar NameChars
 NameChar  ::= a | ... | z | A | ... | Z | Digit

=head2 Comments

Comments begin with a C<%> and terminate at the end of the line or begin with
C</*> and terminate with C<*/>. 

=head2 Variables

As in Prolog, all variables begin with an upper-case letter and are not quoted.
In the following example, C<STUFF> is a variable.

 steals(badguy, STUFF, "Some rich person").

=head2 Constants

Constants begin with lower-case letters.  If you need a constant that begins
with an upper-case letter or contains spaces or other non-alphanumeric
characters, enclose the constant in single or double quotes  The quotes will
not be included in the constant.

In the following example, C<badguy> and C<Some rich person> are both constants:

 steals(badguy, STUFF, "Some rich person").

=head2 Miscellaneous

This will not work:

 p(X) :- X. /* does not work */

Use this instead:

 p(X) :- call(X).

=head1 BUILTINS

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

 once(X) :- X, !;

=item * C<or(X, Y)>

Succeeds as a goal if either C<X> or C<Y> succeeds.

=item * C<print(Term)>.

Prints the current Term.  If the term is an unbound variable, it will print the
an underscore followed by the internal variable number (e.g., "_284").

 print(ovid).         % prints "ovid"
 print("Something").  % prints "Something"
 print(Something).    % prints whatever variable Something is bound to 

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

There are some bugs with printing and escaping characters.  Maybe I'll look
into them :)

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

=back

=head1 BUGS

I'm sure there are bugs.  I don't know of any right now.  Let me know if (when)
you find them.  See the TODO list before that, though.

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
