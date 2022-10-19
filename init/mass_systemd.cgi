#!/usr/local/bin/perl
# Start or stop a bunch of systemd services

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

# Try to stop and restart first
if ($stop || $restart) {
	# Starting or stopping a bunch of services
	$access{'bootup'} || &error($text{'ss_ecannot'});
	$SIG{'TERM'} = 'ignore';	# Restarting webmin may kill this script
	foreach $s (@sel) {
		my ($ok, $out);
		my $is_webmin = $s eq 'webmin.service';
		if ($stop) {
			print &text('mass_ustopping', "<tt>$s</tt>"),"<br>\n";
			($ok, $out) = &stop_action($s)
				if (!$is_webmin);
			}
		elsif ($restart) {
			print &text('mass_urestarting', "<tt>$s</tt>"),"<br>\n";
			if (!$is_webmin) {
				($ok, $out) = &restart_action($s);
				}
			else {
				&restart_miniserv();
				}
			}
		print "<pre>$out</pre>" if ($out);
		if ($is_webmin) {
			print "$text{'mass_skipped'} : ". &text('mass_enoallow', $s),"<p></p>\n"
				if ($stop);
			print $text{'mass_ok'},"<p></p>\n"
				if ($restart);
			}
		elsif (!$ok) {
			print $text{'mass_failed'},"<p></p>\n";
			}
		else {
			print $text{'mass_ok'},"<p></p>\n";
			}
		}
	&webmin_log($stop ? 'massstop' : 'massrestart',
		    'systemd', join(" ", @sel));
	}

# Enable or disable
if ($enable || $disable) {
	# Enable or disable at boot
	$access{'bootup'} == 1 || &error($text{'edit_ecannot'});
	foreach $b (@sel) {
		if ($enable) {
			print &text('mass_uenable', "<tt>$b</tt>"),"<br>\n";
			&enable_at_boot($b);
			}
		else {
			print &text('mass_udisable', "<tt>$b</tt>"),"<br>\n";
			&disable_at_boot($b);
			}
		print $text{'mass_ok'},"<p></p>\n";

		}
	&webmin_log($enable ? 'massenable' : 'massdisable', 'systemd',
		    join(" ", @sel));
	}

# Try to start at last
if ($start) {
	# Starting a bunch of services
	$access{'bootup'} || &error($text{'ss_ecannot'});
	foreach $s (@sel) {
		if ($start) {
			print &text('mass_ustarting', "<tt>$s</tt>"),"<br>\n";
			($ok, $out) = &start_action($s);
			}
		print "<pre>$out</pre>" if ($out);;
		if (!$ok) {
			print $text{'mass_failed'},"<p></p>\n";
			}
		else {
			print $text{'mass_ok'},"<p></p>\n";
			}
		}
	&webmin_log('massstart', 'systemd', join(" ", @sel));
	}

if ($in{'return'}) {
	&ui_print_footer("edit_systemd.cgi?name=".&urlize($in{'return'}),
			 $text{'systemd_return'});
	}
else {
	&ui_print_footer("", $text{'index_return'});
	}
