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

# find(&config, name)
# Returns all config objects with the given name
sub find
{
my ($conf, $name) = @_;
my @t = grep { $_->{'name'} eq $name } @$conf;
return wantarray ? @t : $t[0];
}

# find_value(&config, name)
# Returns all config values with the given name
sub find_value
{
my ($conf, $name) = @_;
my @rv = map { $_->{'value'} } &find($conf, $name);
return wantarray ? @rv : $rv[0];
}

# save_directive(&config, name, value)
# Creates, updates or deletes some directive
sub save_directive
{
my ($conf, $name, $value) = @_;
my $lref = &read_file_lines($config{'config_file'});
my $line = defined($value) ? $name." = ".$value : undef;
my $o = &find($conf, $name);
if ($o && defined($value)) {
	# Update a line
	$lref->[$o->{'line'}] = $line;
	$o->{'value'} = $value;
	}
elsif ($o && !defined($value)) {
	# Commenting out a line
	$lref->[$o->{'line'}] = "# ".$lref->[$o->{'line'}];
	}
elsif (!$o && defined($value)) {
	# Check if exists, but commented out
	my $cline;
	my $clnum = 0;
	foreach my $l (@$lref) {
		if ($l =~ /^#+\s*\Q$name\E\s*=/) {
			$cline = $clnum;
			last;
			}
		$clnum++;
		}
	my $dir = { 'name' => $name,
		    'value' => $value };
	if (defined($cline)) {
		# Comment back in
		$dir->{'line'} = $cline;
		$lref->[$cline] = $line;
		}
	else {
		# Add at end
		$dir->{'line'} = scalar(@$lref);
		push(@$lref, $line);
		}
	push(@$conf, $dir);
	}
}

# list_iscsi_connections()
# Returns a list of hash refs with details of active sessions
sub list_iscsi_connections
{
my @rv;
my $out = &backquote_command(
		"$config{'iscsiadm'} -m session -o show -P 3 2>/dev/null");
my $conn;
foreach my $l (split(/\r?\n/, $out)) {
	if ($l =~ /^Target:\s+(\S+):(\S+)/) {
		$conn = { 'name' => $1,
			  'target' => $2 };
		push(@rv, $conn);
		}
	elsif ($l =~ /Current\s+Portal:\s+(\S+):(\d+)/) {
		$conn->{'ip'} = $1;
		$conn->{'port'} = $2;
		}
	elsif ($l =~ /SID:\s+(\d+)/) {
		$conn->{'num'} = $1;
		}
	elsif ($l =~ /Iface\s+Transport:\s+(\S+)/) {
		$conn->{'proto'} = $1;
		}
	elsif ($l =~ /Attached\s+scsi\s+disk\s+(\S+)/) {
		$conn->{'device'} = "/dev/$1";
		}
	}
return @rv;
}

1;
