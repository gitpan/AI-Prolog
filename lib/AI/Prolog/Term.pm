package AI::Prolog::Term;
$REVISION = '$Id: Term.pm,v 1.3 2005/02/13 21:01:02 ovid Exp $';

$VERSION = '0.03';
use strict;
use warnings;

use aliased 'AI::Prolog::Term::Cut';
use aliased 'AI::Prolog::Parser';

use aliased 'Hash::AsObject';

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

my $CUT = Cut->new(0);
sub CUT {
    my $class = shift;
    if ($@) {
        $CUT = shift;
        return $class;
    }
    return $CUT;
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
    elsif (2 == @_) {
        return $class->_new_from_functor_and_array(@_) if 'ARRAY' eq CORE::ref $_[1];
        return $class->_new_from_functor_and_arity(@_);
    }
    elsif(3 == @_) {
        return $class->_new_binop(@_);
    }
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

sub _new_from_functor_and_array {
    my ($class, $functor, $arrayref) = @_;
    bless {
        functor => $functor,
        arity   => scalar @$arrayref,
        args    => $arrayref,
        # if bound is false, $self is a reference to a free variable
        bound   => 1,
        varid   => undef, # XXX ??
        # if bound and deref are both true, $self is a reference to a ref
        deref   => 0,
        ref     => undef,
    } => $class;
}

sub _new_from_functor_and_arity {
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

sub _new_binop {
    my ($class, $functor, $term1, $term2) = @_;
    bless {
        functor => $functor,
        arity   => 2,
        args    => [$term1, $term2],
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
sub varid   { shift->{varid}   }
sub ref     { shift->{ref}     }

sub deref {
    my $self = shift; # of course, this also begs the question of whether
                      # the java code treated this as an alias or a copy :(
    while ($self->{bound} && $self->{deref}) {
        $self = $self->{ref};
    }
    return $self;
}

sub bound {
    my $self = shift;
    while ($self->{bound} && $self->{deref}) {
        $self = $self->{ref};
    }
    return $self->{bound};
}

sub isBound { shift->bound }

sub traceln {
    my ($self, $msg) = @_;
    if ($self->{trace}) {
        print "$msg\n";
    }
}

sub dup {
    my $self = shift;
    $self->new($self->{functor},$self->{arity});
}

# biind a variable to a term
sub bind {
    my ($self, $term) = @_;
    return if $self eq $term;
    unless ($self->{bound}) {
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
    if ($self->{bound} && ! $self->{deref}) {
        $self->{args}[$pos] = $val;
    }
    else {
        require Carp;
        Carp::croak("AI::Prolog::Term->setarg($pos, ".$val->to_string.").  Cannot setarg on variables!");
    }
}

# retrieves an argument of a term
sub getarg {
    my ($self, $pos) = @_;
    # should check if position is valid
    if ($self->{bound}) {
        return $self->ref->getarg($pos) if $self->{deref};
        return $self->{args}[$pos];
    }
    else {
        require Carp;
        Carp::croak("AI::Prolog::Term->getarg.  Error -- lookup on unbound term!");
    }
}

sub getfunctor {
    my $self = shift;
    return "" unless $self->{bound};
    return $self->ref->getfunctor if $self->{deref};
    return $self->functor;
}

sub getarity {
    my $self = shift;
    return 0 unless $self->{bound};
    return $self->ref->getarity if $self->{deref};
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
    if ($self->{bound}) {
        return $self->ref->occurs1($var) if $self->{deref};
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
    return $self->ref->unify($term, $stack) if $self->{bound} and $self->{deref};
    return $self->unify($term->ref, $stack) if $term->{bound} and $term->{deref};
    if ($self->{bound} and $term->{bound}) { # bound and not deref
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
    if ($self->{bound}) {
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
    if ($self->{bound}) {
        return $self->ref->refresh($term_aref) if $self->{deref};
        return $self unless $self->{arity};
        my $term = $self->dup;
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

sub to_data {
    my $self = shift;
    $self->{_results} = {};
    # @results is the full results, if we ever need it
    my @results = $self->_to_data($self);
    return AsObject->new($self->{_results}), \@results;
}

sub _to_data {
    my ($self, $parent) = @_;
    if (defined $self->{varname}) {
        # XXX here's where the [HEAD|TAIL] bug is.  The engine works fine,
        # but we can't bind TAIL to a result object and are forced to
        # switch to raw_results.
        my $varname = delete $self->{varname};
        ($parent->{_results}{$varname}) = $self->_to_data($parent);
        $self->{varname} = $varname;
    }
    if ($self->{bound}) {
        my $functor = $self->functor;
        my $arity   = $self->arity;
        return $self->ref->_to_data($parent) if $self->{deref};
        return [] if NULL eq $functor && ! $arity;
        if ("cons" eq $functor && 2 == $arity) {
            my @result = $self->{args}[0]->_to_data($parent);
            my $term   = $self->{args}[1];

            while ("cons" eq $term->getfunctor && 2 == $term->getarity) {
                push @result => $term->getarg(0)->_to_data($parent);
                $term    = $term->getarg(1);
            }

            # XXX Not really sure about this one
            push @result => $term->_to_data($parent) 
                unless NULL eq $term->getfunctor && ! $term->getarity;
            #    ? "]"
            #    : "|" . $term->_to_data($parent) . "]";
            return \@result;
        }
        else {
            my @results = $self->functor;
            if ($self->arity) {
                #push @results => [];
                my $arity = $self->arity;
                my @args = @{$self->args};
                if (@args) {
                    for my $i (0 .. $arity -1) {
                        push @results => $args[$i]->_to_data($parent);
                    }
                    # I have no idea what the following line was doing.
                    #push @results => $args[$arity - 1]->_to_data($parent)
                }
            }
            return @results;
        }
    } # else unbound;
    return undef;
}

sub to_string {
    my ($self, $extended) = @_;
    if ($self->{bound}) {
        my $functor = $self->functor;
        my $arity   = $self->arity;
        my $prettyprint = $self->prettyprint;
        return $self->ref->to_string($extended) if $self->{deref};
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

# ----------------------------------------------------------
#  Copy a term to put in the database
#    - with new variables (freshly renumbered)
# ----------------------------------------------------------

# XXX XProlog
my %CVDICT;
my $CVN;

sub cleanUp {
    my $self = shift;
    %CVDICT = ();
    $CVN    = 0;
    return $self->_cleanUp;
}

sub _cleanUp {
    my $self = shift;
    my $term;
    if ($self->{bound}) {
        if ($self->{deref}) {
            return $self->{ref}->_cleanUp;
        }
        elsif (! $self->{arity}) {
            return $self;
        }
        else {
            $term = $self->dup;
            for my $i ( 0 .. $self->{arity} - 1) {
                $term->{args}[$i] = $self->{args}[$i]->_cleanUp;
            }
        }
    }
    else { # unbound
        $term = $CVDICT{$self};
        unless ($term) {
            $term = $self->new($CVN++);
            $CVDICT{$self} = $term; # XXX Should this be $self->to_string?
        }
    }
    return $term;
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
    if ($parser->current =~ /^[[:lower:]'"]$/) {
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
        $self->{bound}     = 1;
        $self->{deref}     = 1;
        my ($ref, $string) = $parser->getvar;
        $self->{ref}       = $ref;
        $self->{varname}   = $string;
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
    elsif ('!' eq $parser->current) {
        $parser->advance;
        return $self->CUT;
    }
    else {
        $parser->parseerror("Term should begin with a letter, a digit, or '[', not a @{[$parser->current]}");
    }
    return $self;
}

# only used for integer results
# From XProlog
sub value {
    # int i, res = 0;
    my $self = shift;
    my ($i, $res) = (0,0);
    
    unless ($self->{bound}) {
        require Carp;
        my $term = $self->to_string;
        Carp::croak("Tried to to get value of unbound term ($term)");
    }
    return $self->{ref}->value if $self->{deref};
    my $functor = $self->getfunctor;
    my $arity   = $self->getarity;
    if ('rnd' eq $functor && 1 == $arity) {
        # implement rand
    }
    if ($arity < 2) {
        require Carp;
        my $term = $self->to_string;
        Carp::croak("Term ($term) is not binary");
    }
    my $arg0 = $self->{args}[0]->value;
    my $arg1 = $self->{args}[1]->value;

    return $arg0 + $arg1 if '+'   eq $functor;
    return $arg0 - $arg1 if '-'   eq $functor;
    return $arg0 * $arg1 if '*'   eq $functor;
    return $arg0 / $arg1 if '/'   eq $functor;
    return $arg0 % $arg1 if 'mod' eq $functor;
    require Carp;
    Carp::croak("Unknown operator ($functor)");
}

# public String dump() {
#     return " - Term: " + functor + "/" + arity + ", "
#         + (bound? "bound, " : "")
#         + (deref? "ref, " : "")
#         + varid ;
# }


sub dump {
    my $self = shift;
    return " - Term: $self->{functor}/$self->{arity}, "
         . ($self->{bound}? "bound, " : "")
         . ($self->{deref}? "ref, "   : "")
         . $self->{varid};
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

=head1 BUGS

A query using C<[HEAD|TAIL]> syntax does not bind properly with the C<TAIL>
variable when returning a result object.  This bug can be found in the
C<_to_data> method of this class.

=head1 SEE ALSO

W-Prolog:  L<http://goanna.cs.rmit.edu.au/~winikoff/wp/>

Michael BartE<225>k's online guide to programming Prolog:
L<http://kti.ms.mff.cuni.cz/~bartak/prolog/index.html>

=head1 AUTHOR

Curtis "Ovid" Poe, E<lt>moc tod oohay ta eop_divo_sitrucE<gt>

Reverse the name to email me.

This work is based on W-Prolog, L<http://goanna.cs.rmit.edu.au/~winikoff/wp/>,
by Dr. Michael Winikoff.  Many thanks to Dr. Winikoff for granting me
permission to port this.

=head1 COPYRIGHT AND LICENSE

Copyright 2005 by Curtis "Ovid" Poe

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
