#!/usr/local/bin/perl
# update.pl
# Find and install updated usermin modules, and email out the result

$no_acl_check++;
require './usermin-lib.pl';
if (!-r "$config{'usermin_dir'}/miniserv.conf") {
	# Usermin not installed
	exit(0);
	}

# Get the update source
if ($config{'upsource'}) {
	$config{'upsource'} =~ /^http:\/\/([^:\/]+)(:(\d+))?(\/\S+)$/ ||
		die "Invalid update source URL!";
	$host = $1;
	$port = $2 ? $3 : 80;
	$page = $4;
	}
else {
	$host = $update_host;
	$port = $update_port;
	$page = $update_page;
	}

# Retrieve the updates list (format is  module version url support description )
$temp = &transname();
&http_download($host, $port, $page, $temp);
open(UPDATES, "<".$temp);
while(<UPDATES>) {
	if (/^([^\t]+)\t+([^\t]+)\t+([^\t]+)\t+([^\t]+)\t+(.*)/) {
		push(@updates, [ $1, $2, $3, $4, $5 ]);
		}
	}
close(UPDATES);
unlink($temp);

# Go through the results
foreach $u (@updates) {
	next if ($u->[1] >= &get_usermin_base_version() + .01 ||
		 $u->[1] < &get_usermin_base_version());
	local %minfo = &get_usermin_module_info($u->[0]);
	local %tinfo = &get_usermin_theme_info($u->[0]);
	if (!%minfo && !%tinfo && !$config{'upmissing'}) {
		$rv .= &text('update_mmissing', $u->[0])."\n"
			if (!$config{'upquiet'});
		next;
		}
	if (%minfo && $minfo{'version'} >= $u->[1]) {
		$rv .= &text('update_malready', $u->[0])."\n"
			if (!$config{'upquiet'});
		next;
		}
	if (%tinfo && $tinfo{'version'} >= $u->[1]) {
		$rv .= &text('update_malready', $u->[0])."\n"
			if (!$config{'upquiet'});
		next;
		}
	local $osinfo = { 'os_support' => $u->[3] };
	if (!&check_usermin_os_support($osinfo)) {
		$rv .= &text('update_mos', $u->[0])."\n"
			if (!$config{'upquiet'});
		next;
		}
	if ($config{'upshow'}) {
		# Just tell the user what would be done
		$rv .= &text('update_mshow', $u->[0], $u->[1])."\n".
		       $text{'update_fixes'}." : ".$u->[4]."\n\n";
		}
	else {
		# Actually do the update ..
		local (@mdescs, @mdirs, @msizes);
		$rv .= &text('update_mok', $u->[0], $u->[1])."\n".
		       $text{'update_fixes'}." : ".$u->[4]."\n\n";
		if ($u->[2] =~ /^http:\/\/([^:\/]+)(:(\d+))?(\/\S+)$/) {
			$mhost = $1;
			$mport = $2 ? $3 : 80;
			$mpage = $4;
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
		&http_download($mhost, $mport, $mpage, $mtemp, \$error);
		if ($error) {
			$rv .= "$error\n\n";
			last;
			}
		else {
			$irv = &install_usermin_module($mtemp, 1, 0);
			if (!ref($irv)) {
				$irv =~ s/<[^>]*>//g;
				$irv .= &text('update_failed', $irv)."\n\n";
				}
			else {
				$irv .= &text('update_mdesc', $irv->[0]->[0],
					      $irv->[2]->[0])."\n\n";
				}
			}
		}
	}

# Check if a new version of usermin itself is available
$file = &transname();
&http_download('www.webmin.com', 80, '/index6.html', $file);
open(FILE, "<".$file);
while(<FILE>) {
	if (/usermin-([0-9\.]+)\.tar\.gz/) {
		$version = $1;
		last;
		}
	}
close(FILE);
unlink($file);
if ($version > &get_usermin_version()) {
	$rv .= &text('update_version', $version)."\n";
	}

# Send off a results email
if ($config{'upemail'} && $rv && &foreign_check("mailboxes")) {
	# Construct and send the email
	&foreign_require("mailboxes", "mailboxes-lib.pl");
	local $data;
	local $type = $gconfig{'real_os_type'} || $gconfig{'os_type'};
	local $version = $gconfig{'real_os_version'} || $gconfig{'os_version'};
	local $myhost = &get_system_hostname();
	$data .= "$myhost ($type $version)\n\n";
	$data .= &text('update_rv', "http://$host:$port$page")."\n\n";
	$data .= $rv;
	&mailboxes::send_text_mail(&mailboxes::get_from_address(),
				   $config{'upemail'},
				   undef,
				   $text{'update_subject'},
				   $data);
	}

