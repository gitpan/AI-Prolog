package AI::Prolog::Term;

$VERSION = '0.01';
use strict;
use warnings;

use aliased 'AI::Prolog::Parser';

use constant NULL => 'null';

# Var is a type of term
# A term is a basic data structure in Prolog
# There are three types of terms:
#   1. Values     (i.e., have a functor and arguments)
#   2. Variables  (i.e., unbound)
#   3. References (bound to another variable)

my $VARNUM = 1;

# controls where occurcheck is used in unification.
# In early Java versions, the occurcheck was always performed
# which resulted in lower performance.

my $OCCURCHECK = 0;
sub occurcheck {
    my ($class, $value) = @_;
    $OCCURCHECK = $value if defined $value;
    return $OCCURCHECK;
}

# controls printing of lists as [a,b]
# instead of cons(a, cons(b, null))

sub prettyprint { 1 }

# controls whether predicates can beging with an underscore.
# Beginning a system with an underscore makes it inaccessible
# to the user.

my $INTERNALPARSE = 0;
sub internalparse { 
    my ($class, $value) = @_;
    $INTERNALPARSE = $value if defined $value;
    return $INTERNALPARSE;
}

sub new {
    my $proto = shift;
    my $class = CORE::ref $proto || $proto; # yes, I know what I'm doing
    return $class->_new_var unless @_;
    if (1 == @_) {
        my $arg = shift;
        return $class->_new_with_id($arg)     if ! CORE::ref $arg && $arg =~ /^[[:digit:]]+$/;
        return $class->_new_from_string($arg) if ! CORE::ref $arg;
        return $class->_new_from_parser($arg) if   CORE::ref $arg && $arg->isa(Parser);
    }
    return $class->_new_with_functor_and_arity(@_) if 2 == @_;
    require Carp;
    Carp::croak("Unknown arguments to Term->new");
}

sub _new_from_string {
    my ($class, $string) = @_;
    my $parsed = Parser->new($string);
    return $class->_new_from_parser($parsed);
}

sub _new_var {
    my $class = shift;
    bless {
        functor => undef,
        arity   => 0,
        args    => [],
        # if bound is false, $self is a reference to a free variable
        bound   => 0,
        varid   => $VARNUM++,
        # if bound and dered are both true, $self is a reference to a ref
        deref   => 0,
        ref     => undef,
    } => $class;
}

sub _new_with_id {
    my ($class, $id) = @_;
    bless {
        functor => undef,
        arity   => 0,
        args    => [],
        # if bound is false, $self is a reference to a free variable
        bound   => 0,
        varid   => $id,
        # if bound and dered are both true, $self is a reference to a ref
        deref   => 0,
        ref     => undef,
    } => $class;
}

sub _new_with_functor_and_arity {
    my ($class, $functor, $arity) = @_;
    bless {
        functor => $functor,
        arity   => $arity,
        args    => [],
        # if bound is false, $self is a reference to a free variable
        bound   => 1,
        varid   => undef, # XXX ??
        # if bound and deref are both true, $self is a reference to a ref
        deref   => 0,
        ref     => undef,
    } => $class;
}

sub varnum  { $VARNUM          } # class method
sub functor { shift->{functor} }
sub arity   { shift->{arity}   }
sub args    { shift->{args}    }
sub bound   { shift->{bound}   }
sub varid   { shift->{varid}   }
sub deref   { shift->{deref}   }
sub ref     { shift->{ref}     }

# bind a variable to a term
sub bind {
    my ($self, $term) = @_;
    return if $self eq $term;
    unless ($self->bound) {
        $self->{bound} = 1;
        $self->{deref} = 1;
        $self->{ref}   = $term;
    }
    else {
        require Carp;
        Carp::croak("AI::Prolog::Term->bind(".$self->to_string.").  Cannot bind to nonvar!");
    }
}

# unbinds a term -- i.e., resets it to a variable
sub unbind {
    my $self = shift;
    $self->{bound} = 0;
    $self->{ref}   = undef;
    # XXX Now possible for a bind to have had no effect so ignore safety test
    # XXX if (bound) bound = false;
    # XXX else IO.error("Term.unbind","Can't unbind var!");
}

# set specific arguments.  A primitive way of constructing terms is to
# create them with Term(s,f) and then build up the arguments.  Using the
# parser is much simpler
sub setarg {
    my ($self, $pos, $val) = @_;
    if ($self->bound && ! $self->deref) {
        $self->{args}[$pos] = $val;
    }
    else {
        require Carp;
        Carp::croak("AI::Prolog::Term->setarg($pos, ".$val->to_string.").  Cannot setarg on variables!");
    }
}

