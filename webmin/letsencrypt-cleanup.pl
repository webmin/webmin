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
my ($zone, $zname) = &get_bind_zone_for_domain($dname);
$zone || die "No zone named $dname found";
&lock_file(&bind8::make_chroot(&bind8::absolute_path($zone->{'file'})));
my @recs = &bind8::read_zone_file($zone->{'file'}, $zname);

# Find and remove the record. Does nothing if it doesn't exist so as not to
# fail a repeated cleanup.
my ($r) = grep { $_->{'name'} eq "_acme-challenge.".$dname."." } @recs;
if ($r) {
	&bind8::delete_record($zone->{'file'}, $r);
	&bind8::sign_dnssec_zone_if_key($zone, \@recs);
	&bind8::bump_soa_record($zone->{'file'}, \@recs);
	}
&unlock_file(&bind8::make_chroot(&bind8::absolute_path($zone->{'file'})));

# Apply the change
&bind8::restart_bind();
sleep(10);	# Wait for DNS propagation
&webmin_log("letsencryptcleanup", undef, $dname);
