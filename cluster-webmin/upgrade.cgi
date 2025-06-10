#!/usr/local/bin/perl
# upgrade.cgi
# Download webmin and upgrade all managed servers of compatible types

require './cluster-webmin-lib.pl';
&foreign_require("proc", "proc-lib.pl");
&foreign_require("webmin", "webmin-lib.pl");
&foreign_require("webmin", "gnupg-lib.pl");
&ReadParseMime();

&ui_print_unbuffered_header(undef, $text{'upgrade_title'}, "");

# Save this CGI from being killed by the upgrade
$SIG{'TERM'} = 'IGNORE';

if ($in{'source'} == 0) {
	# from local file
	&error_setup(&webmin::text('upgrade_err1', $in{'file'}));
	$file = $in{'file'};
	if (!(-r $file)) { &inst_error($webmin::text{'upgrade_efile'}); }
	}
elsif ($in{'source'} == 1) {
	# from uploaded file
	&error_setup($webmin::text{'upgrade_err2'});
	$file = &tempname();
	$need_unlink = 1;
	if ($no_upload) {
                &inst_error($webmin::text{'upgrade_ebrowser'});
                }
	open(MOD, ">$file");
	print MOD $in{'upload'};
	close(MOD);
	}
elsif ($in{'source'} == 2) {
	# find latest version at www.webmin.com by looking at index page
	&error_setup($webmin::text{'upgrade_err3'});
	($ok, $site_version) = &webmin::get_latest_webmin_version();
	$ok || &inst_error($site_version);
	if ($in{'mode'} eq 'rpm') {
		$progress_callback_url = &convert_osdn_url(
			"http://$webmin::osdn_host/webadmin/webmin-${site_version}-1.noarch.rpm");
		}
        elsif ($in{'mode'} eq 'deb') {
                # Downloading Debian package
		$progress_callback_url = &convert_osdn_url(
			"http://$webmin::osdn_host/webadmin/webmin_${site_version}_all.deb");
                }
	else {
		$progress_callback_url = &convert_osdn_url(
			"http://$webmin::osdn_host/webadmin/webmin-${site_version}.tar.gz");
		}
	$file = &tempname();
	($host, $port, $page, $ssl) = &parse_http_url($progress_callback_url);
	&http_download($host, $port, $page, $file,
			\$error, \&progress_callback);
	$error && &inst_error($progress_callback_url." : ".$error);
	$need_unlink = 1;
	}
elsif ($in{'source'} == 5) {
	# Download from some URL
	&error_setup(&webmin::text('upgrade_err5', $in{'url'}));
	$file = &tempname();
	$progress_callback_url = $in{'url'};
	if ($in{'url'} =~ /^(http|https):\/\/([^\/]+)(\/.*)$/) {
		$ssl = $1 eq 'https';
		$host = $2; $page = $3; $port = $ssl ? 443 : 80;
		if ($host =~ /^(.*):(\d+)$/) { $host = $1; $port = $2; }
		&http_download($host, $port, $page, $file, \$error,
			       \&progress_callback, $ssl);
		}
	elsif ($in{'url'} =~ /^ftp:\/\/([^\/]+)(:21)?\/(.*)$/) {
		$host = $1; $ffile = $3;
		&ftp_download($host, $ffile, $file,
			      \$error, \&progress_callback);
		}
	else { &inst_error($webmin::text{'upgrade_eurl'}); }
	$need_unlink = 1;
	$error && &inst_error($error);
	}

# Import the signature for RPM
if (&has_command("rpm")) {
	system("rpm --import $root_directory/webmin/jcameron-key.asc >/dev/null 2>&1");
	}

# Work out what kind of file we have (RPM or tar.gz)
if (`rpm -qp $file 2>&1` =~ /(^|\n)webmin-(\d+\.\d+)/) {
	# Looks like a webmin RPM
	$mode = "rpm";
	$version = $2;
	}
elsif (`dpkg --info $file 2>&1` =~ /Package:\s+webmin/) {
	# Looks like a Webmin Debian package
	$mode = "deb";
	`dpkg --info $file 2>&1` =~ /Version:\s+(\S+)/;
	$version = $1;
	}
