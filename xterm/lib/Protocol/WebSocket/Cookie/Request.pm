package Protocol::WebSocket::Cookie::Request;

use strict;
use warnings;

use base 'Protocol::WebSocket::Cookie';

sub parse {
    my $self = shift;

    $self->SUPER::parse(@_);

    my $cookies = [];

    my $version = 1;
    if ($self->pairs->[0] eq '$Version') {
        my $pair = shift @{$self->pairs};
        $version = $pair->[1];
    }

    my $cookie;
    foreach my $pair (@{$self->pairs}) {
        next unless defined $pair->[0];

        if ($pair->[0] =~ m/^[^\$]/) {
            push @$cookies, $cookie if defined $cookie;

            $cookie = $self->_build_cookie(
                name    => $pair->[0],
                value   => $pair->[1],
                version => $version
            );
        }
        elsif ($pair->[0] eq '$Path') {
            $cookie->path($pair->[1]);
        }
        elsif ($pair->[0] eq '$Domain') {
            $cookie->domain($pair->[1]);
        }
    }

    push @$cookies, $cookie if defined $cookie;

    return $cookies;
}

sub name    { @_ > 1 ? $_[0]->{name}    = $_[1] : $_[0]->{name} }
sub value   { @_ > 1 ? $_[0]->{value}   = $_[1] : $_[0]->{value} }
sub version { @_ > 1 ? $_[0]->{version} = $_[1] : $_[0]->{version} }
sub path    { @_ > 1 ? $_[0]->{path}    = $_[1] : $_[0]->{path} }
sub domain  { @_ > 1 ? $_[0]->{domain}  = $_[1] : $_[0]->{domain} }

sub _build_cookie { shift; Protocol::WebSocket::Cookie::Request->new(@_) }

1;
__END__

=head1 NAME

Protocol::WebSocket::Cookie::Request - WebSocket Cookie Request

=head1 SYNOPSIS

    # Constructor

    # Parser
    my $cookie = Protocol::WebSocket::Cookie::Request->new;
    $cookies = $cookie->parse(
        '$Version=1; foo="bar"; $Path=/; bar=baz; $Domain=.example.com');

=head1 DESCRIPTION

Construct or parse a WebSocket request cookie.

=head1 ATTRIBUTES

=head2 C<name>

=head2 C<value>

=head2 C<version>

=head2 C<path>

=head2 C<domain>

=head1 METHODS

=head2 C<parse>

Parse a WebSocket request cookie.

=head2 C<to_string>

Construct a WebSocket request cookie.

=cut
