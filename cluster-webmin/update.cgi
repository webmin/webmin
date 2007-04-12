#!/usr/local/bin/perl
# update.cgi
# Download and install needed updates on multiple servers

require './cluster-webmin-lib.pl';
&foreign_require("webmin", "webmin-lib.pl");
&ReadParse();
&error_setup($webmin::text{'update_err'});

# Fetch list of updates
($updates, $host, $port, $page, $ssl) = &webmin::fetch_updates(
	$in{'source'} == 0 ? $webmin::update_url : $in{'other'});

# Build list of selected hosts, and show them
@servers = &list_servers();
&ui_print_unbuffered_header(undef, $text{'update_title'}, "");
@hosts = &create_on_parse("update_header", undef, undef);

# Setup error handler for down hosts
sub inst_error
{
$inst_error_msg = join("", @_);
}
&remote_error_setup(\&inst_error);

# Run the update, on all hosts in parallel
$p = 0;
foreach $h (@hosts) {
	local ($s) = grep { $_->{'id'} == $h->{'id'} } @servers;
	$s || &error("Failed to find server for $h->{'id'}");

	local ($rh = "READ$p", $wh = "WRITE$p");
	pipe($rh, $wh);
	select($wh); $| = 1; select(STDOUT);
	if (!fork()) {
		# Do the install in a subprocess
		close($rh);

		&remote_foreign_require($s->{'host'}, "webmin",
					"webmin-lib.pl");
		if ($inst_error_msg) {
			# Failed to contact host ..
			print $wh &serialise_variable($inst_error_msg);
			exit;
			}

		# Work out which modules are needed
		local @rv;
		local $bv = &remote_foreign_call(
			$s->{'host'}, "webmin",
			"get_webmin_base_version");
		foreach $u (@$updates) {
			local %minfo = &remote_foreign_call(
				$s->{'host'}, "webmin",
				"get_module_info", $u->[0]);
			local %tinfo = %minfo ? () :
				&remote_foreign_call(
					$s->{'host'}, "webmin",
					"get_theme_info", $u->[0]);
			local %info = %minfo ? %minfo : %tinfo;
			next if (($u->[1] >= $bv + .01 ||
				  $u->[1] < $bv) &&
				 (!%info || $info{'longdesc'} || !$in{'third'}));

			# Check if update is appropriate
			$count++;
			if (!%info && !$in{'missing'}) {
				push(@rv, &webmin::text('update_mmissing',
						      "<b>$u->[0]</b>"));
				next;
				}
			if (%info && $info{'version'} >= $u->[1]) {
				push(@rv, &webmin::text('update_malready',
						      "<b>$u->[0]</b>"));
				next;
				}
			local $osinfo = { 'os_support' => $u->[3] };
			if (!&check_os_support($osinfo)) {
				push(@rv, &webmin::text('update_mos',
						      "<b>$u->[0]</b>"));
				next;
				}

			if ($in{'show'}) {
				# Just send back info
				push(@rv, [ 0, @$u ]);
				}
			else {
				# Do the update!
				($mhost, $mport, $mpage, $mssl) =
					&parse_http_url($u->[2], $host, $port, $page, $ssl);
				$mtemp = &remote_foreign_call(
					$s->{'host'}, "webmin", "tempname");
				local $err;
				&remote_foreign_call(
					$s->{'host'}, "webmin",
					"http_download", $mhost, $mport,
					$mpage, $mtemp, \$err, undef, $mssl);
				if ($err) {
					# Download failed
					push(@rv, $err);
					}
				else {
					# Do the install
					$irv = &remote_foreign_call(
						$s->{'host'}, "webmin",
						"install_webmin_module",
						$mtemp, 1, 0,
						[ $base_remote_user ]);
					if (ref($irv)) {
						push(@rv, [ 1, @$u ]);
						}
					else {
						push(@rv, $irv);
						}
					}
				}
			}
		print $wh &serialise_variable(\@rv);
		close($wh);
		exit;
		}
	close($wh);
	$p++;
	}

# Get back all the results
$p = 0;
foreach $h (@hosts) {
	local $rh = "READ$p";
	local $line = <$rh>;
	close($rh);
	local $rv = &unserialise_variable($line);

	local ($s) = grep { $_->{'id'} == $h->{'id'} } @servers;
	local $d = &server_name($s);

	print &text('update_onhost', $d),"<br>\n";
	if (!$line) {
		print &text('update_failed', "Unknown reason"),"<p>\n";
		}
	elsif (!ref($rv)) {
		print &text('update_failed', $rv),"<p>\n";
		}
	elsif (!@$rv) {
		print &text('update_none', $rv),"<p>\n";
		}
	else {
		# Show list of modules
		print "<ul>\n";
		foreach $u (@$rv) {
			if (ref($u)) {
				# A module
				print &webmin::text($u->[0] ? 'update_mok' : 'update_mshow', "<b>$u->[1]</b>", "<b>$u->[2]</b>"),"<br>\n";
				print "&nbsp;&nbsp;&nbsp;$webmin::text{'update_fixes'} : $u->[5]<br>\n";
				}
			else {
				# Some message
				print $u,"<br>\n";
				}
			}
		print "</ul><p>\n";
		}
	$p++;
	}
print "<p><b>$text{'upgrade_done'}</b><p>\n";

&remote_finished();
&ui_print_footer("", $text{'index_return'});