# retrievs an argument of a term
sub getarg {
    my ($self, $pos) = @_;
    # should check if position is valid
    if ($self->{bound}) {
        return $self->ref->getarg($pos) if $self->deref;
        return $self->{args}[$pos];
    }
    else {
        require Carp;
        Carp::croak("AI::Prolog::Term->getarg.  Error -- lookup on unbound term!");
    }
}

sub getfunctor {
    my $self = shift;
    return "" unless $self->bound;
    return $self->ref->getfunctor if $self->deref;
    return $self->functor;
}

sub getarity {
    my $self = shift;
    return 0 unless $self->bound;
    return $self->ref->getarity if $self->deref;
    return $self->arity;
}

# check whether a variable occurs in a term
# XXX Since a variable is not considered to occur in itself,
# XXX added occurs1 and a new front end called occurs()
sub occurs {
    my ($self, $var) = @_;
    return if $self->{varid} == $var;
    return $self->occurs1($var);
}

sub occurs1 {
    my ($self, $var) = @_;
    if ($self->bound) {
        return $self->ref->occurs1($var) if $self->deref;
        for my $i (0 .. $self->arity - 1) {
            return 1 if $self->{args}[$i]->occurs1($var);
        }
    }
    else {
        return $self->varid == $var;
    }
}

# Unification is the basic primitive operation in logic programming.
# $stack: the stack is used to store the address of variables which
# are bound by the unification.  This is needed when backtracking.

sub unify {
    my ($self, $term, $stack) = @_;
    return $self->ref->unify($term, $stack) if $self->bound and $self->deref;
    return $self->unify($term->ref, $stack) if $term->bound and $term->deref;
    if ($self->bound and $term->bound) { # bound and not deref
        if ($self->functor eq $term->getfunctor && $self->arity == $term->getarity) {
            for my $i (0 .. $self->arity - 1) {
                if (! $self->{args}[$i]->unify($term->getarg($i), $stack)) {
                    return;
                }
            }
            return 1;
        }
        else {
            return; # functor/arity don't match ...
        }
    } # at least one arg not bound ...
    if ($self->bound) {
        # added missing occurcheck
        if ($self->occurcheck) {
            if ($self->occurs($term->varid)) {
                return;
            }
        }
        $term->bind($self);
        push @{$stack} => $term; # side-effect -- setting stack vars
        return 1;
    }
    # do occurcheck if turned on
    return if $self->occurcheck && $term->occurs($self->varid);
    $self->bind($term);
    push @{$stack} => $self; # save for backtracking
    return 1;
}

# refresh creates new variables.  If the variables already exist
# in its arguments then they are used.  This is used when parsing
# a clause so that variables throughout the clause are shared.
# Includes a copy operation.

sub refresh {
    my ($self, $term_aref) = @_;
    if ($self->bound) {
        return $self->ref->refresh($term_aref) if $self->deref;
        my $term = $self->new($self->functor, $self->arity);
        for my $i (0 .. $self->arity - 1) {
            $term->{args}[$i] = $self->{args}[$i]->refresh($term_aref); # for 0 .. $self->arity - 1;
        }
        return $term;
    }
    # else unbound
    return _getvar($self, $term_aref, $self->varid);
}

sub _getvar {
    my ($self, $l, $varid) = @_;
    unless ( $l->[$varid] ) {
        $l->[$varid] = $self->new;
    }
    return $l->[$varid];
}

sub to_string {
    my ($self, $extended) = @_;
    if ($self->bound) {
        my $functor = $self->functor;
        my $arity   = $self->arity;
        my $prettyprint = $self->prettyprint;
        return $self->ref->to_string($extended) if $self->deref;
        return "[]" if NULL eq $functor && ! $arity && $prettyprint;
        my $string;
        if ("cons" eq $functor && 2 == $arity && $prettyprint) {
            $string = "[" . $self->{args}[0]->to_string;
            my $term   = $self->{args}[1];

            while ("cons" eq $term->getfunctor && 2 == $term->getarity) {
                $string .= "," . $term->getarg(0)->to_string;
                $term    = $term->getarg(1);
            }

            $string .= (NULL eq $term->getfunctor && ! $term->getarity)
                ? "]"
                : "|" . $term->to_string . "]";
            return "$string";
        }
        else {
            $string = $self->functor;
            if ($self->arity) {
                $string .= "(";
                my $arity = $self->arity;
                my @args = @{$self->args};
                if (@args) {
                    $string .= $args[$_]->to_string . "," for 0 .. $arity - 2;
                    $string .= $args[$arity - 1]->to_string
                }
                $string .=  ")";
            }
        }
        return $string;
    } # else unbound;
    return "_" . $self->varid;
}