else {
        # Check if it is a webmin tar.gz file
        open(TAR, "gunzip -c $file | tar tf - 2>&1 |");
        while(<TAR>) {
                s/\r|\n//g;
                if (/^webmin-([0-9\.]+)\//) {
                        $version = $1;
                        }
                if (/^usermin-([0-9\.]+)\//) {
                        $usermin_version = $1;
                        }
                if (/^[^\/]+\/(\S+)$/) {
                        $hasfile{$1}++;
                        }
		if (/^(webmin-([0-9\.]+)\/([^\/]+))$/ && $3 ne ".") {
			# Found a top-level file, or *possibly* a directory
			# under some versions of tar. Keep it so we know which
			# files to extract.
			push(@topfiles, $_);
			}
		elsif (/^(webmin-[0-9\.]+\/([^\/]+))\// && $2 ne ".") {
			# Found a sub-directory, like webmin-1.xx/foo/
			# Keep this, so that we know which modules to extract.
			# Also keep the full directory like webmin-1.xx/foo
			# to avoid treating it as a file.
			$intar{$2}++;
			$tardir{$1}++;
			}
                }
        close(TAR);
        if ($usermin_version) {
                &inst_error(&webmin::text('upgrade_eusermin',$usermin_version));
                }
        if (!$version) {
                if ($hasfile{'module.info'}) {
                        &inst_error(&webmin::text('upgrade_emod', 'index.cgi'));
                        }
                else {
                        &inst_error($webmin::text{'upgrade_etar'});
                        }
                }
	$mode = "";
	}

# Check the signature if possible and if requested
if ($in{'sig'}) {
	# Check the package signature
	($ec, $emsg) = &webmin::gnupg_setup();
	if (!$ec) {
		if ($mode eq 'rpm') {
			# Use rpm's gpg signature verification
			system("rpm --import $webmin::module_root_directory/jcameron-key.asc >/dev/null 2>&1");
			local $out = `rpm --checksig $file 2>&1`;
			if ($?) {
				$ec = 3;
				$emsg = &webmin::text('upgrade_echecksig',
					      "<pre>$out</pre>");
				}
			}
		else {
			# Do a manual signature check
			if ($in{'source'} == 2) {
				# Download the key for this tar.gz
				local ($sigtemp, $sigerror);
				&http_download($webmin::update_host, $webmin::update_port, "/download/sigs/webmin-$version.tar.gz-sig.asc", \$sigtemp, \$sigerror);
				if ($sigerror) {
					$ec = 4;
					$emsg = &webmin::text(
						'upgrade_edownsig', $sigerror);
					}
				else {
					local $data = `cat $file`;
					local ($vc, $vmsg) =
					    &webmin::verify_data(
						$data, $sigtemp);
					if ($vc > 1) {
						$ec = 3;
						$emsg = &webmin::text(
						    "upgrade_everify$vc",
						    &html_escape($vmsg));
						}
					}
				}
			else {
				$emsg = $webmin::text{'upgrade_nosig'};
				}
			}
		}

	# Tell the user about any GnuPG error
	if ($ec) {
		&inst_error($emsg);
		}
	elsif ($emsg) {
		print "$emsg<p>\n";
		}
	else {
		print "$webmin::text{'upgrade_sigok'}<p>\n";
		}
	}
else {
	print "$webmin::text{'upgrade_nocheck'}<p>\n";
	}

# gunzip the file if needed
open(FILE, "<$file");
read(FILE, $two, 2);
close(FILE);
if ($two eq "\037\213") {
	if (!&has_command("gunzip")) {
		&inst_error($webmin::text{'upgrade_egunzip'});
		}
	$newfile = &tempname();
	$out = `gunzip -c $file 2>&1 >$newfile`;
	if ($?) {
		unlink($newfile);
		&inst_error(&webmin::text('upgrade_egzip', "<tt>$out</tt>"));
		}
	unlink($file) if ($need_unlink);
	$need_unlink = 1;
	$file = $newfile;
	}

# Setup error handler for down hosts
sub inst_error_callback
{
$inst_error_msg = join("", @_);
}
&remote_error_setup(\&inst_error_callback);

# Build list of selected hosts
@hosts = &list_webmin_hosts();
@servers = &list_servers();
if ($in{'server'} == -2) {
	# Upgrade servers know to run older versions?
	@hosts = grep { $_->{'version'} < $version } @hosts;
	print "<b>",&text('upgrade_header3', $version),"</b><p>\n";
	}
elsif ($in{'server'} =~ /^group_(.*)/) {
	# Upgrade members of some group
        local ($group) = grep { $_->{'name'} eq $1 }
                              &servers::list_all_groups(\@servers);
        @hosts = grep { local $hid = $_->{'id'};
                        local ($s) = grep { $_->{'id'} == $hid } @servers;
                        &indexof($s->{'host'}, @{$group->{'members'}}) >= 0 }
                      @hosts;
        print "<b>",&text('upgrade_header4', $group->{'name'}),"</b><p>\n";
	}
