#!/usr/local/bin/perl
# create_copy.cgi
# Display a form for creating a new copy

require './samba-lib.pl';

# check acls
%access = &get_module_acl();
&error_setup("<blink><font color=red>$text{'eacl_aviol'}</font></blink>");
&error("$text{'eacl_np'} $text{'eacl_pcopy'}") unless $access{'copy'};
 
&ui_print_header(undef, $text{'create_title'}, "");

print $text{'create_msg'};
print "<p>\n";
print "<form action=save_copy.cgi>\n";
print "<table>\n";
print "<tr> <td><b>$text{'create_from'}</b></td>\n";
print "<td><select name=copy>\n";
foreach $c (&list_shares()) {
	if ($c eq "global") { next; }
	print "<option>$c\n";
	}
print "</select></td> </tr>\n";
print "<tr> <td><b>$text{'create_name'}</b></td>\n";
print "<td><input size=15 name=name></td> </tr>\n";
print "</table>\n";
print "<input type=submit value=$text{'create'}></form><p>\n";

&ui_print_footer("", $text{'index_sharelist'});

