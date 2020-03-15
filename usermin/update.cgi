#!/usr/local/bin/perl
# update.cgi
# Find and install usermin modules that need updating

require './usermin-lib.pl';
$access{'upgrade'} || &error($text{'acl_ecannot'});
&ReadParse();
&error_setup($text{'update_err'});

# Validate inputs
if ($in{'source'} == 0) {
	$host = $update_host;
	$port = $update_port;
	$page = $update_page;
	}
else {
	$in{'other'} =~ /^(http|https):\/\/([^:\/]+)(:(\d+))?(\/\S+)$/ ||
		&error($text{'update_eurl'});
	$ssl = $1 eq 'https';
	$host = $2;
	$port = $3 ? $4 : $ssl ? 443 : 80;
	$page = $5;
	}

# Retrieve the updates list (format is  module version url support description )
$temp = &transname();
&http_download($host, $port, $page, $temp, undef, undef, $ssl);
open(UPDATES, "<$temp");
while(<UPDATES>) {
	if (/^([^\t]+)\t+([^\t]+)\t+([^\t]+)\t+([^\t]+)\t+(.*)/) {
		push(@updates, [ $1, $2, $3, $4, $5 ]);
		}
	}
close(UPDATES);
unlink($temp);
@updates || &error($text{'update_efile'});

# Display the results and maybe take action
&ui_print_unbuffered_header(undef, $text{'update_title'}, "");

print "<b>",&text('update_info'),"</b><p>\n";
foreach $u (@updates) {
	next if ($u->[1] >= &get_usermin_base_version() + .01 ||
		 $u->[1] < &get_usermin_base_version());
	$count++;
	local %minfo = &get_usermin_module_info($u->[0]);
	local %tinfo = &get_usermin_theme_info($u->[0]);
	if (!%minfo && !%tinfo && !$in{'missing'}) {
		print &text('update_mmissing', "<b>$u->[0]</b>"),"<p>\n";
		next;
		}
	if (%minfo && $minfo{'version'} >= $u->[1]) {
		print &text('update_malready', "<b>$u->[0]</b>"),"<p>\n";
		next;
		}
	if (%tinfo && $tinfo{'version'} >= $u->[1]) {
		print &text('update_malready', "<b>$u->[0]</b>"),"<p>\n";
		next;
		}
	local $osinfo = { 'os_support' => $u->[3] };
	if (!&check_usermin_os_support($osinfo)) {
		print &text('update_mos', "<b>$u->[0]</b>"),"<p>\n";
		next;
		}
	if ($in{'show'}) {
		# Just tell the user what would be done
		print &text('update_mshow', "<b>$u->[0]</b>", "<b>$u->[1]</b>"),
		      "<br>\n";
		print "&nbsp;" x 10;
		print $text{'update_fixes'}," : ",$u->[4],"<p>\n";
		}
	else {
		# Actually do the update ..
		local (@mdescs, @mdirs, @msizes);
		print &text('update_mok', "<b>$u->[0]</b>", "<b>$u->[1]</b>"),
		      "<br>\n";
		print "&nbsp;" x 10;
		print $text{'update_fixes'}," : ",$u->[4],"<br>\n";
		$mssl = $ssl;
		if ($u->[2] =~ /^(http|https):\/\/([^:\/]+)(:(\d+))?(\/\S+)$/) {
			$mssl = $1 eq 'https';
			$mhost = $2;
			$mport = $3 ? $4 : $mssl ? 443 : 80;
			$mpage = $5;
			}
		elsif ($u->[2] =~ /^\/\S+$/) {
			$mhost = $host;
			$mport = $port;
			$mpage = $u->[2];
			}
		else {
			$mhost = $host;
			$mport = $port;
			($mpage = $page) =~ s/[^\/]+$//;
			$mpage .= $u->[2];
			}
		$mtemp = &transname();
		$progress_callback_url = $u->[2];
		$progress_callback_prefix = "&nbsp;" x 10;
		&http_download($mhost, $mport, $mpage, $mtemp, undef,
			       \&progress_callback, $mssl);
		$irv = &install_usermin_module($mtemp, 1, 0);
		print "&nbsp;" x 10;
		if (!ref($irv)) {
			print &text('update_failed', $irv),"<p>\n";
			}
		else {
			print &text('update_mdesc', "<b>$irv->[0]->[0]</b>",
				    "<b>$irv->[2]->[0]</b>"),"<p>\n";
			}
		}
	}
print &text('update_none'),"<br>\n" if (!$count);

# Check if a new version of webmin itself is available
$file = &transname();
&http_download('www.webmin.com', 80, '/index6.html', $file);
open(FILE, "<$file");
while(<FILE>) {
	if (/usermin-([0-9\.]+)\.tar\.gz/) {
		$version = $1;
		last;
		}
	}
close(FILE);
unlink($file);
if ($version > &get_usermin_version()) {
	print "<b>",&text('update_version', $version),"</b><p>\n";
	}

print "<p>\n";
&ui_print_footer("", $text{'index_return'});

