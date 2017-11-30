#!/usr/local/bin/perl
# Called from cron to re-sign all zones that are too old
use strict;
use warnings;
our %config;

my $no_acl_check++;
require './bind8-lib.pl';

my $zonefile;
my $krfile;
my $dom;
my $err;

my $debug;
if (@ARGV && $ARGV[0] eq "--debug") {
	$debug = 1;
	}
my $period = $config{'dnssec_period'} || 21;

my @zones = &list_zone_names();
my $errcount = 0;
my $donecount = 0;
foreach my $z (@zones) {
	# Get the key
	next if ($z->{'type'} ne 'master');
	my $zonefile = &get_zone_file($z);
	my $krfile = "$zonefile".".krf";	
	my $dom = $z->{'members'} ? $z->{'values'}->[0] : $z->{'name'};

	print STDERR "Considering zone $z->{'name'}\n" if ($debug);

	# Do DNSSEC-Tools resign operation if zone is being managed by
	# DNSSEC-Tools
	if (&have_dnssec_tools_support() &&
	    &check_if_dnssec_tools_managed($dom)) {
		&lock_file(&make_chroot($zonefile));
		my $err = &dt_resign_zone($dom, $zonefile, $krfile, $period);
		&unlock_file(&make_chroot($zonefile));

		if ($err) {
			print STDERR "  Re-signing of $z->{'name'} failed : $err\n";
			$errcount++;
		}
		elsif ($debug) {
			print STDERR "  Re-signed $z->{'name'} OK\n";
		}
		next;
	}
		
	my @keys = &get_dnssec_key($z);
	print STDERR "  Key count ",scalar(@keys),"\n" if ($debug);
	next if (@keys != 2);
	my ($zonekey) = grep { !$_->{'ksk'} } @keys;
	next if (!$zonekey);
	print STDERR "  Zone key in ",$zonekey->{'privatefile'},"\n"
		if ($debug);

	# Check if old enough
	my @st = stat($zonekey->{'privatefile'});
	if (!@st) {
		print STDERR "  Private key file $zonekey->{'privatefile'} ",
			     "missing\n" if ($debug);
		next;
		}
	my $old = (time() - $st[9]) / (24*60*60);
	print STDERR "  Age in days $old\n" if ($debug);
	if ($old > $period) {
		# Too old .. signing
		my $err = &resign_dnssec_key($z);
		if ($err) {
			print STDERR "  Re-signing of $z->{'name'} failed : $err\n";
			$errcount++;
			}
		elsif ($debug) {
			print STDERR "  Re-signed $z->{'name'} OK\n";
			}
		$donecount++ if (!$err);
		}
	}
if ($donecount) {
	&restart_bind();
	}
exit($errcount);
