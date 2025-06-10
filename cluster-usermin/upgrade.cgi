#!/usr/local/bin/perl
# upgrade.cgi
# Download usermin and upgrade all managed servers of compatible types

require './cluster-usermin-lib.pl';
&foreign_require("proc", "proc-lib.pl");
&foreign_require("webmin", "webmin-lib.pl");
&foreign_require("webmin", "gnupg-lib.pl");
&ReadParseMime();

&ui_print_unbuffered_header(undef, $text{'upgrade_title'}, "");

# Save this CGI from being killed by the upgrade
$SIG{'TERM'} = 'IGNORE';

if ($in{'source'} == 0) {
	# from local file
	&error_setup(&usermin::text('upgrade_err1', $in{'file'}));
	$file = $in{'file'};
	if (!(-r $file)) { &inst_error($usermin::text{'upgrade_efile'}); }
	}
elsif ($in{'source'} == 1) {
	# from uploaded file
	&error_setup($usermin::text{'upgrade_err2'});
	$file = &tempname();
	$need_unlink = 1;
	if ($no_upload) {
                &inst_error($usermin::text{'upgrade_ebrowser'});
                }
	open(MOD, ">$file");
	print MOD $in{'upload'};
	close(MOD);
	}
elsif ($in{'source'} == 2) {
	# find latest version at www.usermin.com by looking at index page
	&error_setup($usermin::text{'upgrade_err3'});
	$file = &tempname();
	&http_download($usermin::update_host, $usermin::update_port, '/index6.html', $file, \$error);
	$error && &inst_error($error);
	open(FILE, "<$file");
	while(<FILE>) {
		if (/usermin-([0-9\.]+)\.tar\.gz/) {
			$site_version = $1;
			last;
			}
		}
	close(FILE);
	unlink($file);
	if ($in{'mode'} eq 'rpm') {
		$progress_callback_url = "http://$usermin::update_host/download/rpm/usermin-${site_version}-1.noarch.rpm";
		&http_download($usermin::update_host, $usermin::update_port,
		  "/download/rpm/usermin-${site_version}-1.noarch.rpm", $file,
		  \$error, \&progress_callback);
		}
	elsif ($in{'mode'} eq 'deb') {
		$progress_callback_url = "http://$usermin::update_host/download/deb/usermin_${site_version}_all.deb";
		&http_download($usermin::update_host, $usermin::update_port,
		  "/download/deb/usermin_${site_version}_all.deb", $file,
		  \$error, \&progress_callback);
		}
	else {
		$progress_callback_url = "http://$usermin::update_host/download/usermin-${site_version}.tar.gz";
		&http_download($usermin::update_host, $usermin::update_port,
		  "/download/usermin-${site_version}.tar.gz", $file,
		  \$error, \&progress_callback);
		}
	$error && &inst_error($error);
	$need_unlink = 1;
	}
elsif ($in{'source'} == 5) {
	# Download from some URL
	&error_setup(&usermin::text('upgrade_err5', $in{'url'}));
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
	else { &inst_error($usermin::text{'upgrade_eurl'}); }
	$need_unlink = 1;
	$error && &inst_error($error);
	}

# Work out what kind of file we have (RPM or tar.gz)
if (`rpm -qp $file 2>&1` =~ /(^|\n)usermin-(\d+\.\d+)/) {
	# Looks like a usermin RPM
	$mode = "rpm";
	$version = $2;
	}
elsif (`dpkg --info $file 2>&1` =~ /Package:\s+usermin\n\s*Version:\s+(\d+\.\d+)/) {
        # Looks like a Usermin Debian package
        $mode = "deb";
        $version = $2;
        }
else {
        # Check if it is a usermin tar.gz file
        open(TAR, "gunzip -c $file | tar tf - 2>&1 |");
        while(<TAR>) {
                s/\r|\n//g;
                if (/^usermin-([0-9\.]+)\//) {
                        $version = $1;
                        }
                if (/^webmin-([0-9\.]+)\//) {
                        $webmin_version = $1;
                        }
                if (/^[^\/]+\/(\S+)$/) {
                        $hasfile{$1}++;
                        }
                if (/^(usermin-([0-9\.]+)\/[^\/]+)$/) {
                        push(@topfiles, $1);
                        }
                elsif (/^usermin-[0-9\.]+\/([^\/]+)\//) {
                        $intar{$1}++;
                        }
                }
        close(TAR);
        if ($webmin_version) {
                &inst_error(&usermin::text('upgrade_ewebmin',
					   $webmin_version));
                }
        if (!$version) {
                if ($hasfile{'module.info'}) {
                        &inst_error(&usermin::text('upgrade_emod', 'index.cgi'));
                        }
                else {
                        &inst_error($usermin::text{'upgrade_etar'});
                        }
                }
	$mode = "";
	}

# gunzip the file if needed
open(FILE, "<$file");
read(FILE, $two, 2);
close(FILE);
if ($two eq "\037\213") {
	if (!&has_command("gunzip")) {
		&inst_error($usermin::text{'upgrade_egunzip'});
		}
	$newfile = &tempname();
	$out = `gunzip -c $file 2>&1 >$newfile`;
	if ($?) {
		unlink($newfile);
		&inst_error(&usermin::text('upgrade_egzip', "<tt>$out</tt>"));
		}
	unlink($file) if ($need_unlink);
	$need_unlink = 1;
	$file = $newfile;
	}

