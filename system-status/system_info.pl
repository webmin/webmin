
use strict;
use warnings;
require 'system-status-lib.pl';
our (%text, %gconfig, $module_name, %config);

# list_system_info(&data, &in)
# Returns general information about the system, such as available disk space
sub list_system_info
{
my $info = &get_collected_info();
my @rv;
my @table;
my @raw = $info;

# Refresh button for root
if (&foreign_available($module_name) && $config{'collect_interval'} ne 'none') {
	push(@rv, { 'type' => 'link',
		    'id' => 'recollect',
		    'priority' => 100,
		    'desc' => $text{'right_recollect'},
		    'link' => '/'.$module_name.'/recollect.cgi' });
	}

# Table of system info
my $table = { 'type' => 'table',
	      'id' => 'sysinfo',
	      'desc' => $text{'right_header'},
	      'priority' => 100,
	      'table' => \@table,
	      'raw' => \@raw };
push(@rv, $table);

if (&show_section('host')) {
	# Hostname
	my $ip = $info && $info->{'ips'} ? $info->{'ips'}->[0]->[0]
					 : &to_ipaddress(get_system_hostname());
	$ip = " ($ip)" if ($ip);
	push(@table, { 'desc' => $text{'right_host'},
		       'value' => &get_system_hostname().$ip });

	# Operating system
	my $os = &html_escape($gconfig{'os_version'} eq '*' ?
				$gconfig{'real_os_type'} :
				$gconfig{'real_os_type'}.' '.
				  $gconfig{'real_os_version'});
	push(@table, { 'desc' => $text{'right_os'},
		       'value' => $os
		     });

	# Webmin version
	my $webmin_version = &get_webmin_version();
	push(@table, { 'desc' => $text{'right_webmin'},
		       'value' => $webmin_version });
	push(@raw, { 'webmin_version' => $webmin_version });

	# Versions of other important modules, where available
	# I fully admit that putting this here rather than in module-specific
	# code is a hack, but the current API doesn't offer good alternative.
	foreach my $v ([ "virtual-server", $text{'right_vvirtualmin'} ],
		       [ "server-manager", $text{'right_vvm2'} ]) {
		if (&foreign_available($v->[0])) {
			my %vinfo = &get_module_info($v->[0]);
			push(@table, { 'desc' => $v->[1],
				       'value' => $vinfo{'version'} });
			push(@raw, { ($v->[0] eq 'virtual-server' ? 
				'vm_version' : 'cm_version') => $vinfo{'version'} });
			}
		}

	# System time
	my $tm = localtime(time());
	if (&foreign_available("time")) {
		$tm = &ui_link($gconfig{'webprefix'}.'/time/', $tm);
		}
	push(@table, { 'desc' => $text{'right_time'},
		       'value' => $tm });
	}

if (&show_section('cpu')) {
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
	}

# Temperatures, if available
if ($info->{'cputemps'} && &show_section('temp')) {
	my @temps;
	foreach my $t (@{$info->{'cputemps'}}) {
		push(@temps, $t->{'core'}.": ".
			     &convert_temp_units($t->{'temp'}));
		}
	push(@table, { 'desc' => $text{'right_cputemps'},
		       'value' => join(" ", @temps),
		       'wide' => 1 });
	}
if ($info->{'drivetemps'} && &show_section('temp')) {
	my @temps;
	foreach my $t (@{$info->{'drivetemps'}}) {
		my $short = $t->{'device'};
		$short =~ s/^\/dev\///;
		my $emsg = "";
		if ($t->{'errors'}) {
			$emsg .= " (<font color=red>".
			    &text('right_driveerr', $t->{'errors'}).
			    "</font>)";
			}
		elsif ($t->{'failed'}) {
			$emsg .= " (<font color=red>".
			    $text{'right_drivefailed'}.
			    "</font>)";
			}
		push(@temps, $short.": ".
			     &convert_temp_units($t->{'temp'}).$emsg);
		}
	push(@table, { 'desc' => $text{'right_drivetemps'},
		       'value' => join(" ", @temps),
		       'wide' => 1 });
	}

# System uptime
&foreign_require("proc");
if (&show_section('load')) {
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
			$pr = &ui_link($gconfig{'webprefix'}.'/proc/', $pr);
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
	}

# Memory usage
if ($info->{'mem'} && &show_section('mem')) {
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
if ($info->{'disk_total'} && &show_section('disk')) {
	my ($total, $free) = ($info->{'disk_total'}, $info->{'disk_free'});
	push(@table, { 'desc' => $text{'right_disk'},
		       'value' => &text('right_used',
				   &nice_size($total),
				   &nice_size($total-$free)),
		       'chart' => [ $total, $total-$free ] });
	}

# Warnings about filesytems running now on space
if ($info->{'disk_fs'} && &show_section('disk')) {
	foreach my $fs (@{$info->{'disk_fs'}}) {
		next if (!$fs->{'total'});
		if ($fs->{'free'} == 0) {
			my $msg = &text('right_fsfull',
					"<tt>$fs->{'dir'}</tt>",
					&nice_size($fs->{'total'}));
			push(@rv, { 'type' => 'warning',
				    'level' => 'danger',
				    'warning' => $msg });
			}
		elsif ($fs->{'free'}*1.0 / $fs->{'total'} < 0.01) {
			my $msg = &text('right_fsnearly',
					"<tt>$fs->{'dir'}</tt>",
					&nice_size($fs->{'total'}),
					&nice_size($fs->{'free'}));
			push(@rv, { 'type' => 'warning',
				    'level' => 'warn',
				    'warning' => $msg });
			}
		next if (!$fs->{'itotal'});
		if ($fs->{'ifree'} == 0) {
			my $msg = &text('right_ifsfull',
					"<tt>$fs->{'dir'}</tt>",
					$fs->{'itotal'});
			push(@rv, { 'type' => 'warning',
				    'level' => 'danger',
				    'warning' => $msg });
			}
		elsif ($fs->{'ifree'}*1.0 / $fs->{'itotal'} < 0.01) {
			my $msg = &text('right_ifsnearly',
					"<tt>$fs->{'dir'}</tt>",
					$fs->{'itotal'},
					$fs->{'ifree'});
			push(@rv, { 'type' => 'warning',
				    'level' => 'warn',
				    'warning' => $msg });
			}
		}
	}

# Package updates
if ($info->{'poss'} && &show_section('poss')) {
	my @poss = @{$info->{'poss'}};
	&foreign_require("package-updates");
	my %prog;
	foreach my $p (&package_updates::get_update_progress()) {
		%prog = (%prog, (map { $_, 1 } split(/\s+/, $p->{'pkgs'})));
		}
	@poss = grep { !$prog{$_->{'name'}} } @poss;
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
		$msg = &ui_link($gconfig{'webprefix'}."/package-updates/index.cgi?mode=updates", $msg);
		}
	push(@table, { 'desc' => $text{'right_updates'},
		       'value' => $msg,
		       'wide' => 1 });
	}

return @rv;
}

# convert_temp_units(celsius)
# Given a number in celsius, convert and format it nicely
sub convert_temp_units
{
my ($c) = @_;
if ($config{'collect_units'}) {
	return int(($c * 9.0 / 5) + 32)."&#8457;";
	}
else {
	return int($c)."&#8451;";
	}
}

# show_section(name)
# Returns 1 if some section is visible to the current user
sub show_section
{
my ($s) = @_;
my %access = &get_module_acl();
$access{'show'} ||= "";
if ($access{'show'} eq '*') {
	return 1;
	}
else {
	return &indexof($s, split(/\s+/, $access{'show'})) >= 0;
	}
}

1;
