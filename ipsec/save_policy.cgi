#!/usr/local/bin/perl
# save_policy.cgi
# Update some policy file

require './ipsec-lib.pl';
&ReadParse();
&error_setup($text{'policy_err'});

if ($in{'mode'} == 0) {
	@policies = ( );
	}
elsif ($in{'mode'} == 1) {
	@policies = ( "0.0.0.0/0" );
	}
else {
	for($i=0; defined($n = $in{"net_$i"}); $i++) {
		next if ($n eq '');
		$m = $in{"mask_$i"};
		&check_ipaddress($n) || &error(&text('policy_enet', $i+1));
		$m =~ /^\d+/ && $m <= 32 || &error(&text('policy_emask', $i+1));
		push(@policies, "$n/$m");
		}
	}
&lock_file("$config{'policies_dir'}/$in{'policy'}");
&write_policy($in{'policy'}, \@policies);
&unlock_file("$config{'policies_dir'}/$in{'policy'}");
&webmin_log("policy", undef, $in{'policy'});
&redirect("");

