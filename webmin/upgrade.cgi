#!/usr/local/bin/perl
# upgrade.cgi
# Upgrade webmin if possible

require './webmin-lib.pl';
&foreign_require("proc", "proc-lib.pl");
&foreign_require("acl", "acl-lib.pl");
if ($ENV{'REQUEST_METHOD'} eq 'GET') {
	&ReadParse();
	}
else {
	&ReadParseMime();
	}

if ($in{'source'} == 3) {
	# Get the latest version from Caldera with cupdate
	&redirect("/cupdate/");
	return;
	}
elsif ($in{'source'} == 6) {
	# Upgrade from package repository
	&redirect("/package-updates/update.cgi?u=webmin");
	return;
	}

$| = 1;
$theme_no_table = 1;
&ui_print_header(undef, $text{'upgrade_title'}, "");

# Do we have an install dir?
my $indir = $in{'dir'};

# Is this a minimal install?
my $mini_type;

if (!$indir) {
	my $install_dir = "$config_directory/install-dir";
	if (-e $install_dir) {
		$indir = &read_file_contents($install_dir);
		$indir = &trim($indir);
		$mini_type = -r "$indir/minimal-install" ? "-minimal" : "";
		$indir = undef if (!-d $indir);
		}
	}

# Save this CGI from being killed by the upgrade
$SIG{'TERM'} = 'IGNORE';

if ($in{'source'} == 0) {
	# from local file
	&error_setup(&text('upgrade_err1', $in{'file'}));
	$file = $in{'file'};
	if (!-r $file) { &inst_error($text{'upgrade_efile'}); }
	if ($file =~ /webmin-(\d+\.\d+)(\-(\d+))?/) {
		$version = $1;
		$release = $3;
		$full = $version.($release ? "-$release" : "");
		}
	if (!$in{'force'}) {
		&check_inst_version($full);
		}
	}
elsif ($in{'source'} == 1) {
	# from uploaded file
	&error_setup($text{'upgrade_err2'});
	$file = &transname();
	$need_unlink = 1;
	if ($no_upload) {
                &inst_error($text{'upgrade_ebrowser'});
                }
	open(MOD, ">$file");
	print MOD $in{'upload'};
	close(MOD);
	if ($in{'upload_filename'} =~ /webmin-(\d+\.\d+)(\-(\d+))?/) {
		$version = $1;
		$release = $3;
		$full = $version.($release ? "-$release" : "");
		}
	}
elsif ($in{'source'} == 2) {
	# find latest version at www.webmin.com by looking at index page
	&error_setup($text{'upgrade_err3'});
	($ok, $version, $release) = &get_latest_webmin_version();
	$ok || &inst_error($version);
	$full = $version.($release ? "-$release" : "");
	if (!$in{'force'}) {
		# Is the new version and release actually newer
		&check_inst_version($full);
		}
	my $sfx;
	if ($in{'mode'} eq 'rpm') {
		# Downloading RPM
		$release ||= 1;
		$progress_callback_url = &convert_osdn_url(
		    "http://$osdn_host/webadmin/newkey-webmin-${version}-${release}.noarch.rpm");
		$sfx = ".rpm";
		}
	elsif ($in{'mode'} eq 'deb') {
		# Downloading Debian package
		$release = $release ? "-".$release : "";
		$progress_callback_url = &convert_osdn_url(
		    "http://$osdn_host/webadmin/newkey-webmin_${version}${release}_all.deb");
		$sfx = ".deb";
		}
	elsif ($in{'mode'} eq 'solaris-pkg') {
		# Downloading my Solaris package
		$release = $release ? "-".$release : "";
		$progress_callback_url = &convert_osdn_url(
		    "http://$osdn_host/webadmin/webmin-${version}${release}.pkg.gz");
		$sfx = ".pkg";
		}
	else {
		# Downloading tar.gz file
		$release = $release ? "-".$release : "";
		$progress_callback_url = &convert_osdn_url(
			"http://$osdn_host/webadmin/webmin-${version}${release}${mini_type}.tar.gz");
		$sfx = ".tar.gz";
		}
	($host, $port, $page, $ssl) = &parse_http_url($progress_callback_url);
	$file = &transname().$sfx;
	&http_download($host, $port, $page, $file, \$error,
		       \&progress_callback, $ssl);
	$error && &inst_error($error);
	$need_unlink = 1;
	}
