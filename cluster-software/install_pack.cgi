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
	if (!$in{'local'}) {
		&install_error($text{'install_elocal'});
		}
	if (!-r $in{'local'}) {
		&install_error(&text('install_elocal2', &html_escape($in{'local'})));
		}
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
	@rv = map { $_." ".$_ } split(/\s+/, $in{'update'});
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

# Show install form
print &ui_form_start("do_install.cgi");
print &ui_hidden("file", $pfile);
print &ui_hidden("unknownfile", $unknownfile);
print &ui_hidden("need_unlink", $need_unlink);
print &ui_hidden("source", $in{'source'});
print &ui_hidden("ssl", $ssl);
print &ui_hidden("host", $host);
print &ui_hidden("page", $page);
print &ui_hidden("port", $port);
print &ui_hidden("ftpfile", $file);
print &ui_hidden("down", $in{'down'});
print &ui_table_start($text{'install_header'}, undef, 4);

# Packages to install
$plist = "";
foreach (@rv) {
	($p, $d) = split(/\s+/, $_, 2);
	if ($d && $d ne $p) {
		$plist .= &html_escape($d)." (".&html_escape($p).")<br>\n";
		}
	else {
		$plist .= &html_escape($p)."<br>\n";
		}
	}
print &ui_table_row($text{'install_packs'}, $plist, 3);

# Type-specific options
if ($in{'source'} != 3 && !@anydiff) {
	&software::install_options($pfile, $p);
	}

# Show input for hosts to install on
&create_on_input($text{'install_servers'},
		 $in{'source'} == 3, $in{'source'} == 3);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'install_ok'} ] ]);


&ui_print_footer("", $text{'index_return'});

sub install_error
{
print "<b>$main::whatfailed : @{[&html_escape($_[0])]}</b> <p>\n";
&ui_print_footer("", $text{'index_return'});
exit;
}

