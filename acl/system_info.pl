
use strict;
use warnings;
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
	next if ($user ne $remote_user && $user ne "!".$remote_user);
	push(@logins, [ $user, $ltime, $lip, $k ]);
	}
if (@logins) {
	@logins = sort { $b->[1] <=> $a->[1] } @logins;
	if (@logins > 5) {
		@logins = @logins[0..4];
		}
	my $html = &ui_columns_start([ $text{'sessions_host'},
				       $text{'sessions_login'},
				       $text{'sessions_state'} ]);
	my $open = 0;
	foreach my $l (@logins) {
		my $state;
		if ($l->[0] =~ /^\!/) {
			$state = $text{'sessions_out'};
			}
		elsif ($l->[3] eq $main::session_id ||
		       $l->[3] eq &hash_session_id($main::session_id)) {
			$state = "<font color=green>$text{'sessions_this'}</a>";
			}
		else {
			$state = $text{'sessions_in'};
			if ($l->[2] ne $ENV{'REMOTE_HOST'}) {
				$open++;
				$state = "<font color=orange>$state</font>";
				}
			}
		$html .= &ui_columns_row([ $l->[2],
					   &make_date($l->[1]),
					   $state ]);
		}
	$html .= &ui_columns_end();
	push(@rv, { 'type' => 'html',
		    'desc' => $text{'logins_title'},
		    'open' => $open,
		    'id' => $module_name.'_logins',
		    'priority' => -100,
		    'html' => $html });
	}
return @rv;
}
