#!/usr/local/bin/perl
# list_sessions.cgi
# Display current login sessions

require './acl-lib.pl';
$access{'sessions'} || &error($text{'sessions_ecannot'});
&ui_print_header(undef, $text{'sessions_title'}, "");

&get_miniserv_config(\%miniserv);
&open_session_db(\%miniserv);
$time_now = time();

foreach $u (&list_users()) {
	$hasuser{$u->{'name'}}++;
	}

$haslog = &foreign_available("webminlog");

print "<b>$text{'sessions_desc'}</b><p>\n";
print &ui_columns_start([ $text{'sessions_id'},
			  $text{'sessions_user'},
			  $text{'sessions_host'},
			  $haslog ? ( $text{'sessions_login'} ) : ( ),
			  "" ], 100);
foreach $k (sort { @a=split(/\s+/, $sessiondb{$a}); @b=split(/\s+/, $sessiondb{$b}); $b[1] <=> $a[1] } keys %sessiondb) {
	next if ($k =~ /^1111111/);
	local ($user, $ltime, $lip) = split(/\s+/, $sessiondb{$k});
	next if ($miniserv{'logouttime'} &&
		 $time_now - $ltime > $miniserv{'logouttime'}*60);
	local @cols;
	push(@cols, "<a href='delete_session.cgi?id=$k'>$k</a>");
	if ($hasuser{$user}) {
		push(@cols, "<a href='edit_user.cgi?user=$user'>$user</a>");
		}
	elsif ($miniserv{'unixauth'}) {
		push(@cols, "$user (<a href='edit_user.cgi?user=$miniserv{'unixauth'}'>$miniserv{'unixauth'}</a>)");
		}
	else {
		push(@cols, $user);
		}
	push(@cols, $lip);
	push(@cols, &make_date($ltime));
	if ($haslog) {
		push(@cols, "<a href='../webminlog/search.cgi?uall=1&mall=1&tall=1&wall=1&fall=1&sid=$k'>$text{'sessions_lview'}</a>");
		}
	print &ui_columns_row(\@cols);
	}
print &ui_columns_end();

&ui_print_footer("", $text{'index_return'});

