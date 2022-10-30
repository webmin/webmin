package Net::WebSocket::Server;

use 5.006;
use strict;
use warnings FATAL => 'all';

use Carp;
use IO::Socket::INET;
use IO::Select;
use Net::WebSocket::Server::Connection;
use Time::HiRes qw(time);
use List::Util qw(min);

our $VERSION = '0.004000';
$VERSION = eval $VERSION;

$SIG{PIPE} = 'IGNORE';

sub new {
  my $class = shift;

  my %params = @_;

  my $self = {
    listen         => 80,
    silence_max    => 20,
    tick_period    => 0,
    watch_readable => [],
    watch_writable => [],
    on_connect     => sub{},
    on_tick        => sub{},
    on_shutdown    => sub{},
  };

  while (my ($key, $value) = each %params ) {
    croak "Invalid $class parameter '$key'" unless exists $self->{$key};
    croak "$class parameter '$key' expected type is ".ref($self->{$key}) if ref $self->{$key} && ref $value ne ref $self->{$key};
    $self->{$key} = $value;
  }

  bless $self, $class;

  # send a ping every silence_max by checking whether data was received in the last silence_max/2
  $self->{silence_checkinterval} = $self->{silence_max} / 2;

  foreach my $watchtype (qw(readable writable)) {
    $self->{"select_$watchtype"} = IO::Select->new();
    my $key = "watch_$watchtype";
    croak "$class parameter '$key' expects an arrayref containing an even number of elements" unless @{$self->{$key}} % 2 == 0;
    my @watch = @{$self->{$key}};
    $self->{$key} = {};
    $self->_watch($watchtype, @watch);
  }

  return $self;
}

sub watch_readable {
  my $self = shift;
  croak "watch_readable expects an even number of arguments" unless @_ % 2 == 0;
  $self->_watch(readable => @_);
}

sub watched_readable {
  my $self = shift;
  return $self->{watch_readable}{$_[0]}{cb} if @_;
  return map {$_->{fh}, $_->{cb}} values %{$self->{watch_readable}};
}

sub watch_writable {
  my $self = shift;
  croak "watch_writable expects an even number of arguments" unless @_ % 2 == 0;
  $self->_watch(writable => @_);
}

sub watched_writable {
  my $self = shift;
  return $self->{watch_writable}{$_[0]}{cb} if @_;
  return map {$_->{fh}, $_->{cb}} values %{$self->{watch_writable}};
}

sub _watch {
  my $self = shift;
  my $watchtype = shift;
  croak "watch_$watchtype expects an even number of arguments after the type" unless @_ % 2 == 0;
  for (my $i = 0; $i < @_; $i+=2) {
    my ($fh, $cb) = ($_[$i], $_[$i+1]);
    croak "watch_$watchtype expects the second value of each pair to be a coderef, but element $i was not" unless ref $cb eq 'CODE';
    if ($self->{"watch_$watchtype"}{$fh}) {
      carp "watch_$watchtype was given a filehandle at index $i which is already being watched; ignoring!";
      next;
    }
    $self->{"select_$watchtype"}->add($fh);
    $self->{"watch_$watchtype"}{$fh} = {fh=>$fh, cb=>$cb};
  }
}

sub unwatch_readable {
  my $self = shift;
  $self->_unwatch(readable => @_);
}

sub unwatch_writable {
  my $self = shift;
  $self->_unwatch(writable => @_);
}

