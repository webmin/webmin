#!/usr/local/bin/perl
# index.cgi
# Display icons for various things that can be configured in sendmail

require './sendmail-lib.pl';
require './boxes-lib.pl';

# Check if sendmail is actually installed
if (!-x $config{'sendmail_path'}) {
	&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1, 0,
		&help_search_link("sendmail", "man", "doc", "google"));
	print &text('index_epath', "<tt>$config{'sendmail_path'}</tt>",
			  "@{[&get_webprefix()]}/config.cgi?$module_name"),"<p>\n";

	&foreign_require("software", "software-lib.pl");
	$lnk = &software::missing_install_link(
			"sendmail", $text{'index_sendmail'},
			"../$module_name/", $text{'index_title'});
	print $lnk,"<p>\n" if ($lnk);

	&ui_print_footer("/", $text{'index'});
	exit;
	}

# Get the executable version number
$ever = &get_sendmail_version(\$out);

# Check if the config file exists, and is the right version
if (!-s $config{'sendmail_cf'}) {
	&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1, 0,
		&help_search_link("sendmail", "man", "doc", "google"));
	print &text('index_econfig', "<tt>$config{'sendmail_cf'}</tt>",
		  "@{[&get_webprefix()]}/config.cgi?$module_name"),"<p>\n";

	&foreign_require("software", "software-lib.pl");
	$lnk = &software::missing_install_link(
			"sendmail", $text{'index_sendmail'},
			"../$module_name/", $text{'index_header'});
	print $lnk,"<p>\n" if ($lnk);

	&ui_print_footer("/", $text{'index'});
	exit;
	}
$conf = &get_sendmailcf();
$cfgver = &find_type("V", $conf);
&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1, 0,
	&help_search_link("sendmail", "man", "doc", "google"), undef, undef,
	$ever && $cfgver ? &text('index_version2',$ever,"V$cfgver->{'value'}") :
	$cfgver ? &text('index_version', "V$cfgver->{'value'}") :
	$ever ? &text('index_xversion', $ever) : undef);

if (!&check_sendmail_version($conf)) {
	print "$text{'index_eversion'}<p>\n";
	&ui_print_footer("/", "index");
	exit;
	}

local $mcount;
if (!$config{'mailq_count'}) {
	# Check the mail spool
	@qfiles = &list_mail_queue($conf);
	if ($access{'qdoms'}) {
		# Filter out blocked mails
		@qfiles = grep { &can_view_qfile(&mail_from_queue($_)) }
		       	       @qfiles;
		}
	$mcount = scalar(@qfiles);
	}

@olinks =  ( "list_opts.cgi", "list_ports.cgi", "list_aliases.cgi", "list_cws.cgi", "list_masq.cgi", "list_trusts.cgi", "list_virtusers.cgi", "list_mailers.cgi", "list_generics.cgi", "list_cgs.cgi", "list_domains.cgi", "list_access.cgi", "list_relay.cgi", "list_features.cgi", "list_mailq.cgi", "../mailboxes/" );

@otitles = ( "$text{'opts_title'} (O)", $text{'ports_title'}, "$text{'aliases_title'} (aliases)", "$text{'cws_title'} (Cw)", "$text{'masq_title'} (CM)", "$text{'trusts_title'} (T)", "$text{'virtusers_title'} (virtuser)", "$text{'mailers_title'} (mailertable)", "$text{'generics_title'} (generics)", "$text{'cgs_title'} (CG)", "$text{'domains_title'} (domaintable)", "$text{'access_title'} (access)", "$text{'relay_title'} (CR)", $text{'features_title'}, "$text{'mailq_title'} (mailq)".(defined($mcount) ? "<br>".&text('mailq_count', $mcount) : ""), "$text{'boxes_title'}"); 

@oicons =  ( "images/opts.gif", "images/ports.gif", "images/aliases.gif", "images/cws.gif", "images/masq.gif", "images/trusts.gif", "images/virtusers.gif", "images/mailers.gif", "images/generics.gif", "images/cgs.gif", "images/domains.gif", "images/access.gif", "images/relay.gif", "images/features.gif", "images/mailq.gif", "images/boxes.gif" );

&filter_icons($access{'opts'}, "list_opts.cgi");
&filter_icons($access{'ports'}, "list_ports.cgi");
&filter_icons($access{'cws'}, "list_cws.cgi");
&filter_icons($access{'masq'}, "list_masq.cgi");
&filter_icons($access{'trusts'}, "list_trusts.cgi");
&filter_icons($access{'vmode'}, "list_virtusers.cgi");
&filter_icons($access{'amode'}, "list_aliases.cgi");
&filter_icons($access{'omode'}, "list_generics.cgi");
&filter_icons($access{'cgs'}, "list_cgs.cgi");
&filter_icons($access{'relay'}, "list_relay.cgi");
&filter_icons($access{'mailq'}, "list_mailq.cgi");
&filter_icons($access{'mailers'}, "list_mailers.cgi");
&filter_icons($access{'access'}, "list_access.cgi");
&filter_icons($access{'domains'}, "list_domains.cgi");
&filter_icons($features_access, "list_features.cgi");
&filter_icons(&foreign_available("mailboxes"), "list_boxes.cgi");

&icons_table(\@olinks, \@otitles, \@oicons);

if ($access{'stop'}) {
	print &ui_hr();
	print &ui_buttons_start();
	if (&is_sendmail_running()) {
		print &ui_buttons_row("stop.cgi", $text{'index_stop'},
				      $text{'index_stopmsg'});
		}
	else {
		print &ui_buttons_row("start.cgi", $text{'index_start'},
				      &text('index_startmsg',
				"<tt>$config{'sendmail_command'}</tt>"));
		}
	print &ui_buttons_end();
	}

&ui_print_footer("/", $text{'index'});

sub filter_icons
{
if (!$_[0]) {
	local $idx = &indexof($_[1], @olinks);
	splice(@olinks, $idx, 1);
	splice(@otitles, $idx, 1);
	splice(@oicons, $idx, 1);
	}
}

