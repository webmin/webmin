#!/usr/local/bin/perl
# save_export.cgi
# Save, create or delete an export

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './exports-lib.pl';
our (%text, %in, %config);
&ReadParse();

&lock_file($config{'exports_file'});
my @exps = &list_exports();

my %exp;
if ($in{'delete'}) {
	# Deleting some export
	my $exp = $exps[$in{'idx'}];
	&delete_export($exp);
	%exp = %$exp;
	}
else {
	my ($oldexp, %opts);
	if (!$in{'new'}) {
		# Get old export
		$oldexp = $exps[$in{'idx'}];
		%opts = %{$oldexp->{'options'}};
		}

	# Validate and parse inputs
	&error_setup($text{'save_err'});
	-d $in{'dir'} || &error(&text('save_edir', $in{'dir'}));
	$exp{'dir'} = $in{'dir'};
	if (defined($in{'pfs_def'})) {
		$in{'pfs_def'} || $in{'pfs'} =~ /^\/\S+$/ ||
			&error(&text('save_epfs', $in{'pfs'}));
		$exp{'pfs'} = $in{'pfs_def'} ? undef : $in{'pfs'};
		}
	$exp{'active'} = $in{'active'};
	
	if ($in{'mode'} == 0) { $exp{'host'} = "=public"; }
	elsif ($in{'mode'} == 1) {
		$in{'netgroup'} =~ /^\S+$/ ||
			&error($text{'save_enetgroup'});
		$exp{'host'} = '@'.$in{'netgroup'};
		}
	elsif ($in{'mode'} == 2) {
		&check_ipaddress($in{'network'}) ||
			&error(&text('save_enetwork', $in{'network'}));
		&check_ipaddress($in{'netmask'}) ||
			&error(&text('save_enetmask', $in{'netmask'}));
		$exp{'host'} = $in{'network'}."/".$in{'netmask'};
		}
	elsif ($in{'mode'} == 3) { $exp{'host'} = ""; }
	else {
		$in{'host'} =~ /\*/ || &to_ipaddress($in{'host'}) ||
			&error(&text('save_ehost', $in{'host'}));
		$exp{'host'} = $in{'host'};
		}

	# Authentication is in the host name
	if ($in{'ver'} >= 4) {
		$opts{'sec'} = join(":", split(/\r?\n/, $in{'sec'}));
		if ($opts{'sec'} eq 'sys') {
			delete($opts{'sec'});
			}
		if ($opts{'sec'} && $opts{'sec'} !~ /:/ && $exp{'host'} eq '') {
			# Allow hosts allowed for this security level
			$exp{'host'} = 'gss/'.$opts{'sec'};
			delete($opts{'sec'});
			}
		}

	# Validate and parse options
	delete($opts{'rw'});
	delete($opts{'ro'});
	if ($in{'ro'}) {
		$opts{'ro'} = "";
		}
	else {
		$opts{'rw'} = "";
		}
	
	delete($opts{'secure'});
	delete($opts{'insecure'});
	$opts{'insecure'} = "" if ($in{'insecure'});

	delete($opts{'no_subtree_check'});
	delete($opts{'subtree_check'});
	$opts{'no_subtree_check'} = "" if ($in{'no_subtree_check'});

	delete($opts{'nohide'});
	delete($opts{'hide'});
	$opts{'nohide'} = "" if ($in{'nohide'});
	
	delete($opts{'sync'}); delete($opts{'async'});
	if ($in{'sync'} == 1) {
		$opts{'sync'} = "";
		}
	elsif ($in{'sync'} == 2) {
		$opts{'async'} = "";
		}

	delete($opts{'root_squash'});
	delete($opts{'no_root_squash'});
	delete($opts{'all_squash'});
	delete($opts{'no_all_squash'});
	$opts{'no_root_squash'} = "" if ($in{'squash'} == 0);
	$opts{'all_squash'} = "" if ($in{'squash'} == 2);

	if ($in{'anonuid_def'}) {
		delete($opts{'anonuid'});
		}
	elsif ($in{'anonuid'} =~ /^-?[0-9]+$/) {
		$opts{'anonuid'} = $in{'anonuid'};
		}
	else {
		$opts{'anonuid'} = getpwnam($in{'anonuid'});
		$opts{'anonuid'} || &error($text{'save_eanonuid'});
		}

	if ($in{'anongid_def'}) {
		delete($opts{'anongid'});
		}
	elsif ($in{'anongid'} =~ /^-?[0-9]+$/) {
		$opts{'anongid'} = $in{'anongid'};
		}
	else {
		$opts{'anongid'} = getgrnam($in{'anongid'});
		$opts{'anongid'} || &error($text{'save_eanongid'});
		}

	# NFSv2 specific options
	delete($opts{'link_relative'});
	delete($opts{'link_absolute'});
	delete($opts{'noaccess'});
	delete($opts{'squash_uids'});
	delete($opts{'squash_gids'});
	delete($opts{'map_daemon'});

	$opts{'link_relative'} = "" if ($in{'link_relative'});
	$opts{'noaccess'} = "" if ($in{'noaccess'});

	if (!$in{'squash_uids_def'}) {
		if ($in{'squash_uids'} !~ /^[\d+\-\,]+$/) {
			&error($text{'save_euids'});
			}
		else {
			$opts{'squash_uids'} = $in{'squash_uids'};
			$opts{'map_daemon'} = "";
			}
		}
	    
	if (!$in{'squash_gids_def'}) {
		if ($in{'squash_gids'} !~ /^[\d+\-\,]+$/) {
			&error($text{'save_egids'});
			}
		else {
			$opts{'squash_gids'} = $in{'squash_gids'};
			$opts{'map_daemon'} = "";
			}
		}

	$exp{'options'} = \%opts;

	# Create or update the export
	if ($in{'new'}) {
		if ($exp{'pfs'}) {
			&create_export_via_pfs(\%exp);
			}
		else {
			&create_export(\%exp);
			}
		}
	else {
		&modify_export(\%exp, $oldexp);
		}
	}
&unlock_file($config{'exports_file'});

if ($in{'delete'}) {
	&webmin_log("delete", "export", $exp{'dir'}, \%exp);
	}
elsif ($in{'new'}) {
	&webmin_log("create", "export", $exp{'dir'}, \%exp);
	}
else {
	&webmin_log("modify", "export", $exp{'dir'}, \%exp);
	}
&redirect("");

