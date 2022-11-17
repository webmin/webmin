package Protocol::WebSocket::Frame;

use strict;
use warnings;

use Config;
use Encode ();
use Scalar::Util 'readonly';

use constant MAX_RAND_INT       => 2**32;
use constant MATH_RANDOM_SECURE => eval "require Math::Random::Secure;";

our $MAX_PAYLOAD_SIZE = 65536;
our $MAX_FRAGMENTS_AMOUNT = 128;

our %TYPES = (
    continuation => 0x00,
    text         => 0x01,
    binary       => 0x02,
    ping         => 0x09,
    pong         => 0x0a,
    close        => 0x08
);

sub new {
    my $class = shift;
    $class = ref $class if ref $class;
    my $buffer;

    if (@_ == 1) {
        $buffer = shift @_;
    }
    else {
        my %args = @_;
        $buffer = delete $args{buffer};
    }

    my $self = {@_};
    bless $self, $class;

    $buffer = '' unless defined $buffer;

    if (Encode::is_utf8($buffer)) {
        $self->{buffer} = Encode::encode('UTF-8', $buffer);
    }
    else {
        $self->{buffer} = $buffer;
    }

    if (defined($self->{type}) && defined($TYPES{$self->{type}})) {
        $self->opcode($TYPES{$self->{type}});
    }

    $self->{version} ||= 'draft-ietf-hybi-17';

    $self->{fragments} = [];

    $self->{max_fragments_amount} ||= $MAX_FRAGMENTS_AMOUNT unless exists $self->{max_fragments_amount};
    $self->{max_payload_size}     ||= $MAX_PAYLOAD_SIZE unless exists $self->{max_payload_size};

    return $self;
}

sub version {
    my $self = shift;

    return $self->{version};
}

sub append {
    my $self = shift;

    return unless defined $_[0];

    $self->{buffer} .= $_[0];
    $_[0] = '' unless readonly $_[0];

    return $self;
}

sub next {
    my $self = shift;

    my $bytes = $self->next_bytes;
    return unless defined $bytes;

    return Encode::decode('UTF-8', $bytes);
}

sub fin {
    @_ > 1 ? $_[0]->{fin} =
        $_[1]
      : defined($_[0]->{fin}) ? $_[0]->{fin}
      :                         1;
}
sub rsv { @_ > 1 ? $_[0]->{rsv} = $_[1] : $_[0]->{rsv} }

sub opcode {
    @_ > 1 ? $_[0]->{opcode} =
        $_[1]
      : defined($_[0]->{opcode}) ? $_[0]->{opcode}
      :                            1;
}
sub masked { @_ > 1 ? $_[0]->{masked} = $_[1] : $_[0]->{masked} }

sub is_ping         { $_[0]->opcode == 9 }
sub is_pong         { $_[0]->opcode == 10 }
sub is_close        { $_[0]->opcode == 8 }
sub is_continuation { $_[0]->opcode == 0 }
sub is_text         { $_[0]->opcode == 1 }
sub is_binary       { $_[0]->opcode == 2 }

