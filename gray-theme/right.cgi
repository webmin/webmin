#!/usr/local/bin/perl
# Show server or domain information

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
&ReadParse();
&load_theme_library();
if (&get_product_name() eq "usermin") {
	$level = 3;
	}
else {
	$level = 0;
	}
%text = &load_language($current_theme);
$bar_width = 300;
foreach $o (split(/\0/, $in{'open'})) {
	push(@open, $o);
	$open{$o} = 1;
	}

$prehead = defined(&WebminCore::theme_prehead) ?
		&capture_function_output(\&WebminCore::theme_prehead) : "";
&popup_header(undef, $prehead);
print "<center>\n";

# Webmin logo
if (&get_product_name() eq 'webmin') {
	print "<a href=http://www.webmin.com/ target=_new><img src=images/webmin-blue.png border=0></a><p>\n";
	}

if ($level == 0) {
	# Show general system information
	print &ui_table_start(undef, undef, 2);

	# Ask status module for collected info
	&foreign_require("system-status");
	$info = &system_status::get_collected_info();

	# Hostname
	$ip = $info && $info->{'ips'} ? $info->{'ips'}->[0]->[0] :
				&to_ipaddress(get_system_hostname());
	$ip = " ($ip)" if ($ip);
	$host = &get_system_hostname().$ip;
	if (&foreign_available("net")) {
		$host = "<a href=net/list_dns.cgi>$host</a>";
		}
	print &ui_table_row($text{'right_host'},
		$host);

	# Operating system
	print &ui_table_row($text{'right_os'},
		$gconfig{'os_version'} eq '*' ?
		    $gconfig{'real_os_type'} :
		    $gconfig{'real_os_type'}." ".$gconfig{'real_os_version'});

	# Webmin version
	print &ui_table_row($text{'right_webmin'},
		&get_webmin_version());

	# System time
	$tm = localtime(time());
	print &ui_table_row($text{'right_time'},
		&foreign_available("time") ? "<a href=time/>$tm</a>" : $tm);

	# Kernel and CPU
	if ($info->{'kernel'}) {
		print &ui_table_row($text{'right_kernel'},
			&text('right_kernelon',
			      $info->{'kernel'}->{'os'},
			      $info->{'kernel'}->{'version'},
			      $info->{'kernel'}->{'arch'}));
		}

	# CPU type and cores
	if ($info->{'load'}) {
		@c = @{$info->{'load'}};
		if (@c > 3) {
			print &ui_table_row($text{'right_cpuinfo'},
				&text('right_cputype', @c));
			}
		}

	# Temperatures, if available
	if ($info->{'cputemps'}) {
		my @temps;
		foreach my $t (@{$info->{'cputemps'}}) {
			push(@temps, $t->{'core'}.": ".
				     int($t->{'temp'})."&#8451;");
			}
		print &ui_table_row($text{'right_cputemps'},
			join(", ", @temps));
		}
	if ($info->{'drivetemps'}) {
		my @temps;
		foreach my $t (@{$info->{'drivetemps'}}) {
			my $short = $t->{'device'};
			$short =~ s/^\/dev\///;
			my $emsg;
			if ($t->{'errors'}) {
				$emsg .= " (<font color=red>".
					 &text('right_driveerr', $t->{'errors'}).
					 "</font>)";
				}
			push(@temps, $short.": ".$t->{'temp'}."&#8451;".$emsg);
			}
		print &ui_table_row($text{'right_drivetemps'},
			join(", ", @temps));
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
		if (&foreign_available("init")) {
			$uptime = "<a href=init/>$uptime</a>";
			}
		print &ui_table_row($text{'right_uptime'}, $uptime);
		}

	# Running processes
	if (&foreign_check("proc")) {
		@procs = &proc::list_processes();
		$pr = scalar(@procs);
		print &ui_table_row($text{'right_procs'},
			&foreign_available("proc") ? "<a href=proc/>$pr</a>"
						   : $pr);
		}

	# Load averages
	if ($info->{'load'}) {
		@c = @{$info->{'load'}};
		if (@c) {
			print &ui_table_row($text{'right_cpu'},
				&text('right_load', @c));
			}
		}

	# CPU usage
	if ($info->{'cpu'}) {
		@c = @{$info->{'cpu'}};
		print &ui_table_row($text{'right_cpuuse'},
			&text('right_cpustats', @c));
		}

	# Memory usage
	if ($info->{'mem'}) {
		@m = @{$info->{'mem'}};
		if (@m && $m[0]) {
			print &ui_table_row($text{'right_real'},
				&text('right_used',
				      &nice_size($m[0]*1024),
				      &nice_size(($m[0]-$m[1])*1024))."<br>\n".
				&bar_chart($m[0], $m[0]-$m[1], 1));
			}

		if (@m && $m[2]) {
			print &ui_table_row($text{'right_virt'},
				&text('right_used',
			 	      &nice_size($m[2]*1024),
				      &nice_size(($m[2]-$m[3])*1024))."<br>\n".
				&bar_chart($m[2], $m[2]-$m[3], 1));
			}
		}

	# Disk space on local drives
	if ($info->{'disk_total'}) {
		($total, $free) = ($info->{'disk_total'}, $info->{'disk_free'});
		$disk = &text('right_used',
			      &nice_size($total),
			      &nice_size($total-$free));
		if (&foreign_available("mount")) {
			$disk = "<a href=mount/>$disk</a>";
			}
		print &ui_table_row($text{'right_disk'},
			$disk."<br>\n".
			&bar_chart($total, $total-$free, 1));
		}

	# Package updates
	if ($info->{'poss'}) {
		@poss = @{$info->{'poss'}};
		@secs = grep { $_->{'security'} } @poss;
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
			$msg = "<a href='package-updates/index.cgi?mode=updates'>$msg</a>";
			}
		print &ui_table_row($text{'right_updates'}, $msg);
		}

	print &ui_table_end();

	# Check for incorrect OS
	if (&foreign_check("webmin")) {
		&foreign_require("webmin", "webmin-lib.pl");
		&webmin::show_webmin_notifications();
		}
	}
