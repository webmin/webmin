#!/usr/local/bin/perl
# edit_defacl.cgi
# Display global ACL options for usermin

require './usermin-lib.pl';
$access{'defacl'} || &error($text{'acl_ecannot'});
&ui_print_header(undef, $text{'defacl_title'}, "");

print "$text{'defacl_desc'}<p>\n";
print "<form action=save_defacl.cgi method=post>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'defacl_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

&get_usermin_miniserv_config(\%miniserv);
do "$miniserv{'root'}/acl_security.pl";
&read_file("$miniserv{'root'}/defaultacl", \%acl);
&read_file("$config{'usermin_dir'}/user.acl", \%acl);
&acl_security_form(\%acl);

print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'save'}'></form>\n";

&ui_print_footer("", $text{'index_return'});

