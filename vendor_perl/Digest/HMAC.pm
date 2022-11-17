package Digest::HMAC;
our $VERSION = '1.04'; # VERSION
our $AUTHORITY = 'cpan:ARODLAND'; # AUTHORITY

use strict;

# OO interface

sub new
{
    my($class, $key, $hasher, $block_size) =  @_;
    $block_size ||= 64;
    $key = $hasher->new->add($key)->digest if length($key) > $block_size;

    my $self = bless {}, $class;
    $self->{k_ipad} = $key ^ (chr(0x36) x $block_size);
    $self->{k_opad} = $key ^ (chr(0x5c) x $block_size);
    $self->{hasher} = $hasher->new->add($self->{k_ipad});
    $self;
}

sub reset
{
    my $self = shift;
    $self->{hasher}->reset->add($self->{k_ipad});
    $self;
}

sub add     { my $self = shift; $self->{hasher}->add(@_);     $self; }
sub addfile { my $self = shift; $self->{hasher}->addfile(@_); $self; }

sub _digest
{
    my $self = shift;
    my $inner_digest = $self->{hasher}->digest;
    $self->{hasher}->reset->add($self->{k_opad}, $inner_digest);
}

sub digest    { shift->_digest->digest;    }
sub hexdigest { shift->_digest->hexdigest; }
sub b64digest { shift->_digest->b64digest; }


# Functional interface

require Exporter;
*import = \&Exporter::import;
use vars qw(@EXPORT_OK);
@EXPORT_OK = qw(hmac hmac_hex);

sub hmac
{
    my($data, $key, $hash_func, $block_size) = @_;
    $block_size ||= 64;
    $key = &$hash_func($key) if length($key) > $block_size;

    my $k_ipad = $key ^ (chr(0x36) x $block_size);
    my $k_opad = $key ^ (chr(0x5c) x $block_size);

    &$hash_func($k_opad, &$hash_func($k_ipad, $data));
}

sub hmac_hex { unpack("H*", &hmac); }

1;

__END__

=head1 NAME

Digest::HMAC - Keyed-Hashing for Message Authentication

=head1 SYNOPSIS

 # Functional style
 use Digest::HMAC qw(hmac hmac_hex);
 $digest = hmac($data, $key, \&myhash);
 print hmac_hex($data, $key, \&myhash);

 # OO style
 use Digest::HMAC;
 $hmac = Digest::HMAC->new($key, "Digest::MyHash");

 $hmac->add($data);
 $hmac->addfile(*FILE);

 $digest = $hmac->digest;
 $digest = $hmac->hexdigest;
 $digest = $hmac->b64digest;

=head1 DESCRIPTION

HMAC is used for message integrity checks between two parties that
share a secret key, and works in combination with some other Digest
algorithm, usually MD5 or SHA-1.  The HMAC mechanism is described in
RFC 2104.

HMAC follow the common C<Digest::> interface, but the constructor
takes the secret key and the name of some other simple C<Digest::>
as argument.

The hmac() and hmac_hex() functions and the Digest::HMAC->new() constructor
takes an optional $blocksize argument as well.  The HMAC algorithm assumes the
digester to hash by iterating a basic compression function on blocks of data
and the $blocksize should match the byte-length of such blocks.

The default $blocksize is 64 which is suitable for the MD5 and SHA-1 digest
functions.  For stronger algorithms the blocksize probably needs to be
increased.

=head1 SEE ALSO

L<Digest::HMAC_MD5>, L<Digest::HMAC_SHA1>

RFC 2104

=head1 MAINTAINER

Andrew Rodland <arodland@cpan.org>

=head1 ORIGINAL AUTHORS

Graham Barr <gbarr@ti.com>, Gisle Aas <gisle@aas.no>

=cut
