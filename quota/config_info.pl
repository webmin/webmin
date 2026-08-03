# Build and parse the Btrfs-specific module configuration field.
require './quota-lib.pl';

# config_pre_load(info, [order])
# Hide Btrfs-specific settings unless both a mounted Btrfs filesystem and the
# command-line tool needed to manage it are available.
sub config_pre_load
{
my ($info, $order) = @_;
my @btrfs = &list_btrfs_filesystems();
return if (@btrfs && &has_command("btrfs"));

# Remove the field from both the configuration metadata and display order.
delete($info->{'btrfs_mode'});
@$order = grep { $_ ne "btrfs_mode" } @$order if ($order);
}

# show_btrfs_mode(mode)
# Display the accounting mode selector, defaulting unknown values to full mode.
sub show_btrfs_mode
{
my ($mode) = @_;
$mode = "full" if ($mode ne "simple");
return &ui_radio("btrfs_mode", $mode,
	[ [ "full", $text{'config_btrfs_full'} ],
	  [ "simple", $text{'config_btrfs_simple'} ] ]);
}

# parse_btrfs_mode()
# Store only a supported mode and fall back to full accounting otherwise.
sub parse_btrfs_mode
{
return $in{'btrfs_mode'} eq "simple" ? "simple" : "full";
}

1;
