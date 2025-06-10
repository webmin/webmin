#!/usr/local/bin/perl
# create_group.cgi
# Create a new Webmin group across multiple servers

require './cluster-webmin-lib.pl';
&ReadParse();
&error_setup($text{'group_err1'});
@hosts = &list_webmin_hosts();

# Validate inputs
$in{'name'} =~ /^[A-z0-9\-\_\.]+$/ ||
	&error(&text('user_ename', $in{'name'}));

# Setup error handler for down hosts
sub group_error
{
$group_error_msg = join("", @_);
}
&remote_error_setup(\&group_error);

# Work out which hosts to create on
&ui_print_header(undef, $text{'group_title1'}, "");
foreach $h (@hosts) {
	local ($alr) = grep { $_->{'name'} eq $in{'name'} } @{$h->{'groups'}};
	push(@already, $h) if ($alr);
	}
@hosts = &create_on_parse('group_doing', \@already, $in{'name'});
foreach $h (@hosts) {
	foreach $ug (@{$h->{'users'}}, @{$h->{'groups'}}) {
		$taken{$ug->{'name'}}++;
		}
	}
$taken{$in{'name'}} && &error(&text('user_etaken', $in{'name'}));

@servers = &list_servers();
$p = 0;
foreach $h (@hosts) {
	local ($s) = grep { $_->{'id'} == $h->{'id'} } @servers;
	local ($rh = "READ$p", $wh = "WRITE$p");
	pipe($rh, $wh);
	if (!fork()) {
		close($rh);
		&remote_foreign_require($s->{'host'}, "acl", "acl-lib.pl");
		if ($group_error_msg) {
			# Host is down
			print $wh &serialise_variable([ 0, $group_error_msg ]);
			exit;
			}

		# Create the group
		local %newgrp = ( 'name', $in{'name'} );
		local @mods = ( split(/\0/, $in{'mods1'}),
				split(/\0/, $in{'mods2'}),
				split(/\0/, $in{'mods3'}) );

		if ($in{'group'}) {
			# Add group to the chosen group
			($group) = grep { $_->{'name'} eq $in{'group'} }
					@{$h->{'groups'}};
			if (!$group) {
				# Doesn't exist on this server
				print $wh &serialise_variable(
					[ 0, $text{'user_egroup'} ]);
				exit;
				}
			push(@{$group->{'members'}}, $newgrp{'name'});
			&remote_foreign_call($s->{'host'}, "acl", "modify_group",
					     $group->{'name'}, $group);

			# Add modules from group
			local @ownmods;
			foreach $m (@mods) {
				push(@ownmods, $m)
				    if (&indexof($m, @{$group->{'modules'}}) < 0);
				}
			@mods = &unique(@mods, @{$group->{'modules'}});
			$newgrp{'ownmods'} = \@ownmods;

			# Copy ACL files for group
			&remote_foreign_call($s->{'host'}, "acl", "copy_acl_files",
					     $group->{'name'}, $newgrp{'name'},
					     [ @{$group->{'modules'}}, "" ]);
			}

		$newgrp{'modules'} = \@mods;
		&remote_foreign_call($s->{'host'}, "acl", "create_group", \%newgrp);
		push(@{$h->{'groups'}}, \%newgrp);
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
		print &text('group_success', $d),"<br>\n";
		}
	else {
		# Something went wrong
		print &text('group_failed', $d, $rv->[1]),"<br>\n";
		}
	$p++;
	}

print "<p><b>$text{'group_done'}</b><p>\n";

&remote_finished();
&ui_print_footer("", $text{'index_return'});

