#!/usr/local/bin/perl
# sync.cgi
# Create missing users and groups on servers

require './cluster-webmin-lib.pl';
&ReadParse();
@hosts = &list_webmin_hosts();
@servers = &list_servers();
&ui_print_header(undef, $text{'sync_title'}, "");

# Work out which hosts
@phosts = &create_on_parse(undef, undef, undef, 1);

# Build lists of all users and groups
foreach $h (@hosts) {
	local ($serv) = grep { $_->{'id'} == $h->{'id'} } @servers;
	foreach $u (@{$h->{'users'}}) {
		if (!$doneuser{$u->{'name'}}++) {
			push(@ulist, $u);
			$u->{'source'} = $serv;
			}
		}
	foreach $g (@{$h->{'groups'}}) {
		if (!$donegroup{$g->{'name'}}++) {
			push(@glist, $g);
			$g->{'source'} = $serv;
			}
		}
	}

# Find users and groups to sync
if ($in{'users_mode'} == 1) {
	@usync = @ulist;
	}
elsif ($in{'users_mode'} == 2) {
	map { $usel{$_}++ } split(/\s+/, $in{'usel'});
	@usync = grep { $usel{$_->{'name'}} } @ulist;
	}
elsif ($in{'users_mode'} == 3) {
	map { $unot{$_}++ } split(/\s+/, $in{'unot'});
	@usync = grep { !$unot{$_->{'name'}} } @ulist;
	}

if ($in{'groups_mode'} == 1) {
	@gsync = @glist;
	}
elsif ($in{'groups_mode'} == 2) {
	map { $gsel{$_}++ } split(/\s+/, $in{'gsel'});
	@gsync = grep { $gsel{$_->{'name'}} } @glist;
	}
elsif ($in{'groups_mode'} == 3) {
	map { $gnot{$_}++ } split(/\s+/, $in{'gnot'});
	@gsync = grep { !$gnot{$_->{'name'}} } @glist;
	}

# add_error(messages...): save a remote host error for display.
sub add_error
{
$add_error_msg = join("", @_);
}
&remote_error_setup(\&add_error);

# Sync on chosen hosts
foreach $host (@phosts) {
	$add_error_msg = undef;
	local ($serv) = grep { $_->{'id'} == $host->{'id'} } @servers;
	print "<b>",&text('sync_on', &server_name($serv)),"</b><p>\n";
	print "<ul>\n";

	# Find missing users and groups
	local (%usync, %gsync);
	map { $usync{$_->{'name'}}++ } @{$host->{'users'}};
	map { $gsync{$_->{'name'}}++ } @{$host->{'groups'}};
	local @uneed = grep { !$usync{$_->{'name'}} } @usync;
	local @gneed = grep { !$gsync{$_->{'name'}} } @gsync;
	if (@uneed || @gneed) {
		&remote_foreign_require($serv->{'host'},
					"acl", "acl-lib.pl");
		$done_require{$serv->{'host'}}++;
		if ($add_error_msg) {
			# Host is down!
			print "$add_error_msg<p>\n";
			print "</ul>\n";
			next;
			}

		# Copy missing users and groups, then cache completed copies.
		foreach my $type ('user', 'group') {
			foreach my $account ($type eq 'user' ? @uneed : @gneed) {
				print &text($type eq 'user' ? 'sync_ucreate' :
					'sync_gcreate', $account->{'name'}),"<br>\n";
				print &text('sync_acl', $account->{'name'}),"<br>\n";
				if (!$in{'test'}) {
					# Dry runs skip account and ACL writes.
					my ($copy, $err) =
						&sync_account($account, $serv, $type);
					if ($err) {
						# Do not cache failed copies.
						print &html_escape($err),"<p>\n";
						next;
						}
					push(@{$host->{$type.'s'}}, $copy);
					}
				print "$text{'refresh_done'}<p>\n";
				}
			}

		# Restart webmin
		print "$text{'sync_restart'}<br>\n";
		if (!$in{'test'}) {
			&remote_foreign_call($serv->{'host'}, "acl",
					     "reload_miniserv");
			}
		print "$text{'refresh_done'}<p>\n";

		# Update in local list
		&save_webmin_host($host);
		}
	else {
		print "$text{'sync_insync'}<p>\n";
		}
	print "</ul>\n";
	}

