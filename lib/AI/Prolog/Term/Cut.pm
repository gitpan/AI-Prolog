package AI::Prolog::Term::Cut;
$REVISION = '$Id: Cut.pm,v 1.1 2005/02/13 20:59:19 ovid Exp $';
$VERSION = '0.1';
@ISA = 'AI::Prolog::Term';
use strict;
use warnings;

use aliased 'AI::Prolog::Term';

sub new {
    my ($proto, $stack_top) = @_;
    my $self = $proto->SUPER::new('!',0);
    $self->{varid} = $stack_top;
    return $self;
}

sub to_string {
    my $self = shift;
    return "Cut->$self->{varid}";
}

sub dup { # recast as Term?
    my $self = shift;
    return $self->new($self->{varid});
}

1;
__END__
   final class Cut extends Term
//-------------------------------
{

    public Cut( int stackTop )
    {
        super("!",0);
        varid = stackTop;
    }
    public String toString()
    {
        return "Cut->" + varid ;
    }

    public  Term dup()    // to copy correctly CUT & Number terms
    {
       return new Cut( varid ); }
}


1;
