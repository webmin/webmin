#!/usr/local/bin/perl
# conf_forwarding.cgi
# Display global forwarding and transfer options

require './bind8-lib.pl';
$access{'defaults'} || &error($text{'forwarding_ecannot'});
&ui_print_header(undef, $text{'forwarding_title'}, "");

$conf = &get_config();
$options = &find("options", $conf);
$mems = $options->{'members'};

print "<form action=save_forwarding.cgi>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'forwarding_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr>\n";
print &forwarders_input($text{'forwarding_fwders'}, 'forwarders', $mems);
print "</tr>\n";

print "<tr>\n";
print &choice_input($text{'forwarding_fwd'}, 'forward', $mems,
		    $text{'yes'}, 'first', $text{'no'}, 'only',
		    $text{'default'}, undef);
print "</tr>\n";

print "<tr>\n";
print &opt_input($text{'forwarding_max'}, "max-transfer-time-in",
		 $mems, $text{'default'}, 4, $text{'forwarding_minutes'});
print "</tr>\n";

print "<tr>\n";
print &choice_input($text{'forwarding_format'}, 'transfer-format', $mems,
		    $text{'forwarding_one'}, 'one-answer',
		    $text{'forwarding_many'}, 'many-answers',
		    $text{'default'}, undef);
print "</tr>\n";

print "<tr>\n";
print &opt_input($text{'forwarding_in'}, "transfers-in",
		 $mems, $text{'default'}, 4);
print "</tr>\n";

print "</table></td></tr></table>\n";
print "<input type=submit value=\"$text{'save'}\"></form>\n";

&ui_print_footer("", $text{'index_return'});

