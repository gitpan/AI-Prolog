package AI::Prolog::TermList;
$REVISION = '$Id: TermList.pm,v 1.5 2005/02/20 18:27:55 ovid Exp $';

$VERSION = 0.02;

use strict;
use warnings;

use aliased 'AI::Prolog::Term';
use aliased 'AI::Prolog::Parser';
use aliased 'AI::Prolog::TermList::Clause';
use aliased 'AI::Prolog::TermList::Primitive';

sub new {
    #my ($proto, $parser, $nexttermlist, $definertermlist) = @_;
    my $proto = shift;
    my $class = ref $proto || $proto; # yes, I know what I'm doing
    return _new_from_term($class, @_)          if 1 == @_ && $_[0]->isa(Term);
    return _new_from_parser($class, @_)        if 1 == @_ && $_[0]->isa(Parser); # aargh! Lack of MMD sucks
    return _new_from_term_and_next($class, @_) if 2 == @_;
    return _new_with_definer($class, @_)       if 3 == @_;
    if (@_) {
        require Carp;
        Carp::croak "Unknown arguments to TermList->new:  @_";
    }
    bless {
        term       => undef,
        next       => undef,
        definer    => [], # XXX
        nextClause => undef, # serves two purposes: either links clauses in database
                             # or points to defining clause for goals
    } => $class;
}

sub _new_from_term {
    my ($class, $term) = @_;
    my $self = $class->new;
    $self->{term} = $term;
    return $self;
}

sub _new_from_parser {
    my ($class, $ps) = @_;
    my $self = $class->new;
    my @ts   = Term->new($ps);
    $ps->skipspace;

    if ($ps->current eq ':') {
        $ps->advance;

        if ($ps->current eq '=') {
            # we're parsing a primitive
            $ps->advance;
            $ps->skipspace;
            my $id = $ps->getnum;
            $ps->skipspace;
            $self->{term} = $ts[0];
            $self->{next} = Primitive->new($id);
        }
        elsif ($ps->current ne '-') {
            $ps->parseerror("Expected '-' after ':'");
        }
        else {
            $ps->advance;
            $ps->skipspace;

            push @ts => Term->new($ps);
            $ps->skipspace;

            while ($ps->current eq ',') {
                $ps->advance;
                $ps->skipspace;
                push @ts => Term->new($ps);
                $ps->skipspace;
            }

            my @tsl;
            for my $j (reverse 1 .. $#ts) {
                $tsl[$j] = $self->new($ts[$j], $tsl[$j+1]);
            }

            $self->{term} = $ts[0];
            $self->{next} = $tsl[1];
        }
    }
    else {
        $self->{term} = $ts[0];
        $self->{next} = undef;
    }

    if ($ps->current ne '.') {
        $ps->parseerror("Expected '.' Got '@{[$ps->current]}'");
    }
    $ps->advance;
    return $self;
}

sub _new_with_definer {
    my ($class, $term, $next, $definer) = @_;
    my $self = $class->new;
    $self->{term}       = $term;
    $self->{next}       = $next;
    $self->{definer}    = $definer->definer;
    return $self;
}

sub _new_from_term_and_next {
    my ($class, $term, $next) = @_;
    my $self = $class->_new_from_term($term);
    $self->{next} = $next;
    return $self;
}

sub term       { shift->{term}       }
sub definer    { shift->{definer}    }

sub next {
    my $self = shift;
    if (@_) {
        $self->{next} = shift;
        return $self;
    }
    return $self->{next};
}

sub nextClause {
    my $self = shift;
    if (@_) {
        # XXX debug
        my $nextClause = shift;
        no warnings 'uninitialized';
        if ($nextClause eq $self) {
            require Carp;
            Carp::confess("Trying to assign a termlist as its own successor");
        }
        $self->{nextClause} = $nextClause;
        return $self;
    }
    return $self->{nextClause};
}

sub to_string {
    my $self = shift;
    my $to_string = "[" . $self->term->to_string;
    my $tl = $self->next;
    while ($tl) {
        $to_string .= ", " . $tl->term->to_string;
        $tl = $tl->next;
    }
    return "$to_string]";
}

sub resolve {
    my ($self, $kb) = @_;
    my $key = sprintf "%s/%s" =>
        $self->{term}->getfunctor,
        $self->{term}->getarity;
    $self->nextClause($kb->get($key));
}

sub lookupIn {
    my ($self, $kb) = @_;
    my $key = sprintf "%s/%s" =>
        $self->{term}->getfunctor,
        $self->{term}->getarity;
    $self->nextClause($kb->get($key));
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
