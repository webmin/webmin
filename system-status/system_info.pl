
use strict;
use warnings;
require 'system-status-lib.pl';
our (%text, %gconfig);

# list_system_info(&data, &in)
# Returns general information about the system, such as available disk space
sub list_system_info
{
my $info = &get_collected_info();
my @rv;
my @table;

my $table = { 'type' => 'table',
	      'desc' => $text{'right_header'},
	      'table' => \@table };
push(@rv, $table);

# Hostname
my $ip = $info && $info->{'ips'} ? $info->{'ips'}->[0]->[0]
				 : &to_ipaddress(get_system_hostname());
$ip = " ($ip)" if ($ip);
push(@table, { 'desc' => $text{'right_host'},
	       'value' => &get_system_hostname().$ip });

# Operating system
push(@table, { 'desc' => $text{'right_os'},
	       'value' => $gconfig{'os_version'} eq '*' ?
			$gconfig{'real_os_type'} :
			$gconfig{'real_os_type'}.' '.$gconfig{'real_os_version'}
	     });

# Webmin version
push(@table, { 'desc' => $text{'right_webmin'},
	       'value' => &get_webmin_version() });

# System time
my $tm = localtime(time());
if (&foreign_available("time")) {
	$tm = &ui_link('/time/', $tm);
	}
push(@table, { 'desc' => $text{'right_time'},
	       'value' => $tm });

# Kernel and architecture
if ($info->{'kernel'}) {
	push(@table, { 'desc' => $text{'right_kernel'},
		       'value' => &text('right_kernelon',
					$info->{'kernel'}->{'os'},
					$info->{'kernel'}->{'version'},
					$info->{'kernel'}->{'arch'}) });
	}

# CPU type and cores
if ($info->{'load'}) {
	my @c = @{$info->{'load'}};
	if (@c > 3) {
		push(@table, { 'desc' => $text{'right_cpuinfo'},
			       'value' => &text('right_cputype', @c) });
		}
	}

# System uptime
&foreign_require("proc");
my $uptime;
my ($d, $h, $m) = &proc::get_system_uptime();
if ($d) {
	$uptime = &text('right_updays', $d, $h, $m);
	}
elsif ($m) {
	$uptime = &text('right_uphours', $h, $m);
	}
elsif ($m) {
	$uptime = &text('right_upmins', $m);
	}
if ($uptime) {
	push(@table, { 'desc' => $text{'right_uptime'},
		       'value' => $uptime });
	}

# Running processes
if (&foreign_check("proc")) {
	my @procs = &proc::list_processes();
	my $pr = scalar(@procs);
	if (&foreign_available("proc")) {
		$pr = &ui_link('/proc/', $pr);
		}
	push(@table, { 'desc' => $text{'right_procs'},
		       'value' => $pr });
	}

# Load averages
if ($info->{'load'}) {
	my @c = @{$info->{'load'}};
	if (@c) {
		push(@table, { 'desc' => $text{'right_cpu'},
			       'value' => &text('right_load', @c) });
		}
	}

# CPU usage
if ($info->{'cpu'}) {
	my @c = @{$info->{'cpu'}};
	push(@table, { 'desc' => $text{'right_cpuuse'},
		       'value' => &text('right_cpustats', @c) });
	}

# Memory usage
if ($info->{'mem'}) {
	my @m = @{$info->{'mem'}};
	if (@m && $m[0]) {
		push(@table, { 'desc' => $text{'right_real'},
			       'value' => &text('right_used',
					&nice_size($m[0]*1024),
					&nice_size(($m[0]-$m[1])*1024)),
			       'chart' => [ $m[0], $m[0]-$m[1] ] });
		}

	if (@m && $m[2]) {
		push(@table, { 'desc' => $text{'right_virt'},
			       'value' => &text('right_used',
					&nice_size($m[2]*1024),
					&nice_size(($m[2]-$m[3])*1024)),
			       'chart' => [ $m[2], $m[2]-$m[3] ] });
		}
	}

# Disk space on local drives
if ($info->{'disk_total'}) {
	my ($total, $free) = ($info->{'disk_total'}, $info->{'disk_free'});
	push(@table, { 'desc' => $text{'right_disk'},
		       'value' => &text('right_used',
				   &nice_size($total),
				   &nice_size($total-$free)),
		       'chart' => [ $total, $total-$free ] });
	}

# Package updates
if ($info->{'poss'}) {
	my @poss = @{$info->{'poss'}};
	my @secs = grep { $_->{'security'} } @poss;
	my $msg;
	if (@poss && @secs) {
		$msg = &text('right_upsec', scalar(@poss),
					    scalar(@secs));
		}
	elsif (@poss) {
		$msg = &text('right_upneed', scalar(@poss));
		}
	else {
		$msg = $text{'right_upok'};
		}
	if (&foreign_available("package-updates")) {
		$msg = &ui_link("/package-updates/index.cgi?mode=updates", $msg);
		}
	push(@table, { 'desc' => $text{'right_update'},
		       'value' => $msg });
	}

return @rv;
}

1;
