package AI::Prolog::Engine;
$REVISION = '$Id: Engine.pm,v 1.4 2005/01/29 16:44:47 ovid Exp $';
$VERSION = '0.02';
use strict;
use warnings;

use Clone qw/clone/;

use aliased 'AI::Prolog::Term';
use aliased 'AI::Prolog::TermList';
use aliased 'AI::Prolog::Parser';
use aliased 'AI::Prolog::ChoicePoint';

use constant OnceMark => 'OnceMark';

# The engine is what executes prolog queries.
# Author emeritus:  Dr. Michael Winikoff
# Translation to Perl:  Curtis "Ovid" Poe

# $prog An initial program - this will be extended
# $term The query to be executed

# This governs whether tracing is done
my $TRACE;
sub trace {
    my $class = shift;
    if (@_) {
        $TRACE = shift;
        return $class;
    }
    return $TRACE;
}

my $FORMATTED = 1;
sub formatted {
    my $self = shift;
    if (@_) {
        $FORMATTED = shift;
        return $self;
    }
    return $FORMATTED;
}

my $RAW_RESULTS;
sub raw_results {
    my $self = shift;
    if (@_) {
        $RAW_RESULTS = shift;
        if ($RAW_RESULTS) {
            $self->formatted(0);
        }
        return $self;
    }
    return $RAW_RESULTS;
}

sub new {
    my ($class, $term, $prog) = @_;
    Term->internalparse(1); # enable underscore as first character of term
    my $self = bless {
        # The stack holds choicepoints and a list of variables
        # which need to be un-bound upon backtracking.
	    _stack     => [],
        # We use a hash to store the program
        _db        => {}, 
        _goal      => TermList->new($term,undef), # TermList
	    _call      => $term, # Term
        # Used to time how long queries take
    	time      => undef,
        # A bookmark to the fail predicate
	    _failgoal  => undef, # TermList
        _run_called => undef,
    } => $class;

    eval {
        $self->{_db} = Parser->consult(<<'        END_PROG', $prog);
            eq(X,X).
            fail :- eq(c,d). 
            print(X) :- _print(X).
            if(X,Y,Z) :- once(wprologtest(X,R)) , wprologcase(R,Y,Z).
            wprologtest(X,yes) :- call(X). wprologtest(X,no). 
            wprologcase(yes,X,Y) :- call(X). 
            wprologcase(no,X,Y) :- call(Y).
            not(X) :- if(X,fail,true). 
            or(X,Y) :- call(X).
            or(X,Y) :- call(Y).
            true. 
            call(X) :- _call(X). 
            nl :- _nl. 
            once(X) :- _onceenter , call(X) , _onceleave.
        END_PROG
        Parser->resolve($self->{_db});
    };
    if ($@) {
        require Carp;
        Carp::croak("Engine->new failed.  Cannot parse default program: $@");
    }
    Term->internalparse(0);
    $self->{_goal}->resolve($self->{_db});
    $self->{_failgoal} = TermList->new(Term->new("fail",0), undef);
    $self->{_failgoal}->resolve($self->{_db});
    return $self;
}

sub query {
    my ($self, $query)   = @_;
    $self->{_stack}      = [];
    $self->{_run_called} = undef;
    $self->{_goal}       = TermList->new($query, undef);
    $self->{_call}       = $query;
    Term->internalparse(0);
    $self->{_goal}->resolve($self->{_db});
    $self->{_failgoal}   = TermList->new(Term->new("fail",0), undef);
    $self->{_failgoal}->resolve($self->{_db});
    return $self;
}

sub _stack    { shift->{_stack}    }
sub _db       { shift->{_db}       }
sub _goal     { shift->{_goal}     }
sub _call     { shift->{_call}     }
sub _failgoal { shift->{_failgoal} }

sub _dump {
    my ($self, $clausenum) = @_;
    if ($self->trace) {
        warn "Goal: " . $self->{_goal}->to_string . " clausenum = $clausenum\n";
    }
}

# adds fail to the goal and lets the engine do the rest
#sub more {shift->results};

sub results {
    my $self = shift;
    if ($self->{_run_called}) {
        $self->{_goal} = TermList->new(Term->new("fail",0), $self->{_goal});
        $self->{_goal}->resolve($self->{_db});
        $self->{_run_called} = 1;
    }
    _run($self);
}

