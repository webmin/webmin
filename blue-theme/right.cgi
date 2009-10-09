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

&popup_header(undef, &capture_function_output(\&WebminCore::theme_prehead));
print "<center>\n";

# Webmin logo
if (&get_product_name() eq 'webmin') {
	print "<a href=http://www.webmin.com/ target=_new><img src=images/webmin-blue.png border=0></a><p>\n";
	}

if ($level == 0) {
	# Show general system information
	print "<table width=70%>\n";

	# Hostname
	print "<tr> <td><b>$text{'right_host'}</b></td>\n";
	print "<td>",&get_system_hostname(),"</td> </tr>\n";

	# Operating system
	print "<tr> <td><b>$text{'right_os'}</b></td>\n";
	if ($gconfig{'os_version'} eq '*') {
		print "<td>$gconfig{'real_os_type'}</td> </tr>\n";
		}
	else {
		print "<td>$gconfig{'real_os_type'} $gconfig{'real_os_version'}</td> </tr>\n";
		}

	# Webmin version
	print "<tr> <td><b>$text{'right_webmin'}</b></td>\n";
	print "<td>",&get_webmin_version(),"</td> </tr>\n";

	# System time
	$tm = localtime(time());
	print "<tr> <td><b>$text{'right_time'}</b></td>\n";
	if (&foreign_available("time")) {
		$tm = "<a href=time/>$tm</a>";
		}
	print "<td>$tm</td> </tr>\n";

	# Ask status module for more
	&foreign_require("system-status");
	$info = &system_status::get_collected_info();

	# Kernel and CPU
	if ($info->{'kernel'}) {
		print "<tr> <td><b>$text{'right_kernel'}</b></td>\n";
		print "<td>",&text('right_kernelon',
				   $info->{'kernel'}->{'os'},
				   $info->{'kernel'}->{'version'},
				   $info->{'kernel'}->{'arch'}),"</td> </tr>\n";
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
		print "<tr> <td><b>$text{'right_uptime'}</b></td>\n";
		print "<td>$uptime</td> </tr>\n";
		}

	# Running processes
	if (&foreign_check("proc")) {
		@procs = &proc::list_processes();
		$pr = scalar(@procs);
		print "<tr> <td><b>$text{'right_procs'}</b></td>\n";
		if (&foreign_available("proc")) {
			$pr = "<a href=proc/>$pr</a>";
			}
		print "<td>$pr</td> </tr>\n";
		}

	# Load and memory info
	if ($info->{'load'}) {
		@c = @{$info->{'load'}};
		if (@c) {
			print "<tr> <td><b>$text{'right_cpu'}</b></td>\n";
			print "<td>",&text('right_load', @c),"</td> </tr>\n";
			}
		@m = @{$info->{'mem'}};
		if (@m && $m[0]) {
			print "<tr> <td><b>$text{'right_real'}</b></td>\n";
			print "<td>",&text('right_used',
				&nice_size($m[0]*1024),
				&nice_size(($m[0]-$m[1])*1024)),
			      "</td> </tr>\n";
			print "<tr> <td></td>\n";
			print "<td>",&bar_chart($m[0], $m[0]-$m[1], 1),
			      "</td> </tr>\n";
			}

		if (@m && $m[2]) {
			print "<tr> <td><b>$text{'right_virt'}</b></td>\n";
			print "<td>",&text('right_used',
				&nice_size($m[2]*1024),
				&nice_size(($m[2]-$m[3])*1024)),
			      "</td> </tr>\n";
			print "<tr> <td></td>\n";
			print "<td>",&bar_chart($m[2], $m[2]-$m[3], 1),
			      "</td> </tr>\n";
			}
		}

	# Disk space on local drives
	if ($info->{'disk_total'}) {
		($total, $free) = ($info->{'disk_total'}, $info->{'disk_free'});
		print "<tr> <td><b>$text{'right_disk'}</b></td>\n";
		print "<td>",&text('right_used',
			   &nice_size($total),
			   &nice_size($total-$free)),"</td> </tr>\n";
		print "<tr> <td></td>\n";
		print "<td>",&bar_chart($total, $total-$free, 1),
		      "</td> </tr>\n";
		}

	# Package updates
	if ($info->{'poss'}) {
		print "<tr> <td><b>$text{'right_updates'}</b></td>\n";
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
		print "<td>$msg</td> </tr>\n";
		}

	print "</table>\n";

	# Check for incorrect OS
	if (&foreign_check("webmin")) {
		&foreign_require("webmin", "webmin-lib.pl");
		&webmin::show_webmin_notifications();
		}
	}
elsif ($level == 3) {
	# Show Usermin user's information
	print "<h3>$text{'right_header5'}</h3>\n";
	print "<table width=70%>\n";

	# Host and login info
	print "<tr> <td><b>$text{'right_host'}</b></td>\n";
	print "<td>",&get_system_hostname(),"</td> </tr>\n";

	print "<tr> <td><b>$text{'right_os'}</b></td>\n";
	if ($gconfig{'os_version'} eq '*') {
		print "<td>$gconfig{'real_os_type'}</td> </tr>\n";
		}
	else {
		print "<td>$gconfig{'real_os_type'} $gconfig{'real_os_version'}</td> </tr>\n";
		}

	print "<tr> <td><b>$text{'right_usermin'}</b></td>\n";
	print "<td>",&get_webmin_version(),"</td> </tr>\n";

	# System time
	$tm = localtime(time());
	print "<tr> <td><b>$text{'right_time'}</b></td>\n";
	print "<td>$tm</td> </tr>\n";

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
			print "<tr> <td><b>$text{'right_uquota'}</b></td>\n";
			print "<td>",&text('right_out',
				&nice_size($usage*$bsize),
				&nice_size($quota*$bsize)),"</td> </tr>\n";
			print "<tr> <td></td>\n";
			print "<td>",&bar_chart($quota, $usage, 1),
			      "</td> </tr>\n";
			}
		}
	print "</table>\n";
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
	print "<img src=images/open.gif border=0>\n";
	print "<a href='right.cgi?$others'>$text</a>";
	}
else {
	print "<img src=images/closed.gif border=0>\n";
	print "<a href='right.cgi?open=$name$others'>$text</a>";
	}
print "</font><br>\n";
return $open{$name};
}

