#!/usr/local/bin/perl
# edit_ftpusers.cgi
# Lists users to be denied access

require './proftpd-lib.pl';
&ui_print_header(undef, $text{'ftpusers_title'}, "",
	undef, undef, undef, undef, &restart_button());

print &text('ftpusers_desc', "<tt>$config{'ftpusers'}</tt>"),"<p>\n";
print "<form action=save_ftpusers.cgi method=post>\n";
print "<textarea wrap=on rows=5 cols=80 name=users>";
open(USERS, $config{'ftpusers'});
while(<USERS>) {
	s/\s+/ /g;
	print;
	}
close(USERS);
print "</textarea><br>\n";
print "<input type=submit value='$text{'save'}'></form>\n";

&ui_print_footer("", $text{'index_return'});

