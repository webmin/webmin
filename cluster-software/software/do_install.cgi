#!/usr/local/bin/perl
# do_install.cgi
# Do the actual installation of a package from a file

require './software-lib.pl';
&ReadParse();
&error_setup(&text('do_err', $in{'package'}));

if ($show_install_progress) {
	&ui_print_unbuffered_header(undef, $text{'do_title'}, "");
	}
else {
	&ui_print_header(undef, $text{'do_title'}, "");
	}

@packages = &file_packages($in{'file'});
if (defined(&install_packages) && @packages > 1) {
	# Can install everything in one hit
	$error = &install_packages($in{'file'}, \%in);
	if ($error) { &install_error($error); }
	if ($in{'need_unlink'}) { &unlink_file($in{'file'}); }

	foreach $p (@packages) {
		# display information
		($package, $desc) = split(/\s+/, $p, 2);
		@pinfo = &show_package_info($package);
		print "<table border width=100%>\n";
		print "<tr $tb> <td><b>$text{'do_files'}</b></td> </tr>\n";
		print "<tr $cb> <td><table width=100%>\n";
		$n = &check_files($package);
		for($i=0; $i<$n; $i++) {
			if ($i%2 == 0) { print "<tr>\n"; }
			print "<td width=50%>",
				&html_escape($files{$i,'path'}),"</td>\n";
			if ($i%2 == 1) { print "</tr>\n"; }
			}
		print "</table></td></tr></table><p>\n";
		&list_packages($package);
		&webmin_log('install', 'package', $package,
			    { 'desc' => $packages{0,'desc'},
			      'class' => $packages{0,'class'} });
		}
	}
else {
	# Must install and show one by one
	foreach $p (@packages) {
		# attempt to install
		print "<hr>\n" if ($p ne $packages[0]);
		($package, $desc) = split(/\s+/, $p, 2);
		if ($show_install_progress) {
			print "<pre>\n";
			$error = &install_package(
				$in{'file'}, &html_escape($package), \%in, 1);
			print "</pre>\n";
			}
		else {
			$error = &install_package(
				$in{'file'}, &html_escape($package), \%in);
			}
		if ($error) { &install_error($error); }
		if ($in{'need_unlink'}) { &unlink_file($in{'file'}); }

		# display information
		@pinfo = &show_package_info($package);
		print "<table border width=100%>\n";
		print "<tr $tb> <td><b>$text{'do_files'}</b></td> </tr>\n";
		print "<tr $cb> <td><table width=100%>\n";
		$n = &check_files($package);
		for($i=0; $i<$n; $i++) {
			if ($i%2 == 0) { print "<tr>\n"; }
			print "<td width=50%>",
				&html_escape($files{$i,'path'}),"</td>\n";
			if ($i%2 == 1) { print "</tr>\n"; }
			}
		print "</table></td></tr></table><p>\n";
		&list_packages($package);
		&webmin_log('install', 'package', $package,
			    { 'desc' => $packages{0,'desc'},
			      'class' => $packages{0,'class'} });
		}
	}

&ui_print_footer("", $text{'index_return'});

sub install_error
{
print "<b>",&text('do_efailed', $error),"</b><p>\n";
print $text{'do_efailedmsg1'},"<p>\n";
if ($in{'need_unlink'}) {
	print &text('do_efailedmsg2',
		"delete_file.cgi?file=".
		&urlize($in{'file'})),"<p>\n";
	}
print "<hr>\n";
&ui_print_footer("", $text{'index_return'});
exit;
}

