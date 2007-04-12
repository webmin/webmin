#!/usr/local/bin/perl
# conf_acls.cgi
# Display global ACLs

require './bind8-lib.pl';
$access{'defaults'} || &error($text{'acls_ecannot'});
&ui_print_header(undef, $text{'acls_title'}, "");

$conf = &get_config();
@acls = ( &find("acl", $conf), { } );

print "<form action=save_acls.cgi>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'acls_name'}</b></td> ",
      "<td><b>$text{'acls_values'}</b></td> </tr>\n";
for($i=0; $i<@acls; $i++) {
	print "<tr $cb>\n";
	printf "<td valign=top><input name=name_$i size=15 value='%s'></td>\n",
		$acls[$i]->{'value'};
	@vals = map { $_->{'name'} } @{$acls[$i]->{'members'}};
	print "<td><textarea rows=2 cols=60 name=values_$i wrap=auto>",
		join(" ", @vals),"</textarea></td> </tr>\n";
	}
print "</table>\n";
print "<input type=submit value=\"$text{'save'}\"></form>\n";

&ui_print_footer("", $text{'index_return'});

