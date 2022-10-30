package Protocol::WebSocket::Request;

use strict;
use warnings;

use base 'Protocol::WebSocket::Message';

require Carp;
use MIME::Base64 ();

use Protocol::WebSocket::Cookie::Request;

sub new {
    my $self = shift->SUPER::new(@_);
    my (%params) = @_;

    $self->{headers} = $params{headers} || [];

    return $self;
}

sub new_from_psgi {
    my $class = shift;
    my $env = @_ > 1 ? {@_} : shift;

    Carp::croak('env is required') unless keys %$env;

    my $version = '';

    my $cookies;

    my $fields = {
        upgrade    => $env->{HTTP_UPGRADE},
        connection => $env->{HTTP_CONNECTION},
        host       => $env->{HTTP_HOST},
    };

    if ($env->{HTTP_WEBSOCKET_PROTOCOL}) {
        $fields->{'websocket-protocol'} =
          $env->{HTTP_WEBSOCKET_PROTOCOL};
    }
    elsif ($env->{HTTP_SEC_WEBSOCKET_PROTOCOL}) {
        $fields->{'sec-websocket-protocol'} =
          $env->{HTTP_SEC_WEBSOCKET_PROTOCOL};
    }

    if (exists $env->{HTTP_SEC_WEBSOCKET_VERSION}) {
        $fields->{'sec-websocket-version'} =
          $env->{HTTP_SEC_WEBSOCKET_VERSION};
        if ($env->{HTTP_SEC_WEBSOCKET_VERSION} eq '13') {
            $version = 'draft-ietf-hybi-17';
        }
        else {
            $version = 'draft-ietf-hybi-10';
        }
    }

    if ($env->{HTTP_SEC_WEBSOCKET_KEY}) {
        $fields->{'sec-websocket-key'} = $env->{HTTP_SEC_WEBSOCKET_KEY};
    }
    elsif ($env->{HTTP_SEC_WEBSOCKET_KEY1}) {
        $version = 'draft-ietf-hybi-00';
        $fields->{'sec-websocket-key1'} = $env->{HTTP_SEC_WEBSOCKET_KEY1};
        $fields->{'sec-websocket-key2'} = $env->{HTTP_SEC_WEBSOCKET_KEY2};
    }

    if ($version eq 'draft-ietf-hybi-10') {
        $fields->{'sec-websocket-origin'} = $env->{HTTP_SEC_WEBSOCKET_ORIGIN};
    }
    else {
        $fields->{origin} = $env->{HTTP_ORIGIN};
    }

    if ($env->{HTTP_COOKIE}) {
        $cookies = Protocol::WebSocket::Cookie->new->parse($env->{HTTP_COOKIE});
    }

    my $self = $class->new(
        version       => $version,
        fields        => $fields,
        cookies       => $cookies,
        resource_name => "$env->{SCRIPT_NAME}$env->{PATH_INFO}"
          . ($env->{QUERY_STRING} ? "?$env->{QUERY_STRING}" : "")
    );
    $self->state('body');

    if (   $env->{HTTP_X_FORWARDED_PROTO}
        && $env->{HTTP_X_FORWARDED_PROTO} eq 'https')
    {
        $self->secure(1);
    }

    return $self;
}

sub cookies {
    if(@_ > 1) {
        my $cookie = Protocol::WebSocket::Cookie->new;
        return unless $_[1];

        if (my $cookies = $cookie->parse($_[1])) {
            $_[0]->{cookies} = $cookies;
        }
    } else {
        return $_[0]->{cookies};
    }
}

sub resource_name {
    @_ > 1 ? $_[0]->{resource_name} = $_[1] : $_[0]->{resource_name} || '/';
}

sub upgrade    { shift->field('Upgrade') }
sub connection { shift->field('Connection') }

sub number1 { shift->_number('number1', 'key1', @_) }
sub number2 { shift->_number('number2', 'key2', @_) }

sub key  { shift->_key('key'  => @_) }
sub key1 { shift->_key('key1' => @_) }
sub key2 { shift->_key('key2' => @_) }