elsif ($level == 3) {
	# Show Usermin user's information
	print "<h3>$text{'right_header5'}</h3>\n";
	print &ui_table_start(undef, undef, 2);

	# Host and login info
	print &ui_table_row($text{'right_host'},
		&get_system_hostname());

	# Operating system
	print &ui_table_row($text{'right_os'},
		$gconfig{'os_version'} eq '*' ?
		    $gconfig{'real_os_type'} :
		    $gconfig{'real_os_type'}." ".$gconfig{'real_os_version'});

	# Webmin version
	print &ui_table_row($text{'right_usermin'},
		&get_webmin_version());

	# System time
	$tm = localtime(time());
	print &ui_table_row($text{'right_time'},
		&foreign_available("time") ? "<a href=time/>$tm</a>" : $tm);

	# Disk quotas
	if (&foreign_installed("quota")) {
		&foreign_require("quota", "quota-lib.pl");
		$n = &quota::user_filesystems($remote_user);
		$usage = 0;
		$quota = 0;
		for($i=0; $i<$n; $i++) {
			if ($quota::filesys{$i,'hblocks'}) {
				$quota += $quota::filesys{$i,'hblocks'};
				$usage += $quota::filesys{$i,'ublocks'};
				}
			elsif ($quota::filesys{$i,'sblocks'}) {
				$quota += $quota::filesys{$i,'sblocks'};
				$usage += $quota::filesys{$i,'ublocks'};
				}
			}
		if ($quota) {
			$bsize = $quota::config{'block_size'};
			print &ui_table_row($text{'right_uquota'},
				&text('right_out',
				      &nice_size($usage*$bsize),
				      &nice_size($quota*$bsize))."<br>\n".
				&bar_chart($quota, $usage, 1));
			}
		}
	print &ui_table_end();
	}

print "</center>\n";
&popup_footer();

# bar_chart(total, used, blue-rest)
# Returns HTML for a bar chart of a single value
sub bar_chart
{
local ($total, $used, $blue) = @_;
local $rv;
$rv .= sprintf "<img src=images/red.gif width=%s height=10>",
	int($bar_width*$used/$total)+1;
if ($blue) {
	$rv .= sprintf "<img src=images/blue.gif width=%s height=10>",
		$bar_width - int($bar_width*$used/$total)-1;
	}
else {
	$rv .= sprintf "<img src=images/white.gif width=%s height=10>",
		$bar_width - int($bar_width*$used/$total)-1;
	}
return $rv;
}

# bar_chart_three(total, used1, used2, used3)
# Returns HTML for a bar chart of three values, stacked
sub bar_chart_three
{
local ($total, $used1, $used2, $used3) = @_;
local $rv;
local $w1 = int($bar_width*$used1/$total)+1;
local $w2 = int($bar_width*$used2/$total);
local $w3 = int($bar_width*$used3/$total);
$rv .= sprintf "<img src=images/red.gif width=%s height=10>", $w1;
$rv .= sprintf "<img src=images/purple.gif width=%s height=10>", $w2;
$rv .= sprintf "<img src=images/blue.gif width=%s height=10>", $w3;
$rv .= sprintf "<img src=images/grey.gif width=%s height=10>",
	$bar_width - $w1 - $w2 - $w3;
return $rv;
}

# collapsed_header(text, name)
sub collapsed_header
{
local ($text, $name) = @_;
print "<br><font style='font-size:16px'>";
local $others = join("&", map { "open=$_" } grep { $_ ne $name } @open);
$others = "&$others" if ($others);
if ($open{$name}) {
	print "<img src=images/gray-open.gif border=0>\n";
	print "<a href='right.cgi?$others'>$text</a>";
	}
else {
	print "<img src=images/gray-closed.gif border=0>\n";
	print "<a href='right.cgi?open=$name$others'>$text</a>";
	}
print "</font><br>\n";
return $open{$name};
}

