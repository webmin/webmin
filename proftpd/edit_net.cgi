#!/usr/local/bin/perl
# edit_net.cgi
# Display networking options

require './proftpd-lib.pl';
&ui_print_header(undef, $text{'net_title'}, "",
	undef, undef, undef, undef, &restart_button());
$conf = &get_config();

print "<form action=save_net.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'net_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr>\n";
print &choice_input($text{'net_type'}, 'ServerType', $conf, 'inetd',
		    $text{'net_inetd'}, 'inetd',
		    $text{'net_stand'}, 'standalone');
print &text_input($text{'net_port'}, 'Port', $conf, '21', 6);
print "</tr>\n";

print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'save'}'></form>\n";

&ui_print_footer("", $text{'index_return'});

