package AI::Prolog::KnowledgeBase;
$REVISION = '$Id: KnowledgeBase.pm,v 1.1 2005/02/13 20:59:19 ovid Exp $';
$VERSION = '0.02';
use strict;
use warnings;

use aliased 'AI::Prolog::Parser';
use aliased 'AI::Prolog::TermList::Clause';

sub new {
    bless {
        ht         => {},
        primitives => {}, # only uses keys
        oldIndex   => "",
    } => shift;
}

sub ht {shift->{ht}} # temp hack XXX

sub to_string {
    my $self = shift;
    return "{" .
        (join ', ' =>
            map  { join '=' => $_->[0], $_->[1] }
            sort { $a->[2] <=> $b->[2] }
            map  { [$_ , $self->_sortable_term($self->{_vardict}{$_}) ] }
                keys %{$self->{ht}})
        ."}";
}

sub _sortable_term {
    my ($self, $term) = @_;
    my $string = $term->to_string;
    my $number = substr $string => 1;
    return $string, $number;
}

sub put {
    my ($self, $key, $termlist) = @_;
    $self->{ht}{$key} = $termlist;
}

sub elements { [values %{ shift->{ht} }] }
sub reset    {
    my $self = shift;
    $self->{ht}         = {};
    $self->{primitives} = {};
    $self->{oldIndex}   = '';
}

sub consult {
    my $self = shift;
    $self->{oldIndex} = '';
    Parser->new(shift)->Program($self);
}

sub addPrimitive {
    my ($self, $clause) = @_;
    my $term  = $clause->term;
    my $index = sprintf "%s/%s" =>
        $term->getfunctor,
        $term->getarity;
    my $c = $self->{ht}{$index};
    if ($c) {
        while ($c->nextClause) {
            $c = $c->nextClause;
        }
        $c->nextClause($clause);
    }
    else {
        $self->{primitives}{$index} = 1;
        $self->{ht}{$index} = $clause;
    }
}

sub addClause {
    my ($self, $clause) = @_;
    my $term = $clause->term;
    my $index = sprintf "%s/%s" =>
        $term->getfunctor,
        $term->getarity;
    if ($self->{primitives}{$index}) {
        require Carp;
        Carp::carp("Trying to modify primitive predicate: $index");
        return;
    }
    unless ($index eq $self->{oldIndex}) {
        delete $self->{ht}{$index};
        $self->{ht}{$index} = $clause;
        $self->{oldIndex} = $index;
    }
    else {
        my $c = $self->{ht}{$index};
        while ($c->nextClause) {
            $c = $c->nextClause;
        }
        $c->nextClause($clause);
    }
}

sub assert {
    my ($self, $term) = @_;
    $term = $term->cleanUp;
    # XXX whoops.  Need to check exact semantics in Term
    my $newC = Clause->new($term->deref,undef);
    
    my $index = sprintf "%s/%s" => $term->getfunctor, $term->getarity;
    if ($self->{primitives}{$index}) {
        require Carp && Carp::carp("Trying to assert a primitive: $index");
        return;
    }
    my $c = $self->{ht}{$index};
    if ($c) {
        while ($c->nextClause) {
            $c = $c->nextClause;
        }
        $c->nextClause($newC);
    }
    else {
        $self->{ht}{$index} = $newC;
    }
}

sub asserta {
    my ($self, $term) = @_;
    my $index = sprintf "%s/%s" =>
        $term->getfunctor,
        $term->getarity;
    if ($self->{primitives}{$index}) {
        require Carp && Carp::carp("Trying to assert a primitive: $index");
        return;
    }
    $term = $term->cleanUp;
    my $newC = Clause->new($term->deref, undef);
    my $c    = $self->{ht}{$index};
    $newC->nextClause($c);
    $self->{ht}{$index} = $newC;
}

sub retract {
    my ($self, $term, $stack) = @_;
    my $newC = Clause->new($term);#, undef);
    my $index = sprintf "%s/%s" =>
        $term->getfunctor,
        $term->getarity;
    if (exists $self->{primitives}{$index}) {
        require Carp && Carp::carp("Trying to retract a primitive: $index");
        return;
    }
    my $cc;
    my $c = $self->{ht}{$index};

    while ($c) {
        my $vars = [];
        my $xxx  = $c->term->refresh($vars);
        my $top  = @{$stack};

        if ($xxx->unify($term, $stack)) {
            if ($cc) {
                $cc->nextClause($c->nextClause);
            }
            elsif (! $c->nextClause) {
                delete $self->{ht}{$index};
            }
            else {
                $self->{ht}{$index} = $c->nextClause;
            }
            return 1;
        }
        for (my $i = @{$stack} - $top; $i > 0; $i--) {
            my $t = pop @{$stack};
            $t->unbind;
        }
        $cc = $c;
        $c  = $c->nextClause;
    }
    return;
}

sub retractall {
    my ($self, $term, $arity) = @_;
    my $index = sprintf "%s/%s" =>
        $term->getfunctor,
        $term->getarity;
    if ($self->{primitives}{$index}) {
        require Carp && Carp::carp("Trying to retractall primitives: $index");
        return;
    }
    delete $self->{ht}{$index};
    return 1;
}

sub get {
    my ($self, $term) = @_;
    my $key = ref $term? $term->to_string : $term;
    return $self->{ht}{$key};
}

sub set {
    my ($self, $term, $value) = @_;
    my $key = ref $term? $term->to_string : $term;
    $self->{ht}{$key} = $value->cleanUp;
}

sub dump {
    my ($self, $full) = @_;
    my $i = 1;
    while (my ($key, $value) = each %{$self->{ht}}) {
        next if ! $full && $self->{primitives}{$key};
        if ($value->isa(Clause)) {
            print $i++.". $key: \n";
            do {
                print "   " . $value->term->to_string;
                if ($value->next) {
                    print " :- " . $value->next->to_string;
                }
                print ".\n";
                $value = $value->nextClause;
            } while ($value);
        }
        else {
            print $i++.". $key = $value\n";
        }
    }
    print "\n";
}

sub list {
    my ($self, $term, $arity) = @_;
    my $index = sprintf "%s/%s" =>
        $term->getfunctor,
        $arity->getfunctor;
    print "\n$index: \n";
    my $head = $self->{ht}{$index};
    while ($head) {
        print "   " . $head->term->to_string;
        if ($head->next) {
            print " :- " . $head->next->to_string;
        }
        print ".\n";
        $head = $head->nextClause;
    }
}

1;

__END__

=head1 NAME

AI::Prolog::KnowledgeBase - The Prolog database.

=head1 SYNOPSIS

 my $kb = KnowledgeBase->new;

=head1 DESCRIPTION

There are no user-serviceable parts inside here.  See L<AI::Prolog|AI::Prolog>
for more information.  If you must know more, there are a few comments
sprinkled through the code.

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

