package AI::Prolog::Engine;

$VERSION = '0.01';
use strict;
use warnings;

use Time::HiRes qw/gettimeofday/;

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
    my ($self, $trace) = @_;
    $TRACE = $trace if defined $trace;
    return $TRACE;
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

sub _stack    { shift->{_stack}    }
sub _db       { shift->{_db}       }
sub _goal     { shift->{_goal}     }
sub _call     { shift->{_call}     }
sub _failgoal { shift->{_failgoal} }

sub dump {
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
            # here's where we set the time
            return $self->_call->to_string;
            #$self->more;
        }
        
        unless (defined $self->_goal && $self->{_goal}->term) {
            require Carp;
            Carp::croak("Engine->run fatal error.  goal->term is null!");
        }
        my $func  = $self->{_goal}->term->getfunctor;
        my $arity = $self->{_goal}->term->getarity;
        $self->dump($clausenum);

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
            print $self->{_goal}->term->getarg(0)->to_string;
            $self->{_goal} = $self->{_goal}->next;
        }
        elsif ('_nl' eq $func && ! $arity) {
            print "\n";
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

1;

__END__

=head1 NAME

AI::Prolog::End - Run queries against a Prolog database.

=head1 SYNOPSIS

 my $engine = AI::Prolog::Engine->new($query, $database).
 while (my $results = $engine->results) {
     print "$result\n";
 }

=head1 DESCRIPTION

See L<AI::Prolog|AI::Prolog> for more information.  If you must know more,
there are plenty of comments sprinkled through the code.

If you look through the code, you will notice that it's appears to be
based on the Warren Abstract Machine (WAM).  This is pretty much a standard
definition of a Prolog compiler.

The C<new()> function actually bootstraps some Prolog code onto your program to
give you access to the built in predicates listed in the
L<AI::Prolog|AI::Prolog> documentation.
