package Protocol::WebSocket::Message;

use strict;
use warnings;

use base 'Protocol::WebSocket::Stateful';

use Scalar::Util qw(readonly);
require Digest::MD5;

our $MAX_MESSAGE_SIZE = 10 * 2048;

sub new {
    my $class = shift;
    $class = ref $class if ref $class;

    my $self = {@_};
    bless $self, $class;

    $self->{version} ||= '';

    $self->{buffer} = '';

    $self->{fields} ||= {};

    $self->{max_message_size} ||= $MAX_MESSAGE_SIZE;

    $self->{cookies} ||= [];

    $self->state('first_line');

    return $self;
}

sub secure { @_ > 1 ? $_[0]->{secure} = $_[1] : $_[0]->{secure} }

sub fields { shift->{fields} }

sub field {
    my $self = shift;
    my $name = lc shift;

    return $self->fields->{$name} unless @_;

    $self->fields->{$name} = $_[0];

    return $self;
}

sub error {
    my $self = shift;

    return $self->{error} unless @_;

    my $error = shift;
    $self->{error} = $error;
    $self->state('error');

    return $self;
}

sub subprotocol {
    @_ > 1 ? $_[0]->{subprotocol} = $_[1] : $_[0]->{subprotocol};
}

sub host   { @_ > 1 ? $_[0]->{host}   = $_[1] : $_[0]->{host} }
sub origin { @_ > 1 ? $_[0]->{origin} = $_[1] : $_[0]->{origin} }

sub version { @_ > 1 ? $_[0]->{version} = $_[1] : $_[0]->{version} }

sub number1   { @_ > 1 ? $_[0]->{number1}   = $_[1] : $_[0]->{number1} }
sub number2   { @_ > 1 ? $_[0]->{number2}   = $_[1] : $_[0]->{number2} }
sub challenge { @_ > 1 ? $_[0]->{challenge} = $_[1] : $_[0]->{challenge} }

sub checksum {
    my $self = shift;

    if (@_) {
        $self->{checksum} = $_[0];
        return $self;
    }

    return $self->{checksum} if defined $self->{checksum};

    Carp::croak(qq/number1 is required/)   unless defined $self->number1;
    Carp::croak(qq/number2 is required/)   unless defined $self->number2;
    Carp::croak(qq/challenge is required/) unless defined $self->challenge;

    my $checksum = '';
    $checksum .= pack 'N' => $self->number1;
    $checksum .= pack 'N' => $self->number2;
    $checksum .= $self->challenge;
    $checksum = Digest::MD5::md5($checksum);

    return $self->{checksum} ||= $checksum;
}

sub parse {
    my $self = shift;

    return 1 unless defined $_[0];

    return if $self->error;

    return unless $self->_append(@_);

    while (!$self->is_state('body') && defined(my $line = $self->_get_line)) {
        if ($self->state eq 'first_line') {
            return unless defined $self->_parse_first_line($line);

            $self->state('fields');
        }
        elsif ($line ne '') {
            return unless defined $self->_parse_field($line);
        }
        else {
            $self->state('body');
            last;
        }
    }

    return 1 unless $self->is_state('body');

    my $rv = $self->_parse_body;
    return unless defined $rv;

    # Need more data
    return $rv unless ref $rv;

    $_[0] = $self->{buffer} unless readonly $_[0] || ref $_[0];
    return $self->done;
}

sub _extract_number {
    my $self = shift;
    my $key  = shift;

    my $number = join '' => $key =~ m/\d+/g;
    my $spaces = $key =~ s/ / /g;

    return if $spaces == 0;

    return int($number / $spaces);
}

sub _append {
    my $self = shift;

    return if $self->error;

    if (ref $_[0]) {
        $_[0]->read(my $buf, $self->{max_message_size});
        $self->{buffer} .= $buf;
    }
    else {
        $self->{buffer} .= $_[0];
        $_[0] = '' unless readonly $_[0];
    }

    if (length $self->{buffer} > $self->{max_message_size}) {
        $self->error('Message is too long');
        return;
    }

    return $self;
}

sub _get_line {
    my $self = shift;

    if ($self->{buffer} =~ s/^(.*?)\x0d?\x0a//) {
        return $1;
    }

    return;
}

sub _parse_first_line {shift}

sub _parse_field {
    my $self = shift;
    my $line = shift;

    my ($name, $value) = split /:\s*/ => $line => 2;
    unless (defined $name && defined $value) {
        $self->error('Invalid field');
        return;
    }

    #$name =~ s/^Sec-WebSocket-Origin$/Origin/i; # FIXME
    $self->field($name => $value);

    if ($name =~ m/^x-forwarded-proto$/i) {
        $self->secure(1);
    }

    return $self;
}

sub _parse_body {shift}

1;
__END__

=head1 NAME

Protocol::WebSocket::Message - Base class for WebSocket request and response

=head1 DESCRIPTION

A base class for L<Protocol::WebSocket::Request> and
L<Protocol::WebSocket::Response>.

=head1 ATTRIBUTES

=head2 C<version>

=head2 C<fields>

=head2 C<field>

=head2 C<host>

=head2 C<origin>

=head2 C<secure>

=head2 C<subprotocol>

=head2 C<error>

=head2 C<number1>

=head2 C<number2>

=head2 C<challenge>

=head1 METHODS

=head2 C<new>

Create a new L<Protocol::WebSocket::Message> instance.

=head2 C<checksum>

=head2 C<parse>

=cut
