#!/usr/local/bin/perl
# index.cgi

require './idmapd-lib.pl';

# Check if rpc.idmapd is installed
@st = stat($config{'idmapd_path'});
if (!@st) {
	&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
		&help_search_link("idmapd", "man"));
	print &text('index_eidmapd', "<tt>$config{'idmapd_path'}</tt>",
		  "@{[&get_webprefix()]}/config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
		 &help_search_link("idmapd", "man"));
%conf = &get_config();

print "<form action=\"save.cgi\">\n";
print "<table border width=100%>\n";
print "<tr $cb> <td><table>\n";
print "<tr $tb> <td colspan=4><b>$text{'general'}</b></td> </tr>\n";

print "<tr $cb> <td>",&hlink("<b>$text{'pipefs_dir'}</b>","pipefsdir"),"</td>\n";
print "<td><input name=pipefsdir size=40 value=\"$conf{'Pipefs-Directory'}\">",
    &file_chooser_button("pipefsdir", 1), "</td></tr>\n";

print "<tr> <td>",&hlink("<b>$text{'domain'}</b>","domain"),"</td>\n";
print "<td><input name=domain size=40 value=\"$conf{'Domain'}\"> </td></tr>\n";

print "<tr $tb> <td colspan=3><b>$text{'mapping'}</b></td> </tr>\n";

print "<tr> <td>",&hlink("<b>$text{'nobody_user'}</b>","nobody_user"),"</td>\n";
print "<td><input name=nobody_user size=40 value=\"$conf{'Nobody-User'}\">",
    &user_chooser_button("nobody_user", 0), "</td></tr>\n";

print "<tr> <td>",&hlink("<b>$text{'nobody_group'}</b>","nobody_group"),"</td>\n";
print "<td><input name=nobody_group size=40 value=\"$conf{'Nobody-Group'}\">",
    &group_chooser_button("nobody_group", 0), "</td></tr>\n";

print "</table></td></tr></table>\n";
print "<input type=submit value=\"$text{'save'}\"></form>\n";

&ui_print_footer("/", $text{'index'});
