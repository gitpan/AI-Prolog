package AI::Prolog::Engine::Primitives;
$REVISION = '$Id: Primitives.pm,v 1.1 2005/08/06 23:28:40 ovid Exp $';
$VERSION = '0.2';
use strict;
use warnings;

use base 'AI::Prolog::Engine';
use Scalar::Util qw/looks_like_number/;

use aliased 'AI::Prolog::Term';
use aliased 'AI::Prolog::Term::Cut';
use aliased 'AI::Prolog::Term::Number';
use aliased 'AI::Prolog::TermList';
use aliased 'AI::Prolog::TermList::Step';
use aliased 'AI::Prolog::ChoicePoint';

my %DESCRIPTION_FOR;
my $LONGEST_PREDICATE = '';

sub _load_builtins {
    return if keys %DESCRIPTION_FOR;
    require Pod::Simple::Text;
    require Pod::Perldoc;
    my $perldoc = Pod::Perldoc->new;
    my $builtin_pod = 'AI::Prolog::Builtins';
    my ($found)   = $perldoc->grand_search_init([$builtin_pod]);
    die "Help failed.  Cannot find documentation for $builtin_pod: $!"
        unless $found;
    open FH, '<', $found
        or die "Cannot open $found for reading: ($!)";
    my @lines = <FH>;
    close FH or die "Cannot close $found: ($!)";
    while (@lines) {
        local $_ = shift @lines;
        my $predicate;
        if (/^=item\s*(\S+)/) {
            $predicate = $1;
            if ($predicate =~ m{.*/\d+}) {
                my @pod = "=head1 $predicate";
                $LONGEST_PREDICATE = $predicate
                    if length $predicate > length $LONGEST_PREDICATE;
                while ($_ = shift @lines) {
                    if (/^=(?:item|back)/) {
                        unshift @lines => $_;
                        last;
                    }
                    push @pod => $_;
                }
                push @pod => "=cut";
                # XXX I hate instantiating this here, but there appears to be a bug
                # in parsing if I don't :(
                my $parser = Pod::Simple::Text->new;
                my $output;
                $parser->output_string(\$output);
                $parser->parse_lines(@pod, undef);
                $DESCRIPTION_FOR{$predicate} = $output;
                $output = '';
            }
        }
    }
}

sub _remove_choices {
    # this implements the cut operator
    my ($self, $varid) = @_;
    my @stack;
    my $i = @{$self->{_stack}};
    while ($i > $varid) {
        my $o = pop @{$self->{_stack}};
        unless ($o->isa(ChoicePoint)) {
            push @stack => $o;
        }
        $i--;
    }
    while (@stack) {
        push @{$self->{_stack}} => pop @stack;
    }
}

sub _splice_goal_list {
    my ($self, $term) = @_;
    my ($t2, $p, $p1, $ptail);
    my @vars;
    my $i = 0;
    $term = $term->getarg(0);
    while ($term && $term->getfunctor ne "null") {
        $t2 = $term->getarg(0);
        if ($t2 eq Term->CUT) {
            $p = TermList->new(Cut->new( scalar @{$self->{_stack}}));
        }
        else {
            $p = TermList->new( $t2 );
        }
        if ($i++ == 0) {
            $p1 = $ptail = $p;
        }
        else {
            $ptail->next($p);
            $ptail = $p;
        }
        $term = $term->getarg(1);
    }
    $ptail->next($self->{_goal}->next);
    $self->{_goal} = $p1;
    $self->{_goal}->resolve($self->{_db});
}

use constant CONTINUE => 1;
use constant RETURN   => 2;
use constant FAIL     => ();
my @PRIMITIVES; # we'll fix this later

$PRIMITIVES[1] = sub { # !/0 (cut)
    my ($self, $term, $c) = @_;
    _remove_choices( $self, $term->varid );
    CONTINUE;
};

$PRIMITIVES[2] = sub {  # call/1
    my ($self, $term, $c) = @_;
    $self->{_goal} = TermList->new($term->getarg(0), $self->{_goal}->next);
    $self->{_goal}->resolve($self->{_db});
    RETURN;
};

$PRIMITIVES[3] = sub { # fail/0
    FAIL;
};

$PRIMITIVES[4] = sub { # consult/1
    my ($self, $term, $c) = @_;
    my $file = $term->getarg(0)->getfunctor;
    local *FH;
    if (open FH, "< $file") {
        my $prolog = do { local $/; <FH> };
        $self->{_db}->consult($prolog);
        return CONTINUE;
    }
    else {
        warn "Could not open ($file) for reading: $!";
        return FAIL;
    }
};

$PRIMITIVES[5] = sub { # assert/1
    my ($self, $term, $c) = @_;
    $self->{_db}->assert($term->getarg(0));
    CONTINUE;
};

$PRIMITIVES[7] = sub { # retract/1
    my ($self, $term, $c) = @_;
    unless ($self->{_db}->retract($term->getarg(0), $self->{_stack})) {
        $self->backtrack;
        return FAIL;
    }
    $self->{_cp}->clause($self->{_retract_clause}); # if $self->{_cp}; # doesn't work
    CONTINUE;
};

$PRIMITIVES[8] = sub { # listing/0
    my $self = shift;
    $self->{_db}->dump(0);
    CONTINUE;
};

