#!/usr/bin/perl
use strict;
use warnings;
no warnings 'once';
use Test::More;
use Cwd qw(abs_path);
use File::Basename qw(dirname);

my $root = abs_path(dirname(__FILE__)."/../..") or die "rootdir: $!";
our ($no_check_support, $smbfs_fs) = (1, "smbfs");
our (%options, %in);
my %selected;

# Keep host discovery and HTML rendering out of these option-editing tests.
sub has_command { return undef; }
sub hlink { return ""; }
sub ui_table_hr { return ""; }
sub ui_table_row { return ""; }
sub ui_yesno_radio { return ""; }

# ui_radio(name, selected, choices)
# Record each selected value so the XFS controls can be checked directly.
sub ui_radio
{
$selected{$_[0]} = $_[1];
return "";
}

do "$root/mount/linux-lib.pl" or die "linux-lib.pl: $@ $!";

# Native and legacy aliases must display the correct independent quota modes.
foreach my $case (
	[ 'uquota,gquota', 1, 1 ], [ 'usrquota,grpquota', 1, 1 ],
	[ 'uquota', 1, 0 ], [ 'gquota', 0, 1 ], [ 'quota', 1, 0 ],
	[ 'uqnoenforce,gqnoenforce', 2, 2 ], [ 'qnoenforce', 2, 0 ],
	[ 'noquota', 0, 0 ], [ 'pquota', 0, 0 ]) {
	my ($opts, $user, $group) = @$case;
	%options = map { $_ => "" } split(/,/, $opts);
	%selected = ( );
	generate_options("xfs", 0);
	is_deeply([ @selected{qw(xfs_usrquota xfs_grpquota)} ], [$user, $group],
		  "$opts displays the correct user and group quota modes");
	}

# Saving any mode must replace old aliases while preserving unrelated options.
foreach my $initial ('uquota,gquota', 'quota,usrquota,grpquota',
		    'uqnoenforce,gqnoenforce', 'qnoenforce', 'noquota') {
	foreach my $user (0..2) {
		foreach my $group (0..2) {
			%options = (map({ $_ => "" } split(/,/, $initial)),
				    inode64 => "", pquota => "", logbsize => "32k");
			%in = (lnx_nodev => 2, lnx_noexec => 2, lnx_nosuid => 2,
			       xfs_usrquota => $user, xfs_grpquota => $group);
			check_options("xfs", $root, "/test-xfs");
			my %expected = (inode64 => "", pquota => "", logbsize => "32k");
			# Keep the global disable when no accounting was requested.
			$expected{'noquota'} = ""
				if ($initial eq 'noquota' && !$user && !$group);
			$expected{'uquota'} = "" if ($user == 1);
			$expected{'uqnoenforce'} = "" if ($user == 2);
			$expected{'gquota'} = "" if ($group == 1);
			$expected{'gqnoenforce'} = "" if ($group == 2);
			is_deeply(\%options, \%expected,
				  "$initial changes to user=$user group=$group without stale aliases");
			}
		}
	}

done_testing();
