#!/usr/local/bin/perl
# index_run.cgi
# Allows running of a new command

require './proc-lib.pl';
if (!$access{'run'}) {
	&redirect("index_tree.cgi");
	}
use Config;
&ui_print_header(undef, $text{'index_title'}, "", "run", !$no_module_config, 1);
&ReadParse();
&index_links("run");

print "<form action=run.cgi method=post>\n";
print "<table>\n";
print "<tr> <td>",&hlink("<b>$text{'run_command'}</b>","cmd"),"</td>\n";
print "<td><input name=cmd size=40>\n";
print "<input type=submit value=\"$text{'run_submit'}\"></td> </tr>\n";

print "<tr> <td>",&hlink("<b>$text{'run_mode'}</b>","mode"),"</td>\n";
print "<td><input type=radio name=mode value=1> $text{'run_bg'}\n";
print "<input type=radio name=mode value=0 checked> $text{'run_fg'}</td>\n";
print "</tr>\n";

if (&supports_users()) {
	if ($< == 0) {
		print "<tr> <td>",&hlink("<b>$text{'run_as'}</b>","runas"),
		      "</td>\n";
		print "<td>",&ui_user_textbox("user", $default_run_user),
		      "</td> </tr>\n";
		}
	else {
		print &ui_hidden("user", $remote_user),"\n";
		}
	}

print "<tr> <td valign=top>",
      &hlink("<b>$text{'run_input'}</b>","input"),"</td>\n";
print "<td><textarea name=input rows=5 cols=30></textarea></td> </tr>\n";
print "</table></form>\n";

&ui_print_footer("/", $text{'index'});
