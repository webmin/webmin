#!/usr/local/bin/perl
# Show server or domain information

# XXX re-enable
#use strict;
#use warnings;
require 'gray-theme/gray-theme-lib.pl';
&ReadParse();
&load_theme_library();
my %text = &load_language($current_theme);
my $bar_width = 300;

my $prehead = defined(&WebminCore::theme_prehead) ?
		&capture_function_output(\&WebminCore::theme_prehead) : "";
&popup_header(undef, $prehead);
print "<center>\n";

# Webmin logo
if (&get_product_name() eq 'webmin') {
	print "<a href=http://www.webmin.com/ target=_new><img src=images/webmin-blue.png border=0></a><p>\n";
	}

# Get system info to show
my @info = &list_combined_system_info();

foreach my $info (@info) {
	print &ui_table_start($info->{'desc'}, undef, 2);
	if ($info->{'type'} eq 'table') {
		foreach my $t (@{$info->{'table'}}) {
			my $chart = "";
			if ($t->{'chart'}) {
				my @c = @{$t->{'chart'}};
				if (@c == 2) {
					$chart = &bar_chart_three(
						$c[0], $c[1], 0, $c[0]-$c[1]);
					}
				else {
					$chart = &bar_chart_three(
						$c[0], $c[1], $c[2],
						$c[0]-$c[1]-$c[2]);
					}
				$chart = "<br>".$chart;
				}
			print &ui_table_row($t->{'desc'}, $t->{'value'}.$chart);
			}
		}
	print &ui_table_end();
	}

if ($level == 3) {
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
my ($total, $used1, $used2, $used3) = @_;
my $rv;
my $w1 = int($bar_width*$used1/$total)+1;
my $w2 = int($bar_width*$used2/$total);
my $w3 = int($bar_width*$used3/$total);
$rv .= sprintf "<img src=images/red.gif width=%s height=10>", $w1;
$rv .= sprintf "<img src=images/purple.gif width=%s height=10>", $w2;
$rv .= sprintf "<img src=images/blue.gif width=%s height=10>", $w3;
$rv .= sprintf "<img src=images/grey.gif width=%s height=10>",
	$bar_width - $w1 - $w2 - $w3;
return $rv;
}

