#!/usr/local/bin/perl
# Called from cron to re-sign all zones that are too old

$no_acl_check++;
require './bind8-lib.pl';

my $zonefile;
my $krfile;
my $dom;
my $err;

if ($ARGV[0] eq "--debug") {
	$debug = 1;
	}
my $period = $config{'dnssec_period'} || 21;

@zones = &list_zone_names();
$errcount = 0;
$donecount = 0;
foreach $z (@zones) {
	# Get the key
	next if ($z->{'type'} ne 'master');
	$zonefile = &get_zone_file($z);
	$krfile = "$zonefile".".krf";	
	$dom = $z->{'members'} ? $z->{'values'}->[0] : $z->{'name'};

	print STDERR "Considering zone $z->{'name'}\n" if ($debug);

	# Do DNSSEC-Tools resign operation if zone is being managed by
	# DNSSEC-Tools
	if (&have_dnssec_tools_support() &&
	    &check_if_dnssec_tools_managed($dom)) {
		&lock_file(&make_chroot($zonefile));
		$err = &dt_resign_zone($dom, $zonefile, $krfile, $period);
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
