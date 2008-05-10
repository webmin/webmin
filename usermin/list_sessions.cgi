#!/usr/local/bin/perl
# list_sessions.cgi
# Display current login sessions

require './usermin-lib.pl';
$access{'sessions'} || &error($text{'sessions_ecannot'});
&ui_print_header(undef, $text{'sessions_title'}, "");

&get_usermin_miniserv_config(\%miniserv);
&acl::open_session_db(\%miniserv);
$time_now = time();

if (&foreign_available("useradmin")) {
	&foreign_require("useradmin", "user-lib.pl");
	@users = &useradmin::list_users();
	%umap = map { $_->{'user'}, $_ } @users;
	}

print "<b>$text{'sessions_desc'}</b><p>\n";
@keys = keys %acl::sessiondb;
if (@keys) {
	print "<table border>\n";
	print "<tr $tb> <td><b>$text{'sessions_id'}</b></td> ",
	      "<td><b>$text{'sessions_user'}</b></td> ",
	      "<td><b>$text{'sessions_host'}</b></td> ",
	      "<td><b>$text{'sessions_login'}</b></td> </tr>\n";
	foreach $k (sort { @a=split(/\s+/, $acl::sessiondb{$a}); @b=split(/\s+/, $acl::sessiondb{$b}); $b[1] <=> $a[1] } @keys) {
		next if ($k =~ /^1111111/);
		local ($user, $ltime, $lip) = split(/\s+/, $acl::sessiondb{$k});
		next if ($miniserv{'logouttime'} &&
			 $time_now - $ltime > $miniserv{'logouttime'}*60);
		print "<tr $cb>\n";
		print "<td><a href='delete_session.cgi?id=$k'>$k</a></td>\n";
		if ($uinfo = $umap{$user}) {
			print "<td><a href='../useradmin/edit_user.cgi?num=$uinfo->{'num'}'>$user</a></td>\n";
			}
		else {
			print "<td>$user</td>\n";
			}
		print "<td>",($lip || "<br>"),"</td>\n";
		local $tm = localtime($ltime);
		print "<td><tt>$tm</tt></td>\n";
		print "</tr>\n";
		}
	print "</table>\n";
	}
else {
	print "<b>$text{'sessions_none'}</b><p>\n";
	}

# Show quick switch form
print &ui_hr();
print &ui_form_start("switch.cgi", "get", "_new");
print $text{'sessions_switch'},"\n";
print &ui_user_textbox("user");
print &ui_submit($text{'sessions_ok'});
print &ui_form_end();

&ui_print_footer("", $text{'index_return'});

