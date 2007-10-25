#!/usr/local/bin/perl
# password_form.cgi
# Display the form that allows users to change their passwords at login time

$ENV{'MINISERV_INTERNAL'} || die "Can only be called by miniserv.pl";
require './web-lib.pl';
&init_config();
&ReadParse();
&header(undef, undef, undef, undef, 1, 1);

print "<center>\n";
print "<h3>$text{'password_expired'}</h3><p>\n";

print "$text{'password_prefix'}\n";
print "<form action=$gconfig{'webprefix'}/password_change.cgi method=post>\n";
print "<input type=hidden name=user value='",&html_escape($in{'user'}),"'>\n";
print "<input type=hidden name=pam value='",&html_escape($in{'pam'}),"'>\n";

print "<table border width=40%>\n";
print "<tr $tb> <td><b>$text{'password_header'}</b></td> </tr>\n";
print "<tr $cb> <td align=center><table cellpadding=3>\n";

print "<tr> <td><b>$text{'password_user'}</b></td>\n";
print "<td><tt>",&html_escape($in{'user'}),"</tt></td> </tr>\n";

print "<tr> <td><b>$text{'password_old'}</b></td>\n";
print "<td><input name=old size=20 type=password></td> </tr>\n";

print "<tr> <td><b>$text{'password_new1'}</b></td>\n";
print "<td><input name=new1 size=20 type=password></td> </tr>\n";
print "<tr> <td><b>$text{'password_new2'}</b></td>\n";
print "<td><input name=new2 size=20 type=password></td> </tr>\n";

print "<tr> <td colspan=2 align=center><input type=submit ",
      "value='$text{'password_ok'}'>\n";
print "<input type=reset value='$text{'password_clear'}'><br>\n";
print "</td> </tr>\n";
print "</table></td></tr></table><p>\n";
print "<hr>\n";
print "</form></center>\n";
print "$text{'password_postfix'}\n";
&footer();

