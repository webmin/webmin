#!/usr/local/bin/perl
# edit_auth.cgi
# Display authentication settings

require './heartbeat-lib.pl';
&ui_print_header(undef, $text{'auth_title'}, "");

$conf = &get_auth_config();

print "<form action=save_auth.cgi>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'auth_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table><tr>\n";
print "<td valign=top><b>$text{'auth_mode'}</td> <td>\n";

$i = 1;
$n = $conf->{'auth'}->[0];
foreach $k ('crc', 'sha1', 'md5') {
	printf "<input type=radio name=auth value=%d %s> %s\n",
		$i, $conf->{$n}->[0] eq $k ? "checked" : "",
		$text{"auth_$k"};
	if ($k ne 'crc') {
		($thisnum) = grep { $conf->{$_}->[0] eq $k } (keys %$conf);
		printf "<input name=%s size=20 value='%s'>\n",
			$k, $conf->{$thisnum}->[1];
		}
	print "<br>\n";
	$i++;
	}

print "</td></tr></table></td></tr></table>\n";
print "<input type=submit value='$text{'save'}'></form>\n";

&ui_print_footer("", $text{'index_return'});

