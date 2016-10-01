#!/usr/local/bin/perl
# upgrade.cgi
# Upgrade usermin if possible

require './usermin-lib.pl';
$access{'upgrade'} || &error($text{'acl_ecannot'});
&foreign_require("proc", "proc-lib.pl");
if ($ENV{'CONTENT_TYPE'} =~ /boundary=/) {
	&ReadParseMime();
	}
else {
	&ReadParse();
	}
&get_usermin_miniserv_config(\%miniserv);

&ui_print_unbuffered_header(undef, $in{'install'} ? $text{'upgrade_title2'} : $text{'upgrade_title'}, "");

if ($in{'source'} == 0) {
	# from local file
	&error_setup(&text('upgrade_err1', $in{'file'}));
	$file = $in{'file'};
	if (!(-r $file)) { &inst_error($text{'upgrade_efile'}); }
	}
elsif ($in{'source'} == 1) {
	# from uploaded file
	&error_setup($text{'upgrade_err2'});
	$file = &transname();
	$need_unlink = 1;
	if ($no_upload) {
                &inst_error($text{'upgrade_ebrowser'});
                }
	&open_tempfile(MOD, ">$file", 0, 1);
	&print_tempfile(MOD, $in{'upload'});
	&close_tempfile(MOD);
	}
elsif ($in{'source'} == 2) {
	# find latest version at www.webmin.com by looking at index page
	&error_setup($text{'upgrade_err3'});
	$file = &transname();
	&http_download('www.webmin.com', 80, '/index6.html', $file, \$error);
	$error && &inst_error($error);
	open(FILE, $file);
	while(<FILE>) {
		if (/usermin-([0-9\.]+)\.tar\.gz/) {
			$version = $1;
			last;
			}
		}
	close(FILE);
	unlink($file);
	if (!$in{'force'}) {
		if ($version == &get_usermin_version()) {
			&inst_error(&text('upgrade_elatest', $version));
			}
		elsif ($version <= &get_usermin_version()) {
			&inst_error(&text('upgrade_eversion', $version));
			}
		}

	# Work out the current Usermin type (webmail or regular)
	$product = "usermin";
	if (&has_command("rpm") && $in{'mode'} eq 'rpm' &&
	    &execute_command("rpm -q usermin-webmail") == 0) {
		$product = "usermin-webmail";
		}
	elsif (&has_command("dpkg") && $in{'mode'} eq 'deb' &&
	       &execute_command("dpkg --list usermin-webmail") == 0) {
		$product = "usermin-webmail";
		}

	if ($in{'mode'} eq 'rpm') {
		$progress_callback_url = &convert_osdn_url(
		    "http://$webmin::osdn_host/webadmin/${product}-${version}-1.noarch.rpm");
		}
	elsif ($in{'mode'} eq 'deb') {
		$progress_callback_url = &convert_osdn_url(
		    "http://$webmin::osdn_host/webadmin/${product}_${version}_all.deb");
		}
	else {
		$progress_callback_url = &convert_osdn_url(
		    "http://$webmin::osdn_host/webadmin/${product}-${version}.tar.gz");
		}
	($host, $port, $page, $ssl) = &parse_http_url($progress_callback_url);
	&http_download($host, $port, $page, $file, \$error,
		       \&progress_callback, $ssl);
	$error && &inst_error($error);
	$need_unlink = 1;
	}
elsif ($in{'source'} == 5) {
	# Download from some URL
	&error_setup(&text('upgrade_err5', $in{'url'}));
	$file = &transname();
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
	else { &inst_error($text{'upgrade_eurl'}); }
	$need_unlink = 1;
	$error && &inst_error($error);
	}
$qfile = quotemeta($file);