sub to_string {
    my $self = shift;

    my $version = $self->version || 'draft-ietf-hybi-17';

    my $string = '';

    Carp::croak(qq/resource_name is required/)
      unless defined $self->resource_name;
    $string .= "GET " . $self->resource_name . " HTTP/1.1\x0d\x0a";

    $string .= "Upgrade: WebSocket\x0d\x0a";
    $string .= "Connection: Upgrade\x0d\x0a";

    Carp::croak(qq/Host is required/) unless defined $self->host;
    $string .= "Host: " . $self->host . "\x0d\x0a";

    if (ref $self->{cookies} eq 'Protocol::WebSocket::Cookie') {
        my $cookie_string = $self->{cookies}->to_string;
        $string .= 'Cookie: ' . $cookie_string . "\x0d\x0a"
            if $cookie_string;
    }

    my $origin = $self->origin ? $self->origin : 'http://' . $self->host;
    $origin =~ s{^http:}{https:} if $self->secure;
    $string .= (
        $version eq 'draft-ietf-hybi-10'
        ? "Sec-WebSocket-Origin"
        : "Origin"
      )
      . ': '
      . $origin
      . "\x0d\x0a";

    if ($version eq 'draft-ietf-hybi-10' || $version eq 'draft-ietf-hybi-17') {
        my $key = $self->key;

        if (!$key) {
            $key = '';
            $key .= chr(int(rand(256))) for 1 .. 16;

            $key = MIME::Base64::encode_base64($key);
            $key =~ s{\s+}{}g;
        }

        $string
          .= 'Sec-WebSocket-Protocol: ' . $self->subprotocol . "\x0d\x0a"
          if defined $self->subprotocol;

        $string .= 'Sec-WebSocket-Key: ' . $key . "\x0d\x0a";
        $string
          .= 'Sec-WebSocket-Version: '
          . ($version eq 'draft-ietf-hybi-17' ? 13 : 8)
          . "\x0d\x0a";
    }
    elsif ($version eq 'draft-ietf-hybi-00') {
        $self->_generate_keys;

        $string
          .= 'Sec-WebSocket-Protocol: ' . $self->subprotocol . "\x0d\x0a"
          if defined $self->subprotocol;

        $string .= 'Sec-WebSocket-Key1: ' . $self->key1 . "\x0d\x0a";
        $string .= 'Sec-WebSocket-Key2: ' . $self->key2 . "\x0d\x0a";

        $string .= 'Content-Length: ' . length($self->challenge) . "\x0d\x0a";
    }
    elsif ($version eq 'draft-hixie-75') {
        $string .= 'WebSocket-Protocol: ' . $self->subprotocol . "\x0d\x0a"
          if defined $self->subprotocol;
    }
    else {
        Carp::croak('Version ' . $self->version . ' is not supported');
    }
    my @headers = @{$self->{headers}};
    while (my ($key, $value) = splice @headers, 0, 2) {
        $key =~ s{[\x0d\x0a]}{}gsm;
        $value =~ s{[\x0d\x0a]}{}gsm;

        $string .= "$key: $value\x0d\x0a";
    }

    $string .= "\x0d\x0a";

    $string .= $self->challenge if $version eq 'draft-ietf-hybi-00';

    return $string;
}

sub parse {
    my $self = shift;

    my $retval = $self->SUPER::parse($_[0]);

    if (!$self->{finalized} && ($self->is_body || $self->is_done)) {
        $self->{finalized} = 1;

        if ($self->key1 && $self->key2) {
            $self->version('draft-ietf-hybi-00');
        }
        elsif ($self->key) {
            if ($self->field('sec-websocket-version') eq '13') {
                $self->version('draft-ietf-hybi-17');
            }
            else {
                $self->version('draft-ietf-hybi-10');
            }
        }
        else {
            $self->version('draft-hixie-75');
        }

        if (!$self->_finalize) {
            $self->error('Not a valid request');
            return;
        }
    }

    return $retval;
}

sub _parse_first_line {
    my ($self, $line) = @_;

    my ($req, $resource_name, $http) = split ' ' => $line;

    unless ($req && $resource_name && $http) {
        $self->error('Wrong request line');
        return;
    }

    unless ($req eq 'GET' && $http eq 'HTTP/1.1') {
        $self->error('Wrong method or http version');
        return;
    }

    $self->resource_name($resource_name);

    return $self;
}

sub _parse_body {
    my $self = shift;

    if ($self->key1 && $self->key2) {
        return 1 if length $self->{buffer} < 8;

        my $challenge = substr $self->{buffer}, 0, 8, '';
        $self->challenge($challenge);
    }

    if (length $self->{buffer}) {
        $self->error('Leftovers');
        return;
    }

    return $self;
}

sub _number {
    my $self = shift;
    my ($name, $key, $value) = @_;

    if (defined $value) {
        $self->{$name} = $value;
        return $self;
    }

    return $self->{$name} if defined $self->{$name};

    return $self->{$name} ||= $self->_extract_number($self->$key);
}

sub _key {
    my $self  = shift;
    my $name  = shift;
    my $value = shift;

    unless (defined $value) {
        if (my $value = delete $self->{$name}) {
            $self->field("Sec-WebSocket-" . ucfirst($name) => $value);
        }

        return $self->field("Sec-WebSocket-" . ucfirst($name));
    }

    $self->field("Sec-WebSocket-" . ucfirst($name) => $value);

    return $self;
}

sub _generate_keys {
    my $self = shift;

    unless ($self->key1) {
        my ($number, $key) = $self->_generate_key;
        $self->number1($number);
        $self->key1($key);
    }

    unless ($self->key2) {
        my ($number, $key) = $self->_generate_key;
        $self->number2($number);
        $self->key2($key);
    }

    $self->challenge($self->_generate_challenge) unless $self->challenge;

    return $self;
}

