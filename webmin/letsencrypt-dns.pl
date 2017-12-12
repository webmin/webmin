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
my ($zone, $zname) = &get_bind_zone_for_domain($dname);
$zone || die "No zone named $dname found";
&lock_file(&bind8::make_chroot(&bind8::absolute_path($zone->{'file'})));
my @recs = &bind8::read_zone_file($zone->{'file'}, $zname);

# Remove any existing record
my ($r) = grep { $_->{'name'} eq "_acme-challenge.".$dname."." } @recs;
if ($r) {
	&bind8::delete_record($zone->{'file'}, $r);
	}

# Create the needed DNS record
&bind8::create_record($zone->{'file'},
		      "_acme-challenge.".$dname.".",
		      5,
		      "IN",
		      "TXT",
		      $val);
&bind8::bump_soa_record($zone->{'file'}, \@recs);
&bind8::sign_dnssec_zone_if_key($zone, \@recs);
&unlock_file(&bind8::make_chroot(&bind8::absolute_path($zone->{'file'})));

# Apply the change
&bind8::restart_bind();
sleep(10);	# Wait for DNS propagation
&webmin_log("letsencryptdns", undef, $dname);
exit(0);
