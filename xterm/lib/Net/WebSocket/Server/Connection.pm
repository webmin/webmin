package Net::WebSocket::Server::Connection;

use 5.006;
use strict;
use warnings FATAL => 'all';

use Carp;
use Protocol::WebSocket::Handshake::Server;
use Protocol::WebSocket::Frame;
use Socket qw(IPPROTO_TCP TCP_NODELAY);
use Encode;

sub new {
  my $class = shift;

  my %params = @_;

  my $self = {
    socket        => undef,
    server        => undef,
    nodelay       => 1,
    max_send_size => eval { Protocol::WebSocket::Frame->new->{max_payload_size} } || 65536,
    max_recv_size => eval { Protocol::WebSocket::Frame->new->{max_payload_size} } || 65536,
    on_handshake  => sub{},
    on_ready      => sub{},
    on_disconnect => sub{},
    on_utf8       => sub{},
    on_pong       => sub{},
    on_binary     => sub{},
  };

  while (my ($key, $value) = each %params ) {
    croak "Invalid $class parameter '$key'" unless exists $self->{$key};
    croak "$class parameter '$key' expects a coderef" if ref $self->{$key} eq 'CODE' && ref $value ne 'CODE';
    $self->{$key} = $value;
  }

  croak "$class construction requires '$_'" for grep { !defined $self->{$_} } qw(socket server);

  $self->{handshake} = new Protocol::WebSocket::Handshake::Server();
  $self->{disconnecting} = 0;
  $self->{ip} = $self->{socket}->peerhost;
  $self->{port} = $self->{socket}->peerport;

  # only attempt to start SSL if this is an IO::Socket::SSL-like socket that also has not completed its SSL handshake (SSL_startHandshake => 0)
  $self->{needs_ssl} = 1 if $self->{socket}->can("accept_SSL") && !$self->{socket}->opened;

  bless $self, $class;
}

sub on {
  my $self = shift;
  my %params = @_;

  while (my ($key, $value) = each %params ) {
    croak "Invalid event '$key'" unless exists $self->{"on_$key"};
    croak "Expected a coderef for event '$key'" unless ref $value eq 'CODE';
    $self->{"on_$key"} = $value;
  }
}


### accessors

sub server { $_[0]->{server} }

sub socket { $_[0]->{socket} }

sub is_ready { !$_[0]->{handshake} }

sub ip { $_[0]{ip} }

sub port { $_[0]{port} }

sub nodelay {
  my $self = shift;
  if (@_) {
    $self->{nodelay} = $_[0];
    setsockopt($self->{socket}, IPPROTO_TCP, TCP_NODELAY, $self->{nodelay} ? 1 : 0) unless $self->{handshake};
  }
  return $self->{nodelay};
}

sub max_send_size {
  my $self = shift;
  $self->{max_send_size} = $_[0] if @_;
  return $self->{max_send_size};
}

sub max_recv_size {
  my $self = shift;
  if (@_) {
    croak "Cannot change max_recv_size; handshake is already complete" if $self->{parser};
    $self->{max_recv_size} = $_[0];
  }
  return $self->{max_recv_size};
}


### methods

sub disconnect {
  my ($self, $code, $reason) = @_;
  return if $self->{disconnecting};
  $self->{disconnecting} = 1;

  $self->_event('on_disconnect', $code, $reason);

  my $data = '';
  if (defined $code || defined $reason) {
    $code ||= 1000;
    $reason = '' unless defined $reason;
    $data = pack("na*", $code, $reason);
  }
  $self->send(close => $data) unless $self->{handshake};

  $self->{server}->disconnect($self->{socket});
}

sub send_binary {
  $_[0]->send(binary => $_[1]);
}

sub send_utf8 {
  $_[0]->send(text => Encode::encode('UTF-8', $_[1]));
}

sub send {
  my ($self, $type, $data) = @_;

  if ($self->{handshake}) {
    carp "tried to send data before finishing handshake";
    return 0;
  }

  my $frame = new Protocol::WebSocket::Frame(type => $type, max_payload_size => $self->{max_send_size});
  $frame->append($data) if defined $data;

  my $bytes = eval { $frame->to_bytes };
  if (!defined $bytes) {
    carp "error while building message: $@" if $@;
    return;
  }

  syswrite($self->{socket}, $bytes);
}