# Setup error handler for down hosts
sub inst_error
{
$inst_error_msg = join("", @_);
}
&remote_error_setup(\&inst_error);

# Build list of selected hosts
@hosts = &list_usermin_hosts();
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
		&remote_foreign_require($s->{'host'}, "usermin",
						      "usermin-lib.pl");
		if ($inst_error_msg) {
			# Failed to contact host ..
			print $wh &serialise_variable($inst_error_msg);
			exit;
			}

		# Check the remote host's version
		local $rver = &remote_foreign_call($s->{'host'}, "usermin",
						   "get_usermin_version");
		if ($version == $rver) {
			print $wh &serialise_variable(
				&usermin::text('upgrade_elatest', $version));
			exit;
			}
		elsif ($version <= $rver) {
			print $wh &serialise_variable(
				&usermin::text('upgrade_eversion', $version));
			exit;
			}

		# Check the install type on the remote host
		local $rmode = &remote_eval($s->{'host'}, "usermin",
		    "&get_usermin_miniserv_config(\\\%miniserv); chop(\$m = `cat \$miniserv{'root'}/install-type`); \$m");
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
			local $rst = &remote_eval($s->{'host'}, "usermin",
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
			&remote_eval($s->{'host'}, "usermin", "system(\"rpm --import \$root_directory/webmin/jcameron-key.asc >/dev/null 2>&1\")");
			($out, $ex) = &remote_eval($s->{'host'}, "usermin", "\$out = `rpm -U --ignoreos --ignorearch '$rfile' >/dev/null 2>&1 </dev/null`; (\$out, \$?)");
			&remote_eval($s->{'host'}, "usermin",
				     "unlink('$rfile')")
				if ($host_need_unlink);
			if ($ex) {
				print $wh &serialise_variable(
					"<pre>$out</pre>");
				exit;
				}
			}
                elsif ($mode eq "deb") {
                        # Can just run dpkg command
                        ($out, $ex) = &remote_eval($s->{'host'}, "usermin", "\$out = `dpkg --install '$rfile' >/dev/null 2>&1 </dev/null`; (\$out, \$?)");
                        &remote_eval($s->{'host'}, "usermin","unlink('$rfile')")
                                if ($host_need_unlink);
                        if ($ex) {
                                print $wh &serialise_variable(
                                        "<pre>$out</pre>");
                                exit;
                                }
                        }
		else {
			# Get the original install directory
			local $rdir = &remote_eval($s->{'host'}, "usermin",
			    "chop(\$m = `cat \$config{'usermin_dir'}/install-dir`); \$m");
			if ($rdir) {
				# Extract tar.gz in temporary location first
				$extract = &remote_foreign_call($s->{'host'}, "usermin", "tempname");
				&remote_eval($s->{'host'}, "usermin", "mkdir('$extract', 0755)");
				}
			else {
				# Extract next to original dir
				$oldroot = &remote_eval($s->{'host'}, "usermin", "\$root_directory");
				$extract = "$oldroot/..";
				}

			# Actually unpack the tar file
			local ($out, $ex) = &remote_eval($s->{'host'}, "usermin", "\$out = `cd '$extract' ; tar xf '$rfile' 2>&1 >/dev/null`; (\$out, \$?)");
			if ($ex) {
				print $wh &serialise_variable(
					"<pre>$out</pre>");
				exit;
				}

			# Delete the original tar.gz
			&remote_eval($s->{'host'}, "usermin", "unlink('$rfile')")
				if ($host_need_unlink);

			# Run setup.sh in the extracted directory
			$setup = $rdir ? "./setup.sh '$rdir'" : "./setup.sh";
			($out, $ex) = &remote_eval($s->{'host'}, "usermin",
				"\$SIG{'TERM'} = 'IGNORE';
				 \$ENV{'config_dir'} = \$config{'usermin_dir'};
				 \$ENV{'webmin_upgrade'} = 1;
				 \$ENV{'autothird'} = 1;
				 \$out = `(cd $extract/usermin-$version && $setup) </dev/null 2>&1 | tee /tmp/.webmin/usermin-setup.out`;
				 (\$out, \$?)");
			if ($out !~ /success/i) {
				print $wh &serialise_variable(
					"<pre>$out</pre>");
				exit;
				}
			if ($rdir) {
				# Can delete the temporary source directory
				&remote_eval($s->{'host'}, "usermin",
					     "system(\"rm -rf \'$extract\'\")");
				}
			elsif ($in{'delete'}) {
				# Can delete the old root directory
				&remote_eval($s->{'host'}, "usermin",
					     "system(\"rm -rf \'$oldroot\'\")");
				}
			}

		# Force an RPC re-connect to new version
		&remote_finished();
		&remote_foreign_require($s->{'host'}, "usermin",
					"usermin-lib.pl");
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
				"usermin", "list_modules");
		@mods = grep { !$_->{'clone'} } @mods;
		$h->{'modules'} = \@mods;
		local @themes = &remote_foreign_call($s->{'host'},
				 "usermin", "list_themes");
		$h->{'themes'} = \@themes;
		&save_usermin_host($h);

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
print "<br><b>$whatfailed : $_[0]</b> <p>\n";
&ui_print_footer("", $text{'index_return'});
exit;
}

