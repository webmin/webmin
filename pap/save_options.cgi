#!/usr/local/bin/perl
# save_options.cgi
# Save PPP options

require './pap-lib.pl';
$access{'options'} || &error($text{'options_ecannot'});
&ReadParse();
&error_setup($text{'options_err'});
$file = $in{'file'} || $config{'ppp_options'};
&lock_file($file);
@opts = &parse_ppp_options($file);

# Validate inputs
if (!$in{'ip_def'}) {
	&check_ipaddress($in{'local'}) || &error($text{'options_elocal'});
	&check_ipaddress($in{'remote'}) || &error($text{'options_eremote'});
	}
if (!$in{'netmask_def'}) {
	&check_ipaddress($in{'netmask'}) || &error($text{'options_enetmask'});
	}
if (!$in{'idle_def'}) {
	$in{'idle'} =~ /^\d+$/ || &error($text{'options_eidle'});
	}
@dns = split(/\s+/, $in{'dns'});
foreach $d (@dns) {
	&check_ipaddress($d) || &error(&text('options_edns', $d));
	}

if (!$in{'file'}) {
	# Save AutoPPP setting
	&lock_file($config{'login_config'});
	@login = &parse_login_config();
	($auto) = grep { $_->{'user'} eq "/AutoPPP/" } @login;
	if ($auto && !$in{'auto'}) {
		# Delete AutoPPP entry
		&delete_login_config(\@login, $auto);
		}
	elsif (!$auto && $in{'auto'}) {
		&create_login_config(\@login, 
		    { 'user' => '/AutoPPP/', 'userid' => '-',
		      'utmp' => 'a_ppp', 'program' => &has_command("pppd") });
		}
	}

# Save PPP options
($ip) = grep { $_->{'local'} } @opts;
&save_ppp_option(\@opts, $file, $ip, $in{'ip_def'} ? undef :
	{ 'local' => $in{'local'}, 'remote' => $in{'remote'} });
&save_ppp_option(\@opts, $file, "netmask", $in{'netmask_def'} ? undef :
	{ 'name' => 'netmask', 'value' => $in{'netmask'} });
&save_ppp_option(\@opts, $file, "proxyarp",
		 $in{'proxyarp'} ? { 'name' => 'proxyarp' } : undef);
&save_ppp_option(\@opts, $file, "lock",
		 $in{'lock'} ? { 'name' => 'lock' } : undef);
if ($in{'ctrl'} == 0) {
	&save_ppp_option(\@opts, $file, "modem", undef);
	&save_ppp_option(\@opts, $file, "local", { 'name' => 'local' });
	}
elsif ($in{'ctrl'} == 1) {
	&save_ppp_option(\@opts, $file, "local", undef);
	&save_ppp_option(\@opts, $file, "modem", { 'name' => 'modem' });
	}
else {
	&save_ppp_option(\@opts, $file, "modem", undef);
	&save_ppp_option(\@opts, $file, "local", undef);
	}
if ($in{'auth'} == 0) {
	&save_ppp_option(\@opts, $file, "auth", undef);
	&save_ppp_option(\@opts, $file, "noauth", undef);
	}
elsif ($in{'auth'} == 1) {
	&save_ppp_option(\@opts, $file, "auth", undef);
	&save_ppp_option(\@opts, $file, "noauth", { 'name' => 'noauth' });
	}
else {
	&save_ppp_option(\@opts, $file, "noauth", undef);
	&save_ppp_option(\@opts, $file, "auth", { 'name' => 'auth' });
	}
&save_ppp_option(\@opts, $file, "login",
		 $in{'login'} ? { 'name' => 'login' } : undef);
&save_ppp_option(\@opts, $file, "idle", $in{'idle_def'} ? undef :
		{ 'name' => 'idle', 'value' => $in{'idle'} } );
@olddns = &find("ms-dns", \@opts);
for($i=0; $i<@dns || $i<@olddns; $i++) {
	&save_ppp_option(\@opts, $file, $olddns[$i],
			 $dns[$i] ? { 'name' => 'ms-dns', 'value' => $dns[$i] }
				  : undef);
	}

# All done
&flush_file_lines();
&unlock_file($file);
&unlock_file($config{'login_config'}) if (!$in{'file'});
&webmin_log("options", undef, $in{'tty'}, \%in);
&redirect($in{'file'} ? "list_mgetty.cgi" : "");

