#!/usr/bin/perl
# list_users.cgi
# Show all Webmin users with access to this module only

require './itsecur-lib.pl';
&foreign_require("acl", "acl-lib.pl");
&can_use_error("users");
&header($text{'users_title'}, "",
	undef, undef, undef, undef, &apply_button());
print "<hr>\n";

# Work out which users have access to this module
@users = &acl::list_users();
foreach $u (@users) {
	@m = @{$u->{'modules'}};
	if ($u->{'name'} ne "root" &&
	    &indexof($module_name, @m) >= 0) {
		push(@musers, $u);
		}
	}

#print "$text{'users_desc'}<p>\n";
$edit = &can_edit("users");
if (@musers) {
	print "<a href='edit_user.cgi?new=1'>$text{'users_add'}</a><br>\n"
		if ($edit);
	print "<table border>\n";
	print "<tr $tb> ",
	      "<td><b>$text{'users_name'}</b></td> ",
	      "<td><b>$text{'users_ips'}</b></td> ",
	      "<td><b>$text{'users_enabled'}</b></td> ",
	      "</tr>\n";
	foreach $u (@musers) {
		print "<tr $cb>\n";
		print "<td><a href='edit_user.cgi?",
		      "name=$u->{'name'}'>$u->{'name'}</a></td>\n";
		print "<td>\n";
		if ($u->{'allow'}) {
			print &text('users_allow', $u->{'allow'});
			}
		elsif ($u->{'deny'}) {
			print &text('users_deny', $u->{'deny'});
			}
		else {
			print $text{'users_all'};
			}
		print "</td>\n";
		print "<td>",$u->{'pass'} =~ /^\*LK\*/ ? $text{'rule_no'} : $text{'rule_yes'},"</td>\n";
		%uaccess = &get_module_acl($u->{'name'});
		print "</tr>\n";
		}
	print "</table>\n";
	}
else {
	print "<b>$text{'users_none'}</b><p>\n";
	}
print "<a href='edit_user.cgi?new=1'>$text{'users_add'}</a><p>\n"
	if ($edit);

print "<hr>\n";
&footer("", $text{'index_return'});
