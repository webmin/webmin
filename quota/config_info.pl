# Hide Btrfs-specific configuration when it cannot be used.
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

1;
