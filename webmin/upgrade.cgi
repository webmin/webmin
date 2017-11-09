#!/usr/local/bin/perl
# upgrade.cgi
# Upgrade webmin if possible

require './webmin-lib.pl';
&foreign_require("proc", "proc-lib.pl");
&foreign_require("acl", "acl-lib.pl");
&ReadParseMime();

$| = 1;
$theme_no_table = 1;
&ui_print_header(undef, $text{'upgrade_title'}, "");

# Save this CGI from being killed by the upgrade
$SIG{'TERM'} = 'IGNORE';

if ($in{'source'} == 0) {
	# from local file
	&error_setup(&text('upgrade_err1', $in{'file'}));
	$file = $in{'file'};
	if (!-r $file) { &inst_error($text{'upgrade_efile'}); }
	if ($file =~ /webmin-(\d+\.\d+)/) {
		$version = $1;
		}
	if (!$in{'force'}) {
		if ($version == &get_webmin_version()) {
			&inst_error(&text('upgrade_elatest', $version));
			}
		elsif ($version <= &get_webmin_version()) {
			&inst_error(&text('upgrade_eversion', $version));
			}
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
	if ($in{'upload_filename'} =~ /webmin-(\d+\.\d+)/) {
		$version = $1;
		}
	}
elsif ($in{'source'} == 2) {
	# find latest version at www.webmin.com by looking at index page
	&error_setup($text{'upgrade_err3'});
	($ok, $version) = &get_latest_webmin_version();
	$ok || &inst_error($version);
	if (!$in{'force'}) {
		if ($version == &get_webmin_version()) {
			&inst_error(&text('upgrade_elatest', $version));
			}
		elsif ($version <= &get_webmin_version()) {
			&inst_error(&text('upgrade_eversion', $version));
			}
		}
	if ($in{'mode'} eq 'rpm') {
		# Downloading RPM
		$progress_callback_url = &convert_osdn_url(
		    "http://$osdn_host/webadmin/webmin-$version-1.noarch.rpm");
		}
	elsif ($in{'mode'} eq 'deb') {
		# Downloading Debian package
		$progress_callback_url = &convert_osdn_url(
		    "http://$osdn_host/webadmin/webmin_${version}_all.deb");
		}
	elsif ($in{'mode'} eq 'solaris-pkg') {
		# Downloading my Solaris package
		$progress_callback_url = &convert_osdn_url(
		    "http://$osdn_host/webadmin/webmin-$version.pkg.gz");
		}
	else {
		# Downloading tar.gz file
		$progress_callback_url = &convert_osdn_url(
			"http://$osdn_host/webadmin/webmin-$version.tar.gz");
		}
	($host, $port, $page, $ssl) = &parse_http_url($progress_callback_url);
	$file = &transname();
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
	if ($in{'url'} =~ /webmin-(\d+\.\d+)/) {
		$version = $1;
		}
	}
elsif ($in{'source'} == 3) {
	# Get the latest version from Caldera with cupdate
	&redirect("/cupdate/");
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
	}

# Check the signature if possible
if ($in{'sig'}) {
	# Check the package signature
	($ec, $emsg) = &gnupg_setup();
	if (!$ec) {
		if ($in{'mode'} eq 'rpm') {
			# Use rpm's gpg signature verification
			my $out = `rpm --checksig $qfile 2>&1`;
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
				&http_download($update_host, $update_port, "/download/sigs/webmin-$version.tar.gz-sig.asc", \$sigtemp, \$sigerror);
				if ($sigerror) {
					$ec = 4;
					$emsg = &text('upgrade_edownsig',
						      $sigerror);
					}
				else {
					my $data =&read_file_contents($file);
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
		print "$text{'upgrade_sigok'}<p>\n";
		}
	}
else {
	print "$text{'upgrade_nocheck'}<p>\n";
	}

if ($in{'mode'} ne 'gentoo') {
	# gunzip the file if needed
	open(FILE, $file);
	read(FILE, $two, 2);
	close(FILE);
	if ($two eq "\037\213") {
		if (!&has_command("gunzip")) {
			&inst_error($text{'upgrade_egunzip'});
			}
		$newfile = &transname();
		$out = `gunzip -c $qfile 2>&1 >$newfile`;
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
	if (open(RPM, "$root_directory/rpm-name")) {
		chop($rpmname = <RPM>);
		close(RPM);
		}
	$out = `rpm -qp $qfile`;
	$out =~ /(^|\n)\Q$rpmname\E-(\d+\.\d+)/ ||
		&inst_error($text{'upgrade_erpm'});
	$version = $2;
	if (!$in{'force'}) {
		if ($version == &get_webmin_version()) {
			&inst_error(&text('upgrade_elatest', $version));
			}
		elsif ($version <= &get_webmin_version()) {
			&inst_error(&text('upgrade_eversion', $version));
			}
		}

	# Install the RPM
	$ENV{'tempdir'} = $gconfig{'tempdir'};
	print "<p>",$text{'upgrade_setuprpm'},"<p>\n";
	print "<pre>";
	if ($in{'force'}) {
		&proc::safe_process_exec(
			"rpm -U --force --nodeps $qfile", 0, 0,
			STDOUT, undef, 1, 1);
		}
	else {
		&proc::safe_process_exec(
			"rpm -U --ignoreos --ignorearch --nodeps $qfile", 0, 0,
			STDOUT, undef, 1, 1);
		}
	unlink($file) if ($need_unlink);
	print "</pre>\n";
	}
elsif ($in{'mode'} eq 'deb') {
	# Check if it is a Debian package
	$debname = "webmin";
	if (open(RPM, "$root_directory/deb-name")) {
		chop($debname = <RPM>);
		close(RPM);
		}
	$out = `dpkg --info $qfile`;
	$out =~ /Package:\s+(\S+)/ && $1 eq $debname ||
		&inst_error($text{'upgrade_edeb'});
	$out =~ /Version:\s+(\S+)/ ||
		&inst_error($text{'upgrade_edeb'});
	$version = $1;
	if (!$in{'force'}) {
		if ($version == &get_webmin_version()) {
			&inst_error(&text('upgrade_elatest', $version));
			}
		elsif ($version <= &get_webmin_version()) {
			&inst_error(&text('upgrade_eversion', $version));
			}
		}

	# Install the package
	$ENV{'tempdir'} = $gconfig{'tempdir'};
	print "<p>",$text{'upgrade_setupdeb'},"<p>\n";
	print "<pre>";
	&proc::safe_process_exec("dpkg --install $qfile", 0, 0,
				 STDOUT, undef, 1, 1);
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
	&proc::safe_process_exec_logged(
		"$config_directory/stop", 0, 0, STDOUT, undef, 1,1);

	$in{'root'} = '/';
	$in{'adminfile'} = '$module_root_directory/adminupgrade';
	$rv = &software::install_package($file, $pkg);
	&error($rv) if ($rv);
	unlink($file) if ($need_unlink);
	$ENV{'config_dir'} = $config_directory;
	$ENV{'webmin_upgrade'} = 1;
	$ENV{'autothird'} = 1;
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
	$targ = `grep "miniserv.pl.*$pkg" /var/sadm/install/contents`;
	if ($targ =~ /^(.*)\/miniserv.pl.*$/) {
		$dir = $1;
		}

	$setup = $in{'dir'} ? "./setup.sh '$in{'dir'}'" : "./setup.sh";
	print "Package Directory: $dir<br>";
	print  "cd $dir && ./setup.sh<br>";
	&proc::safe_process_exec(
		"cd $dir && ./setup.sh", 0, 0, STDOUT, undef, 1, 1);
	&proc::safe_process_exec_logged(
		"$config_directory/start", 0, 0, STDOUT, undef, 1,1);
	print "</pre>\n";
	}
elsif ($in{'mode'} eq 'gentoo') {
	# Check if it is a gentoo .tar.gz or .ebuild file of webmin
	open(EMERGE, "emerge --pretend '$file' 2>/dev/null |");
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
		if ($version == &get_webmin_version()) {
			&inst_error(&text('upgrade_elatest', $version));
			}
		elsif ($version <= &get_webmin_version()) {
			&inst_error(&text('upgrade_eversion', $version));
			}
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
	open(TAR, "tar tf $file 2>&1 |");
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
		if ($version == &get_webmin_version()) {
			&inst_error(&text('upgrade_elatest', $version));
			}
		elsif ($version <= &get_webmin_version()) {
			&inst_error(&text('upgrade_eversion', $version));
			}
		}

	# Work out where to extract
	if ($in{'dir'}) {
		# Since we are currently installed in a fixed directory,
		# just extract to a temporary location
		$extract = &transname();
		mkdir($extract, 0755);
		}
	else {
		# Next to the current directory
		$extract = "../..";
		}

	# Do the extraction of the tar file, and run setup.sh
	$| = 1;
	if ($in{'only'}) {
		# Extact top-level files like setup.sh and os_list.txt
		$topfiles = join(" ", map { quotemeta($_) }
					  grep { !$tardir{$_} } @topfiles);
		$out = `cd $extract ; tar xf $file $topfiles 2>&1 >/dev/null`;
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
		$out = `cd $extract ; tar xf $file $mods 2>&1 >/dev/null`;
		if ($?) {
			&inst_error(&text('upgrade_euntar', "<tt>$out</tt>"));
			}
		}
	else {
		# Extract the whole file
		$out = `cd $extract ; tar xf $file 2>&1 >/dev/null`;
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
	$setup = $in{'dir'} ? "./setup.sh '$in{'dir'}'" : "./setup.sh";
	&proc::safe_process_exec(
		"cd $extract/webmin-$version && $setup", 0, 0,
		STDOUT, undef, 1, 1);
	print "</pre>\n";
	if (!$?) {
		if ($in{'delete'}) {
			# Can delete the old root directory
			system("rm -rf \"$root_directory\"");
			}
		elsif ($in{'dir'}) {
			# Can delete the temporary source directory
			system("rm -rf \"$extract\"");
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
print "<b>$main::whatfailed : $_[0]</b> <p>\n";
&ui_print_footer("", $text{'index_return'});
exit;
}

