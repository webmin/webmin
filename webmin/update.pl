#!/usr/local/bin/perl
# update.pl
# Find and install updated modules, and email out the result

$no_acl_check++;
require './webmin-lib.pl';

# Fetch the updates
@urls = $config{'upsource'} ? split(/\t+/, $config{'upsource'})
			    : ( $update_url );
foreach $url (@urls) {
	# Get updates from this URL, and filter to those for this system
	$checksig = $config{'upchecksig'} ? 2 : $url eq $update_url ? 2 : 1;
	eval {
		$main::error_must_die = 1;
		($updates, $host, $port, $page, $ssl) =
		    &fetch_updates($url, $config{'upuser'}, $config{'uppass'},
			           $checksig);
		};
	if ($@) {
		print STDERR "Failed to fetch updates : $@\n";
		exit(0);
		}
	$updates = &filter_updates($updates, undef, $config{'upthird'},
				   $config{'upmissing'});

	# Go through the results
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

		if ($config{'upshow'}) {
			# Just tell the user what would be done
			$rv .= &text('update_mshow', $u->[0], $u->[1])."\n".
			       ($info{'longdesc'} ? "$text{'update_fixes'} : " : "").
			       $u->[4]."\n\n";
			}
		else {
			# Actually do the update ..
			my (@mdescs, @mdirs, @msizes);
			$rv .= &text('update_mok', $u->[0], $u->[1])."\n".
			       ($info{'longdesc'} ? "$text{'update_fixes'} : " : "").
			       $u->[4]."\n\n";
			($mhost, $mport, $mpage, $mssl) =
				&parse_http_url($u->[2], $host, $port, $page, $ssl);
			($mfile = $mpage) =~ s/^(.*)\///;
			$mtemp = &transname($mfile);
			&retry_http_download($mhost, $mport, $mpage, $mtemp, \$error,
				       undef, $mssl,
				       $config{'upuser'}, $config{'uppass'});
			if ($error) {
				$rv .= "$error\n\n";
				last;
				}
			else {
				$irv = &check_update_signature(
				  $mhost, $mport, $mpage,
				  $mssl, $config{'upuser'}, $config{'uppass'},
				  $mtemp, $checksig);
				$irv ||= &install_webmin_module($mtemp, 1, 0,
						      [ "admin", "root" ]);
				if (!ref($irv)) {
					$irv =~ s/<[^>]*>//g;
					$rv .= &text('update_failed', $irv)."\n\n";
					}
				else {
					$rv .= &text('update_mdesc', $irv->[0]->[0],
						      $irv->[2]->[0])."\n\n";
					}
				}
			}
		}
	}

# Check if a new version of webmin itself is available
$version = &get_latest_webmin_version();
if ($version > &get_webmin_version()) {
	$rv .= &text('update_version', $version)."\n";
	}

# Send off a results email
if ($config{'upemail'} && $rv && &foreign_check("mailboxes")) {
	# Construct and send the email
	&foreign_require("mailboxes", "mailboxes-lib.pl");
	my $data;
	my $type = $gconfig{'real_os_type'} || $gconfig{'os_type'};
	my $version = $gconfig{'real_os_version'} || $gconfig{'os_version'};
	my $myhost = &get_system_hostname();
	$data .= "$myhost ($type $version)\n\n";
	$data .= &text('update_rv', "http://$host:$port$page")."\n\n";
	$data .= $rv;
	&mailboxes::send_text_mail(&mailboxes::get_from_address(),
				   $config{'upemail'},
				   undef,
				   $text{'update_subject'},
				   $data);
	}