sub recv {
  my ($self) = @_;

  if ($self->{needs_ssl}) {
    my $ssl_done = $self->{socket}->accept_SSL;
    if ($self->{socket}->errstr) {
      $self->disconnect;
      return;
    }
    return unless $ssl_done;
    $self->{needs_ssl} = 0;
  }

  my ($len, $data) = (0, "");
  if (!($len = sysread($self->{socket}, $data, 8192))) {
    $self->disconnect();
    return;
  }

  # read remaining data
  $len = sysread($self->{socket}, $data, 8192, length($data)) while $len >= 8192;

  if ($self->{handshake}) {
    $self->{handshake}->parse($data);
    if ($self->{handshake}->error) {
      $self->disconnect(1002);
    } elsif ($self->{handshake}->is_done) {
      $self->_event(on_handshake => $self->{handshake});
      return unless do { local $SIG{__WARN__} = sub{}; $self->{socket}->connected };

      syswrite($self->{socket}, $self->{handshake}->to_string);
      delete $self->{handshake};

      $self->{parser} = new Protocol::WebSocket::Frame(max_payload_size => $self->{max_recv_size});
      setsockopt($self->{socket}, IPPROTO_TCP, TCP_NODELAY, 1) if $self->{nodelay};
      $self->_event('on_ready');
    }
    return;
  }

  $self->{parser}->append($data);

  my $bytes;
  while (defined ($bytes = eval { $self->{parser}->next_bytes })) {
    if ($self->{parser}->is_binary) {
      $self->_event(on_binary => $bytes);
    } elsif ($self->{parser}->is_text) {
      $self->_event(on_utf8 => Encode::decode('UTF-8', $bytes));
    } elsif ($self->{parser}->is_pong) {
      $self->_event(on_pong => $bytes);
    } elsif ($self->{parser}->is_close) {
      $self->disconnect(length $bytes ? unpack("na*",$bytes) : ());
      return;
    }
  }

  if ($@) {
    $self->disconnect(1002);
    return;
  }
}

### internal methods

sub _event {
  my ($self, $event, @args) = @_;
  $self->{$event}($self, @args);
}

1; # End of Net::WebSocket::Server

__END__

=head1 NAME

Net::WebSocket::Server::Connection - A WebSocket connection managed by L<Net::WebSocket::Server|Net::WebSocket::Server>. 

=head1 SYNOPSIS

Within the L<connect|Net::WebSocket::Server/connect> callback of a
L<Net::WebSocket::Server>,

    $conn->on(
        utf8 => sub {
            my ($conn, $msg) = @_;
            $conn->send_utf8($msg);
        },
    );

=head1 DESCRIPTION

This module provides an interface to a WebSocket connection including
handshakes and sending / receiving messages.  It is constructed by a running
L<Net::WebSocket::Server|Net::WebSocket::Server> and passed to the registered
L<connect|Net::WebSocket::Server/connect> handler there for configuration.

=head1 CONSTRUCTION

=over

=item C<< Net::WebSocket::Server::Connection->new(I<%opts>) >>

Creates a new C<Net::WebSocket::Server::Connection> object with the given
configuration.  This is typically done for you by
L<Net::WebSocket::Server|Net::WebSocket::Server>; you rarely need to construct
your own explicitly.  Takes the following parameters:

=over

=item C<socket>

The underlying L<IO::Socket|IO::Socket>-like object.  Once set, this cannot be
changed.  Required.

=item C<server>

The associated L<Net::WebSocket::Server|Net::WebSocket::Server> object.  Once
set, this cannot be changed.  Required.

=item C<nodelay>

A boolean value indicating whether C<TCP_NODELAY> should be set on the socket
after the handshake is complete.  Default C<1>.  See L<nodelay()|/nodelay([$enable])>.

=item C<max_send_size>

The maximum size of an outgoing payload.  Default
C<< Protocol::WebSocket::Frame->new->{max_payload_size} >>.

When building an outgoing message, this value is passed to new instances of
L<Protocol::WebSocket::Frame|Protocol::WebSocket::Frame> as the
C<max_payload_size> parameter.

=item C<max_recv_size>

The maximum size of an incoming payload.  Default
C<< Protocol::WebSocket::Frame->new->{max_payload_size} >>.

Once the handshake process is complete, this value is passed to the parser
instance of L<Protocol::WebSocket::Frame|Protocol::WebSocket::Frame> as the
C<max_payload_size> parameter.

=item C<on_C<$event>>

The callback to invoke when the given C<$event> occurs, such as C<ready>.  See
L</EVENTS>.

=back

=back

=head1 METHODS

=over

=item C<on(I<%events>)>

    $connection->on(
        utf8 => sub { ... },
    ),

Takes a list of C<< $event => $callback >> pairs; C<$event> names should not
include an C<on_> prefix.  See L</EVENTS>.

=item C<server()>

Returns the associated L<Net::WebSocket::Server|Net::WebSocket::Server> object.

=item C<socket()>

Returns the underlying socket object.

=item C<is_ready()>

