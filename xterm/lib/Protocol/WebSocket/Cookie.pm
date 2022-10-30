package Protocol::WebSocket::Cookie;

use strict;
use warnings;

sub new {
    my $class = shift;
    $class = ref $class if ref $class;

    my $self = {@_};
    bless $self, $class;

    return $self;
}

sub pairs { @_ > 1 ? $_[0]->{pairs} = $_[1] : $_[0]->{pairs} }

my $TOKEN         = qr/[^;,\s"]+/;
my $NAME          = qr/[^;,\s"=]+/;
my $QUOTED_STRING = qr/"(?:\\"|[^"])+"/;
my $VALUE         = qr/(?:$TOKEN|$QUOTED_STRING)/;

sub parse {
    my $self   = shift;
    my $string = shift;

    $self->{pairs} = [];

    return unless defined $string && $string ne '';

    while ($string =~ m/\s*($NAME)\s*(?:=\s*($VALUE))?;?/g) {
        my ($attr, $value) = ($1, $2);
        if (defined $value) {
            $value =~ s/^"//;
            $value =~ s/"$//;
            $value =~ s/\\"/"/g;
        }
        push @{$self->{pairs}}, [$attr, $value];
    }

    return $self;
}

sub to_string {
    my $self = shift;

    my $string = '';

    my @pairs;
    foreach my $pair (@{$self->pairs}) {
        my $string = '';
        $string .= $pair->[0];

        if (defined $pair->[1]) {
            $string .= '=';
            $string
              .= $pair->[1] !~ m/^$VALUE$/ ? "\"$pair->[1]\"" : $pair->[1];
        }

        push @pairs, $string;
    }

    return join '; ' => @pairs;
}

1;
__END__

=head1 NAME

Protocol::WebSocket::Cookie - Base class for WebSocket cookies

=head1 DESCRIPTION

A base class for L<Protocol::WebSocket::Cookie::Request> and
L<Protocol::WebSocket::Cookie::Response>.

=head1 ATTRIBUTES

=head2 C<pairs>

=head1 METHODS

=head2 C<new>

Create a new L<Protocol::WebSocket::Cookie> instance.

=head2 C<parse>

=head2 C<to_string>

=cut
