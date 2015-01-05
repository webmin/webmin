#!/usr/local/bin/perl
# list_sessions.cgi
# Display current login sessions

require './usermin-lib.pl';
$access{'sessions'} || &error($text{'sessions_ecannot'});
&ui_print_header(undef, $text{'sessions_title'}, "");

&get_usermin_miniserv_config(\%miniserv);
&acl::open_session_db(\%miniserv);
$time_now = time();

print "<b>$text{'sessions_desc'}</b><p>\n";
@keys = keys %acl::sessiondb;
if (@keys) {
	print &ui_columns_start([ $text{'sessions_id'},
				  $text{'sessions_user'},
				  $text{'sessions_host'},
				  $text{'sessions_login'} ]);
	foreach $k (sort { @a=split(/\s+/, $acl::sessiondb{$a}); @b=split(/\s+/, $acl::sessiondb{$b}); $b[1] <=> $a[1] } @keys) {
		next if ($k =~ /^1111111/);
		local ($user, $ltime, $lip) = split(/\s+/, $acl::sessiondb{$k});
		next if ($miniserv{'logouttime'} &&
			 $time_now - $ltime > $miniserv{'logouttime'}*60);
		@cols = ( &ui_link("delete_session.cgi?id=$k",$k) );
		push(@cols, &ui_link("../useradmin/edit_user.cgi?user=".
				     &urlize($user), $user));
		push(@cols, $lip);
		push(@cols, &make_date($ltime));
		print &ui_columns_row(\@cols);
		}
	print &ui_columns_end();
	}
else {
	print "<b>$text{'sessions_none'}</b><p>\n";
	}

# Show quick switch form
print &ui_hr();
print &ui_form_start("switch.cgi", "get", "_blank");
print $text{'sessions_switch'},"\n";
print &ui_user_textbox("user");
print &ui_submit($text{'sessions_ok'});
print &ui_form_end();

&ui_print_footer("", $text{'index_return'});

