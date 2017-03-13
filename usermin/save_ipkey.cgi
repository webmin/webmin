#!/usr/local/bin/perl
# Save, create or delete an IP-specific SSL key

require './usermin-lib.pl';
&ReadParse();
&get_usermin_miniserv_config(\%miniserv);
@ipkeys = &webmin::get_ipkeys(\%miniserv);
if (!$in{'new'}) {
	$ipkey = $ipkeys[$in{'idx'}];
	}
else {
	$ipkey = { };
	}

if ($in{'delete'}) {
	# Just remove this entry
	splice(@ipkeys, $in{'idx'}, 1);
	}
else {
	# Validate inputs
	&error_setup($text{'ipkey_err'});
	@ips = split(/\s+/, $in{'ips'});
	foreach $i (@ips) {
		&check_ipaddress($i) || &check_ip6address($i) ||
			$i =~ /^(\*\.)?[a-z0-9\.\_\-]+$/i ||
			&error(&text('ipkey_eip2', $i));
		}
	@ips || &error(&text('ipkey_eips'));
	$ipkey->{'ips'} = \@ips;
	&webmin::validate_key_cert($in{'key'}, $in{'cert_def'} ? undef : $in{'cert'});
	$ipkey->{'key'} = $in{'key'};
	$ipkey->{'cert'} = $in{'cert_def'} ? undef : $in{'cert'};
	if ($in{'extracas_mode'} == 0) {
		delete($ipkey->{'extracas'});
		}
	elsif ($in{'extracas_mode'} == 2) {
		$ipkey->{'extracas'} = 'none';
		}
	else {
		@files = split(/\s+/, $in{'extracas'});
		@files || &error($text{'ipkey_eextracas'});
		foreach $f (@files) {
			-r $f || &error(&text('ipkey_eextraca', $f));
			}
		$ipkey->{'extracas'} = join(' ', @files);
		}

	# Save or add
	if ($in{'new'}) {
		push(@ipkeys, $ipkey);
		}
	}

&webmin::save_ipkeys(\%miniserv, \@ipkeys);
&lock_file($usermin_miniserv_config);
&put_usermin_miniserv_config(\%miniserv);
&unlock_file($usermin_miniserv_config);
&restart_usermin_miniserv();
&webmin_log("ipkey");
&redirect("edit_ssl.cgi?mode=ips");

