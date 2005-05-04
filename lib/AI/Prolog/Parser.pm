package AI::Prolog::Parser;
$REVISION = '$Id: Parser.pm,v 1.4 2005/02/28 02:32:11 ovid Exp $';

$VERSION = '0.03';
use strict;
use warnings;
use Regexp::Common;

# debugging stuff
use Clone;
use Text::Balanced qw/extract_quotelike extract_delimited/;

use aliased 'AI::Prolog::Term';
use aliased 'AI::Prolog::TermList';
use aliased 'AI::Prolog::TermList::Clause';
use aliased 'AI::Prolog::TermList::Primitive';
use aliased 'AI::Prolog::KnowledgeBase';

sub new {
    my ($proto, $string) = @_;
    my $class = ref $proto || $proto; # yes, I know what I'm doing
    bless {
        _str      => $string,
        _posn     => 0,
        _start    => 0,
        _varnum   => 0,
        _internal => 0,
        _vardict  => {},
    } => $class;
}

sub _vardict_to_string {
    my $self  = shift;
    return "{" .
        (join ', ' => 
            map  { join '=' => $_->[0], $_->[1] }
            sort { $a->[2] <=> $b->[2] }
            map  { [$_ , $self->_sortable_term($self->{_vardict}{$_}) ] }
                keys %{$self->{_vardict}})
        ."}";
}

sub _sortable_term {
    my ($self, $term) = @_;
    my $string = $term->to_string;
    my $number = substr $string => 1;
    return $string, $number;
}

sub to_string {
    my $self = shift;
    my $output = Clone::clone($self);
    $output->{_vardict} = $self->_vardict_to_string;
    return "{" 
        . substr($self->{_str}, 0, $self->{_posn})
        . " ^ " 
        . substr($self->{_str}, $self->{_posn}) 
        . " | " 
        . $self->_vardict_to_string
        . " }";
}

sub _posn    {shift->{_posn}   }
sub _str     {shift->{_str}    }
sub _start   {shift->{_start}  }
sub _varnum  {shift->{_varnum} }
sub _vardict {shift->{_vardict}}

sub _internal {
    my $self = shift;
    if (@_) {
        $self->{_internal} = shift;
        return $self;
    }
    return $self->{_internal};
}

# get the current character
sub current {
    my $self = shift;
    return '#' if $self->empty;
    return substr $self->{_str} => $self->{_posn}, 1;
}

# is the parsestring empty?
sub empty {
    my $self = shift;
    return $self->{_posn} >= length $self->{_str};
}

# Move a character forward
sub advance {
    my $self = shift;
    # print $self->current; # XXX
    $self->{_posn}++ unless $self->{_posn} >= length $self->{_str};
}

# all three get methods must be called before advance
# recognize a name (sequence of alphanumerics)
# XXX the java methods do not directly translate, so
#     we need to revisit this if it breaks
# XXX Update:  There was a subtle bug.  I think
#     I've nailed it, though.  The string index was off by one
sub getname {
    my $self = shift;

    $self->{_start} = $self->{_posn};
    my $getname;
    if ($self->current =~ /['"]/) {
        my $string = substr $self->{_str} => $self->{_start};
        $getname   = extract_delimited($string);
        $self->{_posn} += length $getname;
        return substr $getname => 1, length($getname) - 2; # strip the quotes
    }
    else {
        my $string    = substr $self->{_str} => $self->{_start};
        ($getname)    = $string =~ /^([[:alpha:]][[:alnum:]_]*)/;
        $self->{_posn} += length $getname;
        return $getname;
    }
}

# recognize a number
# XXX same issues as getname
sub getnum {
    my $self = shift;

    $self->{_start} = $self->{_posn};
    my $string      = substr $self->{_str} => $self->{_start};
    my ($getnum)    = $string =~ /^($RE{num}{real})/;
    if ('.' eq substr $getnum => -1, 1) {
        $getnum = substr $getnum => 0, length($getnum) - 1;
    }
    $self->{_posn} += length $getnum;
    return $getnum;
}

# get the term corresponding to a name.
# if the name is new, create a new variable
sub getvar {
    my $self   = shift;
    my $string = $self->getname;
    my $term   = $self->{_vardict}{$string};
    unless ($term) {
        $term = Term->new($self->{_varnum}++); # XXX wrong _varnum?
        $self->{_vardict}{$string} = $term;
    }
    return ($term, $string);
}

# handle errors in one place
sub parseerror {
    my ($self, $character) = @_;
    require Carp;
    Carp::croak "Unexpected character: ($character)";
}

# skips whitespace and prolog comments
sub skipspace {
    my $self = shift;
    $self->advance while $self->current =~ /[[:space:]]/;
    _skipcomment($self);
}

# XXX Other subtle differences
sub _skipcomment {
    my $self = shift;
    if ($self->current eq '%') {
        while ($self->current ne "\n" && $self->current ne "#") {
            $self->advance;
        }
        $self->skipspace;
    }
    if ($self->current eq "/") {
        $self->advance;
        if ($self->current ne "*") {
            $self->parseerror("Expecting '*' after '/'");
        }
        $self->advance;
        while ($self->current ne "*" && $self->current ne "#") {
            $self->advance;
        }
        $self->advance;
        if ($self->current ne "/") {
            $self->parseerror("Expecting terminating '/' on comment");
        }
        $self->advance;
        $self->skipspace;
    }
}

# reset the variable dictionary
sub nextclause {
    my $self = shift;
    $self->{_vardict} = {};
    $self->{_varnum}  = 0;
}

# takes a hash and extends it with the clauses in the string
# $program is a string representing a prolog program
# $db is an initial program that will be augmented with the
# clauses parsed.
# class method, not an instance method
sub consult {
    my ($class, $program, $db) = @_;
    $db ||= KnowledgeBase->new;
    my $ps = $class->new($program);
    $ps->skipspace;

    until ($ps->empty) {
        my $tls   = TermList->new($ps);
        my $func  = $tls->term->getfunctor;
        my $arity = $tls->term->getarity;

        my $head = $tls->term;
        my $body = $tls->next;
        my $key  = "$func/$arity";

        my $add = ($body && $body->isa(Primitive))? 'add_primitive' : 'add_clause';
        my $clause = Clause->new($head,$body);
        $db->$add($clause);
        $ps->skipspace;
        $ps->nextclause; # new set of vars
    }
    return $db;
}

sub resolve {
    my ($class, $db) = @_;
    foreach my $tls (values %{$db->ht}) {
        $tls->resolve($db);
    }
}

1;

__END__

=head1 NAME

AI::Prolog::Parser - A simple Prolog parser.

=head1 SYNOPSIS

 my $database = Parser->consult($prolog_text).

=head1 DESCRIPTION

There are no user-serviceable parts inside here.  See L<AI::Prolog|AI::Prolog>
for more information.  If you must know more, there are a few comments
sprinkled through the code.

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