# gunzip the file if needed
open(FILE, $file);
read(FILE, $two, 2);
close(FILE);
if ($two eq "\037\213") {
	if (!&has_command("gunzip")) {
		&inst_error($text{'upgrade_egunzip'});
		}
	$newfile = &transname();
	$out = `gunzip -c $file 2>&1 >$newfile`;
	if ($?) {
		unlink($newfile);
		&inst_error(&text('upgrade_egzip', "<tt>$out</tt>"));
		}
	unlink($file) if ($need_unlink);
	$need_unlink = 1;
	$file = $newfile;
	}
$qfile = quotemeta($file);

# Get list of updates
$updatestemp = &transname();
&http_download($update_host, $update_port, $update_page, $updatestemp,
               \$updates_error);

if ($in{'mode'} eq 'rpm') {
	# Check if it is an RPM package
	$out = `rpm -qp $qfile`;
	$out =~ /^usermin-(\d+\.\d+)/ ||
	    $out =~ /^usermin-webmail-(\d+\.\d+)/ ||
		&inst_error($text{'upgrade_erpm'});
	$version = $1;
	if ($version <= &get_usermin_version() && !$in{'force'}) {
		&inst_error(&text('upgrade_eversion', $version));
		}

	# Install the RPM
	if ($in{'force'}) {
		$cmd = "rpm -U --force --nodeps $qfile";
		}
	else {
		$cmd = "rpm -U --ignoreos --ignorearch --nodeps $qfile";
		}
	print "<p>",&text($in{'install'} ? 'upgrade_setup2' : 'upgrade_setup',
			  "<tt>$cmd</tt>"),"<br>\n";
	print "<pre>";
	&proc::safe_process_exec($cmd, 0, 0, STDOUT, undef, 1);
	print "</pre>";
	unlink($file) if ($need_unlink);
	}
elsif ($in{'mode'} eq 'deb') {
	# Check if it is a Debian package
	$out = `dpkg --info $qfile`;
	$out =~ /Package:\s+(\S+)/ &&
	    ($1 eq "usermin" || $1 eq "usermin-webmail") ||
		&inst_error($text{'upgrade_edeb'});
	$out =~ /Version:\s+(\S+)/ ||
		&inst_error($text{'upgrade_edeb'});
	$version = $1;
	if ($version <= &get_usermin_version() && !$in{'force'}) {
		&inst_error(&text('upgrade_eversion', $version));
		}

	# Install the package
	$cmd = "dpkg --install $qfile";
	print "<p>",&text($in{'install'} ? 'upgrade_setup2' : 'upgrade_setup',
			  "<tt>$cmd</tt>"),"<br>\n";
	print "<pre>";
	&proc::safe_process_exec($cmd, 0, 0, STDOUT, undef, 1);
	print "</pre>";
	unlink($file) if ($need_unlink);
	}
