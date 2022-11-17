package Digest::HMAC_MD5;
our $VERSION = '1.04'; # VERSION
our $AUTHORITY = 'cpan:ARODLAND'; # AUTHORITY

use strict;
use Digest::MD5  qw(md5);
use Digest::HMAC qw(hmac);

# OO interface
use vars qw(@ISA);
@ISA=qw(Digest::HMAC);
sub new
{
    my $class = shift;
    $class->SUPER::new($_[0], "Digest::MD5", 64);
}

# Functional interface
require Exporter;
*import = \&Exporter::import;
use vars qw(@EXPORT_OK);
@EXPORT_OK=qw(hmac_md5 hmac_md5_hex);

sub hmac_md5
{
    hmac($_[0], $_[1], \&md5, 64);
}

sub hmac_md5_hex
{
    unpack("H*", &hmac_md5)
}

1;

__END__

=head1 NAME

Digest::HMAC_MD5 - Keyed-Hashing for Message Authentication

=head1 SYNOPSIS

 # Functional style
 use Digest::HMAC_MD5 qw(hmac_md5 hmac_md5_hex);
 $digest = hmac_md5($data, $key);
 print hmac_md5_hex($data, $key);

 # OO style
 use Digest::HMAC_MD5;
 $hmac = Digest::HMAC_MD5->new($key);

 $hmac->add($data);
 $hmac->addfile(*FILE);

 $digest = $hmac->digest;
 $digest = $hmac->hexdigest;
 $digest = $hmac->b64digest;

=head1 DESCRIPTION

This module provide HMAC-MD5 hashing.

=head1 SEE ALSO

L<Digest::HMAC>, L<Digest::MD5>, L<Digest::HMAC_SHA1>

=head1 MAINTAINER

Andrew Rodland <arodland@cpan.org>

=head1 ORIGINAL AUTHOR

Gisle Aas <gisle@aas.no>

=cut
