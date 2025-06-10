#!/usr/local/bin/perl
# edit_opts.cgi
# Display PPP options for all connections

require './pptp-client-lib.pl';
&ui_print_header(undef, $text{'opts_title'}, "");

print &text('opts_desc', "<tt>$config{'pptp_options'}</tt>"),"<br>\n";
@opts = &parse_ppp_options($config{'pptp_options'});

print "<form action=save_opts.cgi method=post>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'opts_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

$mtu = &find("mtu", \@opts);
printf "<tr> <td><b>$text{'opts_mtu'}</b></td> <td>\n";
printf "<input type=radio name=mtu_def value=1 %s> %s\n",
	$mtu ? "" : "checked", $text{'default'};
printf "<input type=radio name=mtu_def value=0 %s>\n",
	$mtu ? "checked" : "";
print "<input name=mtu size=6 value='$mtu->{'value'}'> bytes</td>\n";

$mru = &find("mru", \@opts);
printf "<td><b>$text{'opts_mru'}</b></td> <td>\n";
printf "<input type=radio name=mru_def value=1 %s> %s\n",
	$mru ? "" : "checked", $text{'default'};
printf "<input type=radio name=mru_def value=0 %s>\n",
	$mru ? "checked" : "";
print "<input name=mru size=6 value='$mru->{'value'}'> bytes</td> </tr>\n";

print "<tr> <td colspan=4><hr></td> </tr>\n";
print "<tr> <td colspan=4 align=center>$text{'opts_msdesc'}</td> </tr>\n";

# Show MPPE options
&mppe_options_form(\@opts);

print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'save'}'></form>\n";

&ui_print_footer("", $text{'index_return'});

