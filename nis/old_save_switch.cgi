#!/usr/local/bin/perl
# save_switch.cgi
# Save client nsswitch configuration

require './nis-lib.pl';
&ReadParse();
&error_setup($text{'switch_err'});

foreach $sv (split(/\s+/, $in{'list'})) {
	if (defined($o = $in{"order_$sv"})) {
		$o =~ /\S/ ||
			&error(&text('switch_eorder', $text{"switch_$sv"}));
		&save_nsswitch($sv, $o);
		}
	else {
		local @order;
		for($i=1; defined($o = $in{"order_${sv}_${i}"}); $i++) {
			push(@order, $o) if ($o);
			}
		&save_nsswitch($sv, join(" ", @order));
		}
	}
&flush_file_lines();
&redirect("");

