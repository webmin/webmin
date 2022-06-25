#!/usr/local/bin/perl
# delete_group.cgi
# Delete a webmin group across all servers

require './cluster-webmin-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'gdelete_title'}, "");

# Find groups and members on all hosts
foreach $h (&list_webmin_hosts()) {
	foreach $g (@{$h->{'groups'}}) {
		if ($g->{'name'} eq $in{'group'}) {
			push(@hosts, $h);
			push(@mems, @{$g->{'members'}});
			foreach $m (@{$g->{'members'}}) {
				$onhost{$h,$m}++;
				($mg) = grep { $_->{'name'} eq $m }
					     @{$h->{'groups'}};
				push(@subs, $mg->{'name'}) if ($mg);
				}
			last;
			}
		}
	}
@mems = &unique(@mems);

if (@subs) {
	print &text('gdelete_esub',
		"<b>".join(" ", &unique(@subs))."</b>"),"<p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}
if (!$in{'confirm'} && @mems) {
	# Ask if the user really wants to delete the group and members
	print "<center><form action=delete_group.cgi>\n";
	print "<input type=hidden name=group value='$in{'group'}'>\n";
	print &text('gdelete_desc', "<b>$in{'group'}</b>",
		    "<b>".join(" ", @mems)."</b>"),"<p>\n";
	print "<input type=submit name=confirm value='$text{'gdelete_ok'}'>\n";
	print "</form></center>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}

print "<b>",&text('gdelete_doing', $in{'group'}),"</b><p>\n";

# Setup error handler for down hosts
sub group_error
{
$group_error_msg = join("", @_);
}
&remote_error_setup(\&group_error);

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

		# Delete the group
		&remote_foreign_call($s->{'host'}, "acl", "delete_group",
				     $in{'group'});
		$h->{'groups'} = [ grep { $_->{'name'} ne $in{'group'} }
				        @{$h->{'groups'}} ];

		# Remove from any groups
		foreach $g (@{$h->{'groups'}}) {
			local @mems = @{$g->{'members'}};
			local $i = &indexof($in{'group'}, @mems);
			if ($i >= 0) {
				splice(@mems, $i, 1);
				$g->{'members'} = \@mems;
				&remote_foreign_call($s->{'host'}, "acl",
						"modify_group", $g->{'name'}, $g);
				}
			}

		# Delete any members
		foreach $u (grep { $onhost{$h,$_} } @mems) {
			&remote_foreign_call($s->{'host'}, "acl",
					     "delete_user", $u);
			$h->{'users'} = [ grep { $_->{'name'} ne $u }
					       @{$h->{'users'}} ];
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
		print &text('gdelete_success', $d),"<br>\n";
		}
	else {
		# Something went wrong
		print &text('gdelete_failed', $d, $rv->[1]),"<br>\n";
		}
	$p++;
	}

print "<p><b>$text{'gdelete_done'}</b><p>\n";

&remote_finished();
&ui_print_footer("", $text{'index_return'});