sub _generate_key {
    my $self = shift;

    # A random integer from 1 to 12 inclusive
    my $spaces = int(rand(12)) + 1;

    # The largest integer not greater than 4,294,967,295 divided by spaces
    my $max = int(4_294_967_295 / $spaces);

    # A random integer from 0 to $max inclusive
    my $number = int(rand($max + 1));

    # The result of multiplying $number and $spaces together
    my $product = $number * $spaces;

    # A string consisting of $product, expressed in base ten
    my $key = "$product";

    # Insert between one and twelve random characters from the ranges U+0021
    # to U+002F and U+003A to U+007E into $key at random positions.
    my $random_characters = int(rand(12)) + 1;

    for (1 .. $random_characters) {

        # From 0 to the last position
        my $random_position = int(rand(length($key) + 1));

        # Random character
        my $random_character = chr(
              int(rand(2))
            ? int(rand(0x2f - 0x21 + 1)) + 0x21
            : int(rand(0x7e - 0x3a + 1)) + 0x3a
        );

        # Insert random character at random position
        substr $key, $random_position, 0, $random_character;
    }

    # Insert $spaces U+0020 SPACE characters into $key at random positions
    # other than the start or end of the string.
    for (1 .. $spaces) {

        # From 1 to the last-1 position
        my $random_position = int(rand(length($key) - 1)) + 1;

        # Insert
        substr $key, $random_position, 0, ' ';
    }

    return ($number, $key);
}

sub _generate_challenge {
    my $self = shift;

    # A string consisting of eight random bytes (or equivalently, a random 64
    # bit integer encoded in big-endian order).
    my $challenge = '';

    $challenge .= chr(int(rand(256))) for 1 .. 8;

    return $challenge;
}

sub _finalize {
    my $self = shift;

    return unless $self->upgrade && lc $self->upgrade eq 'websocket';

    my $connection = $self->connection;
    return unless $connection;

    my @connections = split /\s*,\s*/, $connection;
    return unless grep { lc $_ eq 'upgrade' } @connections;

    my $origin = $self->field('Sec-WebSocket-Origin') || $self->field('Origin');
    #return unless $origin;
    $self->origin($origin);

    if (defined $self->origin) {
        $self->secure(1) if $self->origin =~ m{^https:};
    }

    my $host = $self->field('Host');
    return unless $host;
    $self->host($host);

    my $subprotocol = $self->field('Sec-WebSocket-Protocol')
      || $self->field('WebSocket-Protocol');
    $self->subprotocol($subprotocol) if $subprotocol;

    $self->cookies($self->field('Cookie'));
    return $self;
}

sub _build_cookie { Protocol::WebSocket::Cookie::Request->new }

1;
__END__

=head1 NAME

Protocol::WebSocket::Request - WebSocket Request

=head1 SYNOPSIS

    # Constructor
    my $req = Protocol::WebSocket::Request->new(
        host          => 'example.com',
        resource_name => '/demo'
    );
    $req->to_string; # GET /demo HTTP/1.1
                     # Upgrade: WebSocket
                     # Connection: Upgrade
                     # Host: example.com
                     # Origin: http://example.com
                     # Sec-WebSocket-Key1: 32 0  3lD& 24+<    i u4  8! -6/4
                     # Sec-WebSocket-Key2: 2q 4  2  54 09064
                     #
                     # x#####

    # Parser
    my $req = Protocol::WebSocket::Request->new;
    $req->parse("GET /demo HTTP/1.1\x0d\x0a");
    $req->parse("Upgrade: WebSocket\x0d\x0a");
    $req->parse("Connection: Upgrade\x0d\x0a");
    $req->parse("Host: example.com\x0d\x0a");
    $req->parse("Origin: http://example.com\x0d\x0a");
    $req->parse(
        "Sec-WebSocket-Key1: 18x 6]8vM;54 *(5:  {   U1]8  z [  8\x0d\x0a");
    $req->parse(
        "Sec-WebSocket-Key2: 1_ tx7X d  <  nw  334J702) 7]o}` 0\x0d\x0a");
    $req->parse("\x0d\x0aTm[K T2u");

=head1 DESCRIPTION

Construct or parse a WebSocket request.

=head1 ATTRIBUTES

=head2 C<host>

=head2 C<key1>

=head2 C<key2>

=head2 C<number1>

=head2 C<number2>

=head2 C<origin>

=head2 C<resource_name>

=head1 METHODS

=head2 C<new>

Create a new L<Protocol::WebSocket::Request> instance.

=head2 C<new_from_psgi>

    my $env = {
        HTTP_HOST => 'example.com',
        HTTP_CONNECTION => 'Upgrade',
        ...
    };
    my $req = Protocol::WebSocket::Request->new_from_psgi($env);

Create a new L<Protocol::WebSocket::Request> instance from L<PSGI> environment.

=head2 C<parse>

    $req->parse($buffer);
    $req->parse($handle);

Parse a WebSocket request. Incoming buffer is modified.

=head2 C<to_string>

Construct a WebSocket request.

=head2 C<connection>

    $self->connection;

A shortcut for C<$self->field('Connection')>.

=head2 C<cookies>

=head2 C<upgrade>

    $self->upgrade;

A shortcut for C<$self->field('Upgrade')>.

=cut
