#!/usr/local/bin/perl
# mass_start_stop.cgi
# Start or stop multiple actions at once

require './init-lib.pl';
&ReadParse();
@sel = split(/\0/, $in{'idx'});
@sel || &error($text{'mass_enone2'});

$start = 1 if ($in{'start'} || $in{'addboot_start'});
$stop = 1 if ($in{'stop'} || $in{'delboot_stop'});
$restart = 1 if ($in{'restart'});
$enable = 1 if ($in{'addboot'} || $in{'addboot_start'});
$disable = 1 if ($in{'delboot'} || $in{'delboot_stop'});

&ui_print_unbuffered_header(undef, $start || $enable ? $text{'mass_start'} :
				   $restart ? $text{'mass_restart'} :
					      $text{'mass_stop'}, "");

# In case the action was Webmin
$SIG{'TERM'} = 'IGNORE';

if ($start || $stop || $restart) {
	# Starting or stopping a bunch of actions
	&foreign_require("proc", "proc-lib.pl");
	$access{'bootup'} || &error($text{'ss_ecannot'});

	# build list of normal and broken actions
	($initrl) = &get_inittab_runlevel();
	@iacts = &list_actions();
	foreach $a (@iacts) {
		@ac = split(/\s+/, $a);
		push(@acts, $ac[0]);
		local $order = "9" x $config{'order_digits'};
		if ($ac[0] =~ /^\//) {
			push(@actsf, $ac[0]);
			}
		else {
			push(@actsf, "$config{'init_dir'}/$ac[0]");
			local @lvls = &action_levels(
				$start || $restart ? 'S' : 'K', $ac[0]);
			foreach $lon (@lvls) {
				local ($l, $o, $n) = split(/\s+/, $lon);
				if ($l eq $initrl) {
					$order = $o;
					last;
					}
				}
			}
		push(@orders, $order);
		}

	if ($start || $restart) {
		@sel = sort { $orders[$a] <=> $orders[$b] } @sel;
		}
	else {
		@sel = sort { $orders[$b] <=> $orders[$a] } @sel;
		}
	foreach $idx (@sel) {
		local $cmd = "$actsf[$idx] ".($start ? "start" :
					      $restart ? "restart" :
						         "stop");
		print &text('ss_exec', "<tt>$cmd</tt>"),"<p>\n";
		print "<pre>";
		&clean_environment();
		&foreign_call("proc", "safe_process_exec_logged", $cmd, 0, 0, STDOUT, undef, 1);
		&reset_environment();
		print "</pre>\n";
		push(@selacts, $acts[$idx]);
		}
	&webmin_log($start ? 'massstart' :
		    $restart ? 'massrestart' : 'massstop', 'action',
		    join(" ", @selacts));
	}

if ($enable || $disable) {
	# Enabling or disabling a bunch of actions
	$access{'bootup'} == 1 || &error($text{'edit_ecannot'});
	@iacts = &list_actions();
	foreach $a (@iacts) {
		@ac = split(/\s+/, $a);
		push(@acts, $ac[0]);
		}
	@toboot = map { $acts[$_] } @sel;
	foreach $b (@toboot) {
		if ($b =~ /^\//) {
			&error(&text('mass_ebroken', $ac[0]));
			}
		}
	if ($enable) {
		# Enable them all
		foreach $b (@toboot) {
			print &text('mass_enable', "<tt>$b</tt>"),"<p>\n";
			&enable_at_boot($b);
			}
		}
	else {
		# Disable them all
		foreach $b (@toboot) {
			print &text('mass_disable', "<tt>$b</tt>"),"<p>\n";
			&disable_at_boot($b);
			}
		}
	&webmin_log($enable ? 'massenable' : 'massdisable', 'action',
		    join(" ", @toboot));
	}

&ui_print_footer("", $text{'index_return'});

