#!/usr/local/bin/perl
#
# postfix-module by Guillaume Cottenceau <gc@mandrakesoft.com>,
# for webmin by Jamie Cameron
#
# A word about this module.
#
# Postfix provides a command to control its parameters: `postconf'.
# That's the reason why I don't parse and set the values manually.
# It's much better because it can resist to changes of the Postfix
# config files.
#
# However, to `set back to default' an already changed parameter,
# there is no way to do it in the case of dynamic parameters.
# [example: I mean that for `static' parameters, which defaults to
# `0', I can set the parameter to `0' ; but for `dynamic'
# parameters such as domainname [which comes from a system call]
# I have no way]
# So for this special case, I parse the config file, and delete
# manually the correct line.
#
# gc.
#


require './postfix-lib.pl';

&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1, 0,
	&help_search_link("postfix", "man", "doc", "google"),
	undef, undef, $postfix_version ?
		&text('index_version', $postfix_version) : undef);

# Save the version for use by other CGIs
&open_tempfile(VERSION, ">$module_config_directory/version", 0, 1);
&print_tempfile(VERSION, "$postfix_version\n");
&close_tempfile(VERSION);

# Verify the postfix control command
if (!&valid_postfix_command($config{'postfix_control_command'})) {
	print &text('index_epath',
		"<tt>$config{'postfix_control_command'}</tt>",
		"../config.cgi?$module_name"),"<p>\n";

	&foreign_require("software", "software-lib.pl");
	$lnk = &software::missing_install_link(
			"postfix", $text{'index_postfix'},
			"../$module_name/", $text{'index_title'});
	print $lnk,"<p>\n" if ($lnk);

	&ui_print_footer("/", $text{'index'});
	exit;
	}

# Verify the postfix config command
if (!&valid_postfix_command($config{'postfix_config_command'})) {
	print &text('index_econfig',
		"<tt>$config{'postfix_config_command'}</tt>",
		"../config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

# Verify the postsuper command
if (!&valid_postfix_command($config{'postfix_super_command'})) {
	print &text('index_esuper',
		"<tt>$config{'postfix_super_command'}</tt>",
		"../config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

# Verify that current configuration is valid. If not, only allow manual editing
if ($config{'index_check'} && ($err = &check_postfix())) {
	print &text('check_error'),"<p>\n";
	print "<pre>$err</pre>\n";
	if ($access{'manual'}) {
		print "<a href=edit_manual.cgi>$text{'check_manual'}</a><p>\n";
		}
	&ui_print_footer("/", $text{'index'});
	exit;
	}

@onames =  ( "general", "address_rewriting", "aliases", "canonical",
	     "virtual", "transport", "relocated", "header", "body", "bcc",
	     &compare_version_numbers($postfix_version, 2.7) > 0 ?
	     	( "dependent" ) : ( ),
	     "local_delivery", "resource",
	     "smtpd", "smtp", "sasl", "client",
	     "rate", "debug", $postfix_version > 2 ? ( ) : ( "ldap" ),
	     "master", "mailq", "postfinger", "boxes", "manual" );

$access{'boxes'} = &foreign_available("mailboxes");
foreach $oitem (@onames)
{
	if ($access{$oitem}) {
		push (@olinks, $oitem eq "boxes" ? "../mailboxes/"
						 : $oitem . ".cgi");
		push (@otitles, $oitem eq 'manual' ? $text{'cmanual_title'}
						   : $text{$oitem . "_title"});
		if ($oitem eq 'mailq' && !$config{'mailq_count'}) {
			# Count the queue
			local @mqueue = &list_queue(0);
			local $mcount = scalar(@mqueue);
			$otitles[$#otitles] .=
				"<br>".&text('mailq_count', $mcount);
			}
		push (@oicons, "images/" . $oitem . ".gif");
	}
}

&icons_table(\@olinks, \@otitles, \@oicons);

# Show start / stop / reload buttons
if ($access{'startstop'}) {
	print &ui_hr();
	print &ui_buttons_start();

	if (&is_postfix_running()) {
		print &ui_buttons_row("stop.cgi", $text{'index_stop'},
                                      $text{'index_stopmsg'});
		print &ui_buttons_row("reload.cgi", $text{'index_reload'},
                                      $text{'index_reloadmsg'});
		}
	else {
		print &ui_buttons_row("start.cgi", $text{'index_start'},
                                      $text{'index_startmsg'});
		}
	print &ui_buttons_end();
	}

&ui_print_footer("/", $text{'index'});



