#!/usr/local/bin/perl
# Called from cron to re-sign all zones that are too old

$no_acl_check++;
require './bind8-lib.pl';

if ($ARGV[0] eq "--debug") {
	$debug = 1;
	}
if (!$config{'dnssec_period'}) {
	print STDERR "Maximum age not set\n" if ($debug);
	exit(0);
	}

@zones = &list_zone_names();
$errcount = 0;
foreach $z (@zones) {
	# Get the key
	next if ($z->{'type'} ne 'master');
	print STDERR "Considering zone $z->{'name'}\n" if ($debug);
	@keys = &get_dnssec_key($z);
	print STDERR "  Key count ",scalar(@keys),"\n" if ($debug);
	next if (@keys != 2);
	($zonekey) = grep { !$_->{'ksk'} } @keys;
	next if (!$zonekey);
	print STDERR "  Zone key in ",$zonekey->{'privatefile'},"\n"
		if ($debug);

	# Check if old enough
	@st = stat($zonekey->{'privatefile'});
	if (!@st) {
		print STDERR "  Private key file $zonekey->{'privatefile'} ",
			     "missing\n" if ($debug);
		next;
		}
	$old = (time() - $st[9]) / (24*60*60);
	print STDERR "  Age in days $old\n" if ($debug);
	if ($old > $config{'dnssec_period'}) {
		# Too old .. signing
		$err = &resign_dnssec_key($z);
		if ($err) {
			print STDERR "  Re-signing failed : $err\n";
			$errcount++;
			}
		elsif ($debug) {
			print STDERR "  Re-signed OK\n";
			}
		}
	}
exit($errcount);