# This constructor is the simplest way to construct a term.  The term is given
# in standard notation.
# Example: my $term = Term->new(Parser->new("p(1,a(X,b))"));
sub _new_from_parser {
    my ($class, $parser) = @_;
    my $self = bless {
        functor => undef,
        arity   => 0,
        args    => [],
        # if bound is false, $self is a reference to a free variable
        bound   => 0,
        varid   => undef, # XXX ??
        # if bound and deref are both true, $self is a reference to a ref
        deref   => 0,
        ref     => undef,
    } => $class;
    my $ts   = [];
    my $i    = 0;

    $parser->skipspace; # otherwise we crash when we hit leading
                        # spaces
    if ($parser->current =~ /^[[:lower:]]$/ ||
        ($self->internalparse && '_' eq $parser->current)) {
        $self->{functor} = $parser->getname;
        $self->{bound}   = 1;
        $self->{deref}   = 0;

        if ('(' eq $parser->current) {
            $parser->advance;
            $parser->skipspace;
            $ts->[$i++] = $self->new($parser);
            $parser->skipspace;

            while (',' eq $parser->current) {
                $parser->advance;
                $parser->skipspace;
                $ts->[$i++] = $self->new($parser);
                $parser->skipspace;
            }

            if (')' ne $parser->current) {
                $parser->parseerror("Expecting: ')'");
            }

            $parser->advance;
            $self->{args} = [];

            $self->{args}[$_] = $ts->[$_] for 0 .. ($i -1);
            $self->{arity} = $i;
        }
        else {
            $self->{arity} = 0;
        }
    }
    elsif ($parser->current =~ /^[[:upper:]]$/) {
        $self->{bound} = 1;
        $self->{deref} = 1;
        $self->{ref}   = $parser->getvar;
    }
    elsif ($parser->current =~ /^[[:digit:]]$/) {
        $self->{functor} = $parser->getnum;
        $self->{arity}   = 0;
        $self->{bound}   = 1;
        $self->{deref}   = 0;
    }
    elsif ('[' eq $parser->current) {
        $parser->advance;

        if (']' eq $parser->current) {
            $parser->advance;
            $self->{functor} = NULL;
            $self->{arity}   = 0;
            $self->{bound}   = 1;
            $self->{deref}   = 0;
        }
        else {
            $parser->skipspace;
            $ts->[$i++] = $self->new($parser);
            $parser->skipspace;

            while (',' eq $parser->current) {
                $parser->advance;
                $parser->skipspace;
                $ts->[$i++] = $self->new($parser);
                $parser->skipspace;
            }

            if ('|' eq $parser->current) {
                $parser->advance;
                $parser->skipspace;
                $ts->[$i++] = $self->new($parser);
                $parser->skipspace;
            }
            else {
                $ts->[$i++] = $self->new(NULL, 0);
            }

            if (']' ne $parser->current) {
                $parser->parseerror("Expecting ']'");
            }

            $parser->advance;
            $self->{bound}   = 1;
            $self->{deref}   = 0;
            $self->{functor} = "cons";
            $self->{arity}   = 2;
            $self->{args}    = [];
            for (my $j = $i - 2; $j > 0; $j--) {
                my $term = $self->new("cons", 2);
                $term->setarg(0, $ts->[$j]);
                $term->setarg(1, $ts->[$j+1]);
                $ts->[$j] = $term;
            }
            $self->{args}[0] = $ts->[0];
            $self->{args}[1] = $ts->[1];
        }
    }
    else {
        $parser->parseerror("Term should begin with a letter, a digit, or '['");
    }
    return $self;
}

1;

__END__

=head1 NAME

AI::Prolog::Term - Create Prolog Terms.

=head1 SYNOPSIS

 my $query = Term->new("steals(Somebody, Something).");

=head1 DESCRIPTION

See L<AI::Prolog|AI::Prolog> for more information.  If you must know more,
there are plenty of comments sprinkled through the code.

