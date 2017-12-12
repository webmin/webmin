#!/usr/local/bin/perl
# Delete all auto-whitelist entries for all users

require './spam-lib.pl';
&error_setup($text{'dawl_err'});
&ReadParse();
&set_config_file_in(\%in);
&can_use_check("awl");
&ReadParse();

&ui_print_unbuffered_header(undef, $text{'dawl_title'}, "");

# Do all users
print $text{'dawl_doing'},"<br>\n";
$count = $ucount = 0;
setpwent();
while($u = getpwent()) {
	push(@users, $u);
	}
endpwent();
foreach $u (@users) {
	next if (!&can_edit_awl($u));
	print "doing $u<br>\n";
	&eval_as_unix_user($u->[0],
		sub
		{
		&open_auto_whitelist_dbm($u) || next;
		foreach $k (keys %awl) {
			delete($awl{$k});
			$count++;
			}
		&close_auto_whitelist_dbm();
		});
	$ucount++;
	}
endpwent();
print &text('dawl_done', $ucount, $count),"<p>\n";

&ui_print_footer($redirect_url, $text{'index_return'});

