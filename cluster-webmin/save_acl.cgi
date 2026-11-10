#!/usr/local/bin/perl
# save_acl.cgi
# Save the ACL for a module for a user or group

require './cluster-webmin-lib.pl';
&ReadParse();
$who = $in{'_acl_user'} ? $in{'_acl_user'} : $in{'_acl_group'};

# Validate and parse inputs
&error_setup($text{'acl_err'});
$maccess{'noconfig'} = $in{'noconfig'};
if (-r "../$in{'_acl_mod'}/acl_security.pl") {
	&foreign_require($in{'_acl_mod'}, "acl_security.pl");
	&foreign_call($in{'_acl_mod'}, "acl_security_save", \%maccess, \%in);
	}

# Setup error handler for down hosts
sub user_error
{
$user_error_msg = join("", @_);
}
&remote_error_setup(\&user_error);

# Write out on all hosts, or just one host
&ui_print_header(undef, $text{'acl_title'}, "");
@allhosts = &list_webmin_hosts();
@servers = &list_servers();
if ($in{'all'}) {
	# Doing on all hosts that the user has the module on
	foreach $h (@allhosts) {
		local $w;
		if ($in{'_acl_user'}) {
			($w) = grep { $_->{'name'} eq $in{'_acl_user'} }
				    @{$h->{'users'}};
			}
		else {
			($w) = grep { $_->{'name'} eq $in{'_acl_group'} }
				    @{$h->{'groups'}};
			}
		next if (!$w);
		local %ingroup;
		foreach $g (@{$h->{'groups'}}) {
			map { $ingroup{$_}++ } @{$g->{'members'}};
			}
		local @m = $ingroup{$w->{'name'}} ? @{$w->{'ownmods'}}
						  : @{$w->{'modules'}};
		push(@hosts, $h) if (&indexof($in{'_acl_mod'}, @m) >= 0 ||
				     !$in{'_acl_mod'});
		}
	print "<b>",&text('acl_doing', $who),"</b><p>\n";
	}
else {
	# Doing on just one host
	@hosts = grep { $_->{'id'} == $in{'_acl_host'} } @allhosts;
	local ($s) = grep { $_->{'id'} == $hosts[0]->{'id'} } @servers;
	print "<b>",&text('acl_doing2', $who, &server_name($s)),"</b><p>\n";
	}
$p = 0;
foreach $h (@hosts) {
	local ($s) = grep { $_->{'id'} == $h->{'id'} } @servers;
	local ($rh = "READ$p", $wh = "WRITE$p");
	pipe($rh, $wh);
	if (!fork()) {
		close($rh);
		# Stop this host's save if a remote read or write fails.
		local $main::remote_error_handler = sub { die join('', @_); };
		my $locked;
		my $ok = eval {
			&remote_foreign_require($s->{'host'}, "acl", "acl-lib.pl");
			my $cd = &remote_eval($s->{'host'}, "acl",
					     '$config_directory');
			my $sfx = $in{'_acl_user'} ? "acl" : "gacl";
			my $file = "$cd/$in{'_acl_mod'}/$who.$sfx";
			my $suffix = $in{'_acl_user'} ? "module_acl" :
							"group_module_acl";
			&remote_foreign_call($s->{'host'}, "acl", "lock_file", $file);
			$locked = $file;
			if ($in{'_acl_mod'} eq '') {
				# This child keeps its host's existing API endpoint.
				my %saved = &remote_foreign_call($s->{'host'},
					"acl", "get_".$suffix, $who, "", 1, 1);
				delete($maccess{'api_only'});
				$maccess{'api_only'} = $saved{'api_only'}
					if (exists($saved{'api_only'}));
				}
			# Use the account's storage backend without updating its parent.
			&remote_foreign_call($s->{'host'}, "acl", "save_".$suffix,
				\%maccess, $who, $in{'_acl_mod'}, 1);
			&remote_foreign_call($s->{'host'}, "acl", "unlock_file", $locked);
			$locked = undef;

			if ($in{'_acl_group'}) {
				# Apply the saved group permissions to its members.
				my ($group) = grep { $_->{'name'} eq $in{'_acl_group'} }
						  @{$h->{'groups'}};
				&remote_foreign_call($s->{'host'}, "acl", "set_acl_files",
					$h->{'users'}, $h->{'groups'}, $in{'_acl_mod'},
					$group->{'members'}, \%maccess);
				}
			1;
			};
		my $err = $@;
		if ($locked) {
			# Release the lock after a failed read or save when reachable.
			eval { &remote_foreign_call($s->{'host'}, "acl",
						   "unlock_file", $locked); };
			$err .= $@ if ($@);
			}
		print $wh &serialise_variable([ $ok ? 1 : 0, $err ]);
		exit;
		}
	close($wh);
	$p++;
	}

# Read back the results
$p = 0;
foreach $h (@hosts) {
	local ($s) = grep { $_->{'id'} == $h->{'id'} } @servers;
	local $d = &server_name($s);
	local $rh = "READ$p";
	local $line = <$rh>;
	local $rv = &unserialise_variable($line);
	close($rh);

	if ($rv && $rv->[0] == 1) {
		# It worked
		print &text('acl_success', $d),"<br>\n";
		}
	else {
		# Something went wrong
		print &text('acl_failed', $d, $rv->[1]),"<br>\n";
		}
	$p++;
	}

print "<p><b>$text{'acl_done'}</b><p>\n";

&remote_finished();
&ui_print_footer("", $text{'index_return'},
	$in{'_acl_user'} ? ( "edit_user.cgi?user=$in{'_acl_user'}&host=$in{'_acl_host'}", $text{'user_return'} ) : ( "edit_group.cgi?group=$in{'_acl_group'}&host=$in{'_acl_host'}", $text{'group_return'} ));

