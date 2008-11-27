
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
	return { 'up' => -1,
		 'desc' => $text{'monitor_nosuch'} };
	}
local $st = &get_drive_status($_[1]->{'drive'});
if (!$st->{'support'} || !$st->{'enabled'}) {
	return { 'up' => -1,
		 'desc' => $text{'monitor_nosmart'} };
	}
elsif (!$st->{'check'}) {
	return { 'up' => 0 };
	}
elsif ($st->{'errors'} && $_[1]->{'errors'}) {
	return { 'up' => 0 };
	}
else {
	return { 'up' => 1 };
	}
}

# status_monitor_dialog(type, &monitor)
# Return form for selecting a drive
sub status_monitor_dialog
{
local $rv;
local @drives = grep { $_->{'type'} eq 'ide' ||
		       $_->{'type'} eq 'scsi' } &fdisk::list_disks_partitions();
@drives = sort { $a->{'device'} cmp $b->{'device'} } @drives;
local ($inlist) = grep { $_->{'device'} eq $_[1]->{'drive'} } @drives;
$inlist = 1 if (!$_[1]->{'drive'});
$rv .= &ui_table_row($text{'monitor_drive'},
      &ui_select("drive", !$_[1]->{'drive'} ? $drives[0]->{'device'} :
			   $inlist ? $_[1]->{'drive'} : undef,
		 [ (map { [ $_->{'device'},
			   $_->{'desc'}.($_->{'model'} ?
				" ($_->{'model'})" : "") ] } @drives),
		   [ "", $text{'monitor_other'} ] ]).
      &ui_textbox("other", $inlist ? "" : $_[1]->{'drive'}, 15), 3);

$rv .= &ui_table_row($text{'monitor_errors'},
	&ui_radio("errors", $_[1]->{'errors'} || 0,
		[ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]));
return $rv;
}

# status_monitor_parse(type, &monitor, &in)
# Parse form for selecting a rule
sub status_monitor_parse
{
$_[1]->{'drive'} = $_[2]->{'drive'} || $_[2]->{'other'};
$_[1]->{'drive'} =~ /^\S+$/ || &error($text{'monitor_edrive'});
$_[1]->{'errors'} = $_[2]->{'errors'};
}

1;

