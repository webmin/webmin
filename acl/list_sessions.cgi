#!/usr/local/bin/perl
# list_sessions.cgi
# Display current login sessions

use strict;
use warnings;
require './acl-lib.pl';
our (%in, %text, %config, %access, %sessiondb);
$access{'sessions'} || &error($text{'sessions_ecannot'});
&ui_print_header(undef, $text{'sessions_title'}, "");
&ReadParse();

my %miniserv;
&get_miniserv_config(\%miniserv);
&open_session_db(\%miniserv);
my $time_now = time();

my %hasuser;
foreach my $u (&list_users()) {
	$hasuser{$u->{'name'}}++;
	}

my $haslog = &foreign_available("webminlog");

print &ui_columns_start([ $text{'sessions_id'},
			  $text{'sessions_state'},
			  $text{'sessions_user'},
			  $text{'sessions_host'},
			  $text{'sessions_login'},
			  $text{'sessions_actions'},
			], 100);
foreach my $k (sort { my @a = split(/\s+/, $sessiondb{$a});
		      my @b = split(/\s+/, $sessiondb{$b}); $b[1] <=> $a[1] }
		    (grep { $sessiondb{$_} } keys %sessiondb)) {
	next if ($k =~ /^1111111/);
	my ($user, $ltime, $lip) = split(/\s+/, $sessiondb{$k});
	next if ($user =~ /^\!/ && !$in{'logouts'});
	next if ($miniserv{'logouttime'} &&
		 $time_now - $ltime > $miniserv{'logouttime'}*60);
	my @cols;
	my $candel = 0;
	if ($k eq $main::session_id ||
	    $k eq &hash_session_id($main::session_id)) {
		# Cannot self-terminate
		push(@cols, "<b><tt>$k</tt></b>");
		push(@cols, $text{'sessions_this'});
		}
	elsif ($user =~ s/^\!//) {
		# Already logged out
		push(@cols, "<tt>$k</tt>");
		push(@cols, $text{'sessions_out'});
		}
	else {
		push(@cols, "<tt>$k</tt>");
		push(@cols, $text{'sessions_in'});
		$candel = 1;
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
	my @links;
	if ($haslog) {
		push(@links, ui_link("../webminlog/search.cgi?uall=1&mall=1&tall=1&wall=1&fall=1&sid=$k", $text{'sessions_lview'}));
		}
	if ($candel) {
		push(@links, ui_link("delete_session.cgi?id=$k", $text{'sessions_kill'}));
		}
	push(@cols, ui_links_row(\@links));
	print &ui_columns_row(\@cols);
	}
print &ui_columns_end();
if (!$in{'logouts'}) {
	print &ui_link("list_sessions.cgi?logouts=1",
		       $text{'sessions_logouts'}),"<p>\n";
	}

&ui_print_footer("", $text{'index_return'});

