#!/usr/local/bin/perl
# Save the limits for a Btrfs qgroup

require './quota-lib.pl';
&ReadParse();
$dir = $in{'dir'};

# Require write access to an allowed mounted Btrfs filesystem and reject
# malformed qgroup IDs before parsing or applying limits.
$access{'ro'} && &error($text{'btrfs_eedit'});
&can_edit_btrfs_filesys($dir) || &error($text{'btrfs_eallow'});
defined(&btrfs_quota_status) && &is_btrfs_fs($dir) ||
	&error($text{'btrfs_enotbtrfs'});
&valid_btrfs_qgroup_id($in{'qgroup'}) || &error($text{'btrfs_eqgroup'});
$in{'qgroup'} eq "0/5" && &error($text{'btrfs_etoplevel'});
&error_setup($text{'btrfs_esave'});

# parse_limit(name)
# Parse one optional byte limit from quota_input and validate its unit factor.
sub parse_limit
{
my ($name) = @_;

# A selected default means that this limit should be removed.
return undef if ($in{$name."_def"});

# Accept only positive decimal values and units offered by ui_bytesbox.
$in{$name} =~ /^\d+(?:\.\d+)?$/ && $in{$name} > 0 ||
	&error($text{'btrfs_elimit'});
local %units = map { $_, 1 } ( 1, 1024, 1024**2, 1024**3,
				     1024**4, 1024**5 );
$units{$in{$name."_units"}} || &error($text{'btrfs_elimit'});
return int($in{$name} * $in{$name."_units"});
}

# Parse both limits completely before making either filesystem change.
$max_referenced = &parse_limit("max_referenced");
$max_exclusive = &parse_limit("max_exclusive");

# Apply the existing ACL ceiling, converting its KiB value to bytes.
if ($access{'maxblocks'}) {
	$maxbytes = $access{'maxblocks'} * 1024;
	defined($max_referenced) && $max_referenced <= $maxbytes &&
	defined($max_exclusive) && $max_exclusive <= $maxbytes ||
		&error(&text('btrfs_emax', &nice_size($maxbytes)));
	}

# Refresh the selected qgroup so unchanged limits are not re-applied. This
# lookup only needs the stored limit values, so no filesystem sync is needed.
$qgroups = &list_btrfs_qgroups($dir, 0, \$listerr);
&error($listerr) if (!$qgroups);
($qgroup) = grep { $_->{'id'} eq $in{'qgroup'} } @$qgroups;
$qgroup || &error($text{'btrfs_eqgroup'});

# same_limit(first, second)
# Returns true when two optional byte limits are identical.
sub same_limit
{
my ($first, $second) = @_;
return !defined($first) && !defined($second) ||
	defined($first) && defined($second) && $first == $second;
}

# Compare the submitted referenced and exclusive limits with their current
# values before running either Btrfs command.
$same_referenced = &same_limit(
	$max_referenced, $qgroup->{'max_referenced'});
$same_exclusive = &same_limit(
	$max_exclusive, $qgroup->{'max_exclusive'});

# Apply only changed limits so each independent setting is left untouched when
# the submitted value already matches it.
if (!$same_referenced) {
	$err = &set_btrfs_qgroup_limit(
		$dir, $in{'qgroup'}, $max_referenced, 0);
	&error($err) if ($err);
	}
if (!$same_exclusive) {
	$err = &set_btrfs_qgroup_limit(
		$dir, $in{'qgroup'}, $max_exclusive, 1);
	&error($err) if ($err);
	}

# Log the completed update and return to the qgroup list.
&webmin_log("save", "btrfs", $in{'qgroup'}, \%in);
&redirect("list_btrfs.cgi?dir=".&urlize($dir));