&ui_print_footer("", $text{'index_return'});

# sync_account(&account, &server, type)
# Copy a source account and its ACLs to server. type is 'user' or 'group'.
# Return (destination account, error), with an undefined error on success.
# New users cannot log in until all ACLs have been copied.
sub sync_account
{
my ($account, $server, $type) = @_;
# The destination assigns its own storage ID and backend.
my $copy = { %$account };
delete @{$copy}{'id', 'proto', 'source'};
my %pending = %$copy;
if ($type eq 'user') {
	# Block password, certificate and configured IP-based logins.
	$pending{'pass'} = '!'.$account->{'pass'};
	$pending{'cert'} = undef;
	$pending{'allow'} = undef;
	$pending{'deny'} = '0.0.0.0/0 ::/0';
	}
my $created;
# Turn remote errors into exceptions so failed copies stop before activation.
local $main::remote_error_handler = sub { die join('', @_)."\n"; };
my $ok = eval {
	# Record successful creation so a later ACL failure can trigger cleanup.
	&remote_foreign_call($server->{'host'}, 'acl', 'create_'.$type,
			     \%pending);
	$created = 1;
	&copy_acls_for($account, $server, $type);
	# Use the destination's ID and backend for activation and the local cache.
	my $dest = &remote_foreign_call($server->{'host'}, 'acl', 'get_'.$type,
					$account->{'name'});
	$dest || die "Cannot find newly synchronized account\n";
	# The remote ACL cache may still predate creation. Keep source settings.
	foreach my $key ('id', 'proto') {
		$copy->{$key} = $dest->{$key} if (exists($dest->{$key}));
		}
	if ($type eq 'user') {
		# Enable logins only after all permissions have been copied.
		&remote_foreign_call($server->{'host'}, 'acl', 'modify_user',
				     $account->{'name'}, $copy);
		}
	1;
	};
my $err = $@;
if (!$ok && $created) {
	# Remove failed copies so synchronization can retry them. A failed ACL
	# transfer leaves the user disabled even if cleanup also fails.
	eval { &remote_foreign_call($server->{'host'}, 'acl', 'delete_'.$type,
				    $account->{'name'}); };
	# Report cleanup errors without losing the original transfer error.
	$err .= $@ if ($@);
	}
return $ok ? ($copy, undef) : (undef, $err);
}

# copy_acls_for(&account, &server, type)
# Copy global and module ACLs from account->{source} to the destination server.
# type is user or group and selects the matching remote ACL helpers.
sub copy_acls_for
{
local $source = $_[0]->{'source'};
&remote_foreign_require($source->{'host'}, "acl", "acl-lib.pl")
	if (!$done_require{$source->{'host'}}++);
local $suffix = $_[2] eq "user" ? "module_acl" : "group_module_acl";
# Global permissions include the account's API-only restriction.
foreach $m (&unique('', @{$_[0]->{'modules'}})) {
	# Copy stored global permissions without adding source defaults or RBAC.
	# Module permissions retain their existing default handling.
	my @options = $m eq '' ? (1, 1) : ();
	local %acl = &remote_foreign_call($source->{'host'}, "acl",
					  "get_".$suffix, $_[0]->{'name'},
					  $m, @options);
	if (%acl) {
		# Only populated source ACLs need a write on the new destination
		# account.
		&remote_foreign_call($_[1]->{'host'}, "acl", "save_".$suffix,
				     \%acl, $_[0]->{'name'}, $m, 1);
		}
	}
}