# this does the actual work
sub _run {
    my ($self) = @_;
    $self->{_run_called} = 1;
    my $found; # boolean
    my $func;  # string
    my ($arity, $clausenum); # ints
    my ($clause, $nextclause, $ts1, $ts2); # TermLists
    my ($t);   # Term
    my $o;     # Object
    my $cp;    # ChoicePoint
    my $vars;  # Term[]

    $clausenum = 1;


    while (1) {
        unless ($self->{_goal}) {
            # we've succeeded.  return results
            if ($self->formatted) {
                return $self->_call->to_string;
            }
            else {
                my @results = $self->_call->to_data;
                return $self->raw_results
                    ? $results[1]
                    : $results[0];
            }
        }
        
        unless (defined $self->_goal && $self->{_goal}->term) {
            require Carp;
            Carp::croak("Engine->run fatal error.  goal->term is null!");
        }
        my $func  = $self->{_goal}->term->getfunctor;
        my $arity = $self->{_goal}->term->getarity;
        $self->_dump($clausenum);

        # if the goal is not a system predicate
        unless ('_' eq substr $func => 0, 1) {
            # if there is an alternative clause, push choicepoint
            if ($self->{_goal}->numclauses > $clausenum) {
                push @{$self->{_stack}} => ChoicePoint->new($clausenum + 1, $self->_goal);
            }
            if ($clausenum > $self->{_goal}->numclauses) {
                $clause = $self->_failgoal;
                warn "$func/$arity undefined!";
                $clause = TermList->new(Term->new("fail", 0), $self->_goal);
                $clause->resolve($self->_db);
            }
            else {
                $clause = $self->_goal->{definer}[$clausenum];
            }

            $clausenum = 1; # reset
            # check unification
            $vars = [];
            if ($clause->term->refresh($vars)->unify($self->_goal->term, $self->{_stack})) {
                $clause = $clause->next;

                # refresh clause -- need to also copy definer
                if ($clause) {
                    $ts1 = TermList->new($clause->term->refresh($vars), undef, $clause);
                    $ts2 = $ts1; # XXX should this be a clone?
                    $clause = $clause->next;

                    while ($clause) {
                        $ts1->{next} = TermList->new($clause->term->refresh($vars), undef, $clause);
                        $ts1 = $ts1->next;
                        $clause = $clause->next;
                    }

                    # splice together refreshed clause and other goals
                    $ts1->{next} = $self->{_goal}->next;
                    $self->{_goal} = $ts2; # XXX again, I think maybe $ts2 should be cloaned

                    # XXX for gc purposes, drop references to data that are not needed
                    undef $t; undef $ts1; undef $ts2; $vars = [];
                    undef $clause; undef $nextclause; undef $func;
                }
                else { # matching against fact
                    $self->{_goal} = $self->_goal->next;
                }
            }
            else { # unification failed.   Backtrack.
                $self->{_goal} = $self->_goal->next;
                $found = 0;
                BACKTRACK: {
                    while (@{$self->{_stack}}) {
                        my $o = pop @{$self->{_stack}};

                        if ($o->isa(Term)) {
                            $t = $o;
                            $t->unbind;
                        }
                        elsif ($o->isa(ChoicePoint)) {
                            $cp = $o;
                            $self->{_goal} = $cp->goal;
                            $clausenum = $cp->clausenum;
                            $found = 1;
                            last BACKTRACK;
                        } # elsif integer, iterative deepening
                        # not implemented yet
                    }
                } # end BACKTRACK

                # stack is empty.  We have not found a choice point.
                # this means we have failed.

                return unless $found;
            }
        }
        # looks like it's a system predicate
        elsif ('_print' eq $func && 1 == $arity) {
            _print($self->{_goal}->term->getarg(0)->to_string);
            $self->{_goal} = $self->{_goal}->next;
        }
        elsif ('_nl' eq $func && ! $arity) {
            _print("\n");
            $self->{_goal} = $self->_goal->next;
        }
        elsif ('_call' eq $func && 1 == $arity) {
            my $templist = TermList->new($self->_goal->term->getarg(0), undef);
            $templist->resolve($self->{_db});
            $templist->{next} = $self->_goal->next;
            $self->{_goal} = $templist;
        }
        # the next two together implement once/1
        elsif ('_onceenter' eq $func && ! $arity) {
            push @{$self->{_stack}} => bless {} => 'OnceMark';
            $self->{_goal} = $self->_goal->next;
        }
        elsif ('_onceleave' eq $func && ! $arity) {
            # find mark, remove it, and all choicepoints above it
            my @tempstack;
            my $o = pop @{$self->{_stack}};
            while (! UNIVERSAL::isa($o, 'OnceMark')) {
                # forget choicepoints
                if (! $o->isa(ChoicePoint)) {
                    push @tempstack => $o;
                }
                $o = pop @{$self->{_stack}};
            }

            while (@tempstack) {
                push @{$self->{_stack}} => pop @tempstack;
            }
            $self->{_goal} = $self->_goal->next;
        }
        else {
            warn "Unknown builtin: $func/$arity";
            $self->{_goal} = $self->_goal->next;
        }
    }       
}

sub _print { # convenient testing hook
    print @_;
}

1;

__END__

=head1 NAME

AI::Prolog::Engine - Run queries against a Prolog database.

=head1 SYNOPSIS

 my $engine = AI::Prolog::Engine->new($query, $database).
 while (my $results = $engine->results) {
     print "$result\n";
 }

=head1 DESCRIPTION

C<AI::Prolog::Engine> is a Warren Abstract Machine (WAM) based Prolog engine.

The C<new()> function actually bootstraps some Prolog code onto your program to
give you access to the built in predicates listed in the
L<AI::Prolog::Builtins|AI::Prolog::Builtins> documentation.

