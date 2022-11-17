package Digest::HMAC_SHA1;
our $VERSION = '1.04'; # VERSION
our $AUTHORITY = 'cpan:ARODLAND'; # AUTHORITY

use strict;
use Digest::SHA qw(sha1);
use Digest::HMAC qw(hmac);

# OO interface
use vars qw(@ISA);
@ISA=qw(Digest::HMAC);
sub new
{
    my $class = shift;
    $class->SUPER::new($_[0], "Digest::SHA", 64);  # Digest::SHA defaults to SHA-1
}

# Functional interface
require Exporter;
*import = \&Exporter::import;
use vars qw(@EXPORT_OK);
@EXPORT_OK=qw(hmac_sha1 hmac_sha1_hex);

sub hmac_sha1
{
    hmac($_[0], $_[1], \&sha1, 64);
}

sub hmac_sha1_hex
{
    unpack("H*", &hmac_sha1)
}

1;

__END__

=head1 NAME

Digest::HMAC_SHA1 - Keyed-Hashing for Message Authentication

=head1 SYNOPSIS

 # Functional style
 use Digest::HMAC_SHA1 qw(hmac_sha1 hmac_sha1_hex);
 $digest = hmac_sha1($data, $key);
 print hmac_sha1_hex($data, $key);

 # OO style
 use Digest::HMAC_SHA1;
 $hmac = Digest::HMAC_SHA1->new($key);

 $hmac->add($data);
 $hmac->addfile(*FILE);

 $digest = $hmac->digest;
 $digest = $hmac->hexdigest;
 $digest = $hmac->b64digest;

=head1 DESCRIPTION

This module provide HMAC-SHA-1 hashing.

=head1 SEE ALSO

L<Digest::HMAC>, L<Digest::SHA>, L<Digest::HMAC_MD5>

=head1 MAINTAINER

Andrew Rodland <arodland@cpan.org>

=head1 ORIGINAL AUTHOR

Gisle Aas <gisle@aas.no>

=cut
