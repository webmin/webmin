#!/usr/local/bin/perl
# do_install.cgi
# Install some package on all hosts, in parallel. If the package was
# downloaded from a URL, have the hosts do the same - otherwise, transfer
# it to each.

require './cluster-software-lib.pl';
&ReadParse();
@packages = &foreign_call("software", "file_packages", $in{'file'});
foreach $p (@packages) {
	local ($n, $d) = split(/\s+/, $p, 2);
	push(@names, $n); push(@descs, $d);
	}
-r $in{'file'} || &error($text{'do_edeleted'});
&ui_print_header(undef, $text{'do_title'}, "");
print "<b>",&text('do_header', join(" ", @names)),"</b><p>\n";

@hosts = &list_software_hosts();
@servers = &list_servers();
foreach $h (@hosts) {
	# Check if already installed
	local ($s) = grep { $_->{'id'} == $h->{'id'} } @servers;
	local $d = $s->{'desc'} ? $s->{'desc'} : $s->{'host'};
	local ($a) = grep { &indexof($_->{'name'}, @names) >= 0 }
			  @{$h->{'packages'}};
	#if ($a) {
	#	print &text('do_already', $d),"<br>\n";
	#	next;
	#	}

	&remote_foreign_require($s->{'host'}, "software", "software-lib.pl");
	local $rfile;
	local $need_unlink = 1;
	if (!$s->{'id'}) {
		# This host, so we already have the file
		$rfile = $in{'file'};
		$need_unlink = 0;
		}
	elsif ($in{'source'} == 2 && $in{'down'}) {
		# Ask the remote server to download the file
		$rfile = &remote_eval($s->{'host'}, "software", '&tempname()');
		if ($in{'ftpfile'}) {
			&remote_foreign_call($s->{'host'}, "software",
				"ftp_download", $in{'host'}, $in{'ftpfile'},
				$rfile);
			}
		else {
			&remote_foreign_call($s->{'host'}, "software",
				"http_download", $in{'host'}, $in{'port'},
				$in{'page'}, $rfile);
			}
		}
	else {
		# Need to copy the file across :(
		$rfile = &remote_write($s->{'host'}, $in{'file'});
		}

	# Do the install ..
	for($i=0; $i<@names; $i++) {
		local $error = &remote_foreign_call($s->{'host'}, "software",
				    "install_package", $rfile, $names[$i], \%in);
		if ($error) {
			print &text('do_failed', $d, $error),"<br>\n";
			}
		else {
			# Success .. get the package details and add to list
			print &text('do_success', $d),"<br>\n";
			if (!$pinfo[$i]) {
				$pinfo[$i] = [ &remote_foreign_call($s->{'host'}, "software",
						"package_info", $names[$i]) ];
				}
			if (&indexof($names[$i], @{$h->{'packages'}}) < 0) {
				push(@{$h->{'packages'}},
				     { 'name' => $names[$i],
				       'desc' => $descs[$i],
				       'class' => $pinfo[$i]->[1] });
				&save_software_host($h);
				}
			}
		}
	&remote_eval($s->{'host'}, "software", "unlink('$rfile')") if ($need_unlink);
	}
unlink($in{'file'}) if ($in{'need_unlink'});
print "<p><b>$text{'do_done'}</b><p>\n";

for($i=0; $i<@names; $i++) {
	next if (!$pinfo[$i]);
	print "<table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'do_details'}</b></td> </tr>\n";
	print "<tr $cb> <td><table width=100%>\n";
	print "<tr> <td valign=top width=20%><b>$text{'do_desc'}</b></td>\n";
	print "<td colspan=3><font size=+1><pre>$pinfo[$i]->[2]</pre></font></td> </tr>\n";

	print "<tr> <td width=20%><b>$text{'do_pack'}</b></td> <td>$pinfo[$i]->[0]</td>\n";
	print "<td width=20%><b>$text{'do_class'}</b></td> <td>",
		$pinfo[$i]->[1] ? $pinfo[$i]->[1] : $text{'do_none'},"</td> </tr>\n";

	print "<tr> <td width=20%><b>$text{'do_ver'}</b></td> <td>$pinfo[$i]->[4]</td>\n";
	print "<td width=20%><b>$text{'do_vend'}</b></td> <td>$pinfo[$i]->[5]</td> </tr>\n";

	print "<tr> <td width=20%><b>$text{'do_arch'}</b></td> <td>$pinfo[$i]->[3]</td>\n";
	print "<td width=20%><b>$text{'do_inst'}</b></td> <td>$pinfo[$i]->[6]</td> </tr>\n";
	print "</table></td></tr></table><p>\n";
	}

&remote_finished();
&ui_print_footer("", $text{'index_return'});

