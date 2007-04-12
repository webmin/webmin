#!/usr/local/bin/perl
# edit_client.cgi
# Display NIS client options

require './nis-lib.pl';
&ui_print_header(undef, $text{'client_title'}, "");

if (!(&get_nis_support() & 1)) {
	print "<p>$text{'client_enis'}<p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}

$nis = &get_client_config();

print "<form action=save_client.cgi method=post>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'client_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

print "<tr> <td><b>$text{'client_domain'}</b></td>\n";
printf "<td valign=top><input type=radio name=domain_def value=1 %s> %s\n",
	$nis->{'domain'} ? '' : 'checked', $text{'client_none'};
printf "<input type=radio name=domain_def value=0 %s>\n",
	$nis->{'domain'} ? 'checked' : '';
printf "<input name=domain size=35 value='%s'></td> </tr>\n",
	$nis->{'domain'};

print "<tr> <td valign=top><b>$text{'client_servers'}</b></td>\n";
printf "<td><input type=radio name=broadcast value=1 %s> %s\n",
	$nis->{'broadcast'} ? 'checked' : '', $text{'client_broadcast'};
printf "<input type=radio name=broadcast value=0 %s> %s<br>\n",
	$nis->{'broadcast'} ? '' : 'checked', $text{'client_listed'};
print "<textarea name=servers rows=3 cols=35>",
      join("\n", &unique(@{$nis->{'servers'}})),"</textarea></td> </tr>\n";

print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'client_ok'}'></form>\n";
&ui_print_footer("", $text{'index_return'});

