package Protocol::WebSocket::Handshake::Client;

use strict;
use warnings;

use base 'Protocol::WebSocket::Handshake';

require Carp;

use Protocol::WebSocket::URL;
use Protocol::WebSocket::Frame;

sub new {
    my $self = shift->SUPER::new(@_);

    $self->_set_url($self->{url}) if defined $self->{url};

    if (my $version = $self->{version}) {
        $self->req->version($version);
        $self->res->version($version);
    }

    return $self;
}

sub url {
    my $self = shift;
    my $url  = shift;

    return $self->{url} unless $url;

    $self->_set_url($url);

    return $self;
}

sub parse {
    my $self  = shift;

    my $req = $self->req;
    my $res = $self->res;

    unless ($res->is_done) {
        unless ($res->parse($_[0])) {
            $self->error($res->error);
            return;
        }

        if ($res->is_done) {
            if (   $req->version eq 'draft-ietf-hybi-00'
                && $req->checksum ne $res->checksum)
            {
                $self->error('Checksum is wrong.');
                return;
            }
        }
    }

    return 1;
}

sub is_done   { shift->res->is_done }
sub to_string { shift->req->to_string }

sub build_frame {
    my $self = shift;

    return Protocol::WebSocket::Frame->new(masked => 1, version => $self->version, @_);
}

sub _build_url { Protocol::WebSocket::URL->new }

sub _set_url {
    my $self = shift;
    my $url  = shift;

    $url = $self->_build_url->parse($url) unless ref $url;

    $self->req->secure(1) if $url->secure;

    my $req = $self->req;

    my $host = $url->host;
    $host .= ':' . $url->port
      if defined $url->port
      && ($url->secure ? $url->port ne '443' : $url->port ne '80');
    $req->host($host);

    $req->resource_name($url->resource_name);

    return $self;
}

1;
__END__

=head1 NAME

Protocol::WebSocket::Handshake::Client - WebSocket Client Handshake

=head1 SYNOPSIS

    my $h =
      Protocol::WebSocket::Handshake::Client->new(url => 'ws://example.com');

    # Create request
    $h->to_string;

    # Parse server response
    $h->parse(<<"EOF");
        WebSocket HTTP message
    EOF

    $h->error;   # Check if there were any errors
    $h->is_done; # Returns 1

=head1 DESCRIPTION

Construct or parse a client WebSocket handshake. This module is written for
convenience, since using request and response directly requires the same code
again and again.

=head1 ATTRIBUTES

=head2 C<url>

    $handshake->url('ws://example.com/demo');

Set or get WebSocket url.

=head1 METHODS

=head2 C<new>

Create a new L<Protocol::WebSocket::Handshake::Client> instance.

=head2 C<parse>

    $handshake->parse($buffer);

Parse a WebSocket server response. Returns C<undef> and sets C<error> attribute
on error. Buffer is modified.

=head2 C<to_string>

Construct a WebSocket client request.

=head2 C<is_done>

Check whether handshake is done.

=cut
