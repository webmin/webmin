#!/usr/local/bin/perl
# sync.cgi
# Create missing users and groups on servers

require './cluster-usermin-lib.pl';
&ReadParse();
@hosts = &list_webmin_hosts();
@servers = &list_servers();
&ui_print_header(undef, $text{'sync_title'}, "");

# Work out which hosts
@phosts = &create_on_parse(undef, undef, undef, 1);

# Build lists of all users and group
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

# Setup error handler for down hosts
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

		# Create missing users
		foreach $u (@uneed) {
			# Create the user
			print &text('sync_ucreate', $u->{'name'}),"<br>\n";
			if (!$in{'test'}) {
				&remote_foreign_call($serv->{'host'},
					"acl", "create_user", $u);
				push(@{$host->{'users'}}, $u);
				}
			print "$text{'refresh_done'}<p>\n";

			print &text('sync_acl', $u->{'name'}),"<br>\n";
			&copy_acls_for($u, $serv);
			print "$text{'refresh_done'}<p>\n";
			}

		# Create missing groups
		foreach $g (@gneed) {
			print &text('sync_gcreate', $g->{'group'}),"<br>\n";
			if (!$in{'test'}) {
				&remote_foreign_call($serv->{'host'},
					"acl", "create_group", $g);
				push(@{$host->{'groups'}}, $g);
				}
			print "$text{'refresh_done'}<p>\n";

			print &text('sync_acl', $g->{'name'}),"<br>\n";
			&copy_acls_for($g, $serv);
			print "$text{'refresh_done'}<p>\n";
			}

		# Restart webmin
		print "$text{'sync_restart'}<br>\n";
		if (!$in{'test'}) {
			&remote_foreign_call($serv->{'host'}, "acl",
					     "restart_miniserv");
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
&webmin_log("sync", undef, undef, \%in);

&ui_print_footer("", $text{'index_return'});

# copy_acls_for(&user|&group, &server)
# Copy all .acl files from the server on which a user or group does exist
# to the given server
sub copy_acls_for
{
local $source = $_[0]->{'source'};
&remote_foreign_require($source->{'host'}, "acl", "acl-lib.pl")
	if (!$done_require{$source->{'host'}}++);
foreach $m (@{$_[0]->{'modules'}}) {
	local %acl = &remote_foreign_call($source->{'host'}, "acl",
					  "get_module_acl", $_[0]->{'name'},$m);
	if (%acl) {
		&remote_foreign_call($_[1]->{'host'}, "acl", "save_module_acl",
				     \%acl, $_[0]->{'name'}, $m);
		}
	}
}

