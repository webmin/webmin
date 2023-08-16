#!/usr/local/bin/perl
# do_install.cgi
# Install some package on all hosts, in parallel. If the package was
# downloaded from a URL, have the hosts do the same - otherwise, transfer
# it to each.

require './cluster-software-lib.pl';
&ReadParse();

# Work out package names, for display to use
if ($in{'source'} == 3) {
	# Package names are from YUM
	@packages = @names = @descs = split(/\s+/, $in{'file'});
	}
else {
	# Get package names and descriptions from file
	@packages = $in{'unknownfile'} ? ( $in{'unknownfile'} ) :
					 &software::file_packages($in{'file'});
	foreach $p (@packages) {
		local ($n, $d) = split(/\s+/, $p, 2);
		push(@names, $n);
		push(@descs, $d || $n);
		}
	}

$in{'source'} == 3 || -r $in{'file'} || &error($text{'do_edeleted'});
&ui_print_header(undef, $text{'do_title'}, "");

# Setup error handler for down hosts
sub inst_error
{
$inst_error_msg = join("", @_);
}
&remote_error_setup(\&inst_error);

# Work out hosts to install on
@hosts = &list_software_hosts();
@already = grep { local ($alr) = grep { $_->{'name'} eq $names[0] }
				    @{$_->{'packages'}};
		  $alr } @hosts;
@hosts = &create_on_parse("do_header", \@already, join(" ", @names));
@servers = &list_servers();