sub next_bytes {
    my $self = shift;

    if (   $self->version eq 'draft-hixie-75'
        || $self->version eq 'draft-ietf-hybi-00')
    {
        if ($self->{buffer} =~ s/^\xff\x00//) {
            $self->opcode(8);
            return '';
        }

        return unless $self->{buffer} =~ s/^[^\x00]*\x00(.*?)\xff//s;

        return $1;
    }

    return unless length $self->{buffer} >= 2;

    while (length $self->{buffer}) {
        my $hdr = substr($self->{buffer}, 0, 1);

        my @bits = split //, unpack("B*", $hdr);

        $self->fin($bits[0]);
        $self->rsv([@bits[1 .. 3]]);

        my $opcode = unpack('C', $hdr) & 0b00001111;

        my $offset = 1;    # FIN,RSV[1-3],OPCODE

        my $payload_len = unpack 'C', substr($self->{buffer}, 1, 1);

        my $masked = ($payload_len & 0b10000000) >> 7;
        $self->masked($masked);

        $offset += 1;      # + MASKED,PAYLOAD_LEN

        $payload_len = $payload_len & 0b01111111;
        if ($payload_len == 126) {
            return unless length($self->{buffer}) >= $offset + 2;

            $payload_len = unpack 'n', substr($self->{buffer}, $offset, 2);

            $offset += 2;
        }
        elsif ($payload_len > 126) {
            return unless length($self->{buffer}) >= $offset + 4;

            my $bits = join '', map { unpack 'B*', $_ } split //,
              substr($self->{buffer}, $offset, 8);

            # Most significant bit must be 0.
            # And here is a crazy way of doing it %)
            $bits =~ s{^.}{0};

            # Can we handle 64bit numbers?
            if ($Config{ivsize} <= 4 || $Config{longsize} < 8 || $] < 5.010) {
                $bits = substr($bits, 32);
                $payload_len = unpack 'N', pack 'B*', $bits;
            }
            else {
                $payload_len = unpack 'Q>', pack 'B*', $bits;
            }

            $offset += 8;
        }

        if ($self->{max_payload_size} && $payload_len > $self->{max_payload_size}) {
            $self->{buffer} = '';
            die "Payload is too big. "
              . "Deny big message ($payload_len) "
              . "or increase max_payload_size ($self->{max_payload_size})";
        }

        my $mask;
        if ($self->masked) {
            return unless length($self->{buffer}) >= $offset + 4;

            $mask = substr($self->{buffer}, $offset, 4);
            $offset += 4;
        }

        return if length($self->{buffer}) < $offset + $payload_len;

        my $payload = substr($self->{buffer}, $offset, $payload_len);

        if ($self->masked) {
            $payload = $self->_mask($payload, $mask);
        }

        substr($self->{buffer}, 0, $offset + $payload_len, '');

        # Injected control frame
        if (@{$self->{fragments}} && $opcode & 0b1000) {
            $self->opcode($opcode);
            return $payload;
        }

        if ($self->fin) {
            if (@{$self->{fragments}}) {
                $self->opcode(shift @{$self->{fragments}});
            }
            else {
                $self->opcode($opcode);
            }
            $payload = join '', @{$self->{fragments}}, $payload;
            $self->{fragments} = [];
            return $payload;
        }
        else {

            # Remember first fragment opcode
            if (!@{$self->{fragments}}) {
                push @{$self->{fragments}}, $opcode;
            }

            push @{$self->{fragments}}, $payload;

            die "Too many fragments"
              if @{$self->{fragments}} > $self->{max_fragments_amount};
        }
    }

    return;
}

sub to_bytes {
    my $self = shift;

    if (   $self->version eq 'draft-hixie-75'
        || $self->version eq 'draft-ietf-hybi-00')
    {
        if ($self->{type} && $self->{type} eq 'close') {
            return "\xff\x00";
        }

        return "\x00" . $self->{buffer} . "\xff";
    }

    if ($self->{max_payload_size} && length $self->{buffer} > $self->{max_payload_size}) {
        die "Payload is too big. "
          . "Send shorter messages or increase max_payload_size";
    }


    my $rsv_set = 0;
    if ( $self->{rsv} && ref( $self->{rsv} ) eq 'ARRAY' ) {
        for my $i ( 0 .. @{ $self->{rsv} } - 1 ) {
            $rsv_set += $self->{rsv}->[$i] * ( 1 << ( 6 - $i ) );
        }
    }

    my $string = '';
    my $opcode = $self->opcode;
    $string .= pack 'C', ($opcode | $rsv_set | ($self->fin ? 128 : 0));

    my $payload_len = length($self->{buffer});
    if ($payload_len <= 125) {
        $payload_len |= 0b10000000 if $self->masked;
        $string .= pack 'C', $payload_len;
    }
    elsif ($payload_len <= 0xffff) {
        $string .= pack 'C', 126 + ($self->masked ? 128 : 0);
        $string .= pack 'n', $payload_len;
    }
    else {
        $string .= pack 'C', 127 + ($self->masked ? 128 : 0);

        # Shifting by an amount >= to the system wordsize is undefined
        $string .= pack 'N', $Config{ivsize} <= 4 ? 0 : $payload_len >> 32;
        $string .= pack 'N', ($payload_len & 0xffffffff);
    }

    if ($self->masked) {

        my $mask = $self->{mask}
          || (
            MATH_RANDOM_SECURE
            ? Math::Random::Secure::irand(MAX_RAND_INT)
            : int(rand(MAX_RAND_INT))
          );

        $mask = pack 'N', $mask;

        $string .= $mask;
        $string .= $self->_mask($self->{buffer}, $mask);
    }
    else {
        $string .= $self->{buffer};
    }

    return $string;
}

