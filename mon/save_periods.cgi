#!/usr/local/bin/perl
# save_periods.cgi
# Save all period directives

require './mon-lib.pl';
&ReadParse();
&error_setup($text{'periods_err'});
$conf = &get_mon_config();
@operiods = &find("period", $conf);

for($i=0; defined($in{"name_$i"}); $i++) {
	next if (!$in{"name_$i"});
	$in{"name_$i"} =~ /^\S+$/ ||
		&error(&text('periods_ename', $in{"name_$i"}));
	if (defined($in{"value_$i"})) {
		push(@periods,
		    { 'name' => 'period',
		      'values' => [ $in{"name_$i"}.":", $in{"value_$i"} ] } );
		}
	else {
		local @pv;
		if (!$in{"days_def_$i"}) {
			push(@pv, "wd {".$in{"dfrom_$i"}."-".
				  $in{"dto_$i"}."}");
			}
		if (!$in{"hours_def_$i"}) {
			$in{"hfrom_$i"} =~ /^(\d+)(am|pm|)$/ ||
				&error(&text('periods_ehour', $i+1));
			$in{"hto_$i"} =~ /^(\d+)(am|pm|)$/ ||
				&error(&text('periods_ehour', $i+1));
			push(@pv, "hr {".$in{"hfrom_$i"}."-".
				  $in{"hto_$i"}."}");
			}
		push(@periods,
		    { 'name' => 'period',
		      'values' => [ $in{"name_$i"}.":", @pv ] } );
		}
	}

for($i=0; $i<@operiods || $i<@periods; $i++) {
	&save_directive($conf, $operiods[$i], $periods[$i]);
	}
&flush_file_lines();

&redirect("");

