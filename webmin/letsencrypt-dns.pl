#!/usr/local/bin/perl
# Called by the let's encrypt client to add a DNS record for validation

$no_acl_check++;
$ENV{'WEBMIN_CONFIG'} ||= "/etc/webmin";
$ENV{'WEBMIN_VAR'} ||= "/var/webmin";
if ($0 =~ /^(.*)\/[^\/]+$/) {
        chdir($pwd = $1);
        }
else {
	chop($pwd = `pwd`);
	}
$0 = "$pwd/letsencrypt-dns.pl";
require './webmin-lib.pl';
&foreign_require("bind8");

# Validate params
my $dname = $ENV{'CERTBOT_DOMAIN'};
my $val = $ENV{'CERTBOT_VALIDATION'};
$dname || die "Missing CERTBOT_DOMAIN environment variable";
$val || die "Missing CERTBOT_VALIDATION environment variable";

# Find the DNS domain and records
$d = &get_virtualmin_for_domain($dname);
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

# Remove any existing record, if different
my ($r) = grep { $_->{'name'} eq "_acme-challenge.".$dname."." } @$recs;
if ($r) {
	if ($r->{'values'}->[0] eq $val) {
		# Record is already fine!
		exit(0);
		}
	elsif ($wapi) {
		&virtual_server::delete_dns_record($recs, $file, $r);
		}
	else {
		&bind8::delete_record($file, $r);
		}
	}

# Create the needed DNS record
$r = { 'name' => "_acme-challenge.".$dname.".",
       'type' => 'TXT',
       'ttl' => 30,
       'values' => [ $val ] };
if ($wapi) {
	&virtual_server::create_dns_record($recs, $file, $r);
	}
else {
	&bind8::create_record($file, $r->{'name'}, $r->{'ttl'}, "IN",
			      $r->{'type'}, $r->{'values'}->[0]);
	}

my $err;
if (!$wapi) {
	# Apply using BIND API calls
	&bind8::bump_soa_record($file, $recs);
	&bind8::sign_dnssec_zone_if_key($zone, $recs);
	&bind8::after_editing($zone);
	&bind8::restart_zone($zone->{'name'}, $zone->{'view'});
	}
else {
	# Apply using Virtualmin API
	$err = &virtual_server::post_records_change($d, $recs, $file);
	&virtual_server::reload_bind_records($d);
	}
&unlock_file(&bind8::make_chroot($file));
die $err if ($err);
sleep($config{'letsencrypt_dns_wait'} || 10);	# Wait for DNS propagation
&webmin_log("letsencryptdns", undef, $dname);
exit(0);
