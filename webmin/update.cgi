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
$count = 0;
foreach $url (@urls) {
	# Get updates from this URL, and filter to those for this system
	$checksig = $in{'checksig'} ? 2 : $url eq $update_url ? 2 : 1;
	($updates, $host, $port, $page, $ssl) =
		&fetch_updates($url, $in{'upuser'}, $in{'uppass'}, $checksig);
	$updates = &filter_updates($updates, undef,
				   $in{'third'}, $in{'missing'});
	$count += scalar(@$updates);
	foreach $u (@$updates) {
		# Get module or theme's details
		my %minfo = &get_module_info($u->[0]);
		my %tinfo = &get_theme_info($u->[0]);
		my %info = %minfo ? %minfo : %tinfo;

		# Skip if we already have the version, perhaps from an earlier
		# update in this run
		my $nver = $u->[1];
		$nver =~ s/^(\d+\.\d+)\..*$/$1/;
		next if (%info && $info{'version'} &&
			 $info{'version'} >= $nver);

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
			my (@mdescs, @mdirs, @msizes);
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
			&retry_http_download($mhost, $mport, $mpage, $mtemp, undef,
				       \&progress_callback, $mssl,
				       $in{'upuser'}, $in{'uppass'});
			$irv = &check_update_signature($mhost, $mport, $mpage,
					$mssl, $in{'upuser'}, $in{'uppass'},
					$mtemp, $checksig);
			$irv ||= &install_webmin_module($mtemp, 1, 0,
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
$version = &get_latest_webmin_version();
if ($version > &get_webmin_version()) {
	print "<b>",&text('update_version', $version),"</b><p>\n";
	}

&ui_print_footer("", $text{'index_return'});

