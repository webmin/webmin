#!/usr/local/bin/perl
# Start or stop a bunch of launchd services

require './init-lib.pl';
&ReadParse();
@sel = split(/\0/, $in{'d'});
@sel || &error($text{'mass_enone'});

$start = 1 if ($in{'start'} || $in{'addboot_start'});
$stop = 1 if ($in{'stop'} || $in{'delboot_stop'});
$restart = 1 if ($in{'restart'} || $in{'delboot_restart'});
$enable = 1 if ($in{'addboot'} || $in{'addboot_start'});
$disable = 1 if ($in{'delboot'} || $in{'delboot_stop'});

&ui_print_unbuffered_header(undef, $start || $enable ? $text{'mass_ustart'}
					  : $text{'mass_ustop'}, "");

if ($start || $stop || $restart) {
	# Starting or stopping a bunch of services
	$access{'bootup'} || &error($text{'ss_ecannot'});
	foreach $s (@sel) {
		if ($start) {
			print &text('mass_ustarting', "<tt>$s</tt>"),"<p>\n";
			($ok, $out) = &start_action($s);
			}
		elsif ($stop) {
			print &text('mass_ustopping', "<tt>$s</tt>"),"<p>\n";
			($ok, $out) = &stop_action($s);
			}
		elsif ($restart) {
			print &text('mass_urestarting', "<tt>$s</tt>"),"<p>\n";
			($ok, $out) = &restart_action($s);
			}
		print "<pre>$out</pre>";
		if (!$ok) {
			print $text{'mass_failed'},"<p>\n";
			}
		else {
			print $text{'mass_ok'},"<p>\n";
			}
		}
	&webmin_log($start ? 'massstart' : $stop ? 'massstop' : 'massrestart',
		    'launchd', join(" ", @sel));
	}

if ($enable || $disable) {
	# Enable or disable at boot
	$access{'bootup'} == 1 || &error($text{'edit_ecannot'});
	foreach $b (@sel) {
		if ($enable) {
			print &text('mass_uenable', "<tt>$b</tt>"),"<p>\n";
			&enable_at_boot($b);
			}
		else {
			print &text('mass_udisable', "<tt>$b</tt>"),"<p>\n";
			&disable_at_boot($b);
			}
		}
	&webmin_log($enable ? 'massenable' : 'massdisable', 'launchd',
		    join(" ", @sel));
	}

if ($in{'return'}) {
	&ui_print_footer("edit_launchd.cgi?name=".&urlize($in{'return'}),
			 $text{'launchd_return'});
	}
else {
	&ui_print_footer("", $text{'index_return'});
	}
