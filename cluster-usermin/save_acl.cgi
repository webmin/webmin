#!/usr/local/bin/perl
# save_acl.cgi
# Save the ACL for a module for a user or group

require './cluster-usermin-lib.pl';
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
		&remote_foreign_require($s->{'host'}, "acl", "acl-lib.pl");
		if ($user_error_msg) {
			# Host is down
			print $wh &serialise_variable([ 0, $user_error_msg ]);
			exit;
			}

		# Save the .acl file
		local $cd = &remote_eval($s->{'host'}, "acl", '$config_directory');
		&remote_foreign_call($s->{'host'}, "acl", "write_file",
			"$cd/$in{'_acl_mod'}/$who.acl", \%maccess);

		# Recursively update the ACL for all member users and groups
		if ($in{'_acl_group'}) {
			local ($group) = grep { $_->{'name'} eq $in{'_acl_group'} }
					      @{$h->{'groups'}};
			&remote_foreign_call($s->{'host'}, "acl", "set_acl_files",
				$h->{'users'}, $h->{'groups'}, $in{'_acl_mod'},
				$group->{'members'}, \%maccess);
			}

		print $wh &serialise_variable([ 1 ]);
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

