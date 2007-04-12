#!/usr/local/bin/perl
# save_filter.cgi
# Save user filter options

require './jabber-lib.pl';
&ReadParse();
&error_setup($text{'filter_err'});

$conf = &get_jabber_config();
$session = &find_by_tag("service", "id", "sessions", $conf);
$jsm = &find("jsm", $session);
$filter = &find("filter", $jsm);
$allow = &find("allow", $filter);

# Validate and store inputs
$in{'max'} =~ /^\d+$/ || &error($text{'filter_emax'});
&save_directive($filter, "max_size",
		[ [ "max_size", [ { }, 0, $in{'max'} ] ] ] );
$conds = &find("conditions", $allow);
foreach $c (@filter_conds) {
	if ($in{"cond_$c"}) {
		&save_directive($conds, $c, [ [ $c, [ { } ] ] ] );
		}
	else {
		&save_directive($conds, $c);
		}
	}
$acts = &find("actions", $allow);
foreach $c (@filter_acts) {
	if ($in{"act_$c"}) {
		&save_directive($acts, $c, [ [ $c, [ { } ] ] ] );
		}
	else {
		&save_directive($acts, $c);
		}
	}

&save_jabber_config($conf);
&redirect("");

