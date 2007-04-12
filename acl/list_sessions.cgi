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
print "<table border>\n";
print "<tr $tb> <td><b>$text{'sessions_id'}</b></td> ",
      "<td><b>$text{'sessions_user'}</b></td> ",
      "<td><b>$text{'sessions_host'}</b></td> ",
      $haslog ? "<td><b>$text{'sessions_login'}</b></td> " : "",
      "<td><br></td> </tr>\n";
foreach $k (sort { @a=split(/\s+/, $sessiondb{$a}); @b=split(/\s+/, $sessiondb{$b}); $b[1] <=> $a[1] } keys %sessiondb) {
	next if ($k =~ /^1111111/);
	local ($user, $ltime, $lip) = split(/\s+/, $sessiondb{$k});
	next if ($miniserv{'logouttime'} &&
		 $time_now - $ltime > $miniserv{'logouttime'}*60);
	print "<tr $cb>\n";
	print "<td><a href='delete_session.cgi?id=$k'>$k</a></td>\n";
	if ($hasuser{$user}) {
		print "<td><a href='edit_user.cgi?user=$user'>$user</a></td>\n";
		}
	elsif ($miniserv{'unixauth'}) {
		print "<td>$user (<a href='edit_user.cgi?user=$miniserv{'unixauth'}'>$miniserv{'unixauth'}</a>)</td>\n";
		}
	else {
		print "<td>$user</td>\n";
		}
	print "<td>",($lip || "<br>"),"</td>\n";
	local $tm = localtime($ltime);
	print "<td><tt>$tm</tt></td>\n";
	if ($haslog) {
		print "<td><a href='../webminlog/search.cgi?",
		      "uall=1&mall=1&tall=1&wall=1&fall=1&sid=$k'>$text{'sessions_lview'}</a></td>\n";
		}
	print "</tr>\n";
	}
print "</table><br>\n";

&ui_print_footer("", $text{'index_return'});