else {
	# Check if it is a usermin tarfile
	open(TAR, "tar tf $file 2>&1 |");
	while(<TAR>) {
		if (/^usermin-([0-9\.]+)\//) {
			$version = $1;
			}
		if (/^webmin-([0-9\.]+)\//) {
			$webmin_version = $1;
			}
		if (/^[^\/]+\/(\S+)$/) {
			$hasfile{$1}++;
			}
		}
	close(TAR);
	if ($webmin_version) {
		&inst_error(&text('upgrade_ewebmin', $webmin_version));
		}
	if (!$version) {
		if ($hasfile{'module.info'}) {
			&inst_error(&text('upgrade_emod', 'edit_mods.cgi'));
			}
		else {
			&inst_error($text{'upgrade_etar'});
			}
		}
	if (!$in{'force'}) {
		if ($version <= &get_usermin_version()) {
			&inst_error(&text('upgrade_eversion', $version));
			}
		}

	$| = 1;
	local $cmd;
	if ($in{'install'}) {
		# Installing .. extract it in /usr/local and run setup.sh
		local $root = "/usr/local";
		mkdir($root, 0755);
		$out = `cd $root ; tar xf $file 2>&1 >/dev/null`;
		if ($?) {
			&inst_error(&text('upgrade_euntar', "<tt>$out</tt>"));
			}
		unlink($file) if ($need_unlink);
		$ENV{'config_dir'} = $standard_usermin_dir;
		$ENV{'var_dir'} = "/var/usermin";
		$perl = &get_perl_path();
		$ENV{'perl'} = $perl;
		$ENV{'autoos'} = 3;
		$ENV{'port'} = 20000;
		$ENV{'ssl'} = 1;
		$ENV{'os_type'} = $gconfig{'os_type'};
		$ENV{'os_version'} = $gconfig{'os_version'};
		$ENV{'real_os_type'} = $gconfig{'real_os_type'};
		$ENV{'real_os_version'} = $gconfig{'real_os_version'};
		$cmd = "(cd $root/usermin-$version && ./setup.sh)";
		print "<p>",&text('upgrade_setup2', "<tt>setup.sh</tt>"),"<br>\n";
		}
	else {
		# Upgrading .. work out where to extract
		if ($in{'dir'}) {
			# Since we are currently installed in a fixed directory,
			# just extract to a temporary location
			$extract = &transname();
			mkdir($extract, 0755);
			}
		else {
			# Next to the current directory
			$extract = "$miniserv{'root'}/..";
			}

		# Extract it next to the current directory and run setup.sh
		$out = `cd $extract ; tar xf $file 2>&1 >/dev/null`;
		if ($?) {
			&inst_error(&text('upgrade_euntar', "<tt>$out</tt>"));
			}
		unlink($file) if ($need_unlink);
		$ENV{'config_dir'} = $config{'usermin_dir'};
		$ENV{'webmin_upgrade'} = 1;
		$ENV{'autothird'} = 1;
		$setup = $in{'dir'} ? "./setup.sh '$in{'dir'}'" : "./setup.sh";
		if ($in{'delete'}) {
			$ENV{'deletedold'} = 1;
			$cmd = "(cd $extract/usermin-$version && $setup && rm -rf \"$miniserv{'root'}\")";
			}
		else {
			$cmd = "(cd $extract/usermin-$version && $setup)";
			}
		print "<p>",&text('upgrade_setup', "<tt>setup.sh</tt>"),"<br>\n";
		}
	print "<pre>";
	&proc::safe_process_exec($cmd, 0, 0, STDOUT, undef, 1);
	print "</pre>";
	if ($in{'dir'}) {
		# Can delete the temporary source directory
		system("rm -rf \"$extract\"");
		}
	}

# Notify Webmin that this module might now be usable
&foreign_require("webmin", "webmin-lib.pl");
($inst, $changed) = &webmin::build_installed_modules(0, 'usermin');
if (@$changed && defined(&theme_post_change_modules)) {
	&theme_post_change_modules();
	}

&webmin_log($in{'install'} ? "uinstall" : "upgrade", undef, undef,
	    { 'version' => $version, 'mode' => $in{'mode'} });

# Find out about any updates for this new version.
if ($updates_error) {
        print "<br>",&text('upgrade_eupdates', $updates_error),"<p>\n";
        }
else {
        open(UPDATES, $updatestemp);
        while(<UPDATES>) {
                if (/^([^\t]+)\t+([^\t]+)\t+([^\t]+)\t+([^\t]+)\t+(.*)/) {
                        push(@updates, [ $1, $2, $3, $4, $5 ]);
                        }
                }
        close(UPDATES);
        unlink($updatestemp);
        $bversion = &base_version($version);
        foreach $u (@updates) {
                next if ($u->[1] >= $bversion + .01 || $u->[1] <= $bversion ||
			 $u->[1] <= $version);
                local $osinfo = { 'os_support' => $u->[3] };
                next if (!&check_usermin_os_support($osinfo));
                $ucount++;
                }
        if ($ucount) {
                print "<br>",&text('upgrade_updates', $ucount,
                        "update.cgi?source=0&show=0&missing=0"),"<p>\n";
                }
        }

&ui_print_footer("", $text{'index_return'});

sub inst_error
{
unlink($file) if ($need_unlink);
&error($_[0]);
exit;
}

