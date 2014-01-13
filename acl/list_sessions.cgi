#!/usr/local/bin/perl
# list_sessions.cgi
# Display current login sessions

use strict;
use warnings;
require './acl-lib.pl';
our (%in, %text, %config, %access, %sessiondb);
$access{'sessions'} || &error($text{'sessions_ecannot'});
&ui_print_header(undef, $text{'sessions_title'}, "");

my %miniserv;
&get_miniserv_config(\%miniserv);
&open_session_db(\%miniserv);
my $time_now = time();

my %hasuser;
foreach my $u (&list_users()) {
	$hasuser{$u->{'name'}}++;
	}

my $haslog = &foreign_available("webminlog");

print "<b>$text{'sessions_desc'}</b><p>\n";
print &ui_columns_start([ $text{'sessions_id'},
			  $text{'sessions_user'},
			  $text{'sessions_host'},
			  $haslog ? ( $text{'sessions_login'} ) : ( ),
			  "" ], 100);
foreach my $k (sort { my @a = split(/\s+/, $sessiondb{$a});
		      my @b = split(/\s+/, $sessiondb{$b}); $b[1] <=> $a[1] }
		    keys %sessiondb) {
	next if ($k =~ /^1111111/);
	my ($user, $ltime, $lip) = split(/\s+/, $sessiondb{$k});
	next if ($miniserv{'logouttime'} &&
		 $time_now - $ltime > $miniserv{'logouttime'}*60);
	my @cols;
	if ($k eq $main::session_id ||
	    $k eq &hash_session_id($main::session_id)) {
		# Cannot self-terminate
		push(@cols, "<b>$k</b>");
		}
	else {
		push(@cols, ui_link("delete_session.cgi?id=$k", $k));
		}
	if ($hasuser{$user}) {
		push(@cols, ui_link("edit_user.cgi?user=$user", $user));
		}
	elsif ($miniserv{'unixauth'}) {
		push(@cols, "$user (" . ui_link("edit_user.cgi?user=$miniserv{'unixauth'}", $miniserv{'unixauth'}) . ")");
		}
	else {
		push(@cols, $user);
		}
	push(@cols, $lip);
	push(@cols, &make_date($ltime));
	if ($haslog) {
		push(@cols, ui_link("../webminlog/search.cgi?uall=1&mall=1&tall=1&wall=1&fall=1&sid=$k", $text{'sessions_lview'}));
		}
	print &ui_columns_row(\@cols);
	}
print &ui_columns_end();

&ui_print_footer("", $text{'index_return'});

