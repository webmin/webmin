#!/usr/local/bin/perl
# delete_user.cgi
# Delete a webmin user across all servers

require './cluster-webmin-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'udelete_title'}, "");
print "<b>",&text('udelete_doing', $in{'user'}),"</b><p>\n";

# Setup error handler for down hosts
sub user_error
{
$user_error_msg = join("", @_);
}
&remote_error_setup(\&user_error);

# Delete the user on all servers that have him
foreach $h (&list_webmin_hosts()) {
	foreach $u (@{$h->{'users'}}) {
		if ($u->{'name'} eq $in{'user'}) {
			push(@hosts, $h);
			last;
			}
		}
	}
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

		# Delete the user
		&remote_foreign_call($s->{'host'}, "acl", "delete_user",
				     $in{'user'});
		$h->{'users'} = [ grep { $_->{'name'} ne $in{'user'} }
				       @{$h->{'users'}} ];

		# Remove from any groups
		foreach $g (@{$h->{'groups'}}) {
			local @mems = @{$g->{'members'}};
			local $i = &indexof($in{'user'}, @mems);
			if ($i >= 0) {
				splice(@mems, $i, 1);
				$g->{'members'} = \@mems;
				&remote_foreign_call($s->{'host'}, "acl",
						"modify_group", $g->{'name'}, $g);
				}
			}
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
		print &text('udelete_success', $d),"<br>\n";
		}
	else {
		# Something went wrong
		print &text('udelete_failed', $d, $rv->[1]),"<br>\n";
		}
	$p++;
	}

print "<p><b>$text{'udelete_done'}</b><p>\n";

&remote_finished();
&ui_print_footer("", $text{'index_return'});