elsif ($in{'server'} != -1) {
        # Upgrade one host
        @hosts = grep { $_->{'id'} == $in{'server'} } @hosts;
        local ($s) = grep { $_->{'id'} == $hosts[0]->{'id'} } @servers;
        print "<b>",&text('upgrade_header2', &server_name($s)),"</b><p>\n";
        }
else {
	# Upgrading every host
	print "<p><b>",&text('upgrade_header'),"</b><p>\n";
        }

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

		if (!$s->{'fast'} && $s->{'id'} != 0) {
			print $wh &serialise_variable($text{'upgrade_efast'});
			exit;
			}
		&remote_foreign_require($s->{'host'}, "webmin","webmin-lib.pl");
		if ($inst_error_msg) {
			# Failed to contact host ..
			print $wh &serialise_variable($inst_error_msg);
			exit;
			}

		# Check the remote host's version
		local $rver = &remote_foreign_call($s->{'host'}, "webmin",
						   "get_webmin_version");
		if ($version == $rver) {
			print $wh &serialise_variable(
				&webmin::text('upgrade_elatest', $version));
			exit;
			}
		elsif ($version <= $rver) {
			print $wh &serialise_variable(
				&webmin::text('upgrade_eversion', $version));
			exit;
			}

		# Check the install type on the remote host
		local $rmode = &remote_eval($s->{'host'}, "webmin",
		    "chop(\$m = `cat \$root_directory/install-type`); \$m");
		if ($rmode ne $mode) {
			print $wh &serialise_variable(
				&text('upgrade_emode',
				      $text{'upgrade_mode_'.$rmode},
				      $text{'upgrade_mode_'.$mode}));
			exit;
			}

		# Get the file to the server somehow
		local $rfile;
		local $host_need_unlink = 1;
		if (!$s->{'id'}) {
			# This host, so we already have the file
			$rfile = $file;
			$host_need_unlink = 0;
			}
		elsif ($in{'source'} == 0) {
			# Is the file the same on remote? (like if we have NFS)
			local @st = stat($file);
			local $rst = &remote_eval($s->{'host'}, "webmin",
						  "[ stat('$file') ]");
			local @rst = @$rst;
			if (@st && @rst && $st[7] == $rst[7] &&
			    $st[9] == $rst[9]) {
				# File is the same! No need to download
				$rfile = $file;
				$host_need_unlink = 0;
				}
			else {
				# Need to copy the file across :(
				$rfile = &remote_write(
					$s->{'host'}, $file);
				}
			}
		else {
			# Need to copy the file across :(
			$rfile = &remote_write($s->{'host'}, $file);
			}

		# Do the install ..
		if ($mode eq "rpm") {
			# Can just run RPM command
			# XXX doesn't actually check output!
			&remote_eval($s->{'host'}, "webmin", "system(\"rpm --import \$root_directory/webmin/jcameron-key.asc >/dev/null 2>&1\")");
			($out, $ex) = &remote_eval($s->{'host'}, "webmin", "\$out = `rpm -U --ignoreos --ignorearch --nodeps '$rfile' >/dev/null 2>&1 </dev/null`; (\$out, \$?)");
			&remote_eval($s->{'host'}, "webmin", "unlink('$rfile')")
				if ($host_need_unlink);
			if ($ex) {
				print $wh &serialise_variable(
					"<pre>$out</pre>");
				exit;
				}
			}
		elsif ($mode eq "deb") {
			# Can just run dpkg command
			($out, $ex) = &remote_eval($s->{'host'}, "webmin", "\$out = `dpkg --install '$rfile' >/dev/null 2>&1 </dev/null`; (\$out, \$?)");
			&remote_eval($s->{'host'}, "webmin", "unlink('$rfile')")
				if ($host_need_unlink);
			if ($ex) {
				print $wh &serialise_variable(
					"<pre>$out</pre>");
				exit;
				}
			}
		else {
			# Get the original install directory
			local $rdir = &remote_eval($s->{'host'}, "webmin",
		    		"chop(\$d = `cat \$config_directory/install-dir 2>/dev/null`); \$d");
			if ($rdir) {
				# Extract tar.gz in temporary location first
				$extract = &remote_foreign_call($s->{'host'}, "webmin", "tempname");
				&remote_eval($s->{'host'}, "webmin", "mkdir('$extract', 0755)");
				}
			else {
				# Extract next to original dir
				$oldroot = &remote_eval($s->{'host'}, "webmin", "\$root_directory");
				$extract = "$oldroot/..";
				}

			if ($in{'only'}) {
				# Extract only root files and modules that we
				# already have
				$topfiles = join(" ", map { quotemeta($_) }
					 grep { !$tardir{$_} } @topfiles);
				local ($out, $ex) = &remote_eval($s->{'host'}, "webmin", "\$out = `cd '$extract' ; tar xf '$rfile' $topfiles 2>&1 >/dev/null`; (\$out, \$?)");
				if ($ex) {
					print $wh &serialise_variable(
						"<pre>$out</pre>");
					exit;
					}
				@mods = grep { $intar{$_} } map { $_->{'dir'} }
					&remote_foreign_call($s->{'host'},
					  "webmin", "get_all_module_infos", 1);
				                opendir(DIR, $root_directory);
				foreach $d (readdir(DIR)) {
					next if ($d =~ /^\./);
					local $p = "$root_directory/$d";
					if (-d $p && !-r "$p/module.info" &&
					    $intar{$d}) {
						push(@mods, $d);
						}
					}
				closedir(DIR);
				$mods = join(" ",
					 map { quotemeta("webmin-$version/$_") }
					 @mods);
				local ($out, $ex) = &remote_eval($s->{'host'}, "webmin", "\$out = `cd '$extract' ; tar xf '$rfile' $mods 2>&1 >/dev/null`; (\$out, \$?)");
				}
			else {
				# Unpack the whole tar file
				local ($out, $ex) = &remote_eval($s->{'host'}, "webmin", "\$out = `cd '$extract' ; tar xf '$rfile' 2>&1 >/dev/null`; (\$out, \$?)");
				}
			if ($ex) {
				print $wh &serialise_variable(
					"<pre>$out</pre>");
				exit;
				}

			# Delete the original tar.gz
			&remote_eval($s->{'host'}, "webmin", "unlink('$rfile')")
				if ($host_need_unlink);

			# Run setup.sh in the extracted directory
			$setup = $rdir ? "./setup.sh '$rdir'" : "./setup.sh";
			($out, $ex) = &remote_eval($s->{'host'}, "webmin",
				"\$SIG{'TERM'} = 'IGNORE';
				 \$ENV{'config_dir'} = \$config_directory;
				 \$ENV{'webmin_upgrade'} = 1;
				 \$ENV{'autothird'} = 1;
				 \$out = `(cd $extract/webmin-$version && $setup) </dev/null 2>&1 | tee /tmp/.webmin/webmin-setup.out`;
				 (\$out, \$?)");
			if ($ex || $out !~ /success|^0$/i) {
				print $wh &serialise_variable(
					"<pre>$out</pre>");
				exit;
				}
			if ($rdir) {
				# Can delete the temporary source directory
				&remote_eval($s->{'host'}, "webmin",
					     "system(\"rm -rf \'$extract\'\")");
				}
			elsif ($in{'delete'}) {
				# Can delete the old root directory
				&remote_eval($s->{'host'}, "webmin",
					     "system(\"rm -rf \'$oldroot\'\")");
				}
			}

		# Force an RPC re-connect to new version
		&remote_finished();
		&remote_foreign_require($s->{'host'}, "webmin","webmin-lib.pl");
		if ($inst_error_msg) {
			# Failed to contact host ..
			print $wh &serialise_variable(
				&text('upgrade_ereconn', $inst_error_msg));
			exit;
			}
		&remote_foreign_require($s->{'host'}, "acl", "acl-lib.pl");

		# Update local version number and module lists
		$h->{'version'} = $version;
		local @mods = &remote_foreign_call($s->{'host'},
				"webmin", "get_all_module_infos", 1);
		@mods = grep { !$_->{'clone'} } @mods;
		$h->{'modules'} = \@mods;
		local @themes = &remote_foreign_call($s->{'host'},
				 "webmin", "list_themes");
		$h->{'themes'} = \@themes;
		local @users = &remote_foreign_call($s->{'host'},
				"acl", "list_users");
		$h->{'users'} = \@users;
		local @groups = &remote_foreign_call($s->{'host'},
				"acl", "list_groups");
		$h->{'groups'} = \@groups;
		&save_webmin_host($h);

		print $wh &serialise_variable("");
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
		print &text('upgrade_failed', $d, "Unknown reason"),"<br>\n";
		}
	elsif ($rv) {
		print &text('upgrade_failed', $d, $rv),"<br>\n";
		}
	else {
		print &text('upgrade_ok',
			    $text{'upgrade_mode_'.$mode}, $d),"<br>\n";
		}
	$p++;
	}
unlink($file) if ($need_unlink);
print "<p><b>$text{'upgrade_done'}</b><p>\n";

&remote_finished();
&ui_print_footer("", $text{'index_return'});

sub inst_error
{
unlink($file) if ($need_unlink);
print "<br><b>$main::whatfailed : $_[0]</b> <p>\n";
&ui_print_footer("", $text{'index_return'});
exit;
}

