package AI::Prolog::TermList;
$REVISION = '$Id: TermList.pm,v 1.4 2005/01/29 16:44:47 ovid Exp $';

$VERSION = 0.02;

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

No user serviceable parts inside.  You should never be seeing this.

=head1 DESCRIPTION

See L<AI::Prolog|AI::Prolog> for more information.  If you must know more,
there are plenty of comments sprinkled through the code.

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
