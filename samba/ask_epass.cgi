#!/usr/local/bin/perl
# ask_epass.cgi
# Display a form asking for password conversion options

require './samba-lib.pl';
# check acls

&error_setup($text{'eacl_aviol'});
&error("$text{'eacl_np'} $text{'eacl_pmpass'}")
        unless $access{'maint_makepass'};
# display
&ui_print_header(undef, $text{'convert_title'}, "");

&check_user_enabled($text{'convert_cannot'});

print &text('convert_msg', 'conf_pass.cgi'),"\n";
print "$text{'convert_ncdesc'}<p>\n";

print "<form action=make_epass.cgi>\n";

print "<input type=checkbox name=skip value=1 checked> ",
      $text{'convert_noconv'};
print "<input name=skip_list size=40 value=\"$config{dont_convert}\"> ",
	&user_chooser_button("skip_list", 1),"<p>\n";

print "<input type=checkbox name=update value=1 checked> ",
      $text{'convert_update'}," <p>\n";

print "<input type=checkbox name=add value=1 checked> ",
      $text{'convert_add'},"<p>\n";

print "<input type=checkbox name=delete value=1> ",
      $text{'convert_delete'}, "<p>\n";

print "<table> <tr>\n";
print "<td valign=top>$text{'convert_newuser'}</td>\n";
print "<td><input type=radio name=newmode value=0 checked>$text{'convert_nopasswd'}<br>\n";
print "<input type=radio name=newmode value=1>$text{'convert_lock'}<br>\n";
print "<input type=radio name=newmode value=2>$text{'convert_passwd'}\n",
      "<input type=password name=newpass size=20></td>\n";
print "</tr> </table>\n";

print "<input type=submit value=\"$text{'convert_convert'}\"> </form>\n";

&ui_print_footer("", $text{'index_sharelist'});

