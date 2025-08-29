
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, $remote_user, %sessiondb, $module_name);
do 'acl-lib.pl';

# list_system_info(&data, &in)
# Show recent logins
sub list_system_info
{
my ($data, $in) = @_;
my @rv;
my %miniserv;
&get_miniserv_config(\%miniserv);
&open_session_db(\%miniserv);
my @logins;
foreach my $k (keys %sessiondb) {
	next if ($k =~ /^1111111/);
	next if (!$sessiondb{$k});
	my ($user, $ltime, $lip) = split(/\s+/, $sessiondb{$k});
	next if (&webmin_user_is_admin()
		? ($user eq "!" ||
		   ($user ne $remote_user &&
		    # Show all logins for past 3 days for admin
		    $ltime && $ltime < time() - 3*24*60*60))
		: ($user ne $remote_user && $user ne "!".$remote_user));
	push(@logins, [ $user, $ltime, $lip, $k ]);
	}
if (@logins) {
	@logins = sort { $b->[1] <=> $a->[1] } @logins;
	if (@logins > 5) {
		@logins = @logins[0..4];
		}
	my $html = &ui_columns_start([ $text{'sessions_host'},
				       $text{'sessions_user'},
				       $text{'sessions_login_ago'},
				       $text{'sessions_state'},
				       $text{'sessions_action'} ]);
	my $open = 0;
	foreach my $l (@logins) {
		my $state;
		my $candel = 0;
		if ($l->[0] =~ /^\!/) {
			$state = $text{'sessions_out'};
			}
		elsif ($l->[3] eq $main::session_id ||
		       $l->[3] eq &hash_session_id($main::session_id)) {
			$state = "<font color=green>$text{'sessions_this'}</a>";
			}
		else {
			$state = $text{'sessions_in'};
			$candel = 1;
			if ($l->[2] ne $ENV{'REMOTE_HOST'}) {
				$open++;
				$state = "<font color=orange>$state</font>";
				}
			}
		my @links;
		if (&foreign_available("webminlog")) {
		      push(@links,
		         &ui_link("@{[&get_webprefix()]}/webminlog/search.cgi?uall=1&mall=1&tall=1&wall=1&fall=1&sid=$l->[3]",
		         $text{'sessions_lview'}))
			}
		if ($candel) {
		      push(@links,
		         &ui_link("@{[&get_webprefix()]}/acl/delete_session.cgi?id=$l->[3]&redirect_ref=1",
		         $text{'sessions_kill'}))
			}
		my $user = $l->[0];
		$user =~ s/^\!//;
		$html .= &ui_columns_row([
		          $l->[2],
		          $user,
		          &make_date_relative($l->[1]).
			  	"&nbsp;".&ui_help(&make_date($l->[1])),
		          $state,
			  &ui_links_row(\@links) ]);
		}
	$html .= &ui_columns_end();
	if (&foreign_available("acl")) {
		$html .= &ui_link("@{[&get_webprefix()]}/acl/list_sessions.cgi",
				  $text{'sessions_all'}, undef,
				  "title=\"$text{'sessions_title'}\"");
		}
	push(@rv, { 'type' => 'html',
		    'desc' => $text{'logins_title'},
		    'open' => $open,
		    'id' => $module_name.'_logins',
		    'priority' => -100,
		    'html' => $html });
	}
return @rv;
}
