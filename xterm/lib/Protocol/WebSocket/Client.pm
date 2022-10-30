package Protocol::WebSocket::Client;

use strict;
use warnings;

require Carp;
use Protocol::WebSocket::URL;
use Protocol::WebSocket::Handshake::Client;
use Protocol::WebSocket::Frame;

sub new {
    my $class = shift;
    $class = ref $class if ref $class;
    my (%params) = @_;

    my $self = {};
    bless $self, $class;

    Carp::croak('url is required') unless $params{url};
    $self->{url} = Protocol::WebSocket::URL->new->parse($params{url})
      or Carp::croak("Can't parse url");

    $self->{version} = $params{version};

    $self->{on_connect} = $params{on_connect};
    $self->{on_write} = $params{on_write};
    $self->{on_frame} = $params{on_frame};
    $self->{on_eof}   = $params{on_eof};
    $self->{on_error} = $params{on_error};

    $self->{hs} =
      Protocol::WebSocket::Handshake::Client->new(url => $self->{url});

    my %frame_buffer_params = (
        max_fragments_amount => $params{max_fragments_amount}
    );
    $frame_buffer_params{max_payload_size} = $params{max_payload_size} if exists $params{max_payload_size};

    $self->{frame_buffer} = $self->_build_frame(%frame_buffer_params);

    return $self;
}

sub url     { shift->{url} }
sub version { shift->{version} }

sub on {
    my $self = shift;
    my ($event, $cb) = @_;

    $self->{"on_$event"} = $cb;

    return $self;
}

sub read {
    my $self = shift;
    my ($buffer) = @_;

    my $hs           = $self->{hs};
    my $frame_buffer = $self->{frame_buffer};

    unless ($hs->is_done) {
        if (!$hs->parse($buffer)) {
            $self->{on_error}->($self, $hs->error);
            return $self;
        }

        $self->{on_connect}->($self) if $self->{on_connect} && $hs->is_done;
    }

    if ($hs->is_done) {
        $frame_buffer->append($buffer);

        while (my $bytes = $frame_buffer->next) {
            $self->{on_read}->($self, $bytes);

            #$self->{on_frame}->($self, $bytes);
        }
    }

    return $self;
}

sub write {
    my $self = shift;
    my ($buffer) = @_;

    my $frame =
      ref $buffer
      ? $buffer
      : $self->_build_frame(masked => 1, buffer => $buffer);
    $self->{on_write}->($self, $frame->to_bytes);

    return $self;
}

sub connect {
    my $self = shift;

    my $hs = $self->{hs};

    $self->{on_write}->($self, $hs->to_string);

    return $self;
}

sub disconnect {
    my $self = shift;

    my $frame = $self->_build_frame(type => 'close');

    $self->{on_write}->($self, $frame->to_bytes);

    return $self;
}

sub _build_frame {
    my $self = shift;

    return Protocol::WebSocket::Frame->new(version => $self->{version}, @_);
}

1;
__END__

=head1 NAME

Protocol::WebSocket::Client - WebSocket client

=head1 SYNOPSIS

    my $sock = ...get non-blocking socket...;

    my $client = Protocol::WebSocket->new(url => 'ws://localhost:3000');
    $client->on(
        write => sub {
            my $client = shift;
            my ($buf) = @_;

            syswrite $sock, $buf;
        }
    );
    $client->on(
        read => sub {
            my $client = shift;
            my ($buf) = @_;

            ...do smth with read data...
        }
    );

    # Sends a correct handshake header
    $client->connect;

    # Register on connect handler
    $client->on(
        connect => sub {
            $client->write('hi there');
        }
    );

    # Parses incoming data and on every frame calls on_read
    $client->read(...data from socket...);

    # Sends correct close header
    $client->disconnect;

=head1 DESCRIPTION

L<Protocol::WebSocket::Client> is a convenient class for writing a WebSocket
client.

=cut
