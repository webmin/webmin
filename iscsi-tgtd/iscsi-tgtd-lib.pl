# iscsi-tgtd-lib.pl
# Common functions for managing and configuring the iSCSI TGTD server

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
our ($list_disks_partitions_cache, $get_raidtab_cache,
     $list_logical_volumes_cache, $get_tgtd_config_cache);

# check_config()
# Returns undef if the iSCSI server is installed, or an error message if
# missing
sub check_config
{
return &text('check_econfig', "<tt>$config{'config_file'}</tt>")
	if (!-r $config{'config_file'});
return &text('check_etgtadm', "<tt>$config{'tgtadm'}</tt>")
	if (!&has_command($config{'tgtadm'}));
&foreign_require("init");
return &text('check_einit', "<tt>$config{'init_name'}</tt>")
	if (&init::action_status($config{'init_name'}) == 0);
return undef;
}

# get_tgtd_config()
# Parses the iSCSI server config file in an array ref of objects
sub get_tgtd_config
{
if (!$get_tgtd_config_cache) {
	$get_tgtd_config_cache = &read_tgtd_config_file($config{'config_file'});
	}
return $get_tgtd_config_cache;
}

# read_tgtd_config_file(file)
# Parses a single config file into an array ref
sub read_tgtd_config_file
{
my ($file) = @_;
my @rv;
my $lnum = 0;
my $parent;
my $lref = &read_file_lines($file, 1);
foreach my $l (@$lref) {
	$l =~ s/#.*$//;
	if ($l =~ /^\s*include\s(\S+)/) {
		# Include some other files
		my $ifile = $1;
		my $inc = &read_tgtd_config_file($ifile);
		push(@rv, @$inc);
		}
	elsif ($l =~ /^\s*<(\S+)\s+(.*)>/) {
		# Start of a block
		my $dir = { 'name' => $1,
			    'value' => $2,
			    'values' => [ split(/\s+/, $2) ],
			    'type' => 1,
			    'members' => [ ],
			    'file' => $file,
			    'line' => $lnum,
			    'eline' => $lnum,
			    'parent' => $parent };
		if ($parent) {
			push(@{$parent->{'members'}}, $dir);
			}
		else {
			push(@rv, $dir);
			}
		$parent = $dir;
		}
	elsif ($l =~ /^\s*<\/(\S+)>/) {
		# End of a block
		$parent->{'eline'} = $lnum;
		$parent = $parent->{'parent'};
		}
	elsif ($l =~ /^\s*(\S+)\s+(\S.*)/) {
		# Some directive in a block
		my $dir = { 'name' => $1,
			    'value' => $2,
			    'values' => [ split(/\s+/, $2) ],
			    'type' => 0,
			    'file' => $file,
			    'line' => $lnum,
			    'eline' => $lnum,
			    'parent' => $parent };
		if ($parent) {
			push(@{$parent->{'members'}}, $dir);
			}
		else {
			push(@rv, $dir);
			}
		}
	$lnum++;
	}
return \@rv;
}

1;
