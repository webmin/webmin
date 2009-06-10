#!/usr/local/bin/perl
# check.cgi
# Run a fetchmail config file

require './fetchmail-lib.pl';
&ReadParse();

if ($config{'config_file'}) {
	$file = $config{'config_file'};
	}
else {
	&can_edit_user($in{'user'}) || &error($text{'poll_ecannot'});
	@uinfo = getpwnam($in{'user'});
	$file = "$uinfo[7]/.fetchmailrc";
	$uheader = &text('poll_foruser', "<tt>$in{'user'}</tt>");
	}

&ui_print_unbuffered_header($uheader, $text{'check_title'}, "");

$cmd = "$config{'fetchmail_path'} -v -f '$file'";
if ($config{'mda_command'}) {
	$cmd .= " -m '$config{'mda_command'}'";
	}
if (defined($in{'idx'})) {
	@conf = &parse_config_file($file);
	$poll = $conf[$in{'idx'}];
	$cmd .= " $poll->{'poll'}";
	}

print &text('check_exec', "<tt>$cmd</tt>"),"<p>\n";
print "<pre>";
if ($< == 0) {
	# For webmin, switch to the user
	if ($in{'user'} ne 'root') {
		$cmd = &command_as_user($in{'user'}, 0, $cmd)
		}
	open(CMD, "$cmd 2>&1 |");
	&additional_log("exec", undef, "su '$in{'user'}' -c '$cmd'");
	}
else {
	# For usermin, which has already switched
	open(CMD, "$cmd 2>&1 |");
	}
while(<CMD>) {
	print &html_escape($_);
	}
close(CMD);
print "</pre>\n";

if ($? > 256) { print "<b>$text{'check_failed'}</b> <p>\n"; }
else { print "$text{'check_ok'} <p>\n"; }

&webmin_log("check", defined($in{'idx'}) ? "server" : "file",
	    $config{'config_file'} ? $file : $in{'user'}, $poll);

if (!$fetchmail_config && $config{'view_mode'}) {
	&ui_print_footer("edit_user.cgi?user=$in{'user'}", $text{'user_return'},
			 "", $text{'index_return'});
	}
else {
	&ui_print_footer("", $text{'index_return'});
	}