elsif ($in{'source'} == 5) {
	# Download from some URL
	&error_setup(&text('upgrade_err5', $in{'url'}));
	$file = &transname();
	$in{'url'} = &convert_osdn_url($in{'url'});
	$progress_callback_url = $in{'url'};
	if ($in{'url'} =~ /(\.(deb|rpm|pkg|tar.gz))$/i) {
		$file .= $1;
		}
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
	if ($in{'url'} =~ /webmin-(\d+\.\d+)(\-(\d+))?/) {
		$version = $1;
		$release = $3;
		$full = $version.($release ? "-$release" : "");
		}
	}
elsif ($in{'source'} == 4) {
	# Just run the command  emerge webmin
	&error_setup(&text('upgrade_err4'));
	$file = "webmin";
	$need_unlink = 0;
	}
$qfile = quotemeta($file);

# Import the signature for RPM
if ($in{'mode'} eq 'rpm') {
	system("rpm --import $module_root_directory/jcameron-key.asc >/dev/null 2>&1");
	system("rpm --import $module_root_directory/developers-key.asc >/dev/null 2>&1");
	}

# Check the signature if possible
if ($in{'sig'}) {
	# Check the package signature
	($ec, $emsg) = &gnupg_setup();
	if (!$ec) {
		if ($in{'mode'} eq 'rpm') {
			# Use rpm's gpg signature verification
			my $out = &backquote_command(
					"rpm --checksig $qfile 2>&1");
			if ($?) {
				$ec = 3;
				$emsg = &text('upgrade_echecksig',
					      "<pre>$out</pre>");
				}
			}
		else {
			# Do a manual signature check
			if ($in{'source'} == 2) {
				# Download the key for this tar.gz
				my ($sigtemp, $sigerror);
				&http_download($update_host, $update_port, "/download/sigs/webmin-${full}${mini_type}.tar.gz-sig.asc", \$sigtemp, \$sigerror);
				if ($sigerror) {
					$ec = 4;
					$emsg = &text('upgrade_edownsig',
						      $sigerror);
					}
				else {
					my $data = &read_file_contents($file);
					my ($vc, $vmsg) =
					    &verify_data($data, $sigtemp);
					if ($vc > 1) {
						$ec = 3;
						$emsg = &text(
						    "upgrade_everify$vc",
						    &html_escape($vmsg));
						}
					}
				}
			else {
				$emsg = $text{'upgrade_nosig'};
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
		print "<p></p>$text{'upgrade_sigok'}<p>\n";
		}
	}
else {
	print "$text{'upgrade_nocheck'}<p>\n";
	}

if ($in{'mode'} ne 'gentoo') {
	# gunzip the file if needed
	open(FILE, "<$file");
	read(FILE, $two, 2);
	close(FILE);
	if ($two eq "\037\213") {
		if (!&has_command("gunzip")) {
			&inst_error($text{'upgrade_egunzip'});
			}
		$newfile = &transname();
		$out = &backquote_command("gunzip -c $qfile 2>&1 >$newfile");
		if ($?) {
			unlink($newfile);
			&inst_error(&text('upgrade_egzip', "<tt>$out</tt>"));
			}
		unlink($file) if ($need_unlink);
		$need_unlink = 1;
		$file = $newfile;
		}
	}
$qfile = quotemeta($file);

if ($in{'mode'} eq 'rpm') {
	# Check if it is an RPM package
	$rpmname = "webmin";
	if (open(RPM, "<$root_directory/rpm-name")) {
		chop($rpmname = <RPM>);
		close(RPM);
		}
	$out = &backquote_command("rpm -qp $qfile");
	$out =~ /(^|\n)\Q$rpmname\E-(\d+\.\d+)-(\d+)/ ||
	        /(^|\n)\Q$rpmname\E-(\d+\.\d+)/ ||
		&inst_error($text{'upgrade_erpm'});
	$version = $2;
	$release = $3;
	$full = $version.($release ? "-$release" : "");
	if (!$in{'force'}) {
		# Is the new version and release actually newer
		&check_inst_version($full);
		}

	# Install the RPM
	$ENV{'tempdir'} = $gconfig{'tempdir'};
	print "<p>",$text{'upgrade_setuprpm'},"<p>\n";
	print "<pre>";
	if ($in{'force'}) {
		&proc::safe_process_exec(
			"rpm -Uv --force --nodeps $qfile", 0, 0,
			STDOUT, undef, 1, 1);
		}
	else {
		&proc::safe_process_exec(
			"rpm -Uv --ignoreos --ignorearch --nodeps $qfile", 0, 0,
			STDOUT, undef, 1, 1);
		}
	unlink($file) if ($need_unlink);
	print "</pre>\n";
	}
elsif ($in{'mode'} eq 'deb') {
	# Check if it is a Debian package
	$debname = "webmin";
	if (open(RPM, "<$root_directory/deb-name")) {
		chop($debname = <RPM>);
		close(RPM);
		}
	$out = &backquote_command("dpkg --info $qfile");
	$out =~ /Package:\s+(\S+)/ && $1 eq $debname ||
		&inst_error($text{'upgrade_edeb'});
	$out =~ /Version:\s+(\S+)/ ||
		&inst_error($text{'upgrade_edeb'});
	$full = $1;
	($version, $release) = split(/\-/, $full);
	if (!$in{'force'}) {
		&check_inst_version($full);
		}

	# Install the package
	$ENV{'tempdir'} = $gconfig{'tempdir'};
	print "<p>",$text{'upgrade_setupdeb'},"<p>\n";
	print "<pre>";
	$ENV{'DEBIAN_FRONTEND'} = 'noninteractive';
	my $cmd = "dpkg --install --force-depends $qfile";
	if (&has_command("apt-get")) {
		$cmd = "apt-get install $qfile || $cmd";
		}
	&proc::safe_process_exec($cmd, 0, 0, STDOUT, undef, 1, 1);
	unlink($file) if ($need_unlink);
	print "</pre>\n";
	}
elsif ($in{'mode'} eq 'solaris-pkg' || $in{'mode'} eq 'sun-pkg') {
	# Check if it is a solaris package
	&foreign_require("software", "software-lib.pl");
	&foreign_call("software", "is_package", $file) ||
		&inst_error($text{'upgrade_epackage'});
	my @p = &foreign_call("software", "file_packages", $file);
	#
	# The package name will always include "webmin" in lower case,
	# but may be preceded by the source package source ("WS" for the
	# Webmin.com package, "SUNW" for the Sun distributed package).
	# and it could have trailing characters to define a set of items
	# that are installed separately ("r" for the Sun "root" package,
	# "u" for the Sun "usr" package.
	#
	# So the problem is how to match the requested package to the
	# currently installed package.
	#

	foreach $p (@p) {
		# Hardcode till I can get a better thought for doing this
		# via a config (or other) file..
		($pkg, $description) = split(/ /, $p);
		if ($pkg =~ /^(SUNWwebminu|WSwebmin)$/) {
			break;
			}
		else {
			$pkg ='';
			}
		}

	# Fallthrough error
	if ($pkg eq '' ) {
		&inst_error($text{'upgrade_ewpackage'});
		}

	# Install the package
	print "<p>",$text{'upgrade_setuppackage'},"<p>\n";
	print "PKG: $pkg<br>";
	$ENV{'KEEP_ETC_WEBMIN'} = 1;

	# Need to do this inline, otherwise the child process won't install the
	# package.  It would be interesting, however, if this were embedded in
	# a remote script that could be nohup'd and it would restart the server.
	chdir("/");
	my $pre_install_script = "$config_directory/.pre-install";
	my $stop_script = -r $pre_install_script ? $pre_install_script : "$config_directory/stop";
	&proc::safe_process_exec_logged(
		$stop_script, 0, 0, STDOUT, undef, 1,1);

	$in{'root'} = '/';
	$in{'adminfile'} = '$module_root_directory/adminupgrade';
	$rv = &software::install_package($file, $pkg);
	&error($rv) if ($rv);
	unlink($file) if ($need_unlink);
	$ENV{'config_dir'} = $config_directory;
	$ENV{'webmin_upgrade'} = 1;
	$ENV{'autothird'} = 1;
	$ENV{'nostop'} = 1;
	$ENV{'nostart'} = 1;
	$ENV{'tempdir'} = $gconfig{'tempdir'};
	print "<p>",$text{'upgrade_setup'},"<p>\n";
	print "<pre>";

	# We now need to figure out the installed directory for
	# this package.  The best way is to find the basename
	# for the miniserv.pl file associated with this package
	# or, in grep context:
	#   grep "miniserv.pl.*$pkg"
	# and the first element includes the pathname.
	#
	$targ = &backquote_command("grep \"miniserv.pl.*$pkg\" /var/sadm/install/contents");
	if ($targ =~ /^(.*)\/miniserv.pl.*$/) {
		$dir = $1;
		}

	$setup = $indir ? "./setup.sh '$indir'" : "./setup.sh";
	print "Package Directory: $dir<br>";
	print  "cd $dir && ./setup.sh<br>";
	&proc::safe_process_exec(
		"cd $dir && ./setup.sh", 0, 0, STDOUT, undef, 1, 1);
	&proc::safe_process_exec_logged(
		"$config_directory/.post-install", 0, 0, STDOUT, undef, 1,1);
	print "</pre>\n";
	}
elsif ($in{'mode'} eq 'gentoo') {
	# Check if it is a gentoo .tar.gz or .ebuild file of webmin
	open(EMERGE, "emerge --pretend ".quotemeta($file)." 2>/dev/null |");
	while(<EMERGE>) {
		s/\r|\n//g;
		s/\033[^m]+m//g;
		if (/\s+[NRU]\s+\]\s+([^\/]+)\/webmin\-(\d\S+)/) {
			$version = $2;
			}
		}
	close(EMERGE);
	$version || &inst_error($text{'upgrade_egentoo'});
	if (!$in{'force'}) {
		&check_inst_version($version);
		}

	# Install the Gentoo package
	print "<p>",$text{'upgrade_setupgentoo'},"<p>\n";
	print "<pre>";
	&proc::safe_process_exec("emerge '$file'", 0, 0, STDOUT, undef, 1, 1);
	unlink($file) if ($need_unlink);
	print "</pre>\n";
	}
else {
	# Check if it is a webmin tarfile
	open(TAR, "tar tf $qfile 2>&1 |");
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
		&inst_error(&text('upgrade_eusermin', $usermin_version));
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
		&check_inst_version($version);
		}

	# Work out where to extract
	if ($indir) {
		# Since we are currently installed in a fixed directory,
		# just extract to a temporary location
		$extract = &transname();
		mkdir($extract, 0755);
		}
	else {
		# Next to the current directory
		$extract = "$root_directory/..";
		}

	# Do the extraction of the tar file, and run setup.sh
	$| = 1;
	if ($in{'only'}) {
		# Extact top-level files like setup.sh and os_list.txt
		$topfiles = join(" ", map { quotemeta($_) }
					  grep { !$tardir{$_} } @topfiles);
		$out = &backquote_command("cd $extract && tar xf $file $topfiles 2>&1 >/dev/null");
		if ($?) {
			&inst_error(&text('upgrade_euntar', "<tt>$out</tt>"));
			}

		# Add current modules and current non-module directories
		# (like themes and lang and images)
		@mods = grep { $intar{$_} } map { $_->{'dir'} }
			     &get_all_module_infos(1);
		opendir(DIR, $root_directory);
		foreach $d (readdir(DIR)) {
			next if ($d =~ /^\./);
			my $p = "$root_directory/$d";
			if (-d $p && !-r "$p/module.info" && $intar{$d}) {
				push(@mods, $d);
				}
			}
		closedir(DIR);

		# Extract current modules and other directories
		$mods = join(" ", map { quotemeta("webmin-$version/$_") }
				      @mods);
		$out = &backquote_command("cd $extract && tar xf $file $mods 2>&1 >/dev/null");
		if ($?) {
			&inst_error(&text('upgrade_euntar', "<tt>$out</tt>"));
			}
		}
	else {
		# Extract the whole file
		$out = &backquote_command("cd $extract && tar xf $file 2>&1 >/dev/null");
		if ($?) {
			&inst_error(&text('upgrade_euntar', "<tt>$out</tt>"));
			}
		}
	unlink($file) if ($need_unlink);
	$ENV{'config_dir'} = $config_directory;
	$ENV{'webmin_upgrade'} = 1;
	$ENV{'autothird'} = 1;
	$ENV{'tempdir'} = $gconfig{'tempdir'};
	$ENV{'deletedold'} = 1 if ($in{'delete'});
	print "<p>",$text{'upgrade_setup'},"<p>\n";
	print "<pre>";
	$setup = $indir ? "./setup.sh '$indir'" : "./setup.sh";
	&proc::safe_process_exec(
		"cd $extract/webmin-$version && $setup", 0, 0,
		STDOUT, undef, 1, 1);
	print "</pre>\n";
	if (!$?) {
		if ($in{'delete'}) {
			# Can delete the old root directory
			system("rm -rf ".quotemeta($root_directory));
			}
		elsif ($indir) {
			# Can delete the temporary source directory
			system("rm -rf ".quotemeta($extract));
			}
		&lock_file("$config_directory/config");
		$gconfig{'upgrade_delete'} = $in{'delete'};
		&write_file("$config_directory/config", \%gconfig);
		&unlock_file("$config_directory/config");
		}
	}
