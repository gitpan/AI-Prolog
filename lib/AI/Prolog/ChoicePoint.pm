package AI::Prolog::ChoicePoint;
$REVISION = '$Id: ChoicePoint.pm,v 1.4 2005/01/29 16:44:47 ovid Exp $';

$VERSION = '0.02';
use strict;
use warnings;

use constant CP_CLAUSENUM => 0;
use constant CP_GOAL      => 1;

sub new {
    my ($class, $clausenum, $goal) = @_;
    return bless [$clausenum,$goal] => $class;
}

sub clausenum { $_[0]->[CP_CLAUSENUM] }
sub goal      { $_[0]->[CP_GOAL] }

sub to_string {
    my $self = shift;
    return "<< $self->[0] : " . $self->[1]->to_string . ">>";
}

1;

__END__

=head1 NAME

AI::Prolog::ChoicePoint - Create a choicepoint object for the Engine..

=head1 SYNOPSIS

No user serviceable parts inside.  You should never be seeing this.  This
little snippet is merely used when backtracking and needing to try other
alternatives.

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
