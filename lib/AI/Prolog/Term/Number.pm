package AI::Prolog::Term::Number;
$REVISION = '$Id: Number.pm,v 1.1 2005/02/13 20:59:19 ovid Exp $';
$VERSION = '0.1';
@ISA = 'AI::Prolog::Term';
use strict;
use warnings;
use Scalar::Util qw/looks_like_number/;

use aliased 'AI::Prolog::Term';

sub new {
    my ($proto, $number) = @_;
    my $self = $proto->SUPER::new($number, 0);
    $self->{varid} = looks_like_number($number)
        ? $number
        : 0;
    return $self;
}

sub value { shift->{varid} }

sub dup { # should this be recast as the parent?
    my $self = shift;
    return $self->new($self->{varid});
}

1;
__END__
final class Number extends Term
{
    public Number( String s) {
        super(s,0);
        try {
            varid = Integer.parseInt(s);
        } catch (Exception e)
            { varid = 0; }
    }
    public Number( int n) {
        super(Integer.toString(n).intern(),0);
         varid = n;
    }

    public int value() { return varid; }

    public  Term dup()    // to copy correctly CUT & Number terms
    {
        return new Number( varid ); }
}

