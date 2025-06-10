#!/usr/local/bin/perl
# install_pack.cgi
# Install a package from some source

require './software-lib.pl';
if ($ENV{REQUEST_METHOD} eq "POST") {
	&ReadParse(\%getin, "GET");
	&ReadParseMime(undef, \&read_parse_mime_callback, [ $getin{'id'} ]);
	}
else {
	&ReadParse();
	$no_upload = 1;
	}
&error_setup($text{'install_err'});

if ($in{'source'} == 3 && &foreign_installed("package-updates")) {
	# Use the package updates module instead, as it has a nicer UI
	&redirect(
	  "/package-updates/update.cgi?".
	  "redir=".&urlize($in{'return'} || "/$module_name/").
	  "&redirdesc=".&urlize($in{'returndesc'} || $module_info{'desc'}).
	  "&flags=".&urlize($in{'flags'}).
	  "&mode=new".
	  "&".join("&", map { "u=".&urlize($_) }
			    split(/\s+/, $in{'update'})));
	return;
	}

if ($in{'source'} >= 2) {
	&ui_print_unbuffered_header(undef, $text{'install_title'}, "", "install");
	}
else {
	&ui_print_header(undef, $text{'install_title'}, "", "install");
	}

if ($in{source} == 0) {
	# installing from local file (or maybe directory)
	if (!$in{'local'})
		{ &install_error($text{'install_elocal'}); }
	if (!-r $in{'local'} && !-d $in{'local'} && $in{'local'} !~ /\*|\?/)
		{ &install_error(&text('install_elocal2', $in{'local'})); }
	$source = $in{'local'};
	$pfile = $in{'local'};
	$need_unlink = 0;
	}
elsif ($in{source} == 1) {
	# installing from upload .. store file in temp location
	if ($no_upload) {
		&install_error($text{'install_eupload'});
		}
	$in{'upload_filename'} =~ /([^\/\\]+$)/;
	$pfile = &tempname("$1");
	&open_tempfile(PFILE, ">$pfile", 0, 1);
	&print_tempfile(PFILE, $in{'upload'});
	&close_tempfile(PFILE);
	$source = $in{'upload_filename'};
	$need_unlink = 1;
	}
elsif ($in{source} == 2) {
	# installing from URL.. store downloaded file in temp location
	$in{'url'} = &convert_osdn_url($in{'url'});
	$in{'url'} =~ /\/([^\/]+)\/*$/;
	$pfile = &tempname("$1");
	local $error;
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
	else {
		&install_error(&text('install_eurl', &html_escape($in{'url'})));
		}
	&install_error(&html_escape($error)) if ($error);
	$source = $in{'url'};
	$need_unlink = 1;
	}
elsif ($in{'source'} == 3) {
	# installing from some update system
	&clean_environment();
	$in{'update'} =~ /\S/ || &error($text{'install_eupdate'});
	@packs = &update_system_install($in{'update'}, \%in);
	&reset_environment();

	print &ui_hr() if (@packs);
	foreach $p (@packs) {
		&show_package_info($p);
		}
	&webmin_log($config{'update_system'}, "install", undef,
		    { 'packages' => \@packs } ) if (@packs);

	if ($in{'caller'} && &foreign_check("webmin")) {
		# Software installed - refresh installed flag cache
		&foreign_require("webmin");
		($inst, $changed) =
			&webmin::build_installed_modules(0, $in{'caller'});
		if (@$changed && defined(&theme_post_change_modules)) {
			&theme_post_change_modules();
			}
		}

	if ($in{'return'}) {
		&ui_print_footer($in{'return'}, $in{'returndesc'});
		}
	else {
		&ui_print_footer("?tab=install", $text{'index_return'});
		}
	exit;
	}

# Check validity
if (!&is_package($pfile)) {
	if (-d $pfile) {
		&install_error(&text('install_edir', &package_system()));
		}
	else {
		# attempt to uncompress
		local $unc = &uncompress_if_needed($pfile, $need_unlink);
		if ($unc ne $pfile) {
			# uncompressed ok..
			if (!&is_package($unc)) {
				&unlink_file($unc);
				&install_error(&text('install_ezip',
					     &package_system()));
				}
			$pfile = $unc;
			}
		else {
			# uncompress failed.. give up
			#unlink($pfile) if ($need_unlink);
			&install_error(&text('install_efile', &package_system()));
			}
		}
	}

# ask for package to install and install options
@rv = &file_packages($pfile);

print &ui_form_start("do_install.cgi");
print &ui_hidden("file", $pfile);
print &ui_hidden("need_unlink", $need_unlink);
print &ui_table_start($text{'install_header'}, undef, 4);

# Packages to install
$plist = "";
foreach (@rv) {
	($p, $d) = split(/\s+/, $_, 2);
	if ($d) {
		$plist .= &html_escape($d)," (",&html_escape($p),")<br>\n";
		}
	else {
		$plist .= &html_escape($p),"<br>\n";
		}
	}
print &ui_table_row($text{'install_packs'}, $plist, 3);

# Type-specific options
&install_options($pfile, $p);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'install_ok'} ] ]);

&ui_print_footer("?tab=install", $text{'index_return'});

sub install_error
{
print "$main::whatfailed : @{[&html_escape($_[0])]} <p>\n";
&ui_print_footer("?tab=install", $text{'index_return'});
exit;
}


