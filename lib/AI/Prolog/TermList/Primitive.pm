package AI::Prolog::TermList::Primitive;
$REVISION = '$Id: Primitive.pm,v 1.1 2005/02/13 20:59:19 ovid Exp $';
$VERSION = '0.1';
@ISA = 'AI::Prolog::TermList';
use strict;
use warnings;
use Scalar::Util qw/looks_like_number/;

sub new {
    my ($class, $number) = @_;
    my $self = $class->SUPER::new; # correct?
    $self->{ID} = looks_like_number($number) ? $number : 0;
    return $self;
}

sub ID { shift->{ID} }

sub to_string { " <".shift->{ID}."> " }

1;
__END__
{
    int ID = 0;


    public Primitive(String n)
    {
        try {
            ID = Integer.parseInt( n );
        }
        catch (Exception e) {}
    }

    public String toString()
    {
        return " <" + ID + "> " ;
    }

}

