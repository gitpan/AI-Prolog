package AI::Prolog;
$REVISION = '$Id: Prolog.pm,v 1.6 2005/02/13 21:01:02 ovid Exp $';
$VERSION  = '0.5';

use Exporter::Tidy
    shortcuts => [qw/Parser Term Engine/];

use aliased 'AI::Prolog::Parser';
use aliased 'AI::Prolog::Term';
use aliased 'AI::Prolog::Engine';

# they don't want pretty printed strings if they're using this interface
Engine->formatted(0);

sub new {
    my ($class, $program) = @_;
    my $self = bless {
        _prog      => Parser->consult($program),
        _query     => undef,
        _engine    => undef,
    } => $class;
    return $self;
}

sub do {
    my ($self, $query) = @_;
    $self->query($query);
    1 while $self->results;
    $self;
}

sub query {
    my ($self, $query) = @_;
    # make that final period optional
    $query .= '.' unless $query =~ /\.$/;
    $self->{_query} = Term->new($query);
    unless (defined $self->{_engine}) {
        # prime the pump
        $self->{_engine} = Engine->new(@{$self}{qw/_query _prog/});
    }
    $self->{_engine}->query($self->{_query});
    return $self;
}

sub results { 
    my $self = shift;
    unless (defined $self->{_query}) {
        require Carp;
        Carp::croak "You can't fetch results because you have not set a query";
    }
    $self->{_engine}->results;
}

sub trace {
    my $class = shift;
    if (@_) {
        Engine->trace(shift);
        return $class;
    }
    return Engine->trace;
}

sub raw_results {
    my $class = shift;
    if (@_) {
        Engine->raw_results(shift);
        return $class;
    }
    return Engine->raw_results;
}

1;

__END__

=head1 NAME

AI::Prolog - Perl extension for logic programming.

=head1 SYNOPSIS

 use AI::Prolog;
 use Data::Dumper;

 my $database = <<'END_PROLOG';
 append([], X, X).
 append([W|X],Y,[W|Z]) :- append(X,Y,Z).
 END_PROLOG

 my $logic = AI::Prolog->new($database);
 $logic->query('append(X,Y,[a,b,c,d])');
 while (my $result = $logic->results) {
     print Dumper($result->X);
     print Dumper($result->Y);
 }

=head1 ABSTRACT

 AI::Prolog is merely a convenient wrapper for a pure Perl Prolog compiler.
 Regrettably, at the current time, this requires you to know Prolog.  That will
 change in the future.

=head1 EXECUTIVE SUMMARY

In Perl, we traditionally tell the language how to find a solution.  In logic
programming, we describe what a solution would look like and let the language
find it for us.

=head1 QUICKSTART

For those who like to just dive right in, this distribution contains a simple
Prolog shell called C<aiprolog> and a short adventure game called C<spider.pro>.

See the C<bin/> and C<data/> directories in the distribution.

=head1 DESCRIPTION

C<AI::Prolog> is a pure Perl predicate logic engine.  In predicate logic,
instead of telling the computer how to do something, you tell the computer what
something is and let it figure out how to do it.  Conceptually this is similar
to regular expressions.

 my @matches = $string =~ /XX(YY?)ZZ/g

If the string contains data that will satisfy the pattern, C<@matches> will
contain a bunch of "YY" and "Y"s.  Note that you're not telling the program how
to find those matches.  Instead, you supply it with a pattern and it goes off
and does its thing.

To learn more about Prolog, see Roman BartE<225>k's "Guide to Prolog
Programming" at L<http://kti.ms.mff.cuni.cz/~bartak/prolog/index.html>.
Amongst other things, his course uses the Java applet that C<AI::Prolog> was
ported from, so his examples will generally work with this module.

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

=head2 Creating a logic program

This module is actually remarkable easy to use.  To create a Prolog program,
you simply pass the Prolog code as a string to the constructor:

 my $prolog = AI::Prolog->new(<<'END_PROLOG');
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

Side note:  in Prolog, programs are often referred to as databases.

=head2 Creating a query

To create a query for the database, use C<query>.

  $prolog->query("steals(badguy,X)");

=head2 Running a query

Call the C<results> method and inspect the C<results> object:

  while (my $result = $prolog->results) {
      printf "badguy steals %s\n", $results->X;
  }

=head1 GRAMMAR

See L<AI::Prolog::Builtins|AI::Prolog::Builtins> for the grammar and built in
predicates.

=head1 CLASS METHODS

=head2 C<new($program)>

This is the constructor.  It takes a string representing a Prolog program:

 my $prolog = AI::Prolog->new($program_text);

