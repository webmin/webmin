#!/usr/local/bin/perl
# edit_auth.cgi
# Display commands and allowed users

require './mon-lib.pl';
&ui_print_header(undef, $text{'auth_title'}, "");

$file = &mon_auth_file();
open(FILE, $file);
while(<FILE>) {
	s/\r|\n//g;
	s/#.*$//;
	if (/^(\S+):\s*(.*)$/) {
		$auth{$1} = [ split(/,/, $2) ];
		}
	}
close(FILE);

print "$text{'auth_desc'}<p>\n";

print "<form action=save_auth.cgi method=post>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'auth_cmd'}</b></td> ",
      "<td><b>$text{'auth_users'}</b></td> </tr>\n";
printf "<input type=hidden name=types value='%s'>\n", join(" ", keys %auth);
foreach $a (&list_auth_types()) {
	local @au = @{$auth{$a}};
	print "<tr $cb> <td><b>$a</b></td> <td>\n";
	printf "<input type=radio name=${a}_mode value=2 %s> %s\n",
		@au ? "" : "checked", $text{'auth_none'};
	printf "<input type=radio name=${a}_mode value=1 %s> %s\n",
		$au[0] eq "all" ? "checked" : "", $text{'auth_all'};
	printf "<input type=radio name=${a}_mode value=0 %s> %s\n",
		@au && $au[0] ne "all" ? "checked" : "",
		$text{'auth_sel'};
	printf "<input name=$a size=40 value='%s'> %s</td> </tr>\n",
		$au[0] eq "all" ? "" : join(" ", @{$auth{$a}}),
		&user_chooser_button($a, 0);
	delete($auth{$a});
	}
print "</table>\n";
foreach $a (keys %auth) {
	print "<input type=hidden name=$a value='",
		join(",", @{$auth{$a}}),"'>\n";
	}
print "<input type=submit value='$text{'save'}'></form>\n";

&ui_print_footer("", $text{'index_return'});

