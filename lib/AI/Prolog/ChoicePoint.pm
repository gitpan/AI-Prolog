package AI::Prolog::ChoicePoint;

$VERSION = '0.01';
use strict;
use warnings;

sub new {
    my ($class, $clausenum, $goal) = @_;
    bless {
        clausenum => $clausenum,
        goal      => $goal,
    } => $class;
}

sub clausenum { shift->{clausenum} }
sub goal      { shift->{goal}      }

sub to_string {
    my $self = shift;
    return "<< $self->{clausenum} : " . $self->goal->to_string . ">>";
}

1;

__END__

=head1 NAME

AI::Prolog::ChoicePoint - Create a choicepoint object for the Engine..

=head1 SYNOPSIS

No need for you.  You should never be seeing this.  This little snippet
is merely used when backtracking and needing to try other alternatives.

=head1 DESCRIPTION

See L<AI::Prolog|AI::Prolog> for more information.  If you must know more,
there are plenty of comments sprinkled through the code.
