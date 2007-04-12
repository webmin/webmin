#!/usr/local/bin/perl
# save_service.cgi
# Save, create or delete a service

require './mon-lib.pl';
&ReadParse();
$conf = &get_mon_config();
$watch = $conf->[$in{'idx'}];
if ($in{'sidx'} ne '') {
	$oldservice = $service = $watch->{'members'}->[$in{'sidx'}];
	}
else {
	$service = { 'name' => 'service',
		     'indent' => '    ',
		     'members' => [ ] };
	}
&error_setup($text{'service_err'});

if ($in{'delete'}) {
	# Delete this service from the watch
	&save_directive($watch->{'members'}, $service, undef);
	}
else {
	# Validate and store service inputs
	$in{'name'} =~ /^\S+$/ || &error($text{'service_ename'});
	$service->{'values'} = [ $in{'name'} ];
	$in{'interval'} =~ /^\d+$/ || &error($text{'service_einterval'});

	# Save the description
	if ($in{'desc'}) {
		&set_directive($service->{'members'}, "description",
			       $in{'desc'});
		}
	else {
		&set_directive($service->{'members'}, "description");
		}

	&set_directive($service->{'members'}, "interval",
		       $in{'interval'}.$in{'interval_u'});
	if ($in{'monitor_def'}) {
		&set_directive($service->{'members'}, "monitor",
			       $in{'monitor'}.' '.$in{'args'});
		}
	else {
		$in{'other'} =~ /^\S+$/ || &error($text{'service_eother'});
		&set_directive($service->{'members'}, "monitor",
			       $in{'other'}.' '.$in{'args'});
		}

	# Validate and store each period
	for($i=0; defined($in{"idx_$i"}); $i++) {
		# Save period time
		next if ($in{"delete_$i"});
		local $period;
		if (!$in{'new'} && $in{"idx_$i"} ne '') {
			$period = $service->{'members'}->[$in{"idx_$i"}];
			}
		else {
			$period = { 'name' => 'period',
				    'members' => [ ] };
			}
		if ($in{"known_$i"} == 0) {
			$in{"pstr_$i"} =~ /\S/ ||
				&error($text{'service_epstr'});
			$period->{'values'} = [ $in{"pstr_$i"} ];
			}
		elsif ($in{"known_$i"} == 2) {
			$period->{'values'} = [ $in{"name_$i"}.":" ];
			}
		else {
			local @pv;
			if (!$in{"days_def_$i"}) {
				push(@pv, "wd {".$in{"dfrom_$i"}."-".
					  $in{"dto_$i"}."}");
				}
			if (!$in{"hours_def_$i"}) {
				$in{"hfrom_$i"} =~ /^(\d+)(am|pm|)$/ ||
					&error(&text('service_ehour', $i+1));
				$in{"hto_$i"} =~ /^(\d+)(am|pm|)$/ ||
					&error(&text('service_ehour', $i+1));
				push(@pv, "hr {".$in{"hfrom_$i"}."-".
					  $in{"hto_$i"}."}");
				}
			#@pv || &error(&text('service_eperiod', $i+1));
			$period->{'values'} = \@pv;
			}

		# Save alerts
		local (@alert, @upalert, @startupalert);
		for($j=0; defined($in{"alert_${i}_${j}"}); $j++) {
			next if (!$in{"alert_${i}_${j}"});
			local @v = ( $in{"alert_${i}_${j}"}, 
				     $in{"aargs_${i}_${j}"} );
			if ($in{"atype_${i}_${j}"} eq 'alert') {
				push(@alert, { 'name' => 'alert',
					       'values' => \@v });
				}
			elsif ($in{"atype_${i}_${j}"} eq 'upalert') {
				push(@upalert, { 'name' => 'upalert',
					         'values' => \@v });
				}
			else {
				push(@startupalert, { 'name' => 'startupalert',
					              'values' => \@v });
				}
			}
		&set_directive($period->{'members'}, "alert", @alert);
		&set_directive($period->{'members'}, "upalert", @upalert);
		&set_directive($period->{'members'}, "startupalert",
						     @startupalert);

		# Save other period options
		if ($in{"every_def_$i"}) {
			&set_directive($period->{'members'}, "alertevery");
			}
		else {
			$in{"every_$i"} =~ /^\d+$/ ||
				&error($text{'service_eevery'});
			&set_directive($period->{'members'}, "alertevery",
				       $in{"every_$i"}.$in{"every_${i}_u"});
			}

		if ($in{"after_def_$i"}) {
			&set_directive($period->{'members'}, "alertafter");
			}
		else {
			$in{"after_$i"} =~ /^\d+$/ ||
				&error($text{'service_eafter'});
			if ($in{"after_interval_$i"} =~ /^\d+$/) {
				&set_directive($period->{'members'},
					"alertafter", $in{"after_$i"}." ".
					$in{"after_interval_$i"}.
					$in{"after_interval_${i}_u"});
				}
			}

		if ($in{"num_def_$i"}) {
			&set_directive($period->{'members'}, "numalerts");
			}
		else {
			$in{"num_$i"} =~ /^\d+$/ ||
				&error($text{'service_enum'});
			&set_directive($period->{'members'}, "numalerts",
				       $in{"num_$i"});
			}

		push(@period, $period);
		}
	&set_directive($service->{'members'}, "period", @period);

	# Store the service in the config file
	&save_directive($watch->{'members'}, $oldservice, $service);
	}
&flush_file_lines();
&redirect("list_watches.cgi");

# set_directive(&config, name, value, value, ..)
sub set_directive
{
local @o = &find($_[1], $_[0]);
local @n = @_[2 .. @_-1];
local $i;
for($i=0; $i<@o || $i<@n; $i++) {
	local $idx = &indexof($o[$i], @{$_[0]}) if ($o[$i]);
	local $nv = ref($n[$i]) ? $n[$i] : { 'name' => $_[1],
					     'values' => [ $n[$i] ] }
						if (defined($n[$i]));
	if ($o[$i] && defined($n[$i])) {
		$_[0]->[$idx] = $nv;
		}
	elsif ($o[$i]) {
		splice(@{$_[0]}, $idx, 1);
		}
	else {
		push(@{$_[0]}, $nv);
		}
	}
}

