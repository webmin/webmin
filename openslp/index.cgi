#!/usr/local/bin/perl
#
# An OpenSLP webmin module
# by Monty Charlton <monty@caldera.com>,
#
# Copyright (c) 2000 Caldera Systems
#
# Permission to use, copy, modify, and distribute this software and its
# documentation under the terms of the GNU General Public License is hereby 
# granted. No representations are made about the suitability of this software 
# for any purpose. It is provided "as is" without express or implied warranty.
# See the GNU General Public License for more details.
#
require './slp-lib.pl';

# Check if OpenSLP is actually installed
if (!-x $config{'slpd'}) {
	&ui_print_header(undef, $text{'index_title'}, "", "english", 1, 1, 0,
		&help_search_link("openslp", "man", "doc", "google"));
	print &text('index_eslpd', "<tt>$config{'slpd'}</tt>",
		  "@{[&get_webprefix()]}/config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

# Get the version number
$out = `$config{'slpd'} -v 2>&1`;
$out =~ /version:\s+(\S+)/i;
&ui_print_header(undef, $text{'index_title'}, "", "english", 1, 1, 0,
	&help_search_link("openslp", "man", "doc", "google"),
	undef, undef, &text('index_version', "$1"));

# Check if the config file exists
if (!-r $config{'slpd_conf'}) {
	print &text('index_econf', "<tt>$config{'slpd_conf'}</tt>",
		  "@{[&get_webprefix()]}/config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

@links =  ( "edit_snda.cgi", "edit_netcfg.cgi",
	    "edit_dacfg.cgi", "edit_log.cgi" );
@titles = ( $text{'snda_title'}, $text{'netcfg_title'},
	    $text{'dacfg_title'}, $text{'log_title'} );
@icons =  ( "images/snda.gif", "images/netcfg.gif",
	    "images/dacfg.gif", "images/log.gif" );
&icons_table(\@links, \@titles, \@icons);

print &ui_hr();
if (&slpd_is_running()) {
  print "<form action=stop.cgi>\n";
  print "<table width=100%><tr><td>\n";
  print "<input type=submit ",
        "value=\"$text{'index_stop'}\"></td>\n";
  print "<td>$text{'index_stopmsg'}</td> </tr></table>\n";
  print "</form>\n";  
}
else {
  print "<form action=start.cgi>\n";
  print "<table width=100%><tr><td>\n";
  print "<input type=submit ",
        "value=\"$text{'index_start'}\"></td>\n";
  print "<td>$text{'index_startmsg'}</td> </tr></table>\n";
  print "</form>\n";
}
&ui_print_footer("/", $text{'index'});

