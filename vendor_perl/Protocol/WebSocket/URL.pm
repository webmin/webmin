package Protocol::WebSocket::URL;

use strict;
use warnings;

sub new {
    my $class = shift;
    $class = ref $class if ref $class;

    my $self = {@_};
    bless $self, $class;

    $self->{secure} ||= 0;

    return $self;
}

sub secure { @_ > 1 ? $_[0]->{secure} = $_[1] : $_[0]->{secure} }

sub host { @_ > 1 ? $_[0]->{host} = $_[1] : $_[0]->{host} }
sub port { @_ > 1 ? $_[0]->{port} = $_[1] : $_[0]->{port} }

sub resource_name {
    @_ > 1 ? $_[0]->{resource_name} = $_[1] : $_[0]->{resource_name};
}

sub parse {
    my $self   = shift;
    my $string = shift;

    my ($scheme) = $string =~ m{^(wss?)://};
    return unless $scheme;

    $self->secure(1) if $scheme =~ m/ss$/;

    my ($host, $port) = $string =~ m{^$scheme://([^:\/]+)(?::(\d+))?(?:|\/|$)};
    $host = '/' unless defined $host && $host ne '';
    $self->host($host);
    $port ||= $self->secure ? 443 : 80;
    $self->port($port);

    # path and query
    my ($pnq) = $string =~ m{^$scheme://(?:.*?)(/.*)$};
    $pnq = '/' unless defined $pnq && $pnq ne '';
    $self->resource_name($pnq);

    return $self;
}

sub to_string {
    my $self = shift;

    my $string = '';

    $string .= 'ws';
    $string .= 's' if $self->secure;
    $string .= '://';
    $string .= $self->host;
    $string .= ':' . $self->port if defined $self->port;
    $string .= $self->resource_name || '/';

    return $string;
}

1;
__END__

=head1 NAME

Protocol::WebSocket::URL - WebSocket URL

=head1 SYNOPSIS

    # Construct
    my $url = Protocol::WebSocket::URL->new;
    $url->host('example.com');
    $url->port('3000');
    $url->secure(1);
    $url->to_string; # wss://example.com:3000

    # Parse
    my $url = Protocol::WebSocket::URL->new->parse('wss://example.com:3000');
    $url->host;   # example.com
    $url->port;   # 3000
    $url->secure; # 1

=head1 DESCRIPTION

Construct or parse a WebSocket URL.

=head1 ATTRIBUTES

=head2 C<host>

=head2 C<port>

=head2 C<resource_name>

=head2 C<secure>

=head1 METHODS

=head2 C<new>

Create a new L<Protocol::WebSocket::URL> instance.

=head2 C<parse>

Parse a WebSocket URL.

=head2 C<to_string>

Construct a WebSocket URL.

=cut
