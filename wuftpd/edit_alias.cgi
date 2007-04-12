#!/usr/local/bin/perl
# edit_alias.cgi
# Display alias and cd path options

require './wuftpd-lib.pl';
&ui_print_header(undef, $text{'alias_title'}, "", "alias");
$conf = &get_ftpaccess();

print "<form action=save_alias.cgi>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'alias_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

# display alias options
@alias = ( &find_value('alias', $conf), [ ] );
print "<tr> <td valign=top><b>$text{'alias_alias'}</b></td>\n";
print "<td><table border>\n";
print "<tr $tb> <td><b>$text{'alias_from'}</b></td> ",
      "<td><b>$text{'alias_to'}</b></td> </tr>\n";
$i = 0;
foreach $a (@alias) {
	print "<tr $cb>\n";
	print "<td><input name=from_$i size=15 value='$a->[0]'></td>\n";
	print "<td><input name=to_$i size=25 value='$a->[1]'></td>\n";
	print "</tr>\n";
	$i++;
	}
print "</table></td> </tr>\n";

# display cdpath options
@cdpath = map { $_->[0] } &find_value('cdpath', $conf);
print "<tr> <td valign=top><b>$text{'alias_cdpath'}</b></td>\n";
print "<td><textarea name=cdpath rows=5 cols=40>",
	join("\n", @cdpath),"</textarea></td> </tr>\n";

print "</table></td></tr></table>\n";
print "<input type=submit value=\"$text{'save'}\"></form>\n";

&ui_print_footer("", $text{'index_return'});

