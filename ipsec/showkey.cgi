#!/usr/local/bin/perl
# showkey.cgi
# Show this host's public key in a format suitable for inclusion in the config
# file of another host

require './ipsec-lib.pl';
&ui_print_header(undef, $text{'showkey_title'}, "");

print "$text{'showkey_desc1'}<p>\n";
print "<tt>",join("<br>", &wrap_lines(&get_public_key(), 80)),"</tt><p>\n";

print "$text{'showkey_desc2'}<p>\n";
($flags, $proto, $alg, $key) = &get_public_key_dns();
print "<table>\n";
print "<tr> <td><b>$text{'showkey_flags'}</b></td> <td>$flags</td> </tr>\n";
print "<tr> <td><b>$text{'showkey_proto'}</b></td> <td>$proto</td> </tr>\n";
print "<tr> <td><b>$text{'showkey_alg'}</b></td> <td>$alg</td> </tr>\n";
print "<tr> <td valign=top><b>$text{'showkey_key'}</b></td> <td><tt>",
	join("<br>", &wrap_lines($key, 80)),"</tt></td> </tr>\n";
print "</table>\n";

&ui_print_footer("", $text{'index_return'});

