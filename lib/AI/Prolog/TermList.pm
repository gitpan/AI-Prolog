package AI::Prolog::TermList;

$VERSION = 0.01;

use strict;
use warnings;

use aliased 'AI::Prolog::Term';
use aliased 'AI::Prolog::Parser';

sub new {
    my ($proto, $term_or_parser, $nexttermlist, $definertermlist) = @_;
    my $class = ref $proto || $proto; # yes, I know what I'm doing
    return _new_from_clause($class, $term_or_parser)
        if Parser eq ref $term_or_parser; # aargh! Lack of MMD sucks
    my $self = {
        term       => $term_or_parser,
        next       => $nexttermlist,
        definer    => [], # XXX
        numclauses => 0,  # XXX
    };
    if ($definertermlist) {
        $self->{definer}    = $definertermlist->definer;
        $self->{numclauses} = $definertermlist->numclauses;
    }
    bless $self => $class;
}

# used for parsing clauses
sub _new_from_clause {
    my ($class, $ps) = @_;
    my $self = $class->new;
    my $i   = 0;
    my $ts  = [];
    my $tsl = [];
    $ts->[$i++] = Term->new($ps);
    $ps->skipspace;

    if ($ps->current eq ':') {
        $ps->advance;

        if ($ps->current ne '-') {
            $ps->parseerror("Expected '-' after ':'");
        }
        $ps->advance;
        $ps->skipspace;

        $ts->[$i++] = Term->new($ps);
        $ps->skipspace;

        while ($ps->current eq ',') {
            $ps->advance;
            $ps->skipspace;
            $ts->[$i++] = Term->new($ps);
            $ps->skipspace;
        }

        $tsl->[$i] = undef;

        for my $j (reverse 1 .. $i - 1) {
            $tsl->[$j] = $self->new($ts->[$j], $tsl->[$j+1]);
        }

        $self->{term} = $ts->[0];
        $self->{next} = $tsl->[1];
    }
    else {
        $self->{term} = $ts->[0];
        $self->{next} = undef;
    }

    if ($ps->current ne '.') {
        $ps->parseerror("Expected '.'");
    }
    $ps->advance;
    return $self;
}

sub term       { shift->{term}       }
sub next       { shift->{next}       }
sub definer    { shift->{definer}    }
sub numclauses { shift->{numclauses} }

sub to_string {
    my $self = shift;
    my $to_string = "[" . $self->term->to_string;
    my $tl = $self->next;
    while ($tl) {
        $to_string .= ", " . $tl->term->to_string;
        $tl = $tl->next;
    }
    # this is commented out because I still wanted to see an
    # entry for 0 clauses
    #if (@{$self->definer}) {
        $to_string .= "($self->{numclauses} clauses)";
    #}
    return "$to_string]";
}

sub resolve {
    my ($self, $db) = @_;
    unless (@{$self->definer}) {
        $self->{numclauses} = 0;
        $self->{numclauses}++ 
            while exists $db->{$self->{term}->getfunctor."/".$self->{term}->getarity."-".(1 + $self->{numclauses})};

        $self->{definer} = [];

        for my $i (1 .. $self->{numclauses}) { # start numbering at one?
            $self->{definer}[$i] = $db->{$self->{term}->getfunctor."/".$self->term->getarity."-$i"};
        }

        if ($self->next) {
            $self->next->resolve($db);
        }
    }
}

1;

__END__

=head1 NAME

AI::Prolog::TermList - Create lists of Prolog Terms.

=head1 SYNOPSIS

No need for you.  You should never be seeing this.

=head1 DESCRIPTION

See L<AI::Prolog|AI::Prolog> for more information.  If you must know more,
there are plenty of comments sprinkled through the code.
 
