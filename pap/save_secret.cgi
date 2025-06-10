#!/usr/local/bin/perl
# save_secret.cgi
# Update the secrets file to add or change a secret

require './pap-lib.pl';
$access{'secrets'} || &error($text{'secrets_ecannot'});
&ReadParse();
&error_setup($text{'save_secret_esave'});

&lock_file($config{'pap_file'});
if (defined($in{'idx'})) {
	@seclist = &list_secrets();
	%sec = %{$seclist[$in{'idx'}]};
	if ($in{'delete'}) {
		&delete_secret(\%sec);
		&unlock_file($config{'pap_file'});
		&webmin_log("delete", undef, $sec{'client'}, \%sec);
		&redirect("list_secrets.cgi");
		exit;
		}
	}

if ($in{'client_def'}) { $sec{'client'} = ""; }
else { $sec{'client'} = $in{'client'}; }

if ($in{'server_def'}) { $sec{'server'} = "*"; }
else { $sec{'server'} = $in{'server'}; }

if ($in{'pass_mode'} == 0) { $sec{'secret'} = ""; }
elsif ($in{'pass_mode'} == 1) { $sec{'secret'} = "\@$in{'pass_file'}"; }
elsif ($in{'pass_mode'} == 3) { $sec{'secret'} = &opt_crypt($in{'pass_text'}); }

if ($in{'ips_mode'} == 0) { $sec{'ips'} = [ "*" ]; }
elsif ($in{'ips_mode'} == 1) { $sec{'ips'} = [ "-" ]; }
elsif ($in{'ips_mode'} == 2) {
	@ips = split(/\s+/, $in{'ips'});
	foreach $ip (@ips) {
		if (!&to_ipaddress($ip)) {
			&error(&text('save_secret_enoip', $ip));
			}
		}
	$sec{'ips'} = \@ips;
	}

if (defined($in{'idx'})) { &change_secret(\%sec); }
else { &create_secret(\%sec); }
&unlock_file($config{'pap_file'});
delete($sec{'secret'});
&webmin_log(defined($in{'idx'}) ? 'modify' : 'create',
	    undef, $sec{'client'}, \%sec);
&redirect("list_secrets.cgi");

