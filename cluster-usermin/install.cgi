#!/usr/local/bin/perl
# install.cgi
# Download and install usermin module or theme on multiple hosts

require './cluster-usermin-lib.pl';
if ($ENV{REQUEST_METHOD} eq "POST") { &ReadParseMime(); }
else { &ReadParse(); $no_upload = 1; }
&error_setup($text{'install_err'});

if ($in{source} == 2) {
	&ui_print_unbuffered_header(undef, $text{'install_title'}, "");
	}
else {
	&ui_print_header(undef, $text{'install_title'}, "");
	}

if ($in{source} == 0) {
	# installing from local file (or maybe directory)
	if (!$in{'local'})
		{ &download_error($text{'install_elocal'}); }
	if (!-r $in{'local'})
		{ &download_error(&text('install_elocal2', $in{'local'})); }
	$source = $in{'local'};
	$pfile = $in{'local'};
	$need_unlink = 0;
	}
elsif ($in{source} == 1) {
	# installing from upload .. store file in temp location
	if ($no_upload) {
		&download_error($text{'install_eupload'});
		}
	$in{'upload_filename'} =~ /([^\/\\]+$)/;
	$pfile = &tempname("$1");
	&open_tempfile(PFILE, "> $pfile");
	&print_tempfile(PFILE, $in{'upload'});
	&close_tempfile(PFILE);
	$source = $in{'upload_filename'};
	$need_unlink = 1;
	}