$p = 0;
foreach $h (@hosts) {
	# Install on one host
	local ($s) = grep { $_->{'id'} == $h->{'id'} } @servers;
	local $d = $s->{'desc'} || $s->{'realhost'} || $s->{'host'};

	local ($rh = "READ$p", $wh = "WRITE$p");
	pipe($rh, $wh);
	select($wh); $| = 1; select(STDOUT);
	if (!fork()) {
		# Do the install in a subprocess
		close($rh);

		&remote_foreign_require($s->{'host'}, "software",
					"software-lib.pl");
		if ($inst_error_msg) {
			# Failed to contact host ..
			print $wh &serialise_variable([ $inst_error_msg ]);
			exit;
			}
		local $rfile;
		local $need_unlink = 1;
		if ($in{'source'} == 3) {
			# Installing from an update service like APT or YUM
			$need_unlink = 0;
			}
		elsif (!$s->{'id'}) {
			# This host, so we already have the file
			$rfile = $in{'file'};
			$need_unlink = 0;
			}
		elsif ($in{'source'} == 0) {
			# Is the file the same on remote (like if we have NFS)
			local @st = stat($in{'file'});
			local $rst = &remote_eval($s->{'host'}, "software",
						  "[ stat('$in{'file'}') ]");
			local @rst = @$rst;
			if (@st && @rst && $st[7] == $rst[7] &&
			    $st[9] == $rst[9]) {
				# File is the same! No need to download
				$rfile = $in{'file'};
				$need_unlink = 0;
				}
			else {
				# Need to copy the file across :(
				local $filename = $in{'file'};
				$filename =~ /([^\/\\]+)$/;
				$rfile = &remote_write(
					$s->{'host'}, $in{'file'}, undef, "$1");
				}
			}
		elsif ($in{'source'} == 2 && $in{'down'}) {
			# Ask the remote server to download the file
			local $filename = $in{'file'};
			$filename =~ /([^\/\\]+$)/;
			$rfile = &remote_foreign_call($s->{'host'}, "software",
						      "tempname", $1);
			if ($in{'ftpfile'}) {
				&remote_foreign_call($s->{'host'}, "software",
				    "ftp_download", $in{'host'}, $in{'ftpfile'},
				    $rfile);
				}
			else {
				&remote_foreign_call($s->{'host'}, "software",
				    "http_download", $in{'host'}, $in{'port'},
				    $in{'page'}, $rfile, undef, undef,
				    $in{'ssl'});
				}
			}
		else {
			# Need to copy the file across :(
			local $filename = $in{'file'};
			$filename =~ /([^\/\\]+)$/;
			$rfile = &remote_write($s->{'host'}, $in{'file'},
					       undef, "$1");
			}

		# Do the install ..
		local @rv;
		if ($in{'source'} != 3) {
			# Installing some package
			for($i=0; $i<@names; $i++) {
				local $error = &remote_foreign_call(
					$s->{'host'}, "software",
					"install_package", $rfile,
					$names[$i], \%in);
				if ($error) {
					push(@rv, $error);
					}
				else {
					# Success .. get the package details
					push(@rv, [ &remote_foreign_call($s->{'host'}, "software", "package_info", $names[$i]) ] );
					}
				}
			}
		else {
			# Install from update system
			local $rus = &remote_eval($s->{'host'}, "software",
						  '$update_system');
			if ($rus ne $software::update_system) {
				push(@rv, &text('install_erus',
					$rus, $software::update_system));
				}
			else {
				local @resp = &remote_foreign_call($s->{'host'},
					"software", "capture_function_output",
					"software::update_system_install",
					$in{'file'});
				if (@{$resp[1]}) {
					# Worked .. get package details
					foreach $p (@{$resp[1]}) {
						push(@rv, [ &remote_foreign_call($s->{'host'}, "software", "package_info", $p) ] );
						}
					}
				else {
					# May have failed
					($first) = split(/\s+/, $in{'file'});
					local @info = &remote_foreign_call(
						$s->{'host'}, "software",
						"package_info", $first);
					if (@info && $info[0] eq $first) {
						push(@rv, &text('install_ealready', $info[4]));
						}
					else {
						push(@rv, $text{'install_eupdate'});
						}
					}
				}
			}
		&remote_eval($s->{'host'}, "software", "unlink('$rfile')")
			if ($need_unlink);

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
	local $d = $s->{'desc'} || $s->{'realhost'} || $s->{'host'};

	if (!$line) {
		print &text('do_failed', $d, "Unknown reason"),"<br>\n";
		}
	else {
		$i=0;
		foreach $r (@$rv) {
			if (ref($r)) {
				# Install went ok!
				print &text('do_success2', $r->[0],$d),"<br>\n";
				$pinfo[$i] = $r if (!$pinfo[$i] && @$r);
				if (!@$r) {
					# Failed to get info! Need a refresh..
					$refresh{$s->{'id'}} = 1;
					}
				elsif ($names[$i] &&
				       &indexof($names[$i],
					     @{$h->{'packages'}}) < 0) {
					push(@{$h->{'packages'}},
					     { 'name' => $names[$i],
					       'desc' => $descs[$i],
					       'class' => $pinfo[$i]->[1],
					       'version' => $pinfo[$i]->[4] });
					&save_software_host($h);
					}
				}
			else {
				# Failed for some reason..
				print &text('do_failed', $d, $r),"<br>\n";
				}
			$i++;
			}
		}
	$p++;
	}

unlink($in{'file'}) if ($in{'need_unlink'});
print "<p><b>$text{'do_done'}</b><p>\n";

# Show details of installed packages, where we have them
for($i=0; $i<@names; $i++) {
	next if (!$pinfo[$i]);
	print &ui_table_start($text{'do_details'}, "width=100%", 4);

	if ($pinfo[$i]->[2]) {
		print &ui_table_row($text{'do_desc'},
			"<pre>".&html_escape($pinfo[$i]->[2])."</pre>", 3);
		}

	print &ui_table_row($text{'do_pack'},
		$pinfo[$i]->[0]);

	print &ui_table_row($text{'do_class'},
		$pinfo[$i]->[1] || $text{'do_none'});

	print &ui_table_row($text{'do_ver'},
		$pinfo[$i]->[4]);

	print &ui_table_row($text{'do_vend'},
		$pinfo[$i]->[5]);

	print &ui_table_row($text{'do_arch'},
		$pinfo[$i]->[3]);

	print &ui_table_row($text{'do_inst'},
		$pinfo[$i]->[6]);

	print &ui_table_end();
	}

&remote_finished();
&ui_print_footer("", $text{'index_return'});

