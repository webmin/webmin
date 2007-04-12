#!/usr/local/bin/perl
# install_pack.cgi
# Install a package from some source

require './cluster-software-lib.pl';
if ($ENV{REQUEST_METHOD} eq "POST") {
	&ReadParse(\%getin, "GET");
	&ReadParseMime(undef, \&read_parse_mime_callback, [ $getin{'id'} ]);
	}
else {
	&ReadParse();
	$no_upload = 1;
	}
&error_setup($text{'install_err'});

if ($in{source} == 2) {
	&ui_print_unbuffered_header(undef, $text{'install_title'}, "", "install_pack");
	}
else {
	&ui_print_header(undef, $text{'install_title'}, "", "install_pack");
	}

if ($in{source} == 0) {
	# installing from local file (or maybe directory)
	if (!$in{'local'})
		{ &install_error($text{'install_elocal'}); }
	if (!-r $in{'local'})
		{ &install_error(&text('install_elocal2', $in{'local'})); }
	$source = $in{'local'};
	$pfile = $in{'local'};
	$filename = $in{'local'};
	$filename =~ s/^(.*)[\\\/]//;
	$need_unlink = 0;
	}
elsif ($in{source} == 1) {
	# installing from upload .. store file in temp location
	if ($no_upload) {
		&install_error($text{'install_eupload'});
		}
	$in{'upload_filename'} =~ /([^\/\\]+$)/;
	$filename = $in{'upload_filename'};
	$filename =~ s/^(.*)[\\\/]//;
	$pfile = &tempname("$1");
	&open_tempfile(PFILE, ">$pfile");
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
	else { &install_error(&text('install_eurl', $in{'url'})); }
	&install_error($error) if ($error);
	$source = $in{'url'};
	$need_unlink = 1;
	$filename = $in{'url'};
	$filename =~ s/^(.*)[\\\/]//;
	}
elsif ($in{source} == 3) {
	# installing from some update system, so nothing to do here
	$pfile = $in{'update'};
	@rv = split(/\s+/, $in{'update'});
	}

# Check if any remote systems are using the same package system
@anysame = grep { &same_package_system($_) } &list_software_hosts();
@anydiff = grep { !&same_package_system($_) } &list_software_hosts();

# Check validity, if we can
$invalid_msg = undef;
if ($in{'source'} != 3) {
	$ps = &software::package_system();
	if (!&software::is_package($pfile)) {
		if (-d $pfile) {
			&install_error(&text('install_edir', $ps));
			}
		else {
			# attempt to uncompress
			local $unc = &software::uncompress_if_needed(
				$pfile, $need_unlink);
			if ($unc ne $pfile) {
				# uncompressed ok..
				if (!&software::is_package($unc)) {
					# but still not valid :(
					unlink($unc);
					$invalid_msg =
						&text('install_ezip', $ps);
					}
				else {
					$pfile = $unc;
					}
				}
			else {
				# uncompress failed.. give up
				$invalid_msg = &text('install_efile', $ps);
				}
			}
		}

	if (!$invalid_msg) {
		# ask for package to install and install options
		@rv = &software::file_packages($pfile);
		}
	}

if ($invalid_msg) {
	# Could not check package .. but this is OK if we have any remote
	# systems of different types
	if (@anydiff) {
		$filename =~ s/\.[a-z]+$//i;
		@rv = ( $filename );
		$unknownfile = $filename;
		}
	else {
		unlink($pfile) if ($need_unlink);
		&install_error($invalid_msg);
		}
	}

print "<form action=do_install.cgi>\n";
print "<input type=hidden name=file value=\"$pfile\">\n";
print "<input type=hidden name=unknownfile value=\"$unknownfile\">\n";
print "<input type=hidden name=need_unlink value=\"$need_unlink\">\n";
print "<input type=hidden name=source value='$in{'source'}'>\n";
print "<input type=hidden name=ssl value='$ssl'>\n";
print "<input type=hidden name=host value='$host'>\n";
print "<input type=hidden name=page value='$page'>\n";
print "<input type=hidden name=port value='$port'>\n";
print "<input type=hidden name=ftpfile value='$file'>\n";
print "<input type=hidden name=down value='$in{'down'}'>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'install_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";
print "<tr> <td valign=top><b>$text{'install_packs'}</b></td>\n";
print $software::wide_install_options ? "<td colspan=3>\n" : "<td>\n";
foreach (@rv) {
	($p, $d) = split(/\s+/, $_, 2);
	if ($d) {
		print "$d ($p)<br>\n";
		}
	else {
		print "$p<br>\n";
		}
	push(@pn, $p);
	}
print "</td> </tr>\n";
if ($in{'source'} != 3 && !@anydiff) {
	# Options are only shown when all systems use the same package type
	&foreign_call("software", "install_options", $pfile, $p);
	}

# Show input for hosts to install on
&create_on_input($text{'install_servers'},
		 $in{'source'} == 3, $in{'source'} == 3);

print "</table></td></tr>\n";
print "</table><input type=submit value=\"$text{'install_ok'}\"></form>\n";

&ui_print_footer("", $text{'index_return'});

sub install_error
{
print "<b>$main::whatfailed : $_[0]</b> <p>\n";
&ui_print_footer("", $text{'index_return'});
exit;
}

