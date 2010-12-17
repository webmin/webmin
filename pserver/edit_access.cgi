#!/usr/local/bin/perl
# edit_access.cgi
# Display readers and writers

require './pserver-lib.pl';
$access{'access'} || &error($text{'access_ecannot'});
&ui_print_header(undef, $text{'access_title'}, "");

print "<form action=save_access.cgi method=post>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'access_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

if (open(READ, $readers_file)) {
	@readers = ( );
	while(<READ>) {
		s/\r|\n//g;
		s/#.*$//g;
		push(@readers, $_) if (/\S/);
		}
	close(READ);
	}
print "<tr> <td width=50% valign=top nowrap>\n";
printf "<input type=radio name=readers_def value=1 %s> %s\n",
	scalar(@readers) ? "" : "checked", $text{'access_readers1'};
printf "<input type=radio name=readers_def value=0 %s> %s<br>\n",
	scalar(@readers) ? "checked" : "", $text{'access_readers0'};
print "<textarea rows=20 cols=30 name=readers>",
	join("\n", @readers),"</textarea>",
	&user_chooser_button("readers", 1),"</td>\n";

if (open(WRITE, $writers_file)) {
	@writers = ( );
	while(<WRITE>) {
		s/\r|\n//g;
		s/#.*$//g;
		push(@writers, $_) if (/\S/);
		}
	close(WRITE);
	}
print "<td width=50% valign=top nowrap>\n";
printf "<input type=radio name=writers_def value=1 %s> %s\n",
	scalar(@writers) ? "" : "checked", $text{'access_writers1'};
printf "<input type=radio name=writers_def value=0 %s> %s<br>\n",
	scalar(@writers) ? "checked" : "", $text{'access_writers0'};
print "<textarea rows=20 cols=30 name=writers>",
	join("\n", @writers),"</textarea>",
	&user_chooser_button("writers", 1),"</td> </tr>\n";

print "<tr> <td colspan=2>$text{'access_desc'}</td> </tr>\n";

print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'save'}'></form>\n";

&ui_print_footer("", $text{'index_return'});

