#!/usr/local/bin/perl
# Start or stop a bunch of win32 services

require './init-lib.pl';
&ReadParse();
@sel = split(/\0/, $in{'d'});
@sel || &error($text{'mass_enone2'});

$start = 1 if ($in{'start'} || $in{'addboot_start'});
$stop = 1 if ($in{'stop'} || $in{'delboot_stop'});
$enable = 1 if ($in{'addboot'} || $in{'addboot_start'});
$disable = 1 if ($in{'delboot'} || $in{'delboot_stop'});

&ui_print_unbuffered_header(undef, $start || $enable ? $text{'mass_start'}
					  : $text{'mass_stop'}, "");

if ($start || $stop) {
	# Starting or stopping a bunch of services
	$access{'bootup'} || &error($text{'ss_ecannot'});
	foreach $s (@sel) {
		if ($start) {
			print &text('mass_starting', "<tt>$s</tt>"),"<p>\n";
			$err = &start_win32_service($s);
			}
		else {
			print &text('mass_stopping', "<tt>$s</tt>"),"<p>\n";
			$err = &stop_win32_service($s);
			}
		if ($err) {
			print "<pre>$err</pre>";
			print $text{'mass_failed'},"<p>\n";
			}
		else {
			print $text{'mass_ok'},"<p>\n";
			}
		}
	}

if ($enable || $disable) {
	# Enable or disable at boot
	$access{'bootup'} == 1 || &error($text{'edit_ecannot'});
	foreach $b (@sel) {
		if ($enable) {
			print &text('mass_enable', "<tt>$b</tt>"),"<p>\n";
			&enable_win32_service($b);
			}
		else {
			print &text('mass_disable', "<tt>$b</tt>"),"<p>\n";
			&disable_win32_service($b);
			}
		}
	&webmin_log($enable ? 'massenable' : 'massdisable', 'action',
		    join(" ", @sel));
	}

&ui_print_footer("", $text{'index_return'});
