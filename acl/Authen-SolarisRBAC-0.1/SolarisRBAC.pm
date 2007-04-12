package Authen::SolarisRBAC;

require 5.005_62;
use strict;
use warnings;

require Exporter;
require DynaLoader;

our @ISA = qw(Exporter DynaLoader);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Authen::SolarisRBAC ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);
our $VERSION = '0.1';

bootstrap Authen::SolarisRBAC $VERSION;

# Preloaded methods go here.

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Authen::SolarisRBAC - Perl extension for Solaris RBAC

=head1 SYNOPSIS

  use Authen::SolarisRBAC;
  $ok = Authen::SolarisRBAC::chkauth("solaris.admin.dcmgr.admin", "fred");

=head1 DESCRIPTION

Provides wrappers for the Solaris RBAC functions.

=head2 EXPORT

None by default.


=head1 AUTHOR

Jamie Cameron, jcameron@webmin.com

=head1 SEE ALSO

rbac(5).

=cut
