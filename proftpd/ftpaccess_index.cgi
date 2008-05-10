#!/usr/local/bin/perl
# ftpaccess_index.cgi
# Display a menu of icons for a per-directory options file

require './proftpd-lib.pl';
&ReadParse();
$conf = &get_ftpaccess_config($in{'file'});
$desc = "<tt>".&html_escape($in{'file'})."</tt>";
&ui_print_header($desc, $text{'ftpindex_title'}, "",
	undef, undef, undef, undef, "<a href=\"delete_ftpaccess.cgi?file=".
	&urlize($in{'file'})."\">$text{'ftpindex_delete'}</a>".
	"<br>".&restart_button());

print "<h3>$text{'ftpindex_opts'}</h3>\n";
# Add user permissions icon/link
$userperms_icon = { "icon" => "images/type_icon_3.gif",
	     "name" => "User Permissions",
	     "link" => "userpermissions_form.cgi?file=$in{'file'}" };
# Add 'edit as text' icon/link
$ed_icon = { "icon" => "images/edit.gif",
	     "name" => $text{'ftpindex_edit'},
	     "link" => "manual_form.cgi?file=$in{'file'}" };
&config_icons("ftpaccess", "edit_ftpaccess.cgi?file=$in{'file'}&", $ed_icon, $userperms_icon);

@limit = ( &find_directive_struct("Limit", $conf) );
if (@limit) {
	# Limit sub-directives
	print &ui_hr();
	print "<h3>$text{'ftpindex_limit'}</h3>\n";
	foreach $l (@limit) {
		push(@links, "limit_index.cgi?limit=".&indexof($l, @$conf).
			     "&file=$in{'file'}");
		push(@titles, $l->{'value'});
		push(@icons, "images/limit.gif");
		}
	&icons_table(\@links, \@titles, \@icons, 3);
	}

print "<form action=create_limit.cgi>\n";
print "<input type=hidden name=file value='$in{'file'}'>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'ftpindex_addlimit'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";
print "<tr> <td><b>$text{'ftpindex_cmds'}</b></td>\n";
print "<td><input name=cmd size=20>\n";
print "<input type=submit value=\"$text{'create'}\"></td> </tr>\n";
print "</table></td></tr></table></form>\n";

&ui_print_footer("ftpaccess.cgi", $text{'ftpaccess_return'},
	"", $text{'index_return'});


