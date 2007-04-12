#!/usr/local/bin/perl
# save.cgi
# Save the ADSL client configuration

require './adsl-client-lib.pl';
&error_setup($text{'save_err'});
&lock_file($config{'pppoe_conf'});
$conf = &get_config();
&ReadParse();

# Validate and store inputs
$eth = $in{'eth'} || $in{'other'};
$eth =~ /^\S+$/ || &error($text{'save_eeth'});
&save_directive($conf, "ETH", $eth);

if ($in{'demand'} eq 'yes') {
	$in{'timeout'} =~ /^\d+$/ || &error($text{'save_etimeout'});
	&save_directive($conf, "DEMAND", $in{'timeout'});
	}
else {
	&save_directive($conf, "DEMAND", 'no');
	}
 
$olduser = &find("USER", $conf);
$in{'user'} =~ /^\S+$/ || &error($text{'save_euser'});
&save_directive($conf, "USER", $in{'user'});

$dnsdir = &find("USEPEERDNS", $conf) ? "USEPEERDNS" : "PEERDNS";
&save_directive($conf, $dnsdir, $in{'dns'});

if ($in{'connect_def'}) {
	&save_directive($conf, "CONNECT_TIMEOUT", 0);
	}
else {
	$in{'connect'} =~ /^\d+$/ || &error($text{'save_econnect'});
	&save_directive($conf, "CONNECT_TIMEOUT", $in{'connect'});
	}

if ($in{'mss'} eq 'yes') {
	$in{'psize'} =~ /^\d+$/ || &error($text{'save_emss'});
	&save_directive($conf, "CLAMPMSS", $in{'psize'});
	}
else {
	&save_directive($conf, "CLAMPMSS", 'no');
	}

if ($in{'fw'}) {
	&save_directive($conf, "FIREWALL", $in{'fw'});
	}

# Actually save the directives, and update the pap-secrets file
&flush_file_lines();
&unlock_file($config{'pppoe_conf'});
&lock_file($config{'pap_file'});
@secs = &list_secrets();
($sec) = grep { $_->{'client'} eq $olduser } @secs;
if (!$sec) {
	($sec) = grep { $_->{'client'} eq $in{'user'} } @secs;
	}
if ($sec) {
	$sec->{'secret'} = $in{'sec'};
	$sec->{'client'} = $in{'user'};
	&change_secret($sec);
	}
else {
	$sec = { 'secret' => $in{'sec'},
		 'client' => $in{'user'},
		 'server' => '*' };
	&create_secret($sec);
	}
&unlock_file($config{'pap_file'});
&webmin_log("save");

# Tell the user
&ui_print_header(undef, $text{'save_title'}, "");

print "<p>$text{'save_desc'}<p>\n";

&ui_print_footer("", $text{'index_return'});

