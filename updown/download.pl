#!/usr/local/bin/perl
# download.pl
# Start downloading some file, and update the .down file with its progress

$no_acl_check++;
require './updown-lib.pl';

$down = &get_download($ARGV[0]);
$down || die "Download ID $ARGV[0] does not exist!";
&can_write_file($down->{'dir'}) || die "Cannot download files to $down->{'dir'}";

# Do the download, updating the config file with progress
$down->{'pid'} = $$;
&save_download($down);
$error = &do_download($down, \&download_callback, \@paths);
$down->{'complete'} = 1;
$down->{'error'} = $error if ($error);
&save_download($down);

sub download_callback
{
if ($_[0] == 1) {
	# Started ok
	delete($down->{'size'});
	delete($down->{'got'});
	delete($down->{'finished'});
	$lastupdate = 0;
	$lastpercent = 0;
	}
elsif ($_[0] == 2) {
	# Got size
	$down->{'size'} = $_[1];
	}
elsif ($_[0] == 3) {
	# Got some data. Only update the status file every 10 seconds or when
	# a percent of data is received
	$down->{'got'} = $_[1];
	if ($down->{'size'}) {
		$percent = int($down->{'got'}*100/$down->{'size'});
		$now = time();
		return if ($percent <= $lastpercent &&
			   $now < $lastupdate + 10);
		$lastupdate = $now;
		$lastpercent = $percent;
		}
	}
elsif ($_[0] == 4) {
	# All done
	$down->{'finished'} = 1;
	$down->{'total'} += $down->{'got'};
	}
elsif ($_[0] == 5) {
	# Redirecting to new URL
	}
&switch_uid_back();
&save_download($down);
&switch_uid_to($down->{'uid'}, $down->{'gid'});
}

