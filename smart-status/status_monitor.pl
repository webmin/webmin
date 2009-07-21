
do 'smart-status-lib.pl';

# status_monitor_list()
# Just one type is supported
sub status_monitor_list
{
if (&has_command($config{'smartctl'})) {
	return ( [ "smart", $text{'monitor_type'} ] );
	}
else {
	return ( );
	}
}

# status_monitor_status(type, &monitor, from-ui)
# Check the drive status
sub status_monitor_status
{
if (!-r $_[1]->{'drive'}) {
	# Could not find device
	return { 'up' => -1,
		 'desc' => $text{'monitor_nosuch'} };
	}
local @drives = &list_smart_disks_partitions();
local ($d) = grep { $_->{'device'} eq $_[1]->{'drive'} &&
		    $_->{'subdisk'} eq $_[1]->{'subdisk'} } @drives;
if (!$d) {
	# Not in list?!
	return { 'up' => -1,
		 'desc' => $text{'monitor_nosuch'} };
	}
local $st = &get_drive_status($d->{'device'}, $d);

# Record number of errors since last time
local %errors;
local $errors_file = "$module_config_directory/last-errors";
&read_file($errors_file, \%errors);
local %lasterrors = %errors;
$errors{$_[1]->{'drive'}} = $st->{'errors'};
&write_file($errors_file, \%errors);

if (!$st->{'support'} || !$st->{'enabled'}) {
	# SMART not enabled on device
	return { 'up' => -1,
		 'desc' => $text{'monitor_nosmart'} };
	}
elsif (!$st->{'check'}) {
	# Check failed
	return { 'up' => 0 };
	}
elsif ($st->{'errors'} && $_[1]->{'errors'} == 1) {
	# Errors found, and failing on any errors
	return { 'up' => 0,
		 'desc' => &text('monitor_errorsfound', $st->{'errors'}) };
	}
elsif ($st->{'errors'} && $_[1]->{'errors'} == 2 &&
       $st->{'errors'} > $lasterrors{$_[1]->{'drive'}}) {
	# Errors found and have increased
	return { 'up' => 0,
		 'desc' => &text('monitor_errorsinced', $st->{'errors'},
				 $lasterrors{$_[1]->{'drive'}}) };
	}
else {
	# All OK!
	return { 'up' => 1 };
	}
}

# status_monitor_dialog(type, &monitor)
# Return form for selecting a drive
sub status_monitor_dialog
{
local $rv;
local @drives = &list_smart_disks_partitions();
local ($inlist) = grep { $_->{'device'} eq $_[1]->{'drive'} &&
		         $_->{'subdisk'} eq $_[1]->{'subdisk'} } @drives;
$inlist = 1 if (!$_[1]->{'drive'});
$rv .= &ui_table_row($text{'monitor_drive'},
      &ui_select("drive", !$_[1]->{'drive'} ? $drives[0]->{'device'} :
			   $inlist ? $inlist->{'device'}.':'.$inlist->{'subdisk'} :
				     undef,
		 [ (map { [ $_->{'device'}.':'.$_->{'subdisk'},
			   $_->{'desc'}.($_->{'model'} ?
				" ($_->{'model'})" : "") ] } @drives),
		   [ "", $text{'monitor_other'} ] ]).
      &ui_textbox("other", $inlist ? "" : $_[1]->{'drive'}, 15), 3);

$rv .= &ui_table_row($text{'monitor_errors'},
	&ui_radio("errors", $_[1]->{'errors'} || 0,
		[ [ 1, $text{'yes'} ], [ 0, $text{'no'} ],
		  [ 2, $text{'monitor_errorsinc'} ] ]));
return $rv;
}

# status_monitor_parse(type, &monitor, &in)
# Parse form for selecting a rule
sub status_monitor_parse
{
if ($_[2]->{'drive'}) {
	($_[1]->{'drive'}, $_[1]->{'subdisk'}) = split(/:/, $_[2]->{'drive'});
	}
else {
	$_[1]->{'drive'} = $_[2]->{'other'};
	$_[1]->{'subdisk'} = undef;
	$_[1]->{'drive'} =~ /^\S+$/ || &error($text{'monitor_edrive'});
	}
$_[1]->{'errors'} = $_[2]->{'errors'};
}

1;

