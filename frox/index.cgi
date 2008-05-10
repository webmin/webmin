#!/usr/local/bin/perl
# Display icons for the various Frox config sections

require './frox-lib.pl';

# Make sure frox is installed
if (!-r $config{'frox_conf'} && -r $config{'alt_frox_conf'}) {
	system("cp ".quotemeta($config{'alt_frox_conf'})." ".
		     quotemeta($config{'frox_conf'}));
	}
if (!-r $config{'frox_conf'}) {
	&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1);
	&ui_print_endpage(
		&ui_config_link('index_econf',
			[ "<tt>$config{'frox_conf'}</tt>", undef ]));
	}
if (!&has_command($config{'frox'})) {
	&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1);
	&ui_print_endpage(
		&ui_config_link('index_ecmd',
		        [ "<tt>$config{'frox'}</tt>", undef ]));
	}

# Get the version
# XXX

# Show icons
&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1, 0,
		 &help_search_link("frox", "man", "doc", "google"),
		 undef, undef,
		 &text('index_version', $frox_version));

@names = ( "net", "general", "ftp", "cache", "acl" );
push(@names, "iptables") if (&foreign_check("firewall"));
@titles = map { $text{$_."_title"} } @names;
@icons = map { "images/$_.gif" } @names;
@links = map { "edit_${_}.cgi" } @names;
&icons_table(\@links, \@titles, \@icons);

# Show start/stop/apply buttons
$conf = &get_config();
if (&find_value("FromInetd", $conf) ne "yes") {
	print &ui_hr();
	print &ui_buttons_start();
	if (&is_frox_running()) {
		print &ui_buttons_row("apply.cgi", $text{'index_apply'},
				      $text{'index_applydesc'});
		print &ui_buttons_row("stop.cgi", $text{'index_stop'},
				      $text{'index_stopdesc'});
		}
	else {
		print &ui_buttons_row("start.cgi", $text{'index_start'},
				      $text{'index_startdesc'});
		}
	print &ui_buttons_end();
	}
else {
	print "<b>$text{'index_inetd'}</b><p>\n";
	}

&ui_print_footer("/", $text{'index'});

