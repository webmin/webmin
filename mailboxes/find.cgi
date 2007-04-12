#!/usr/local/bin/perl
# find.cgi
# Display users matching some criteria

require './mailboxes-lib.pl';
&ReadParse();

# Build a list of all matching users
foreach $uinfo (&list_mail_users()) {
	if (&can_user(@$uinfo)) {
		if ($in{'match'} == 0 && lc($in{'user'}) eq $uinfo->[0] ||
		    $in{'match'} == 1 && $uinfo->[0] =~ /\Q$in{'user'}\E/i) {
			push(@users, $uinfo);
			}
		}
	}

if (@users == 1) {
	# Can go direct to user
	&redirect("list_mail.cgi?user=$users[0]->[0]");
	}
elsif (@users == 0) {
	# No matches
	&error($text{'find_enone'});
	}
else {
	# Show table of matches
	&ui_print_header(undef, $text{'find_title'}, "");
	print &text('find_results', $in{'user'}),"<p>\n";
	&show_users_table(\@users);
	&ui_print_footer();
	}


