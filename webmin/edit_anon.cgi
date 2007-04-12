#!/usr/local/bin/perl
# edit_anon.cgi
# Display anonymous access form

require './webmin-lib.pl';
&ui_print_header(undef, $text{'anon_title'}, "");
&get_miniserv_config(\%miniserv);

print $text{'anon_desc'},"<br>\n";
print "<b>",$text{'anon_desc2'},"</b><p>\n";
foreach $a (split(/\s+/, $miniserv{'anonymous'})) {
	if ($a =~ /^([^=]+)=(\S+)$/) {
		push(@anon, [ $1, $2 ]);
		}
	}

print "<form action=change_anon.cgi>\n";
print "<table border> <tr $tb>\n";
print "<td><b>$text{'anon_url'}</b></td> <td><b>$text{'anon_user'}</b></td>\n";
print "</tr>\n";
push(@anon, scalar(@anon)%2 == 0 ? ( [ ], [ ] ) : ( [ ] ));
$i = 0;
foreach $a (@anon) {
	print "<tr $cb>\n";
	print "<td><input name=url_$i size=30 value='$a->[0]'></td>\n";
	print "<td><input name=user_$i size=20 value='$a->[1]'></td>\n";
	print "</tr>\n";
	$i++;
	}
print "</table>\n";
print "<input type=submit value='$text{'save'}'></form>\n";

&ui_print_footer("", $text{'index_return'});