sub to_string {
    my $self = shift;

    die 'DO NOT USE';
}

sub _mask {
    my $self = shift;
    my ($payload, $mask) = @_;

    $mask = $mask x (int(length($payload) / 4) + 1);
    $mask = substr($mask, 0, length($payload));
    $payload = "$payload" ^ $mask;

    return $payload;
}

sub max_payload_size {
    my $self = shift;

    return $self->{max_payload_size};
}

1;
__END__

=head1 NAME

Protocol::WebSocket::Frame - WebSocket Frame

=head1 SYNOPSIS

    # Create frame
    my $frame = Protocol::WebSocket::Frame->new('123');
    $frame->to_bytes;

    # Parse frames
    my $frame = Protocol::WebSocket::Frame->new;
    $frame->append(...);
    $f->next; # get next message
    $f->next; # get another next message

=head1 DESCRIPTION

Construct or parse a WebSocket frame.

=head1 RANDOM MASK GENERATION

By default built-in C<rand> is used, this is not secure, so when
L<Math::Random::Secure> is installed it is used instead.

=head1 METHODS

=head2 C<new>

    Protocol::WebSocket::Frame->new('data');   # same as (buffer => 'data')
    Protocol::WebSocket::Frame->new(buffer => 'data', type => 'close');

Create a new L<Protocol::WebSocket::Frame> instance. Automatically detect if the
passed data is a Perl string (UTF-8 flag) or bytes.

When called with more than one arguments, it takes the following named arguments
(all of them are optional).

=over

=item C<buffer> => STR (default: C<"">)

The payload of the frame.

=item C<type> => TYPE_STR (default: C<"text">)

The type of the frame. Accepted values are:

    continuation
    text
    binary
    ping
    pong
    close

=item C<opcode> => INT (default: 1)

The opcode of the frame. If C<type> field is set to a valid string, this field is ignored.

=item C<fin> => BOOL (default: 1)

"fin" flag of the frame. "fin" flag must be 1 in the ending frame of fragments.

=item C<masked> => BOOL (default: 0)

If set to true, the frame will be masked.

=item C<version> => VERSION_STR (default: C<'draft-ietf-hybi-17'>)

WebSocket protocol version string. See L<Protocol::WebSocket> for valid version strings.

=back

=head2 C<is_continuation>

Check if frame is of continuation type.

=head2 C<is_text>

Check if frame is of text type.

=head2 C<is_binary>

Check if frame is of binary type.

=head2 C<is_ping>

Check if frame is a ping request.

=head2 C<is_pong>

Check if frame is a pong response.

=head2 C<is_close>

Check if frame is of close type.

=head2 C<opcode>

    $opcode = $frame->opcode;
    $frame->opcode(8);

Get/set opcode of the frame.

=head2 C<masked>

    $masked = $frame->masked;
    $frame->masked(1);

Get/set masking of the frame.

=head2 C<append>

    $frame->append($chunk);

Append a frame chunk.

Beware that this method is B<destructive>.
It makes C<$chunk> empty unless C<$chunk> is read-only.

=head2 C<next>

    $frame->append(...);

    $frame->next; # next message

Return the next message as a Perl string (UTF-8 decoded).

=head2 C<next_bytes>

Return the next message as is.

=head2 C<to_bytes>

Construct a WebSocket message.

=head2 C<max_payload_size>

The maximum size of the payload. You may set this to C<0> or C<undef> to disable
checking the payload size.

=cut