Returns true if the connection is fully established and ready for data, or
false if the connection is in the middle of the handshake process.

=item C<ip()>

Returns the remote IP of the connection.

=item C<port()>

Returns the remote TCP port of the connection. (This will be some high-numbered
port chosen by the remote host; it can be useful during debugging to help humans
tell apart connections from the same IP.)

=item C<nodelay([I<$enable>])>

A boolean value indicating whether C<TCP_NODELAY> should be set on the socket
after the handshake is complete.  If the handshake is already complete,
immediately modifies the socket's C<TCP_NODELAY> setting.

This setting indicates to the operating system that small packets should not be
delayed for bundling into fewer, larger packets, but should instead be sent
immediately.  While enabling this setting can incur additional strain on the
network, it tends to be the desired behavior for WebSocket servers, so it is
enabled by default.

=item C<max_send_size([I<$size>])>

Sets the maximum allowed size of an outgoing payload.  Returns the current or
newly-set value.

When building an outgoing message, this value is passed to new instances of
L<Protocol::WebSocket::Frame|Protocol::WebSocket::Frame> as the
C<max_payload_size> parameter.

=item C<max_recv_size([I<$size>])>

Sets the maximum allowed size of an incoming payload.  Returns the current or
newly-set value.

Once the handshake process is complete, this value is passed to the parser
instance of L<Protocol::WebSocket::Frame|Protocol::WebSocket::Frame> as the
C<max_payload_size> parameter.

This value cannot be modified once the handshake is completed.

=item C<disconnect(I<$code>, I<$reason>)>

Invokes the registered C<disconnect> handler, sends a C<close> packet with the
given C<$code> and C<$reason>, and disconnects the socket.

=item C<send_utf8(I<$message>)>

Sends a C<utf8> message with the given content.  The message will be
UTF8-encoded automatically.

=item C<send_binary(I<$message>)>

Sends a C<binary> message with the given content.

=item C<send(I<$type>, I<$raw_data>)>

Sends a message with the given type and content.  Typically, one should use the
L<send_utf8()|/send_utf8> and L<send_binary()|/send_binary> methods instead.

=item C<recv()>

Attempts to read from the socket, invoking callbacks for any received messages.
The associated L<Net::WebSocket::Server|Net::WebSocket::Server> will call this
automatically when data is ready to be read.

=back

=head1 EVENTS

Attach a callback for an event by either passing C<on_$event> parameters to the
L<constructor|/CONSTRUCTION> or by passing C<$event> parameters to the L<on()|/on> method.

=over

=item C<handshake(I<$connection>, I<$handshake>)>

Invoked when a handshake message has been received from the client; the
C<$handshake> parameter is the underlying
L<Protocol::WebSocket::Handshake::Server|Protocol::WebSocket::Handshake::Server>
object.  Use this event to inspect the handshake origin, cookies, etc for
validity.  To abort the handshake process, call
L<< $connection->disconnect()|/disconnect >>.

For example:

    if ($handshake->req->origin ne $expected_origin) {
      $connection->disconnect();
      return;
    }

    if ($handshake->req->subprotocol ne $expected_subprotocol) {
      $connection->disconnect();
      return;
    }

=item C<ready(I<$connection>)>

Invoked when the handshake has been completed and the connection is ready to
send and receive WebSocket messages.  Use this event to perform any final
initialization or for the earliest chance to send messages to the client.

=item C<disconnect(I<$connection>, I<$code>, I<$reason>)>

Invoked when the connection is disconnected for any reason.  The C<$code> and
C<$reason>, if any, are also provided.  Use this event for last-minute cleanup
of the connection, but by this point it may not be safe to assume that sent
messages will be received.

=item C<utf8(I<$connection>, I<$message>)>

Invoked when a C<utf8> message is received from the client.  The C<$message>,
if any, is decoded and provided.

=item C<binary(I<$connection>, I<$message>)>

Invoked when a C<binary> message is received from the client.  The C<$message>,
if any, is provided.

=item C<pong(I<$connection>, I<$message>)>

Invoked when a C<pong> message is received from the client.  The C<$message>,
if any, is provided.  If the associated
L<Net::WebSocket::Server|Net::WebSocket::Server> object is configured with a
nonzero L<silence_max|Net::WebSocket::Server/silence_max>, this event will
also occur in response to the C<ping> messages automatically sent to keep the
connection alive.

=back

=head1 AUTHOR

Eric Wastl, C<< <topaz at cpan.org> >>

=head1 SEE ALSO

L<Net::WebSocket::Server|Net::WebSocket::Server>

=head1 LICENSE AND COPYRIGHT

Copyright 2013 Eric Wastl.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
