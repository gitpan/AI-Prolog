package AI::Prolog::TermList::Step;
$REVISION = '$Id: Step.pm,v 1.1 2005/02/13 20:59:19 ovid Exp $';
$VERSION = '0.1';
@ISA = 'AI::Prolog::TermList';
use strict;
use warnings;

use aliased 'AI::Prolog::Term';

sub new {
    my ($class, $termlist) = @_;
    my $self = $class->SUPER::new;
    $self->{next} = $termlist->next;
    $termlist->{next} = $self;
    $self->{term} = Term->new('STEP',0);
    return $self;
}

1;
__END__
{
    public Step ( TermList t){
        super();
        next = t.next;
        t.next=this;
        term = new Term("STEP",0);
    }
}

