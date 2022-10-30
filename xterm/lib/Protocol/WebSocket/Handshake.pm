package Protocol::WebSocket::Handshake;

use strict;
use warnings;

use Protocol::WebSocket::Request;
use Protocol::WebSocket::Response;

sub new {
    my $class = shift;
    $class = ref $class if ref $class;

    my $self = {@_};
    bless $self, $class;

    return $self;
}

sub error { @_ > 1 ? $_[0]->{error} = $_[1] : $_[0]->{error} }

sub version { $_[0]->req->version }

sub req { shift->{req} ||= Protocol::WebSocket::Request->new }
sub res { shift->{res} ||= Protocol::WebSocket::Response->new }

1;
__END__

=head1 NAME

Protocol::WebSocket::Handshake - Base WebSocket Handshake class

=head1 DESCRIPTION

This is a base class for L<Protocol::WebSocket::Handshake::Client> and
L<Protocol::WebSocket::Handshake::Server>.

=head1 ATTRIBUTES

=head2 C<error>

    $handshake->error;

Set or get handshake error.

=head2 C<version>

    $handshake->version;

Set or get handshake version.

=head1 METHODS

=head2 C<new>

Create a new L<Protocol::WebSocket::Handshake> instance.

=head2 C<req>

    $handshake->req;

WebSocket request object.

=head2 C<res>

    $handshake->res;

WebSocket response object.

=cut
