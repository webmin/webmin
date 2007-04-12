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
	&error_setup($webmin::text{'ipkey_err'});
	@ips = split(/\s+/, $in{'ips'});
	foreach $i (@ips) {
		&check_ipaddress($i) ||
			&error(&webmin::text('ipkey_eip', $i));
		}
	@ips || &error(&webmin::text('ipkey_eips'));
	$ipkey->{'ips'} = \@ips;
	&webmin::validate_key_cert($in{'key'}, $in{'cert_def'} ? undef : $in{'cert'});
	$ipkey->{'key'} = $in{'key'};
	$ipkey->{'cert'} = $in{'cert_def'} ? undef : $in{'cert'};

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
&redirect("edit_ssl.cgi");

