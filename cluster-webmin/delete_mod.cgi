#!/usr/local/bin/perl
# delete_mod.cgi
# Delete a module from one or all servers, after asking for confirmation

require './cluster-webmin-lib.pl';
&ReadParse();
@servers = &list_servers();
@hosts = &list_webmin_hosts();
if ($in{'server'} < 0) {
	# Find servers that have the module or theme
	foreach $h (@hosts) {
		foreach $m (@{$h->{'modules'}}, @{$h->{'themes'}}) {
			if ($m->{'dir'} eq $in{'mod'}) {
				local ($s) = grep { $_->{'id'} == $h->{'id'} }
						  @servers;
				push(@got, $s);
				$gotmap{$s} = $h;
				$best = $s if (!$s->{'id'});
				last;
				}
			}
		}
	$s = $best ? $best : $got[0];
	}
else {
	($s) = grep { $_->{'id'} == $in{'server'} } @servers;
	($h) = grep { $_->{'id'} == $in{'server'} } @hosts;
	@got = ( $s );
	$gotmap{$s} = $h;
	}
$h = $gotmap{$s};
foreach $m ($in{'type'} eq 'mod' ? @{$h->{'modules'}} : @{$h->{'themes'}}) {
	$info = $m if ($m->{'dir'} eq $in{'mod'});
	}

# Setup error handler for down hosts
sub del_error
{
$del_error_msg = join("", @_);
}
&remote_error_setup(\&del_error);
&remote_foreign_require($s->{'host'}, "webmin", "webmin-lib.pl");

&ui_print_header(undef, $text{'delete_title'}, "");
if ($in{'sure'}) {
	# do the deletion in separate processes
	print "<br><b>",&text("delete_header_$in{'type'}",
			      $info->{'desc'}),"</b><p>\n";
	$p = 0;
	foreach $g (@got) {
		local ($rh = "READ$p", $wh = "WRITE$p");
		pipe($rh, $wh);
		if (!fork()) {
			close($rh);
			local $h = $gotmap{$g};

			# Check for any dependencies on this host
			foreach $m (@{$h->{'modules'}}) {
				foreach $d (split(/\s+/, $m->{'depends'})) {
					push(@{$ondeps{$d}}, $m);
					}
				}
			if ($ondeps{$in{'mod'}}) {
				print $wh &serialise_variable([ 0, &text('delete_edepends', join(", ", map { $_->{'desc'} } @{$ondeps{$in{'mod'}}})) ]);
				exit;
				}

			# Delete the module
			&remote_foreign_require($g->{'host'}, "webmin",
					     "webmin-lib.pl") if ($s ne $g);
			&remote_foreign_require($g->{'host'}, "acl",
						"acl-lib.pl");
			local $desc = &remote_foreign_call($g->{'host'},
				"webmin", "delete_webmin_module", $in{'mod'},
				$in{'acls'});
			if ($del_error_msg) {
				print $wh &serialise_variable([ 0, $del_error_msg ]);
				}
			elsif ($desc) {
				print $wh &serialise_variable([ 1, $desc ]);
				}
			else {
				print $wh &serialise_variable([ 0, $text{'delete_egone'} ]);
				}

			# Re-request all users and groups from the server
			local @newmods = grep { $_->{'dir'} ne $in{'mod'} }
					      @{$h->{'modules'}};
			local @newthemes = grep { $_->{'dir'} ne $in{'mod'} }
					        @{$h->{'themes'}};
			$h->{'modules'} = \@newmods;
			$h->{'themes'} = \@newthemes;
			$h->{'users'} = [ &remote_foreign_call($g->{'host'},
						"acl", "list_users") ];
			$h->{'groups'} = [ &remote_foreign_call($g->{'host'},
						"acl", "list_groups") ];
			&save_webmin_host($h);

			close($wh);
			exit;
			}
		close($wh);
		$p++;
		}

	# Read back the results
	$p = 0;
	foreach $g (@got) {
		local $rh = "READ$p";
		local $line = <$rh>;
		local $rv = &unserialise_variable($line);
		close($rh);
		local $d = &server_name($g);

		if (!$rv->[0]) {
			print &text('delete_error', $d, $rv->[1]),"<br>\n";
			}
		else {
			print &text('delete_success', $d, $rv->[1]),"<br>\n";
			}
		$p++;
		}
	print "<p><b>$text{'delete_done'}</b><p>\n";
	}
else {
	# Ask if the user is sure..
	$rroot = &remote_eval($s->{'host'}, "webmin", '$root_directory');
	$sz = &remote_foreign_call($s->{'host'}, "webmin", "disk_usage_kb",
				   "$rroot/$in{'mod'}");
	print "<center>\n";
	if ($in{'server'} < 0) {
		print &text("delete_rusure_$in{'type'}",
		    "<b>$info->{'desc'}</b>", $sz),"<p>\n";
		}
	else {
		print &text("delete_rusure2_$in{'type'}",
		    "<b>$info->{'desc'}</b>", $sz, &server_name($s)),"<p>\n";
		}
	print "<form action=delete_mod.cgi>\n";
	print "<input type=hidden name=mod value=\"$in{'mod'}\">\n";
	print "<input type=hidden name=type value=\"$in{'type'}\">\n";
	print "<input type=hidden name=server value=\"$in{'server'}\">\n";
	print "<input type=hidden name=sure value=1>\n";
	print "<input type=submit value=\"$text{'delete_ok'}\"><br>\n";
	print "<input type=checkbox name=acls value=1> $text{'delete_acls'}\n";
	print "</center></form>\n";
	}

&remote_finished();
&ui_print_footer("", $text{'index_return'});