This documentation is provided for completeness.  You probably want to use
L<AI::Prolog|AI::Prolog>.

=head1 CLASS METHODS

=head2 C<new($query, $database)>

This creates a new Prolog engine.  The first argument must be of type
C<AI::Prolog::Term> and the second must be a database created by
C<AI::Prolog::Parser::consult>.

 my $database = Parser->consult($some_prolog_program);
 my $query    = Term->new('steals(badguy, X).');
 my $engine   = Engine->new($query, $database);
 Engine->formatted(1);
 while (my $results = $engine->results) {
    print $results, $/;
 }

The need to have a query at the same time you're instantiating the engine is a
bit of a drawback based upon the original W-Prolog work.  I will likely remove
this drawback in the future.

=head2 C<formatted([$boolean])>

The default value of C<formatted> is true.  This method, if passed a true
value, will cause C<results> to return a nicely formatted string representing
the output of the program.  This string will loosely correspond with the
expected output of a Prolog program.

If false, all calls to C<result> will return Perl data structures instead of
nicely formatted output.

If called with no arguments, this method returns the current C<formatted>
value.

 Engine->formatted(1); # turn on formatting
 Engine->formatted(0); # turn off formatting (default)
 
 if (Engine->formatted) {
     # test if formatting is enabled
 }

B<Note>: if you choose to use the L<AI::Prolog|AI::Prolog> interface instead of
interacting directly with this class, that interface will set C<formatted> to
false.  You will have to set it back in your code if you do not wish this
behavior:

 use AI::Prolog;
 my $logic = AI::Prolog->new($prog_text);
 $logic->query($query_text);
 AI::Logic::Engine->formatted(1); # if you want formatted to true
 while (my $results = $logic->results) {
    print "$results\n";
 }

=head2 C<raw_results([$boolean])>

The default value of C<raw_results> is false.  Setting this property to a true
value automatically sets C<formatted> to false.  C<results> will return the raw
data structures generated by questions when this property is true.
 
 Engine->raw_results(1); # turn on raw results
 Engine->raw_results(0); # turn off raw results (default)
 
 if (Engine->raw_results) {
     # test if raw results is enabled
 }

=head2 C<trace($boolean)>

Set this to a true value to turn on tracing.  This will trace through the
engine's goal satisfaction process while it's running.  This is very slow.

 Engine->trace(1); # turn on tracing
 Engine->trace(0); # turn off tracing

=head1 INSTANCE METHODS

=head2 C<results()>

This method will return the results from the last run query, one result at a
time.  It will return false when there are no more results.  If C<formatted> is
true, it will return a string representation of those results:

 while (my $results = $engine->results) {
    print "$results\n";
 }

If C<formatted> is false, C<$results> will be an object with methods matching
the variables in the query.  Call those methods to access the variables:

 AI::Prolog::Engine->formatted(0);
 $engine->query('steals(badguy, STUFF, VICTIM).');
 while (my $r = $engine->results) {
     printf "badguy steals %s from %s\n", $r->STUFF, $r->VICTIM;
 }

If necessary, you can get access to the full, raw results by setting
C<raw_results> to true.  In this mode, the results are returned as an array
reference with the functor as the first element and an additional element for
each term.  Lists are represented as array references.

 AI::Prolog::Engine->raw_results(1);
 $engine->query('steals(badguy, STUFF, VICTIM).');
 while (my $r = $engine->results) {
    # do stuff with $r in the form:
    # ['steals', 'badguy', $STUFF, $VICTIM]
 }

=head2 C<query($query)>

If you already have an engine object instantiated, call the C<query()> method
for subsequent queries.  Internally, when calling C<new()>, the engine
bootstraps a set of Prolog predicates to provide the built ins.  However, this
process is slow.  Subsequent queries to the same engine with the C<query()>
method can double the speed of your program.
 
 my $engine   = Engine->new($query, $database);
 while (my $results = $engine->results) {
    print $results, $/;
 }
 $query = Term->new("steals(ovid, X).");
 $engine->query($query);
 while (my $results = $engine->results) {
    print $results, $/;
 }

=head1 BUGS

A query using C<[HEAD|TAIL]> syntax does not bind properly with the C<TAIL>
variable when returning a result object.  This is due to a bug in
L<AI::Prolog::Term|AI::Prolog::Term>'s C<_to_data()> method.

Solutions:  use C<raw_results> and parse the resulting data structure yourself
or restructure you query to not require the C<[HEAD|TAIL]> syntax.

=head1 AUTHOR

Curtis "Ovid" Poe, E<lt>moc tod oohay ta eop_divo_sitrucE<gt>

Reverse the name to email me.

This work is based on W-Prolog, http://goanna.cs.rmit.edu.au/~winikoff/wp/,
by Dr. Michael Winikoff.  Many thanks to Dr. Winikoff for granting me
permission to port this.

=head1 COPYRIGHT AND LICENSE

Copyright 2005 by Curtis "Ovid" Poe

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. 

=cut
