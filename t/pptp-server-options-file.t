#!/usr/bin/perl
# Check which PPP options files the PPTP server module may edit.
use strict;
use warnings;
no warnings qw(once redefine uninitialized);
use Test::More;
use FindBin;

my $root = "$FindBin::Bin/..";

# Compile the real checks without initializing the module.
open(my $fh, '<', "$root/pptp-server/pptp-server-lib.pl") or die $!;
my $code = do { local $/; <$fh> };
close($fh);
foreach my $sub ('ppp_options_dir', 'ppp_options_file_ok') {
	$code =~ /(^sub \Q$sub\E\n\{.*?^\})/ms or die "Missing $sub";
	eval "package pp; no strict; no warnings; $1";
	die $@ if $@;
	}
%pp::config = ( 'ppp_options' => '/etc/ppp/options' );
$pp::options_pptp = '/etc/ppp/options.pptp';

foreach my $file ('/etc/ppp/options', '/etc/ppp/options.pptp',
		  '/etc/ppp/pptpd-options', '/etc/ppp/options.pptpd') {
	ok(pp::ppp_options_file_ok($file), "allows $file");
	}
foreach my $file ('', '/etc/pam.d/common-auth', '/etc/ppp/../shadow',
		  '/etc/ppp/peers/x', '/etc/ppp/..', '/etc/ppp/.hidden',
		  "/etc/ppp/x\nlisten 1.2.3.4", '/etc/pppx/options') {
	ok(!pp::ppp_options_file_ok($file), "refuses '$file'");
	}

done_testing();
