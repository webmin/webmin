package Authen::OATH;
$Authen::OATH::VERSION = '2.0.1';
use warnings;
use strict;

use Digest::HMAC;
use Math::BigInt;
use Moo 2.002004;
use Types::Standard qw( Int Str );

has digits => (
    is      => 'rw',
    isa     => Int,
    default => 6,
);

has digest => (
    is      => 'rw',
    isa     => Str,
    default => 'Digest::SHA',
);

has timestep => (
    is      => 'rw',
    isa     => Int,
    default => 30,
);


sub totp {
    my ( $self, $secret, $manual_time ) = @_;
    $secret = join( "", map chr( hex($_) ), $secret =~ /(..)/g )
        if $secret =~ /^[a-fA-F0-9]{32,}$/;
    my $mod = $self->digest;
    if ( eval "require $mod" ) {
        $mod->import();
    }
    my $time = $manual_time || time();
    my $T = Math::BigInt->new( int( $time / $self->timestep ) );
    die "Must request at least 6 digits" if $self->digits < 6;
    ( my $hex = $T->as_hex ) =~ s/^0x(.*)/"0"x(16 - length $1) . $1/e;
    my $bin_code = join( "", map chr( hex($_) ), $hex =~ /(..)/g );
    my $otp = $self->_process( $secret, $bin_code );
    return $otp;
}


sub hotp {
    my ( $self, $secret, $c ) = @_;
    $secret = join( "", map chr( hex($_) ), $secret =~ /(..)/g )
        if $secret =~ /^[a-fA-F0-9]{32,}$/;
    my $mod = $self->digest;
    if ( eval "require $mod" ) {
        $mod->import();
    }
    $c = Math::BigInt->new($c);
    die "Must request at least 6 digits" if $self->digits < 6;
    ( my $hex = $c->as_hex ) =~ s/^0x(.*)/"0"x(16 - length $1) . $1/e;
    my $bin_code = join( "", map chr( hex($_) ), $hex =~ /(..)/g );
    my $otp = $self->_process( $secret, $bin_code );
    return $otp;
}


sub _process {
    my ( $self, $secret, $bin_code ) = @_;
    my $hmac = Digest::HMAC->new( $secret, $self->digest );
    $hmac->add($bin_code);
    my $hash   = $hmac->digest();
    my $offset = hex substr unpack( "H*" => $hash ), -1;
    my $dt     = unpack "N" => substr $hash, $offset, 4;
    $dt &= 0x7fffffff;
    $dt = Math::BigInt->new($dt);
    my $modulus = 10**$self->digits;

    if ( $self->digits < 10 ) {
        return sprintf( "%0$self->{ 'digits' }d", $dt->bmod($modulus) );
    }
    else {
        return $dt->bmod($modulus);
    }

}


1;    # End of Authen::OATH

=pod

=encoding UTF-8

=head1 NAME

Authen::OATH - OATH One Time Passwords

=head1 VERSION

version 2.0.1

=head1 SYNOPSIS

    use Authen::OATH;

    my $oath = Authen::OATH->new();
    my $totp = $oath->totp( 'MySecretPassword' );
    my $hotp = $oath->hotp( 'MyOtherSecretPassword' );

Parameters may be overridden when creating the new object:

    my $oath = Authen::OATH->new( digits => 8 );

The three parameters are "digits", "digest", and "timestep."
Timestep only applies to the totp() function.

While strictly speaking this is outside the specifications of
HOTP and TOTP, you can specify digests other than SHA1. For example:

    my $oath = Authen::OATH->new(
        digits => 10,
        digest => 'Digest::MD6',
    );

If you are using Google Authenticator, you'll want to decode your secret
*before* passing it to the C<totp> method:

    use Convert::Base32 qw( decode_base32 );

    my $oath = Authen::OATH->new;
    my $secret = 'mySecret';
    my $otp = $oath->totp(  decode_base32( $secret ) );

=head1 DESCRIPTION

Implementation of the HOTP and TOTP One Time Password algorithms
as defined by OATH (http://www.openauthentication.org)

All necessary parameters are set by default, though these can be
overridden. Both totp() and htop() have passed all of the test
vectors defined in the RFC documents for TOTP and HOTP.

totp() and hotp() both default to returning 6 digits and using SHA1.
As such, both can be called by passing only the secret key and a
valid OTP will be returned.

=head1 SUBROUTINES/METHODS

=head2 totp

    my $otp = $oath->totp( $secret [, $manual_time ] );

Manual time is an optional parameter. If it is not passed, the current
time is used. This is useful for testing purposes.

=head2 hotp

    my $opt = $oath->hotp( $secret, $counter );

Both parameters are required.

=head2 _process

This is an internal routine and is never called directly.

=head1 CAVEATS

Please see the SYNOPSIS for how interaction with Google Authenticator.

=head1 AUTHOR

Kurt Kincaid <kurt.kincaid@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2010-2017 by Kurt Kincaid.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

__END__
#ABSTRACT: OATH One Time Passwords
