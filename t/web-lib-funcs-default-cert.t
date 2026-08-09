#!/usr/bin/perl
# Regression tests for detection of certificates bundled by older releases.

use strict;
use warnings;
use Test::More;
use File::Basename qw(dirname);
use File::Spec;
use File::Temp qw(tempdir);

my $script = File::Spec->rel2abs(
	File::Spec->catfile(dirname(__FILE__), '..', 'web-lib-funcs.pl'));
require $script;

my $cert = File::Spec->catfile(tempdir(CLEANUP => 1), 'miniserv.pem');
open(my $fh, '>', $cert) or die "open($cert): $!";
print {$fh} "legacy certificate fixture\n";
close($fh) or die "close($cert): $!";

no warnings qw(redefine once);
my $digest = 'fcc4fc2ba3c00ede7008725668ff3af9';
local *main::execute_command = sub {
	my (undef, undef, $output) = @_;
	${$output} = "$digest  $cert\n";
	$? = 0;
	};

local $ENV{'HTTPS'} = 'OFF';
ok(main::miniserv_using_default_cert($cert),
   'a formerly bundled certificate remains detectable without a bundled file');

$digest = '0123456789abcdef0123456789abcdef';
ok(!main::miniserv_using_default_cert($cert),
   'a machine-generated certificate is not flagged');

local $ENV{'MINISERV_KEYFILE'} = $cert;
local $ENV{'HTTPS'} = 'ON';
$digest = '2bb1926297df3d0429be3a4cd00b43ce';
ok(main::miniserv_using_default_cert(),
   'HTTPS login detects the other legacy certificate');

done_testing();
