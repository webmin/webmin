# cluster-passwd-lib.pl

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
%access = &get_module_acl();
&foreign_require("cluster-useradmin", "cluster-useradmin-lib.pl");
&foreign_require("passwd", "passwd-lib.pl");
&foreign_require("useradmin", "user-lib.pl");

# get_all_users([&hosts])
sub get_all_users
{
local @hosts = $_[0] ? @{$_[0]} : &cluster_useradmin::list_useradmin_hosts();
local ($h, %done, @ulist);
foreach $h (sort { $a->{'id'} <=> $b->{'id'} } @hosts) {
	foreach $u (@{$h->{'users'}}) {
		$u->{'host'} = $h;
		push(@ulist, $u) if (!$done{$u->{'user'}}++);
		}
	}
return @ulist;
}

# can_edit_passwd(&user)
sub can_edit_passwd
{
if ($access{'mode'} == 0) {
	return 1;
	}
elsif ($access{'mode'} == 3) {
	return $_[0]->{'user'} eq $remote_user;
	}
elsif ($access{'mode'} == 4) {
	return (!$access{'low'} || $_[0]->{'uid'} >= $access{'low'}) &&
	       (!$access{'high'} || $_[0]->{'uid'} <= $access{'high'});
	}
elsif ($access{'mode'} == 5) {
	local ($g) = grep { $_->{'gid'} == $_[0]->{'gid'} }
			  @{$_[0]->{'host'}->{'groups'}};
	return 1 if (&indexof($g->{'group'},
			      split(/\s+/, $access{'users'})) >= 0);
	if ($access{'sec'}) {
		local $gname;
		foreach $gname (split(/\s+/, $access{'users'})) {
			local ($g) = grep { $_->{'group'} eq $gname }
					  @{$_[0]->{'host'}->{'groups'}};
			return 1 if (&indexof($_[0]->{'user'},
				      split(/,/, $g->{'members'})) >= 0);
			}
		}
	return 0;
	}
elsif ($access{'mode'} == 6) {
	return $_[0]->{'user'} =~ /$access{'users'}/;
	}
else {
	local $idx = &indexof($_[0]->{'user'}, split(/\s+/, $access{'users'}));
	return $access{'mode'} == 1 && $idx >= 0 ||
	       $access{'mode'} == 2 && $idx < 0;
	}
}

sub passwd_error
{
$passwd_error_msg = join("", @_);
}

# modify_on_hosts(&hosts, username, newpass, others, &printfunc)
# Updates the user on all hosts that he exists
sub modify_on_hosts
{
&remote_error_setup(\&passwd_error);
local $pfunc = $_[4];
local @servers = &cluster_useradmin::list_servers();
local $host;
foreach $host (@{$_[0]}) {
	# Connect to the host and get the user
	$passwd_error_msg = undef;
	local $user = grep { $_->{'user'} eq $_[1] } @{$host->{'users'}};
	next if (!$user);
	local ($serv) = grep { $_->{'id'} == $host->{'id'} } @servers;
	&$pfunc(-1, &text('passwd_on', $serv->{'desc'} || $serv->{'host'}));
	&remote_foreign_require($serv->{'host'}, "useradmin", "user-lib.pl");
	if ($passwd_error_msg) {
		# Host is down ..
		&$pfunc(1, &cluster_useradmin::text(
				'usave_failed', $passwd_error_msg));
		next;
		}
	local @ulist = &remote_foreign_call($serv->{'host'}, "useradmin",
					    "list_users");
	($user) = grep { $_->{'user'} eq $_[1] } @ulist;
	if (!$user) {
		# No longer exists?
		&$pfunc(2, $cluster_useradmin::text{'usave_gone'});
		next;
		}

	# Update password fields in user
	$user->{'olduser'} = $user->{'user'};
	$user->{'pass'} = &remote_foreign_call($serv->{'host'}, "useradmin",
					       "encrypt_password", $_[2]);
	$user->{'passmode'} = 3;
	$user->{'plainpass'} = $_[2];
	local $pft = &useradmin::passfiles_type();
	if ($pft == 2 || $pft == 5) {
		$user->{'change'} = int(time() / (60*60*24));
		}
	elsif ($pft == 4) {
		$user->{'change'} = time();
		}

	# Run the pre-change command
	&remote_eval($serv->{'host'}, "useradmin", "set_user_envs", $user);
	&remote_foreign_call($serv->{'host'}, "useradmin",
			     "making_changes");

	# Update the user on the server
	&$pfunc(-2, $cluster_useradmin::text{'usave_update'});
	&remote_foreign_call($serv->{'host'}, "useradmin", "modify_user",
			     $user, $user);
	&$pfunc(-3, $cluster_useradmin::text{'udel_done'});

	# Run post-change command
	&remote_foreign_call($serv->{'host'}, "useradmin", "made_changes");

	if ($_[3]) {
		# Update the user in other modules
		&$pfunc(-2, $cluster_useradmin::text{'usave_mothers'});
		$user->{'passmode'} = 3;
		$user->{'plainpass'} = $_[2];
		&remote_foreign_call($serv->{'host'}, "useradmin",
				     "other_modules", "useradmin_modify_user",
				     $user, $user);
		&$pfunc(-3, $cluster_useradmin::text{'udel_done'});
		}

	# Update in local list
	$host->{'users'} = \@ulist;
	&cluster_useradmin::save_useradmin_host($host);
	&$pfunc(-4);
	}
}

1;

