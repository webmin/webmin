#!/usr/local/bin/perl
# index.cgi
# Display heartbeat option categories

require './heartbeat-lib.pl';

# Try to work out the version number
$heartbeat_version = undef;
if ($config{'version'}) {
	$heartbeat_version = $config{'version'};
	}
elsif (&backquote_command("($config{'heartbeat'} -V) </dev/null 2>&1") =~
       /(\S+)/) {
	$heartbeat_version = $1;
	}
elsif (&foreign_check("software")) {
	&foreign_require("software", "software-lib.pl");
	local @pinfo = &software::package_info("heartbeat");
	if (@pinfo) {
		$heartbeat_version = $pinfo[4];
		$heartbeat_version =~ s/-.*$//;
		}
	}
&open_tempfile(VERSION, ">$module_config_directory/version");
&print_tempfile(VERSION, $heartbeat_version,"\n");
&close_tempfile(VERSION);

&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
	&help_search_link("heartbeat", "man", "doc"),
	undef, undef, $heartbeat_version ? &text('index_version',
						 $heartbeat_version) : undef);

# Check if heartbeat is installed
if (!-d $config{'ha_dir'}) {
	print &text('index_edir', "<tt>$config{'ha_dir'}</tt>",
		  "@{[&get_webprefix()]}/config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

# Check if the config files exist, or if they can be copied
if (!-r $ha_cf && -r $config{'alt_ha_cf'}) {
	system("cp '$config{'alt_ha_cf'}' $ha_cf");
	}
if (!-r $ha_cf) {
	print &text('index_eha_cf', "<tt>$ha_cf</tt>",
		  "@{[&get_webprefix()]}/config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

if (!-r $haresources && -r $config{'alt_haresources'}) {
	system("cp '$config{'alt_haresources'}' '$haresources'");
	}
if (!-r $haresources) {
	print &text('index_eharesources', "<tt>$haresources</tt>",
		  "@{[&get_webprefix()]}/config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

if (!-r $authkeys && -r $config{'alt_authkeys'}) {
	system("cp '$config{'alt_authkeys'}' '$authkeys'");
	}
if (!-r $authkeys) {
	print &text('index_eauthkeys', "<tt>$authkeys</tt>",
		  "@{[&get_webprefix()]}/config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}
if (!-r $config{'req_resource_cmd'}) {
	print &text('index_ereq_resource_cmd', "<tt>$config{'req_resource_cmd'}</tt>",
		  "@{[&get_webprefix()]}/config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

@opts = ( 'conf', 'res','auth' );
@links = map { "edit_${_}.cgi" } @opts;
@titles = map { $text{"${_}_title"} } @opts;
@icons = map { "images/${_}.gif" } @opts;
&icons_table(\@links, \@titles, \@icons);

print &ui_hr();
print "<table width=100%><tr>\n";

# Show status
$status = `($config{'heartbeat'} -s) </dev/null 2>&1`;
print "<tr> <td><b>$text{'index_status'}</b></td>\n";
print "<td><tt>$status</tt></td> </tr>\n";

# Show start/stop button
if (&check_pid_file($config{'pid_file'})) {
	print "<form action=apply.cgi>\n";
	print "<td><input type=submit value='$text{'index_apply'}'></td>\n";
	print "<td>$text{'index_applymsg'}</td>\n";
	print "</form>\n";
	}
else {
	print "<form action=start.cgi>\n";
	print "<td><input type=submit value='$text{'index_start'}'></td>\n";
	print "<td>$text{'index_startmsg'}</td>\n";
	print "</form>\n";
	}

print "</tr></table>\n";

if (!$heartbeat_version) {
	print "<center><b>",&text('index_noversion', "../config.cgi?$module_name"),"</b></center>\n";
	}

&ui_print_footer("/", $text{'index'});
