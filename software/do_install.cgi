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

# Save this CGI from being killed by a webmin or apache upgrade
$SIG{'TERM'} = 'IGNORE';
$SIG{'PIPE'} = 'IGNORE';

@packages = &file_packages($in{'file'});
if (defined(&install_packages) && @packages > 1) {
	# Can install everything in one hit
	&clean_environment();
	$error = &install_packages($in{'file'}, \%in);
	&reset_environment();
	if ($error) { &install_error($error); }
	if ($in{'need_unlink'}) { &unlink_file($in{'file'}); }

	foreach $p (@packages) {
		# Display package details
		($package, $desc) = split(/\s+/, $p, 2);
		@pinfo = &show_package_info($package);

		# Display new files
		@grid = ( );
		$n = &check_files($package);
		for($i=0; $i<$n; $i++) {
			push(@grid, &html_escape($files{$i,'path'}));
			}
		print &ui_grid_table(\@grid, 2, 100, undef, undef,
				     $text{'do_files'});
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
		print &ui_hr() if ($p ne $packages[0]);
		($package, $desc) = split(/\s+/, $p, 2);
		&clean_environment();
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
		&reset_environment();
		if ($error) { &install_error($error); }
		if ($in{'need_unlink'}) { &unlink_file($in{'file'}); }

		# display information
		@pinfo = &show_package_info($package);

		# Show files in package, if possible
		$n = &check_files($package);
		if ($n) {
			@grid = ( );
			for($i=0; $i<$n; $i++) {
				push(@grid, &html_escape($files{$i,'path'}));
				}
			print &ui_grid_table(\@grid, 2, 100, undef, undef,
					     $text{'do_files'});
			}
		&list_packages($package);
		&webmin_log('install', 'package', $package,
			    { 'desc' => $packages{0,'desc'},
			      'class' => $packages{0,'class'} });
		}
	}

&ui_print_footer("", $text{'index_return'});

sub install_error
{
print "<b>",&text('do_efailed', @{[&html_escape($error)]}),"</b><p>\n";
print $text{'do_efailedmsg1'},"<p>\n";
if ($in{'need_unlink'}) {
	print &text('do_efailedmsg2',
		"delete_file.cgi?file=".
		&urlize($in{'file'})),"<p>\n";
	}
&ui_print_footer("", $text{'index_return'});
exit;
}

