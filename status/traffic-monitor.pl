# traffic-monitor.pl
# Check if network traffic is too high

sub get_traffic_status
{
local %traffic;
&read_file("$module_config_directory/traffic", \%traffic);
local $ifaces = &get_traffic_list();
local @i = @{$ifaces->{$_[0]->{'iface'}}};
if (@i) {
	local @l = split(/\s+/, $traffic{$_[0]->{'iface'}.'-'.$_[0]->{'dir'}});
	local $now = time();
	local $diff;
	if ($_[0]->{'dir'} == 0) {
		$diff = ($i[0]+$i[2]) - ($l[0]+$l[2]);
		}
	elsif ($_[0]->{'dir'} == 1) {
		$diff = $i[0] - $l[0];
		}
	else {
		$diff = $i[2] - $l[2];
		}
	if ($now <= $l[4]) {
		return { 'up' => 1 };
		}
	local $up = $diff / ($now - $l[4]) > $_[0]->{'bytes'} ? 0 : 1;
	@l = ( $i[0], $i[1], $i[2], $i[3], $now );
	$traffic{$_[0]->{'iface'}.'-'.$_[0]->{'dir'}} = join(" ", @l);
	&write_file("$module_config_directory/traffic", \%traffic);
	return { 'up' => $up };
	}
else {
	# Interface is gone!
	return { 'up' => -1 };
	}
}

sub show_traffic_dialog
{
print &ui_table_row(undef, $text{'traffic_desc'}, 4);

local $ifaces = &get_traffic_list();
print &ui_table_row($text{'traffic_iface'},
	&ui_select("iface", $_[0]->{'iface'},
		   [ map { [ $_ ] } sort { $a cmp $b } keys %$ifaces ]));

print &ui_table_row($text{'traffic_bytes'},
	&ui_textbox("bytes", $_[0]->{'bytes'}, 6));

print &ui_table_row($text{'traffic_dir'},
	&ui_radio("dir", int($_[0]->{'dir'}),
		[ [ 0, $text{'traffic_dir0'} ],
		  [ 1, $text{'traffic_dir1'} ],
		  [ 2, $text{'traffic_dir2'} ] ]), 3);
}

sub parse_traffic_dialog
{
local $ifaces = &get_traffic_list();
(keys %$ifaces) || &error($text{'traffic_eifaces'});
$in{'bytes'} =~ /^\d+$/ || &error($text{'traffic_ebytes'});
$_[0]->{'iface'} = $in{'iface'};
$_[0]->{'bytes'} = $in{'bytes'};
$_[0]->{'dir'} = $in{'dir'};
}

# get_traffic_list()
# Returns a map from interface names to arrays of bytes in, packets in,
# bytes out, packets out
sub get_traffic_list
{
local %rv;
if ($gconfig{'os_type'} eq 'freebsd') {
	# Get interfaces from netstat command
	open(NETSTAT, "netstat -nib |");
	while(<NETSTAT>) {
		if (/^(\S+)\s+(\d+)\s+(\S+)\s+(\d+\.\d+\.\d+\.\d+)\s+(\d+)\s+(\S+)\s+(\d+)\s+(\d+)\s+(\S+)\s+(\d+)/ && !$rv{$1}) {
			$rv{$1} = [ $7, $5, $10, $8 ];
			}
		}
	close(NETSTAT);
	}
else {
	# Get interfaces from Linux proc file
	open(TR, "/proc/net/dev");
	while(<TR>) {
		if (/^\s*([a-z0-9]+):\s*(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/) {
			$rv{$1} = [ $2, $3, $10, $11 ];
			}
		}
	close(TR);
	}
return \%rv;
}

