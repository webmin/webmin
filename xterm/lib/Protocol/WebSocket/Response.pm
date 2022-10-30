package Protocol::WebSocket::Response;

use strict;
use warnings;

use base 'Protocol::WebSocket::Message';

require Carp;
use MIME::Base64 ();
use Digest::SHA ();

use Protocol::WebSocket::URL;
use Protocol::WebSocket::Cookie::Response;

sub location { @_ > 1 ? $_[0]->{location} = $_[1] : $_[0]->{location} }

sub resource_name {
    @_ > 1 ? $_[0]->{resource_name} = $_[1] : $_[0]->{resource_name};
}

sub cookies { @_ > 1 ? $_[0]->{cookies} = $_[1] : $_[0]->{cookies} }

sub cookie {
    my $self = shift;

    push @{$self->{cookies}}, $self->_build_cookie(@_);
}

sub key { @_ > 1 ? $_[0]->{key} = $_[1] : $_[0]->{key} }

sub number1 { shift->_number('number1', 'key1', @_) }
sub number2 { shift->_number('number2', 'key2', @_) }

sub _number {
    my $self = shift;
    my ($name, $key, $value) = @_;

    my $method = "SUPER::$name";
    return $self->$method($value) if defined $value;

    $value = $self->$method();
    $value = $self->_extract_number($self->$key) if not defined $value;

    return $value;
}

sub key1 { @_ > 1 ? $_[0]->{key1} = $_[1] : $_[0]->{key1} }
sub key2 { @_ > 1 ? $_[0]->{key2} = $_[1] : $_[0]->{key2} }

sub status {
    return '101';
}

sub headers {
    my $self = shift;

    my $version = $self->version || 'draft-ietf-hybi-10';

    my $headers = [];

    push @$headers, Upgrade => 'WebSocket';
    push @$headers, Connection => 'Upgrade';

    if ($version eq 'draft-hixie-75' || $version eq 'draft-ietf-hybi-00') {
        Carp::croak(qq/host is required/) unless defined $self->host;

        my $location = $self->_build_url(
            host          => $self->host,
            secure        => $self->secure,
            resource_name => $self->resource_name,
        );
        my $origin =
          $self->origin ? $self->origin : 'http://' . $location->host;
        $origin =~ s{^http:}{https:} if !$self->origin && $self->secure;

        if ($version eq 'draft-hixie-75') {
            push @$headers, 'WebSocket-Protocol' => $self->subprotocol
              if defined $self->subprotocol;
            push @$headers, 'WebSocket-Origin'   => $origin;
            push @$headers, 'WebSocket-Location' => $location->to_string;
        }
        elsif ($version eq 'draft-ietf-hybi-00') {
            push @$headers, 'Sec-WebSocket-Protocol' => $self->subprotocol
              if defined $self->subprotocol;
            push @$headers, 'Sec-WebSocket-Origin'   => $origin;
            push @$headers, 'Sec-WebSocket-Location' => $location->to_string;
        }
    }
    elsif ($version eq 'draft-ietf-hybi-10' || $version eq 'draft-ietf-hybi-17') {
        Carp::croak(qq/key is required/) unless defined $self->key;

        my $key = $self->key;
        $key .= '258EAFA5-E914-47DA-95CA-C5AB0DC85B11'; # WTF
        $key = Digest::SHA::sha1($key);
        $key = MIME::Base64::encode_base64($key);
        $key =~ s{\s+}{}g;

        push @$headers, 'Sec-WebSocket-Accept' => $key;

        push @$headers, 'Sec-WebSocket-Protocol' => $self->subprotocol
          if defined $self->subprotocol;
    }
    else {
        Carp::croak('Version ' . $version . ' is not supported');
    }

    if (@{$self->cookies}) {
        my $cookie = join ',' => map { $_->to_string } @{$self->cookies};
        push @$headers, 'Set-Cookie' => $cookie;
    }

    return $headers;
}

sub body {
    my $self = shift;

    return $self->checksum if $self->version eq 'draft-ietf-hybi-00';

    return '';
}

sub to_string {
    my $self = shift;

    my $status = $self->status;

    my $string = '';
    $string .= "HTTP/1.1 $status WebSocket Protocol Handshake\x0d\x0a";

    for (my $i = 0; $i < @{$self->headers}; $i += 2) {
        my $key   = $self->headers->[$i];
        my $value = $self->headers->[$i + 1];

        $string .= "$key: $value\x0d\x0a";
    }

    $string .= "\x0d\x0a";

    $string .= $self->body;

    return $string;
}

sub _parse_first_line {
    my ($self, $line) = @_;

    my $status = $self->status;
    unless ($line =~ m{^HTTP/1\.1 $status }) {
        my $vis = $line;
        if( length( $vis ) > 80 ) {
            substr( $vis, 77 )= '...';
        }
        $self->error('Wrong response line. Got [[' . $vis . "]], expected [[HTTP/1.1 $status ]]");
        return;
    }

    return $self;
}

