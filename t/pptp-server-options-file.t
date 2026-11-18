#!/usr/bin/perl
# Check which PPP options files the PPTP server module may edit.
use strict;
use warnings;
no warnings qw(once redefine uninitialized);
use Test::More;
use FindBin;
use File::Temp qw(tempdir);

my $root = "$FindBin::Bin/..";

# Compile the real checks without initializing the module.
open(my $fh, '<', "$root/pptp-server/pptp-server-lib.pl") or die $!;
my $code = do { local $/; <$fh> };
close($fh);
{ package pp; require "$root/web-lib-funcs.pl"; }
foreach my $sub (qw(get_config find_conf ppp_options_dir ppp_options_file_ok ppp_options_file)) {
	$code =~ /(^sub \Q$sub\E\n\{.*?^\})/ms or die "Missing $sub";
	eval "package pp; no strict; no warnings; $1";
	die $@ if $@;
	}
my $tmp = tempdir(CLEANUP => 1);
my $dir = "$tmp/ppp";
mkdir($dir) && mkdir("$tmp/elsewhere") or die $!;
%pp::config = ( 'ppp_options' => "$dir/options" );
$pp::options_pptp = "$dir/options.pptp";

foreach my $name (qw(options options.pptp pptpd-options options.pptpd peers/office)) {
	ok(pp::ppp_options_file_ok("$dir/$name"), "allows $name");
	}
foreach my $file ('', "$tmp/elsewhere/file", "$dir/../elsewhere/file",
		  "$dir/ip-up.d/script", "$dir/..", "$dir/.hidden",
		  "$dir/x\nlisten 1.2.3.4", "$tmp/pppx/options") {
	ok(!pp::ppp_options_file_ok($file), "refuses '$file'");
	}
symlink("$tmp/elsewhere", "$dir/peers") or die $!;
ok(!pp::ppp_options_file_ok("$tmp/ppp/peers/office"), 'peer link outside PPP refused');

# Use the same callback that the Backup Configuration Files module calls.
open(my $backup, '<', "$root/pptp-server/backup_config.pl") or die $!;
my $source = do { local $/; <$backup> };
for my $sub (qw(backup_config_files pre_backup)) {
	$source =~ /(^sub \Q$sub\E\n\{.*?^\})/ms or die "Missing $sub";
	eval "package pp; no strict; no warnings; $1";
	die $@ if $@;
	}
unlink("$tmp/ppp/peers") && mkdir("$tmp/ppp/peers") or die $!;
$pp::config{'file'} = "$tmp/pptpd.conf";
$pp::config{'pap_file'} = "$tmp/ppp/chap-secrets";
$pp::text{'backup_eoptions'} = 'Cannot back up $1';
for my $case ([ "$tmp/ppp/peers/office", "$tmp/ppp/peers/office" ],
	      [ '', "$tmp/ppp/options" ], [ "$tmp/elsewhere/office", undef ]) {
	open(my $conf, '>', $pp::config{'file'}) or die $!;
	print $conf "option $case->[0]\n" if $case->[0];
	close($conf);
	my @files = pp::backup_config_files();
	is($files[2], $case->[1], 'backup selects the active supported file');
	is(pp::pre_backup(), defined($case->[1]) ? undef : "Cannot back up $case->[0]",
	   'unsupported setting reports the configured filename');
	}

done_testing();
