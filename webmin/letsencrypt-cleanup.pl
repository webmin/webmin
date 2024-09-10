#!/usr/local/bin/perl
# Called by the let's encrypt client to remove a DNS record for validation

$no_acl_check++;
$ENV{'WEBMIN_CONFIG'} ||= "/etc/webmin";
$ENV{'WEBMIN_VAR'} ||= "/var/webmin";
if ($0 =~ /^(.*)\/[^\/]+$/) {
        chdir($pwd = $1);
        }
else {
	chop($pwd = `pwd`);
	}
$0 = "$pwd/letsencrypt-cleanup.pl";
require './webmin-lib.pl';
&foreign_require("bind8");

# Validate params
my $dname = $ENV{'CERTBOT_DOMAIN'};
$dname || die "Missing CERTBOT_DOMAIN environment variable";

# Find the DNS domain and records
my $d = &get_virtualmin_for_domain($dname);
my ($zone, $zname) = &get_bind_zone_for_domain($dname);
my ($recs, $file);
my $wapi;
if ($zone) {
	# Use BIND module API calls
	$zone->{'file'} || die "Zone $dname does not have a records file";
	$file = &bind8::absolute_path($zone->{'file'});
	&lock_file(&bind8::make_chroot($file));
	&bind8::before_editing($zone);
	$recs = [ &bind8::read_zone_file($file, $zname) ];
	$wapi = 0;
	}
elsif ($d) {
	# Use Virtualmin API calls
	&virtual_server::pre_records_change($d);
	($recs, $file) = &virtual_server::get_domain_dns_records_and_file($d);
	&lock_file(&bind8::make_chroot($file));
	$wapi = 1;
	}
else {
	die "No DNS zone named $dname found";
	}

# Find and remove the record. Does nothing if it doesn't exist so as not to
# fail a repeated cleanup.
my ($r) = grep { $_->{'name'} eq "_acme-challenge.".$dname."." } @$recs;
if ($r) {
	if ($wapi) {
		&virtual_server::delete_dns_record($recs, $file, $r);
		}
	else {
		&bind8::delete_record($file, $r);
		}
	}

if (!$wapi) {
	# Apply using BIND API calls
	&bind8::sign_dnssec_zone_if_key($zone, $recs);
	&bind8::bump_soa_record($file, $recs);
	&bind8::after_editing($zone);
	&bind8::restart_zone($zone->{'name'}, $zone->{'view'});
	}
else {
	# Apply using Virtualmin API
	&virtual_server::post_records_change($d, $recs, $file);
	&virtual_server::reload_bind_records($d);
	}
&unlock_file(&bind8::make_chroot($file));

&webmin_log("letsencryptcleanup", undef, $dname);