&webmin_log("upgrade", undef, undef, { 'version' => $version,
				       'mode' => $in{'mode'} });

if ($in{'disc'}) {
	# Forcibly disconnect all other login sessions
	&foreign_require("acl", "acl-lib.pl");
	&get_miniserv_config(\%miniserv);
	&acl::open_session_db(\%miniserv);
	foreach $s (keys %acl::sessiondb) {
		if ($s ne $main::session_id) {
			delete($acl::sessiondb{$s});
			}
		}
	dbmclose(%acl::sessiondb);
	&restart_miniserv(1);
	}

# Find out about any updates for this new version.
($updates) = &fetch_updates($update_url);
$updates = &filter_updates($updates, $version);
if (scalar(@$updates)) {
	print "<br>",&text('upgrade_updates', scalar(@$updates),
		"update.cgi?source=0&show=0&missing=0"),"<p>\n";
	}

# Force refresh of cached updates, in case webmin was included
if (&foreign_check("system-status")) {
	&foreign_require("system-status");
	&system_status::refresh_possible_packages([ "webmin" ]);
	}
if (&foreign_check("virtual-server") && @got) {
	&foreign_require("virtual-server");
	&virtual_server::refresh_possible_packages([ "webmin" ]);
	}

&ui_print_footer("", $text{'index_return'});

sub inst_error
{
unlink($file) if ($need_unlink);
unlink($updatestemp);
print "$main::whatfailed : $_[0] <p>\n";
&ui_print_footer("", $text{'index_return'});
exit;
}

sub check_inst_version
{
my ($full) = @_;
return if ($done_check_inst_version++);	  # Full version may have been checked
					  # in a previous call
my $curr_full = &get_webmin_full_version();
if (&compare_version_numbers($full, $curr_full) == 0) {
	&inst_error(&text('upgrade_elatest', $full));
	}
elsif (&compare_version_numbers($full, $curr_full) < 0) {
	&inst_error(&text('upgrade_eversion', $full));
	}
}