$PRIMITIVES[9] = sub { # listing/1
    my ($self, $term, $c) = @_;
    my $predicate = $term->getarg(0)->getfunctor;
    $self->{_db}->list($predicate);
    CONTINUE;
};

$PRIMITIVES[10] = sub { # print/1
    my ($self, $term, $c) = @_;
    AI::Prolog::Engine::_print($term->getarg(0)->to_string);
    CONTINUE;
};

$PRIMITIVES[11] = sub { # println/1
    my ($self, $term, $c) = @_;
    AI::Prolog::Engine::_print($term->getarg(0)->to_string."\n");
    CONTINUE;
};

$PRIMITIVES[12] = sub { AI::Prolog::Engine::_print("\n"); CONTINUE }; # nl

$PRIMITIVES[13] = sub { # trace. notrace.
    my ($self, $term) = @_;
    $self->{_trace} = $term->getfunctor eq 'trace';
    AI::Prolog::Engine::_print("Trace " . ($self->{_trace}? "ON" : "OFF"));
    CONTINUE;
};

$PRIMITIVES[15] = sub { # is/2
    my ($self, $term, $c) = @_;
    my $rhs = $term->getarg(0)->deref;
    my $lhs = $term->getarg(1)->value;
    if ($rhs->is_bound) {
        my $value = $rhs->value;
        return FAIL unless looks_like_number($value);
        return $value == $lhs;
    }
    $rhs->bind(Number->new($lhs));
    push @{$self->{_stack}} => $rhs;
    CONTINUE;
};

$PRIMITIVES[16] = sub { # gt/2
    my ($self, $term) = @_;
    return ($term->getarg(0)->value > $term->getarg(1)->value)
        ? CONTINUE
        : FAIL;
};

$PRIMITIVES[17] = sub { # lt/2
    my ($self, $term) = @_;
    return ($term->getarg(0)->value < $term->getarg(1)->value)
        ? CONTINUE
        : FAIL;
};

$PRIMITIVES[19] = sub { # ge/2
    my ($self, $term) = @_;
    return ($term->getarg(0)->value >= $term->getarg(1)->value)
        ? CONTINUE
        : FAIL;
};

$PRIMITIVES[20] = sub { # le/2
    my ($self, $term) = @_;
    return ($term->getarg(0)->value <= $term->getarg(1)->value)
        ? CONTINUE
        : FAIL;
};

$PRIMITIVES[22] = sub { # halt/0
    my ($self, $term) = @_;
    $self->halt(1);
    CONTINUE;
};

$PRIMITIVES[23] = sub { # var/1
    my ($self, $term, $c) = @_;
    return $term->getarg(0)->bound()? FAIL : CONTINUE;
};

# plus(X,Y)  := 25.
# minux(X,Y) := 26.
# mult(X,Y)  := 27.
# div(X,Y)   := 28.
# mod(X,Y)   := 29.

$PRIMITIVES[30] = sub { # seq/1
    my ($self, $term, $c) = @_;
    $self->_splice_goal_list( $term );
    CONTINUE;
};

my $HELP_OUTPUT;
$PRIMITIVES[31] = sub { # help/0
    _load_builtins();
    unless ($HELP_OUTPUT) {
        $HELP_OUTPUT = "Help is available for the following builtins:\n\n";
        my @predicates = sort keys %DESCRIPTION_FOR;
        my $length     = length $LONGEST_PREDICATE;
        my $columns    = 5;
        my $format     = join '    ' => ("%-${length}s") x $columns;
        while (@predicates) {
            my @row;
            for (1 .. $columns) {
                push @row => @predicates ? shift @predicates
                           :               '';
            }
            $HELP_OUTPUT .= sprintf $format => @row;
            $HELP_OUTPUT .= "\n";
        }
        $HELP_OUTPUT .= "\n";
    }
    AI::Prolog::Engine::_print($HELP_OUTPUT);
    CONTINUE;
};

$PRIMITIVES[32] = sub { # help/1
    my ($self, $term, $c) = @_;
    my $predicate = $term->getarg(0)->to_string;
    _load_builtins();
    if (my $description = $DESCRIPTION_FOR{$predicate}) {
        AI::Prolog::Engine::_print($description);
    }
    else {
        AI::Prolog::Engine::_print("No help available for ($predicate)\n\n");
        $PRIMITIVES[31]->();
    }
    CONTINUE;
};

my $gensymInt = 0;
$PRIMITIVES[33] = sub { # gemsym/1
    my ($self, $term, $c) = @_;
    my $t2 = Term->new('v' . $gensymInt++, 0);
    return $t2->unify($term->getarg(0), $self->{_stack})
        ? CONTINUE
        : FAIL;
};


sub find { $PRIMITIVES[$_[1]] }

1;

__END__

=head1 NAME

AI::Prolog::Engine::Primitives - The code for running aiprolog builtins

=head1 SYNOPSIS

 my $builtin = AI::Prolog::Engine::Primitives ->find($builtin_id);

=head1 DESCRIPTION

This module contains the code to handle the built-in predicates.  The
L<AI::Prolog::Engine|AI::Prolog::Engine> assigns many builtins an ID
number and this number is used to lookup the sub necessary to execute
the built-in.

=head1 AUTHOR

Curtis "Ovid" Poe, E<lt>moc tod oohay ta eop_divo_sitrucE<gt>

Reverse the name to email me.

=head1 COPYRIGHT AND LICENSE

Copyright 2005 by Curtis "Ovid" Poe

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
