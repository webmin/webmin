#!/usr/local/bin/perl
# update.cgi
# Find and install modules that need updating

require './webmin-lib.pl';
&ReadParse();
&error_setup($text{'update_err'});

# Display the results and maybe take action
$| = 1;
$theme_no_table = 1;
&ui_print_header(undef, $text{'update_title'}, "");

print "<b>",&text('update_info'),"</b><p>\n";

# Fetch updates
@urls = $in{'source'} == 0 ? ( $update_url ) : split(/\r?\n/, $in{'other'});
foreach $url (@urls) {
	($updates, $host, $port, $page, $ssl) =
		&fetch_updates($url, $in{'upuser'}, $in{'uppass'});
	foreach $u (@$updates) {
		# Skip modules that are not for this version of Webmin, IF the
		# module is a core module or is not installed
		local %minfo = &get_module_info($u->[0]);
		local %tinfo = &get_theme_info($u->[0]);
		local %info = %minfo ? %minfo : %tinfo;
		next if (($u->[1] >= &get_webmin_base_version() + .01 ||
			  $u->[1] < &get_webmin_base_version()) &&
			 (!%info || $info{'longdesc'} || !$in{'third'}));

		$count++;
		if (!%info && !$in{'missing'}) {
			# Module is not installed on this system
			print &text('update_mmissing',
				    "<b>$u->[0]</b>"),"<p>\n";
			next;
			}
		if (%info && $info{'version'} >= $u->[1]) {
			# Module is already up to date
			if (!$donemodule{$u->[0]}) {
				print &text('update_malready',
					    "<b>$u->[0]</b>"),"<p>\n";
				}
			next;
			}
		local $osinfo = { 'os_support' => $u->[3] };
		if (!&check_os_support($osinfo)) {
			# Module does not support this OS
			print &text('update_mos', "<b>$u->[0]</b>"),"<p>\n";
			next;
			}
		if ($itype = &get_module_install_type($u->[0])) {
			# Module was installed from an RPM/DEB - only allow if
			# update is in the same format
			if ($u->[2] !~ /\.$itype$/i) {
				print &text('update_mtype', "<b>$u->[0]</b>",
							    uc($itype)),"<p>\n";
				next;
				}
			}
		if ($in{'show'}) {
			# Just tell the user what would be done
			print &text('update_mshow', "<b>$u->[0]</b>", "<b>$u->[1]</b>"),
			      "<br>\n";
			print "&nbsp;" x 10;
			print "$text{'update_fixes'} : " if ($info{'longdesc'});
			print $u->[4],"<p>\n";
			$donemodule{$u->[0]} = 1;
			}
		else {
			# Actually do the update ..
			local (@mdescs, @mdirs, @msizes);
			print &text('update_mok', "<b>$u->[0]</b>", "<b>$u->[1]</b>"),
			      "<br>\n";
			print "&nbsp;" x 10;
			print "$text{'update_fixes'} : " if ($info{'longdesc'});
			print $u->[4],"<br>\n";
			($mhost, $mport, $mpage, $mssl) =
				&parse_http_url($u->[2], $host, $port, $page, $ssl);
			($mfile = $mpage) =~ s/^(.*)\///;
			$mtemp = &transname($mfile);
			$progress_callback_url = $u->[2];
			$progress_callback_prefix = "&nbsp;" x 10;
			&http_download($mhost, $mport, $mpage, $mtemp, undef,
				       \&progress_callback, $mssl,
				       $in{'upuser'}, $in{'uppass'});
			$irv = &install_webmin_module($mtemp, 1, 0,
						      [ $base_remote_user ]);
			print "&nbsp;" x 10;
			if (!ref($irv)) {
				print &text('update_failed', $irv),"<p>\n";
				}
			else {
				print &text('update_mdesc', "<b>$irv->[0]->[0]</b>",
					    "<b>$irv->[2]->[0]</b>"),"<p>\n";
				$donemodule{$irv->[0]->[0]} = 1;
				}
			}
		}
	}
print &text('update_none'),"<br>\n" if (!$count);

# Check if a new version of webmin itself is available
$file = &transname();
&http_download('www.webmin.com', 80, '/', $file);
open(FILE, $file);
while(<FILE>) {
	if (/webmin-([0-9\.]+)\.tar\.gz/) {
		$version = $1;
		last;
		}
	}
close(FILE);
unlink($file);
if ($version > &get_webmin_version()) {
	print "<b>",&text('update_version', $version),"</b><p>\n";
	}

&ui_print_footer("", $text{'index_return'});

