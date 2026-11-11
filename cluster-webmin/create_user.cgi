#!/usr/local/bin/perl
# create_user.cgi
# Create a new Webmin user across multiple servers

require './cluster-webmin-lib.pl';
&ReadParse();
&error_setup($text{'user_err1'});
@hosts = &list_webmin_hosts();

# Validate inputs
$in{'name'} =~ /^[A-z0-9\-\_\.]+$/ ||
	&error(&text('user_ename', $in{'name'}));
$in{'pass_def'} == 0 && $in{'pass'} =~ /:/ && &error($text{'user_ecolon'});
if ($in{'ipmode'} > 0) {
	@ips = split(/\s+/, $in{'ips'});
	}

# Setup error handler for down hosts
sub user_error
{
$user_error_msg = join("", @_);
}
&remote_error_setup(\&user_error);

# Work out which hosts to create on
&ui_print_header(undef, $text{'user_title1'}, "");
foreach $h (@hosts) {
	local ($alr) = grep { $_->{'name'} eq $in{'name'} } @{$h->{'users'}};
	push(@already, $h) if ($alr);
	}
@hosts = &create_on_parse('user_doing', \@already, $in{'name'});
foreach $h (@hosts) {
	foreach $ug (@{$h->{'users'}}, @{$h->{'groups'}}) {
		$taken{$ug->{'name'}}++;
		}
	}
$taken{$in{'name'}} && &error(&text('user_etaken', $in{'name'}));

# Create the user on all servers
#print "<b>",&text('user_doing', $in{'name'}),"</b><p>\n";
@servers = &list_servers();
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

		# Create the user
		local %user = ( 'name', $in{'name'} );
		if ($in{'lang'}) {
			$user{'lang'} = $in{'lang'};
			}
		if ($in{'theme'}) {
			$user{'theme'} = $in{'theme'} eq 'webmin' ? undef :
								 $in{'theme'};
			}
		if ($in{'ipmode'} == 1) {
			$user{'allow'} = join(" ", @ips);
			}
		elsif ($in{'ipmode'} == 2) {
			$user{'deny'} = join(" ", @ips);
			}
		if ($in{'pass_def'} == 0) {
			$salt = chr(int(rand(26))+65).chr(int(rand(26))+65);
			$user{'pass'} = &unix_crypt($in{'pass'}, $salt);
			}
		elsif ($in{'pass_def'} == 3) {
			$user{'pass'} = 'x';
			}
		elsif ($in{'pass_def'} == 4) {
			$user{'pass'} = '*LK*';
			}
		elsif ($in{'pass_def'} == 5) {
			$user{'pass'} = 'e';
			}
		$user{'sync'} = 0;

		local @mods = ( split(/\0/, $in{'mods1'}),
				split(/\0/, $in{'mods2'}),
				split(/\0/, $in{'mods3'}) );

		if ($in{'group'}) {
			# Add user to the chosen group
			($group) = grep { $_->{'name'} eq $in{'group'} }
					@{$h->{'groups'}};
			if (!$group) {
				# Doesn't exist on this server
				print $wh &serialise_variable(
					[ 0, $text{'user_egroup'} ]);
				exit;
				}
			push(@{$group->{'members'}}, $user{'name'});
			&remote_foreign_call($s->{'host'}, "acl", "modify_group",
					     $group->{'name'}, $group);

			# Add modules from group
			local @ownmods;
			foreach $m (@mods) {
				push(@ownmods, $m)
				    if (&indexof($m, @{$group->{'modules'}}) < 0);
				}
			@mods = &unique(@mods, @{$group->{'modules'}});
			$user{'ownmods'} = \@ownmods;

			# Copy ACL files for group
			&remote_foreign_call($s->{'host'}, "acl", "copy_acl_files",
					     $group->{'name'}, $user{'name'},
					     [ @{$group->{'modules'}}, "" ]);
			}

		$user{'modules'} = \@mods;
		&remote_foreign_call($s->{'host'}, "acl", "create_user", \%user);
		push(@{$h->{'users'}}, \%user);
		&save_webmin_host($h);

		# Restart the remote webmin
		print $wh &serialise_variable([ 1 ]);
		&remote_foreign_call($s->{'host'}, "acl", "restart_miniserv");
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
		print &text('user_success', $d),"<br>\n";
		}
	else {
		# Something went wrong
		print &text('user_failed', $d, $rv->[1]),"<br>\n";
		}
	$p++;
	}

print "<p><b>$text{'user_done'}</b><p>\n";

&remote_finished();
&ui_print_footer("", $text{'index_return'});