sub _unwatch {
  my $self = shift;
  my $watchtype = shift;
  foreach my $fh (@_) {
    $self->{"select_$watchtype"}->remove($fh);
    delete $self->{"watch_$watchtype"}{$fh};
  }
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

sub start {
  my $self = shift;

  if (ref $self->{listen}) {
    # if we got a server, make sure it's valid by clearing errors and checking errors anyway; if there's still an error, it's closed
    $self->{listen}->clearerr;
    croak "failed to start websocket server; the TCP server provided via 'listen' is invalid. (is the listening socket is closed? are you trying to reuse a server that has already shut down?)"
       if $self->{listen}->error;
  } else {
    # if we merely got a port, set up a reasonable default tcp server
    $self->{listen} = IO::Socket::INET->new(
      Listen    => 5,
      LocalPort => $self->{listen},
      Proto     => 'tcp',
      ReuseAddr => 1,
    ) || croak "failed to listen on port $self->{listen}: $!";
  }

  $self->{select_readable}->add($self->{listen});

  $self->{conns} = {};
  my $silence_nextcheck = $self->{silence_max} ? (time + $self->{silence_checkinterval}) : 0;
  my $tick_next = $self->{tick_period} ? (time + $self->{tick_period}) : 0;

  while ($self->{listen}->opened) {
    my $silence_checktimeout = $self->{silence_max} ? ($silence_nextcheck - time) : undef;
    my $tick_timeout = $self->{tick_period} ? ($tick_next - time) : undef;
    my $timeout = min(grep {defined} ($silence_checktimeout, $tick_timeout));

    my ($ready_read, $ready_write, undef) = IO::Select->select($self->{select_readable}, $self->{select_writable}, undef, $timeout);
    foreach my $fh ($ready_read ? @$ready_read : ()) {
      if ($fh == $self->{listen}) {
        my $sock = $self->{listen}->accept;
        next unless $sock;
        my $conn = new Net::WebSocket::Server::Connection(socket => $sock, server => $self);
        $self->{conns}{$sock} = {conn=>$conn, lastrecv=>time};
        $self->{select_readable}->add($sock);
        $self->{on_connect}($self, $conn);
      } elsif ($self->{watch_readable}{$fh}) {
        $self->{watch_readable}{$fh}{cb}($self, $fh);
      } elsif ($self->{conns}{$fh}) {
        my $connmeta = $self->{conns}{$fh};
        $connmeta->{lastrecv} = time;
        $connmeta->{conn}->recv();
      } else {
        warn "filehandle $fh became readable, but no handler took responsibility for it; removing it";
        $self->{select_readable}->remove($fh);
      }
    }

    foreach my $fh ($ready_write ? @$ready_write : ()) {
      if ($self->{watch_writable}{$fh}) {
        $self->{watch_writable}{$fh}{cb}($self, $fh);
      } else {
        warn "filehandle $fh became writable, but no handler took responsibility for it; removing it";
        $self->{select_writable}->remove($fh);
      }
    }

    if ($self->{silence_max}) {
      my $now = time;
      if ($silence_nextcheck < $now) {
        my $lastcheck = $silence_nextcheck - $self->{silence_checkinterval};
        $_->{conn}->send('ping') for grep { $_->{conn}->is_ready && $_->{lastrecv} < $lastcheck } values %{$self->{conns}};

        $silence_nextcheck = $now + $self->{silence_checkinterval};
      }
    }

    if ($self->{tick_period} && $tick_next < time) {
      $self->{on_tick}($self);
      $tick_next += $self->{tick_period};
    }
  }
}

sub connections { grep {$_->is_ready} map {$_->{conn}} values %{$_[0]{conns}} }

sub shutdown {
  my ($self) = @_;
  $self->{on_shutdown}($self);
  $self->{select_readable}->remove($self->{listen});
  $self->{listen}->shutdown(2);
  $self->{listen}->close();
  $_->disconnect(1001) for $self->connections;
}

sub disconnect {
  my ($self, $fh) = @_;
  $self->{select_readable}->remove($fh);
  $fh->close();
  delete $self->{conns}{$fh};
}

1; # End of Net::WebSocket::Server

__END__

=head1 NAME

Net::WebSocket::Server -  A straightforward Perl WebSocket server with minimal dependencies. 

=head1 SYNOPSIS

Simple echo server for C<utf8> messages.

    use Net::WebSocket::Server;

    Net::WebSocket::Server->new(
        listen => 8080,
        on_connect => sub {
            my ($serv, $conn) = @_;
            $conn->on(
                utf8 => sub {
                    my ($conn, $msg) = @_;
                    $conn->send_utf8($msg);
                },
            );
        },
    )->start;

Server that sends the current time to all clients every second.

    use Net::WebSocket::Server;

    my $ws = Net::WebSocket::Server->new(
        listen => 8080,
        tick_period => 1,
        on_tick => sub {
            my ($serv) = @_;
            $_->send_utf8(time) for $serv->connections;
        },
    )->start;

Broadcast-echo server for C<utf8> and C<binary> messages with origin testing.

    use Net::WebSocket::Server;

    my $origin = 'http://example.com';

    Net::WebSocket::Server->new(
        listen => 8080,
        on_connect => sub {
            my ($serv, $conn) = @_;
            $conn->on(
                handshake => sub {
                    my ($conn, $handshake) = @_;
                    $conn->disconnect() unless $handshake->req->origin eq $origin;
                },
                utf8 => sub {
                    my ($conn, $msg) = @_;
                    $_->send_utf8($msg) for $conn->server->connections;
                },
                binary => sub {
                    my ($conn, $msg) = @_;
                    $_->send_binary($msg) for $conn->server->connections;
                },
            );
        },
    )->start;

See L</listen> for an example of setting up an SSL (C<wss://...>) server.

=head1 DESCRIPTION

This module implements the details of a WebSocket server and invokes the
provided callbacks whenever something interesting happens.  Individual
connections to the server are represented as
L<Net::WebSocket::Server::Connection|Net::WebSocket::Server::Connection>
objects.

=head1 CONSTRUCTION

=over

=item C<< Net::WebSocket::Server->new(I<%opts>) >>

    Net::WebSocket::Server->new(
        listen => 8080,
        on_connect => sub { ... },
    )

Creates a new C<Net::WebSocket::Server> object with the given configuration.
Takes the following parameters:

=over

=item C<listen>

If not a reference, the TCP port on which to listen.  If a reference, a
preconfigured L<IO::Socket::INET|IO::Socket::INET> TCP server to use.  Default C<80>.

To create an SSL WebSocket server (such that you can connect to it via a
C<wss://...> URL), pass an object which acts like L<IO::Socket::INET|IO::Socket::INET>
and speaks SSL, such as L<IO::Socket::SSL|IO::Socket::SSL>. To avoid blocking
during the SSL handshake, pass C<< SSL_startHandshake => 0 >> to the
L<IO::Socket::SSL|IO::Socket::SSL> constructor and the handshake will be handled
automatically as part of the normal server loop.  For example:

    my $ssl_server = IO::Socket::SSL->new(
      Listen             => 5,
      LocalPort          => 8080,
      Proto              => 'tcp',
      SSL_startHandshake => 0,
      SSL_cert_file      => '/path/to/server.crt',
      SSL_key_file       => '/path/to/server.key',
    ) or die "failed to listen: $!";

    Net::WebSocket::Server->new(
        listen => $ssl_server,
        on_connect => sub { ... },
    )->start;

=item C<silence_max>

The maximum amount of time in seconds to allow silence on each connection's
socket.  Every C<silence_max/2> seconds, each connection is checked for
whether data was received since the last check; if not, a WebSocket ping
message is sent.  Set to C<0> to disable.  Default C<20>.

=item C<tick_period>

The amount of time in seconds between C<tick> events.  Set to C<0> to disable.
Default C<0>.

=item C<on_C<$event>>

The callback to invoke when the given C<$event> occurs, such as C<on_connect>.
See L</EVENTS>.

=item C<watch_readable>

=item C<watch_writable>

Each of these takes an I<arrayref> of C<< $filehandle => $callback >> pairs to be
passed to the corresponding method.  Default C<[]>.  See
L<watch_readable()|/watch_readable(@pairs)> and
L<watch_writable()|/watch_writable(@pairs)>.  For example:

    Net::WebSocket::Server->new(
        # ...other relevant arguments...
        watch_readable => [
            \*STDIN => \&on_stdin,
        ],
        watch_writable => [
            $log1_fh => sub { ... },
            $log2_fh => sub { ... },
        ],
    )->start;

=back

=back

=head1 METHODS

=over

=item C<on(I<%events>)>

    $server->on(
        connect => sub { ... },
    );

Takes a list of C<< $event => $callback >> pairs; C<$event> names should not
include an C<on_> prefix.  Typically, events are configured once via the
L<constructor|/CONSTRUCTION> rather than later via this method.  See L</EVENTS>.

=item C<start()>

Starts the WebSocket server; registered callbacks will be invoked as
interesting things happen.  Does not return until L<shutdown()|/shutdown> is
called.

=item C<connections()>

Returns a list of the current
L<Net::WebSocket::Server::Connection|Net::WebSocket::Server::Connection>
objects.

=item C<disconnect(I<$socket>)>

Immediately disconnects the given C<$socket> without calling the corresponding
connection's callback or cleaning up the socket.  For that, see
L<Net::WebSocket::Server::Connection/disconnect>, which ultimately calls this
function anyway.

=item C<shutdown()>

Closes the listening socket and cleanly disconnects all clients, causing the
L<start()|/start> method to return.

=item C<watch_readable(I<@pairs>)>

    $server->watch_readable(
      \*STDIN => \&on_stdin,
    );

Takes a list of C<< $filehandle => $callback >> pairs.  The given filehandles
will be monitored for readability; when readable, the given callback will be
invoked.  Arguments passed to the callback are the server itself and the
filehandle which became readable.

=item C<watch_writable(I<@pairs>)>

    $server->watch_writable(
      $log1_fh => sub { ... },
      $log2_fh => sub { ... },
    );

Takes a list of C<< $filehandle => $callback >> pairs.  The given filehandles
will be monitored for writability; when writable, the given callback will be
invoked.  Arguments passed to the callback are the server itself and the
filehandle which became writable.

=item C<watched_readable([I<$filehandle>])>

=item C<watched_writable([I<$filehandle>])>

These methods return a list of C<< $filehandle => $callback >> pairs that are
curently being watched for readability / writability.  If a filehandle is
given, its callback is returned, or C<undef> if it isn't being watched.

=item C<unwatch_readable(I<@filehandles>)>

=item C<unwatch_writable(I<@filehandles>)>

These methods cause the given filehandles to no longer be watched for
readability / writability.

=back

=head1 EVENTS

Attach a callback for an event by either passing C<on_$event> parameters to the
L<constructor|/CONSTRUCTION> or by passing C<$event> parameters to the
L<on()|/on> method.

=over

=item C<connect(I<$server>, I<$connection>)>

Invoked when a new connection is made.  Use this event to configure the
newly-constructed
L<Net::WebSocket::Server::Connection|Net::WebSocket::Server::Connection>
object.  Arguments passed to the callback are the server accepting the
connection and the new connection object itself.

=item C<tick(I<$server>)>

Invoked every L<tick_period|/tick_period> seconds, or never if
L<tick_period|/tick_period> is C<0>.  Useful to perform actions that aren't in
response to a message from a client.  Arguments passed to the callback are only
the server itself.

=item C<shutdown(I<$server>)>

Invoked immediately before the server shuts down due to the L<shutdown()>
method being invoked.  Any client connections will still be available until
the event handler returns.  Arguments passed to the callback are only the
server that is being shut down.

=back

=head1 CAVEATS

When loaded (via C<use>, at C<BEGIN>-time), this module installs a C<SIGPIPE> handler of C<'IGNORE'>.  Write failures are handled situationally rather than in a global C<SIGPIPE> handler, but this still must be done to prevent the signal from killing the server process.  If you require your own C<SIGPIPE> handler, assign to C<$SIG{PIPE}> after this module is loaded.

=head1 AUTHOR

Eric Wastl, C<< <topaz at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-net-websocket-server at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Net-WebSocket-Server>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Net::WebSocket::Server

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Net-WebSocket-Server>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Net-WebSocket-Server>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Net-WebSocket-Server>

=item * Search CPAN

L<http://search.cpan.org/dist/Net-WebSocket-Server/>

=back

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
