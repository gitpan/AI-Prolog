package AI::Prolog::TermList::Clause;
$REVISION = '$Id: Clause.pm,v 1.1 2005/02/13 20:59:19 ovid Exp $';
$VERSION = '0.1';
@ISA = 'AI::Prolog::TermList';
use strict;
use warnings;

sub new {
        #      Term  TermList
    my $class = shift;
    #pop @_ unless defined $_[-1];
    return $class->SUPER::new(@_);
}

sub to_string {
    my $self = shift;
    my ($term,$next) = ($self->term,$self->next);
    foreach ($term, $next) {
        $_ = $_? $_->to_string : "null";
    }
    return sprintf "%s :- %s" => $term, $next;
    #    $self->term->to_string,
    #    $self->next->to_string;
}

1;
__END__
{
    public Clause(Term t, TermList body)
    {
        super(t, body);
    }


    public final String toString()
    {
        return term + " :- " + next;
    }
}