elsif ($in{source} == 2) {
	# installing from URL.. store downloaded file in temp location
	$in{'url'} =~ /\/([^\/]+)\/*$/;
	$pfile = &tempname("$1");
	$progress_callback_url = $in{'url'};
	if ($in{'url'} =~ /^(http|https):\/\/([^\/]+)(\/.*)$/) {
		# Make a HTTP request
		$ssl = $1 eq 'https';
		$host = $2; $page = $3; $port = $ssl ? 443 : 80;
		if ($host =~ /^(.*):(\d+)$/) { $host = $1; $port = $2; }
		&http_download($host, $port, $page, $pfile, \$error,
			       \&progress_callback, $ssl);
		}
	elsif ($in{'url'} =~ /^ftp:\/\/([^\/]+)(:21)?(\/.*)$/) {
		$host = $1; $file = $3;
		&ftp_download($host, $file, $pfile, \$error,
			      \&progress_callback);
		}
	else { &download_error(&text('install_eurl', $in{'url'})); }
	&download_error($error) if ($error);
	$source = $in{'url'};
	$need_unlink = 1;
	}
$grant = $in{'grant'} ? undef : [ split(/\s+/, $in{'grantto'}) ];

# Check validity
open(MFILE, $pfile);
read(MFILE, $two, 2);
close(MFILE);
if ($two eq "\037\235") {
	# Unix compressed
	&has_command("uncompress") ||
		&download_error(&text('install_ecomp', "<tt>uncompress</tt>"));
	$cmd = "uncompress -c '$pfile' | tar tf -";
	}
elsif ($two eq "\037\213") {
	# Gzipped
	&has_command("gunzip") || 
		&download_error(&text('install_egzip', "<tt>gunzip</tt>"));
	$cmd = "gunzip -c '$pfile' | tar tf -";
	}
else {
	# Just a tar file
	$cmd = "tar tf '$pfile'";
	}
$tar = `$cmd 2>&1`;
$? && &download_error(&text('install_ecmd', "<tt>$tar</tt>"));
foreach $f (split(/\n/, $tar)) {
	if ($f =~ /^\.\/([^\/]+)\/(.*)$/ || $f =~ /^([^\/]+)\/(.*)$/) {
		$mods{$1}++;
		$hasfile{$1,$2}++;
		}
	}
foreach $m (keys %mods) {
	$hasfile{$m,"module.info"} || $hasfile{$m,"theme.info"} ||
		&download_error(&text('install_einfo', "<tt>$m</tt>"));
	}
if (!%mods) {
	&download_error($text{'install_enone'});
	}

# Get the version numbers
$tempdir = &transname();
mkdir($tempdir, 0755);
foreach $m (keys %mods) {
	local $xcmd = $cmd;
	$xcmd =~ s/tf/xf/g;
	system("cd $tempdir ; $xcmd $m/module.info ./$m/module.info >/dev/null 2>&1");
	local %minfo;
	&read_file("$tempdir/$m/module.info", \%minfo);
	$modver{$m} = $minfo{'version'};
	}

# Setup error handler for down hosts
sub inst_error
{
$inst_error_msg = join("", @_);
}
&remote_error_setup(\&inst_error);

# Work out which hosts have the module, and which to install on
@hosts = &list_usermin_hosts();
@servers = &list_servers();
foreach $h (@hosts) {
	local $gotall = 1;
	foreach $m (keys %mods) {
		local ($alr) = grep { $_->{'dir'} eq $m }
				(@{$h->{'modules'}}, @{$h->{'themes'}});
		$gotall = 0 if (!$alr ||
				(defined($modver{$m}) &&
				 $modver{$m} > $alr->{'version'}));
		}
	push(@gothosts, $h) if ($gotall);
	}
@hosts = &create_on_parse("install_header", \@gothosts,
		 join(" ", keys %mods));

# Run the install
$p = 0;
foreach $h (@hosts) {
	local ($s) = grep { $_->{'id'} == $h->{'id'} } @servers;

	local ($rh = "READ$p", $wh = "WRITE$p");
	pipe($rh, $wh);
	select($wh); $| = 1; select(STDOUT);
	if (!fork()) {
		# Do the install in a subprocess
		close($rh);

		&remote_foreign_require($s->{'host'}, "usermin",
					"usermin-lib.pl");
		if ($inst_error_msg) {
			# Failed to contact host ..
			print $wh &serialise_variable($inst_error_msg);
			exit;
			}
		&remote_foreign_require($s->{'host'}, "acl", "acl-lib.pl");
		local $rfile;
		local $host_need_unlink = 1;
		if (!$s->{'id'}) {
			# This host, so we already have the file
			$rfile = $pfile;
			$host_need_unlink = 0;
			}
		elsif ($in{'source'} == 0) {
			# Is the file the same on remote? (like if we have NFS)
			local @st = stat($pfile);
			local $rst = &remote_eval($s->{'host'}, "usermin",
						  "[ stat('$pfile') ]");
			local @rst = @$rst;
			if (@st && @rst && $st[7] == $rst[7] &&
			    $st[9] == $rst[9]) {
				# File is the same! No need to download
				$rfile = $pfile;
				$host_need_unlink = 0;
				}
			else {
				# Need to copy the file across :(
				$rfile = &remote_write(
					$s->{'host'}, $pfile);
				}
			}
		elsif ($in{'source'} == 2 && $in{'down'}) {
			# Ask the remote server to download the file
			$rfile = &remote_foreign_call($s->{'host'}, "usermin",
						      "tempname");
			if ($in{'url'} =~ /^ftp/) {
				&remote_foreign_call($s->{'host'}, "usermin",
				    "ftp_download", $host, $file,
				    $rfile);
				}
			else {
				&remote_foreign_call($s->{'host'}, "usermin",
				    "http_download", $host, $port,
				    $page, $rfile, undef, undef, $ssl);
				}
			}
		else {
			# Need to copy the file across :(
			$rfile = &remote_write($s->{'host'}, $pfile);
			}

		# Do the install ..
		local $rv = &remote_foreign_call($s->{'host'},
				"usermin", "install_usermin_module", $rfile,
				$host_need_unlink, $in{'nodeps'});
		if (ref($rv)) {
			# It worked .. get all the module infos
			local @mods;
			foreach $m (@{$rv->[1]}) {
				$m =~ s/^.*\///;
				local %info = &remote_foreign_call(
						$s->{'host'}, "usermin",
						"get_usermin_module_info", $m);
				if (!%info) {
					# Must have been a theme
					%info = &remote_foreign_call(
						$s->{'host'}, "usermin",
						"get_usermin_theme_info", $m);
					$info{'theme'} = 1;
					}
				push(@mods, \%info);
				}
			print $wh &serialise_variable(\@mods);

			# Re-request all modules and themes from the server
			$h->{'modules'} = [ grep { !$_->{'clone'} }
				&remote_foreign_call($s->{'host'},
					"usermin", "list_modules") ];
			$h->{'themes'} = [ &remote_foreign_call($s->{'host'},
					"usermin", "list_themes") ];
			&save_usermin_host($h);
			}
		else {
			print $wh &serialise_variable($rv);
			}
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

	if (!$line) {
		print &text('do_failed', $d, "Unknown reason"),"<br>\n";
		}
	elsif (!ref($rv)) {
		print &text('do_failed', $d, $rv),"<br>\n";
		}
	else {
		# List the modules installed, and add to lists
		foreach $m (@$rv) {
			if ($m->{'theme'}) {
				print &text('do_success_theme', $d, "<b>$m->{'desc'}</b>"), "<br>\n";
				}
			else {
				print &text('do_success_mod', $d, "<b>$m->{'desc'}</b>"), "<br>\n";
				}
			}
		}
	$p++;
	}
unlink($pfile) if ($need_unlink);
print "<p><b>$text{'do_done'}</b><p>\n";

&remote_finished();
&ui_print_footer("", $text{'index_return'});

sub download_error
{
unlink($pfile) if ($need_unlink);
print "<br><b>$whatfailed : $_[0]</b> <p>\n";
&ui_print_footer("", $text{'index_return'});
exit;
}

