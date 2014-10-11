
do 'smart-status-lib.pl';

# status_monitor_list()
# Just one type is supported
sub status_monitor_list
{
if (&has_command($config{'smartctl'})) {
	return ( [ "smart", $text{'monitor_type'} ],
		 [ "wearout", $text{'monitor_type2'} ] );
	}
else {
	return ( );
	}
}

# status_monitor_status(type, &monitor, from-ui)
# Check the drive status
sub status_monitor_status
{
local ($type, $mon, $ui) = @_;

local @drives = &list_smart_disks_partitions();
local ($d) = grep { ($_->{'device'} eq $mon->{'drive'} ||
		     $_->{'id'} eq $mon->{'drive'}) &&
		    $_->{'subdisk'} eq $mon->{'subdisk'} } @drives;
if (!$d) {
	# Not in list?!
	return { 'up' => -1,
		 'desc' => $text{'monitor_nosuch'} };
	}
local $st = &get_drive_status($d->{'device'}, $d);

if (!$st->{'support'} || !$st->{'enabled'}) {
	# SMART not enabled on device
	return { 'up' => -1,
		 'desc' => $text{'monitor_nosmart'} };
	}

if ($type eq "wearout") {
	# Check SSD wear level
	local $wo;
	foreach my $a (@{$st->{'attribs'}}) {
		if ($a->[0] eq "Media Wearout Indicator") {
			$wo = $a;
			last;
			}
		}
	if (!$wo) {
		return { 'up' => -1,
		         'desc' => $text{'monitor_nowearout'} };
		}
	if ($wo->[3] < $mon->{'wearlevel'}) {
		return { 'up' => 0,
			 'desc' => &text('monitor_wornout', $wo->[3]),
			 'value' => $wo->[3] };
		}
	else {
		return { 'up' => 1,
			 'value' => $wo->[3] };
		}
	}
else {
	# Record number of errors since last time
	local %errors;
	local $errors_file = "$module_config_directory/last-errors";
	&read_file($errors_file, \%errors);
	local %lasterrors = %errors;
	$errors{$mon->{'drive'}} = $st->{'errors'};
	&write_file($errors_file, \%errors);

	# Check for errors
	if (!$st->{'check'}) {
		# Check failed
		return { 'up' => 0 };
		}
	elsif ($st->{'errors'} && $mon->{'errors'} == 1) {
		# Errors found, and failing on any errors
		return { 'up' => 0,
			 'value' => $st->{'errors'},
			 'desc' => &text('monitor_errorsfound', $st->{'errors'}) };
		}
	elsif ($st->{'errors'} && $mon->{'errors'} == 2 &&
	       $st->{'errors'} > $lasterrors{$mon->{'drive'}}) {
		# Errors found and have increased
		return { 'up' => 0,
			 'value' => $st->{'errors'},
			 'desc' => &text('monitor_errorsinced', $st->{'errors'},
					 $lasterrors{$mon->{'drive'}}) };
		}
	else {
		# All OK!
		return { 'up' => 1,
			 'value' => $st->{'errors'} };
		}
	}
}

# status_monitor_dialog(type, &monitor)
# Return form for selecting a drive
sub status_monitor_dialog
{
local ($type, $mon) = @_;
local $rv;
local @drives = &list_smart_disks_partitions();
local ($inlist) = grep { ($_->{'device'} eq $mon->{'drive'} ||
			  $_->{'id'} eq $mon->{'drive'}) &&
		         $_->{'subdisk'} eq $mon->{'subdisk'} } @drives;
$inlist = 1 if (!$mon->{'drive'});
$rv .= &ui_table_row($text{'monitor_drive'},
      &ui_select("drive",
		 !$mon->{'drive'} ? $drives[0]->{'device'} :
		 $inlist ? ($inlist->{'id'} || $inlist->{'device'}).':'.
			     $inlist->{'subdisk'} :
			   undef,
		 [ (map { [ ($_->{'id'} || $_->{'device'}).':'.$_->{'subdisk'},
			   $_->{'desc'}.($_->{'model'} ?
				" ($_->{'model'})" : "") ] } @drives),
		   [ "", $text{'monitor_other'} ] ]).
      &ui_textbox("other", $inlist ? "" : $mon->{'drive'}, 15), 3);

if ($type eq "wearout") {
	$rv .= &ui_table_row($text{'monitor_wearlevel'},
		&ui_textbox("wearlevel", $mon->{'wearlevel'} || 10, 5)."%");
	}
else {
	$rv .= &ui_table_row($text{'monitor_errors'},
		&ui_radio("errors", $mon->{'errors'} || 0,
			[ [ 1, $text{'yes'} ], [ 0, $text{'no'} ],
			  [ 2, $text{'monitor_errorsinc'} ] ]));
	}
return $rv;
}

# status_monitor_parse(type, &monitor, &in)
# Parse form for selecting a rule
sub status_monitor_parse
{
local ($type, $mon, $in) = @_;
if ($in->{'drive'}) {
	($mon->{'drive'}, $mon->{'subdisk'}) = split(/:/, $in->{'drive'});
	}
else {
	$mon->{'drive'} = $in->{'other'};
	$mon->{'subdisk'} = undef;
	$mon->{'drive'} =~ /^\S+$/ || &error($text{'monitor_edrive'});
	}
if ($type eq "wearout") {
	$in->{'wearlevel'} =~ /^\d+(\.\d+)?$/ ||
		&error($text{'monitor_ewearlevel'});
	$mon->{'wearlevel'} = $in->{'wearlevel'};
	}
else {
	$mon->{'errors'} = $in->{'errors'};
	}
}

1;

