#!/usr/local/bin/perl
# conn.cgi
# Open a PPTP connection and add its routes

require './pptp-client-lib.pl';
&error_setup($text{'conn_err'});
&ReadParse();

# Get tunnel details
@tunnels = &list_tunnels();
($tunnel) = grep { $_->{'name'} eq $in{'tunnel'} } @tunnels;
$tunnel || &error($text{'conn_egone'});
&parse_comments($tunnel);
$tunnel->{'server'} || &error($text{'conn_einvalid'});

# Check if it is already active
@conns = &list_connected();
($conn) = grep { $_->[0] eq $in{'tunnel'} } @conns;
$conn && &error($text{'conn_ealready'});

$theme_no_table++;
$| = 1;
&ui_print_header(undef, $text{'conn_title'}, "");

print "<b>",&text('conn_cmd', "<tt>$config{'pptp'} $tunnel->{'server'} ".
				 "call $in{'tunnel'}</tt>"),"</b><p>\n";

# If a password is passed, use it to temprarily overwrite the one in
# the secrets file
if ($in{'cpass'}) {
	$login = &find("name", $tunnel->{'opts'});
	$sn = $login ? $login->{'value'} : &get_system_hostname(1);
	&lock_file($config{'pap_file'});
	@secs = &list_secrets();
	($sec) = grep { $_->{'client'} eq $sn } @secs;
	$oldsecret = $sec->{'secret'};
	$sec->{'secret'} = $in{'cpass'};
	&change_secret($sec);
	&flush_file_lines();
	($ok, @status) = &connect_tunnel($tunnel);
	$sec->{'secret'} = $oldsecret;
	&change_secret($sec);
	&flush_file_lines();
	&unlock_file($config{'pap_file'});
	&lock_file($config{'pap_file'});
	}
else {
	($ok, @status) = &connect_tunnel($tunnel);
	}

if ($ok) {
	# Worked! Tell user
	print "<b>",&text('conn_ok', "<tt>$status[0]</tt>",
			  "<tt>$status[1]</tt>",
			  "<tt>$status[2]</tt>"),"</b><p>\n";
	local @rcmds = @{$status[3]};
	local @rout = @{$status[4]};
	if (@rcmds) {
		print "<b>$text{'conn_routes'}</b><pre>\n";
		for($i=0; $i<@rcmds; $i++) {
			print $rcmds[$i],"\n";
			print "<i>$rout[$i]</i>";
			}
		print "</pre>\n";
		}
	}
else {
	# Failed! Say why
	print "<b>$text{'conn_timeout'}</b><p>\n";
	print "<pre>$status[0]</pre>\n";
	if ($status[0] =~ /mppe/) {
		print "<b>",&text('conn_mppe', "edit_opts.cgi"),"</b><p>\n";
		}
	}

# Save tunnel as default
&lock_file("$module_config_directory/config");
$config{'tunnel'} = $in{'tunnel'};
$config{'iface'} = $status[0] if ($ok);
&write_file("$module_config_directory/config", \%config);
&unlock_file("$module_config_directory/config");

&webmin_log("conn", undef, $in{'tunnel'}, $newiface);
&ui_print_footer("", $text{'index_return'});


