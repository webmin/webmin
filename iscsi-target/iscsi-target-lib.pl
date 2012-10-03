# iscsi-target-lib.pl
# Common functions for managing and configuring an iSCSI target

BEGIN { push(@INC, ".."); };
use strict;
use warnings;
use WebminCore;
&init_config();
&foreign_require("raid");
&foreign_require("fdisk");
&foreign_require("lvm");
&foreign_require("mount");
our (%text, %config, %gconfig, $module_config_file);

# check_config()
# Returns undef if the iSCSI server is installed, or an error message if
# missing
sub check_config
{
return &text('check_econfig', "<tt>$config{'config_file'}</tt>")
	if (!-r $config{'config_file'});
return &text('check_eietadm', "<tt>$config{'ietadm'}</tt>")
	if (!&has_command($config{'ietadm'}));
return undef;
}

# get_iscsi_config()
# Returns an array ref of entries from the iSCSI target config file
sub get_iscsi_config
{
my @rv;
my $fh = "CONFIG";
my $lnum = 0;
&open_readfile($fh, $config{'config_file'}) || return [ ];
my $parent = undef;
while(<$fh>) {
        s/\r|\n//g;
        s/#.*$//;
        my @w = split(/\s+/, $_);
	my $dir;
	if (@w) {
		$dir = { 'name' => $w[0],
			 'value' => $w[1],
			 'line' => $lnum };
		}
	if (/^\S/) {
		# Top-level directive
		$parent = $dir;
		push(@rv, $parent);
		}
	elsif (@w) {
		# Sub-directive
		$parent || &error("Sub-directive with no parent at line $lnum");
		$parent->{'members'} ||= [ ];
		push(@{$parent->{'members'}}, $dir);
		}
	$lnum++;
	}
close($fh);
return \@rv;
}

1;