sub _parse_body {
    my $self = shift;

    if ($self->field('Sec-WebSocket-Accept')) {
        $self->version('draft-ietf-hybi-10');
    }
    elsif ($self->field('Sec-WebSocket-Origin')) {
        $self->version('draft-ietf-hybi-00');

        return 1 if length $self->{buffer} < 16;

        my $checksum = substr $self->{buffer}, 0, 16, '';
        $self->checksum($checksum);
    }
    else {
        $self->version('draft-hixie-75');
    }

    return $self if $self->_finalize;

    $self->error('Not a valid response');
    return;
}

sub _finalize {
    my $self = shift;

    if ($self->version eq 'draft-hixie-75') {
        my $location = $self->field('WebSocket-Location');
        return unless defined $location;
        $self->location($location);

        my $url = $self->_build_url;
        return unless $url->parse($self->location);

        $self->secure($url->secure);
        $self->host($url->host);
        $self->resource_name($url->resource_name);

        $self->origin($self->field('WebSocket-Origin'));

        $self->subprotocol($self->field('WebSocket-Protocol'));
    }
    elsif ($self->version eq 'draft-ietf-hybi-00') {
        my $location = $self->field('Sec-WebSocket-Location');
        return unless defined $location;
        $self->location($location);

        my $url = $self->_build_url;
        return unless $url->parse($self->location);

        $self->secure($url->secure);
        $self->host($url->host);
        $self->resource_name($url->resource_name);

        $self->origin($self->field('Sec-WebSocket-Origin'));
        $self->subprotocol($self->field('Sec-WebSocket-Protocol'));
    }
    else {
        $self->subprotocol($self->field('Sec-WebSocket-Protocol'));
    }

    return 1;
}

sub _build_url    { shift; Protocol::WebSocket::URL->new(@_) }
sub _build_cookie { shift; Protocol::WebSocket::Cookie::Response->new(@_) }

1;
__END__

=head1 NAME

Protocol::WebSocket::Response - WebSocket Response

=head1 SYNOPSIS

    # Constructor
    $res = Protocol::WebSocket::Response->new(
        host          => 'example.com',
        resource_name => '/demo',
        origin        => 'file://',
        number1       => 777_007_543,
        number2       => 114_997_259,
        challenge     => "\x47\x30\x22\x2D\x5A\x3F\x47\x58"
    );
    $res->to_string; # HTTP/1.1 101 WebSocket Protocol Handshake
                     # Upgrade: WebSocket
                     # Connection: Upgrade
                     # Sec-WebSocket-Origin: file://
                     # Sec-WebSocket-Location: ws://example.com/demo
                     #
                     # 0st3Rl&q-2ZU^weu

    # Parser
    $res = Protocol::WebSocket::Response->new;
    $res->parse("HTTP/1.1 101 WebSocket Protocol Handshake\x0d\x0a");
    $res->parse("Upgrade: WebSocket\x0d\x0a");
    $res->parse("Connection: Upgrade\x0d\x0a");
    $res->parse("Sec-WebSocket-Origin: file://\x0d\x0a");
    $res->parse("Sec-WebSocket-Location: ws://example.com/demo\x0d\x0a");
    $res->parse("\x0d\x0a");
    $res->parse("0st3Rl&q-2ZU^weu");

=head1 DESCRIPTION

Construct or parse a WebSocket response.

=head1 ATTRIBUTES

=head2 C<host>

=head2 C<location>

=head2 C<origin>

=head2 C<resource_name>

=head2 C<secure>

=head1 METHODS

=head2 C<new>

Create a new L<Protocol::WebSocket::Response> instance.

=head2 C<parse>

    $res->parse($buffer);

Parse a WebSocket response. Incoming buffer is modified.

=head2 C<to_string>

Construct a WebSocket response.

=head2 C<cookie>

=head2 C<cookies>

=head2 C<key>

=head2 C<key1>

    $self->key1;

Set or get C<Sec-WebSocket-Key1> field.

=head2 C<key2>

    $self->key2;

Set or get C<Sec-WebSocket-Key2> field.

=head2 C<number1>

    $self->number1;
    $self->number1(123456);

Set or extract from C<Sec-WebSocket-Key1> generated C<number> value.

=head2 C<number2>

    $self->number2;
    $self->number2(123456);

Set or extract from C<Sec-WebSocket-Key2> generated C<number> value.

=head2 C<status>

    $self->status;

Get response status (101).

=head2 C<body>

    $self->body;

Get response body.

=head2 C<headers>

    my $arrayref = $self->headers;

Get response headers.

=cut
