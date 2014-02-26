
do 'itsecur-lib.pl';

# status_monitor_list()
# Just one type is supported
sub status_monitor_list
{
return ( [ "rule", $text{'monitor_type'} ] );
}

# status_monitor_status(type, &monitor, from-ui)
# Check the logs to see if the rule has been hit recently
sub status_monitor_status
{
local $rv;
if ($_[2]) {
	# If this call is from the UI, then just return the current status
	local %oldstatus;
	&read_file("$config_directory/status/oldstatus", \%oldstatus);
	$rv = { 'up' => defined($oldstatus{$_[1]->{'id'}}) ?
                        $oldstatus{$_[1]->{'id'}} : -1 };
	}
else {
	# Actually check the logs
	local %lasttime;
	&read_file("$module_config_directory/lasttime", \%lasttime);
	local $l;
	local $stime;
	$rv = { 'up' => 1 };
	foreach $l (reverse(&parse_all_logs(1))) {
		if ($l->{'time'} > $lasttime{$_[1]->{'id'}}) {
			# Consider this line
			if ($l->{'rule'} == $_[1]->{'rule'}) {
				# Got a hit!
				$rv = { 'up' => 0 };
				}
			}
		$stime = $l->{'time'};
		}
	$lasttime{$_[1]->{'id'}} = $stime || time();
	&write_file("$module_config_directory/lasttime", \%lasttime);
	}
return $rv;
}

# status_monitor_dialog(type, &monitor)
# Return form for selecting a rule
sub status_monitor_dialog
{
local $rv;
$rv = "<tr> <td><b>$text{'monitor_rule'}</b></td>\n";
$rv .= "<td colspan=3><select name=rule>\n";
local $r;
foreach $r (&list_rules()) {
	if ($r->{'log'}) {
		$rv .= sprintf "<option value=%s %s>%s</option>\n",
			$r->{'num'},
			$_[1]->{'rule'} == $r->{'num'} ? "selected" : "",
			&text('monitor_num', $r->{'num'},
				&group_name($r->{'source'}),
				&group_name($r->{'dest'}));
		}
	}
$rv .= "</select></td> </tr>\n";
return $rv;
}

# status_monitor_parse(type, &monitor, &in)
# Parse form for selecting a rule
sub status_monitor_parse
{
$_[1]->{'rule'} = $_[2]->{'rule'};
}

1;