See L<AI::Prolog::Builtins|AI::Prolog::Builtins> and the C<examples/> directory
included with this distribution for more details on the program text.

Returns an C<AI::Prolog> object.

=head2 C<trace([$boolean])>

One can "trace" the program execution by setting this property to a true value
before fetching engine results:

 AI::Prolog->trace(1);
 while (my $result = $engine->results) {
     # do something with results
 }

This sends trace information to C<STDOUT> and allows you to see how the engine
is trying to satify your goals.  Naturally, this slows things down quite a bit.

Calling C<trace> without an argument returns the current C<trace> value.

=head2 C<raw_results([$boolean])>

Ordinarily, the object returned by C<query> will provide methods to allow you
to access the data the variables are bound to.  However, this is not always
sufficient.  You can get access to the full, raw results by setting
C<raw_results> to true.  In this mode, the results are returned as an array
reference with the functor as the first element and an additional element for
each term.  Lists are represented as array references.

 AI::Prolog->raw_results(1);
 $prolog->query('steals(badguy, STUFF, VICTIM)');
 while (my $r = $prolog->results) {
     # do stuff with $r in the form:
     # ['steals', 'badguy', $STUFF, $VICTIM]
 }

Calling C<raw_results> without an argument returns the current C<raw_results>
value.

=head1 INSTANCE METHODS

=head2 C<do($query_string)>

This method is useful when you wish to combine the C<query()> and C<results()>
methods but don't care about the results returned.  Most often used with the
C<assert(X)> and C<retract(X)> predicates.

 $prolog->do('assert(loves(ovid,perl))');

This is a shorthand for:

 $prolog->query('assert(loves(ovid,perl))');
 1 while $prolog->results;

This is important because the C<query()> method merely builds the query.  Not
until the C<results()> method is called is the command actually executed.

=head2 C<query($query_string)>

After instantiating an C<AI::Prolog> object, use this method to query it.
Queries currently take the form of a valid prolog query but the final period
is optional:

 $prolog->query('grandfather(Ancestor, julie)');

This method returns C<$self>.

=head2 C<results>

After a query has been issued, this method will return results satisfying the
query.  When no more results are available, this method returns C<undef>.

 while (my $result = $prolog->results) {
     printf "%s is a grandfather of julie.\n", $result->Ancestor;
 }

If C<raw_results> is false (this is the default behavior), the return value
will be a "result" object with methods corresponding to the variables.  This is
currently implemented as a L<Hash::AsObject|Hash::AsObject> so the caveats with
that module apply.

 $logic->query('steals("Bad guy", STUFF, VICTIM)');
 while (my $r = $logic->results) {
     print "Bad guy steals %s from %s\n", $r->STUFF, $r->VICTIM;
 }

See C<raw_results> for an alternate way of generating output.

=head1 BUGS

A query using C<[HEAD|TAIL]> syntax does not bind properly with the C<TAIL>
variable when returning a result object.  You will need to restructure your
query to avoid this syntax or set C<raw_results> to true and parse the results
yourself.

See L<AI::Prolog::Builtins|AI::Prolog::Builtins> and
L<AI::Prolog::Engine|AI::Prolog::Engine> for known bugs and limitations.  Let
me know if (when) you find them.  See the built-ins TODO list before that,
though.

=head1 EXPORT

None by default.  However, for convenience, you can choose ":all" functions to
be exported.  That will provide you with C<Term>, C<Parser>, and C<Engine>
classes.  This is not recommended and most support and documentation will now
target the C<AI::Prolog> interface.

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

=head1 SEE ALSO

L<AI::Prolog::Introduction>

L<AI::Prolog::Builtins>

W-Prolog:  L<http://goanna.cs.rmit.edu.au/~winikoff/wp/>

X-Prolog:  L<http://www.iro.umontreal.ca/~vaucher/XProlog/>

Roman BartE<225>k's online guide to programming Prolog:
L<http://kti.ms.mff.cuni.cz/~bartak/prolog/index.html>

=head1 AUTHOR

Curtis "Ovid" Poe, E<lt>moc tod oohay ta eop_divo_sitrucE<gt>

Reverse the name to email me.

This work is based on W-Prolog, L<http://goanna.cs.rmit.edu.au/~winikoff/wp/>,
by Dr. Michael Winikoff.  Many thanks to Dr. Winikoff for granting me
permission to port this.

Many features also borrowed from X-Prolog L<http://www.iro.umontreal.ca/~vaucher/XProlog/>
with Dr. Jean Vaucher's permission.

=head1 COPYRIGHT AND LICENSE

Copyright 2005 by Curtis "Ovid" Poe

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
