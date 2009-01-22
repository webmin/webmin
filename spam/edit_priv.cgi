#!/usr/local/bin/perl
# edit_priv.cgi
# Display various privileged settings

require './spam-lib.pl';
&ReadParse();
&set_config_file_in(\%in);
&can_use_check("priv");
&ui_print_header($header_subtext, $text{'priv_title'}, "");
$conf = &get_config();

print "$text{'priv_desc'}<p>\n";
&start_form("save_priv.cgi", $text{'priv_header'});

print "<tr> <td><b>$text{'priv_white'}</b></td> <td colspan=3 nowrap>";
&opt_field("auto_whitelist_path", $x=&find("auto_whitelist_path", $conf), 40,
	   "~/.spamassassin/auto-whitelist");
print "</td> </tr>\n";

print "<tr> <td><b>$text{'priv_mode'}</b></td> <td nowrap>";
&opt_field("auto_whitelist_file_mode", $x=&find("auto_whitelist_file_mode", $conf), 4,
	   "0700");
print "</td> </tr>\n";

print "<tr> <td><b>$text{'priv_dcc'}</b></td> <td nowrap>";
&opt_field("dcc_options", $x=&find("dcc_options", $conf), 10, "-R");
print "</td> </tr>\n";

print "<tr> <td><b>$text{'priv_log'}</b></td> <td colspan=3 nowrap>";
&opt_field("timelog_path", $x=&find("timelog_path", $conf), 40, "NULL");
print "</td> </tr>\n";

print "<tr> <td><b>$text{'priv_razor'}</b></td> <td colspan=3 nowrap>";
&opt_field("razor_config", $x=&find("razor_config", $conf), 40, "~/razor.conf");
print "</td> </tr>\n";

&end_form(undef, $text{'save'});
&ui_print_footer($redirect_url, $text{'index_return'});


