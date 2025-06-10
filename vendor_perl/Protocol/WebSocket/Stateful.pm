package Protocol::WebSocket::Stateful;

use strict;
use warnings;

sub new {
    my $class = shift;
    $class = ref $class if ref $class;

    my $self = {@_};
    bless $self, $class;

    return $self;
}

sub state { @_ > 1 ? $_[0]->{state} = $_[1] : $_[0]->{state} }

sub done     { shift->state('done') }
sub is_state { shift->state eq shift }
sub is_body  { shift->is_state('body') }
sub is_done  { shift->is_state('done') }

1;
__END__

=head1 NAME

Protocol::WebSocket::Stateful - Base class for all classes with states

=head1 DESCRIPTION

A base class for all classes with states.

=head1 ATTRIBUTES

=head2 C<state>

=head1 METHODS

=head2 C<new>

Create a new L<Protocol::WebSocket::Stateful> instance.

=head2 C<done>

=head2 C<is_state>

=head2 C<is_body>

=head2 C<is_done>

=cut
