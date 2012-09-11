# Functions for editing the Open-iSCSI configuration file
#
# http://www.server-world.info/en/note?os=CentOS_6&p=iscsi&f=2

BEGIN { push(@INC, ".."); };
use strict;
use warnings;
use WebminCore;
&init_config();
&foreign_require("fdisk");
&foreign_require("mount");
our (%text, %config, %gconfig, $module_config_file);

# check_config()
# Returns undef if the Open-iSCSI client is installed, or an error message if
# missing
sub check_config
{
return &text('check_econfig', "<tt>$config{'config_file'}</tt>")
	if (!-r $config{'config_file'});
return &text('check_eisciadm', "<tt>$config{'iscsiadm'}</tt>")
	if (!&has_command($config{'iscsiadm'}));
return undef;
}

# get_iscsi_config()
# Parses the iscsi client config file into an array ref of directives
sub get_iscsi_config
{
my @rv;
my $fh = "CONFIG";
my $lnum = 0;
&open_readfile($fh, $config{'config_file'}) || return [ ];
while(<$fh>) {
        s/\r|\n//g;
        s/#.*$//;
	if (/^(\S+)\s*=\s*(.*)/) {
		my $dir = { 'name' => $1,
			    'value' => $2,
			    'line' => $lnum };
		push(@rv, $dir);
		}
	$lnum++;
	}
close($fh);
return \@rv;
}

1;
