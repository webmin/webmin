# iscsi-server-lib.pl
# Common functions for managing and configuring an iSCSI server

BEGIN { push(@INC, ".."); };
use strict;
use warnings;
use WebminCore;
&init_config();
&foreign_require("raid");
&foreign_require("fdisk");
&foreign_require("lvm");
our (%text, %config);

# check_config()
# Returns undef if the iSCSI server is installed, or an error message if
# missing
sub check_config
{
return &text('check_etargets', "<tt>$config{'targets_file'}</tt>")
	if (!-r $config{'targets_file'});
return &text('check_eserver', "<tt>$config{'iscsi_server'}</tt>")
	if (!&has_command($config{'iscsi_server'}));
return undef;
}

# get_iscsi_config()
# Returns an array ref of entries from the iSCSI server config file
sub get_iscsi_config
{
my @rv;
my $fh = "CONFIG";
my $lnum = 0;
&open_readfile($fh, $config{'targets_file'}) || return [ ];
while(<$fh>) {
	s/\r|\n//g;
	s/#.*$//;
	my @w = split(/\s+/, $_);
	if ($w[0] =~ /^extent(\d+)/) {
		# An extent is a sub-section of some file or device
		my $ext = { 'type' => 'extent',
			    'num' => $1,
			    'line' => $lnum,
			    'device' => $w[1],
			    'start' => &parse_bytes($w[2]),
			    'size' => &parse_bytes($w[3]),
			   };
		push(@rv, $ext);
		}
	elsif ($w[0] =~ /^device(\d+)/) {
		# A device is a collection of extents
		my $dev = { 'type' => 'device',
			    'num' => $1,
			    'line' => $lnum,
			    'mode' => $w[1],
			    'extents' => [ @w[2..$#w] ],
			  };
		push(@rv, $dev);
		}
	elsif ($w[0] =~ /^target(\d+)/) {
		# A target is the export of an extent
		if (@w == 3) {
			# If flags are missing, assume read/write
			@w = ( $w[0], "ro", $w[1], $w[2] );
			}
		my $tar = { 'type' => 'target',
			    'num' => $1,
			    'line' => $lnum,
			    'flags' => $w[1],
                            'export' => $w[2],
			    'network' => $w[3] };
		push(@rv, $tar);
		}
	$lnum++;
	}
close($fh);
return \@rv;
}

# parse_bytes(str)
# Converts a string like 100MB into a number of bytes
sub parse_bytes
{
my ($str) = @_;
if ($str =~ /^(\d+)TB/i) {
	return $1 * 1024 * 1204 * 1024 * 1024;
	}
elsif ($str =~ /^(\d+)GB/i) {
	return $1 * 1204 * 1024 * 1024;
	}
elsif ($str =~ /^(\d+)MB/i) {
	return $1 * 1024 * 1024;
	}
elsif ($str =~ /^(\d+)KB/i) {
	return $1 * 1024;
	}
elsif ($str =~ /^\d+$/) {
	return $str;
	}
else {
	&error("Unknown size number $str");
	}
}

# is_iscsi_server_running()
# Returns the PID if the server process is running, or 0 if not
sub is_iscsi_server_running
{
return &check_pid_file($config{'pid_file'});
}

1;

