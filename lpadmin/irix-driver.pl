# irix-driver.pl
# Functions for webmin print and smb drivers.
# Very similar to the webmin driver, but with a different interface
# program selector

$webmin_windows_driver = 1;
$webmin_print_driver = 1;

# is_windows_driver(path)
# Returns a driver structure if some path is a windows driver
sub is_windows_driver
{
return &is_webmin_windows_driver(@_);
}

# is_driver(path)
# Returns a structure containing the details of a driver
sub is_driver
{
return &is_webmin_driver(@_);
}

# create_windows_driver(&printer, &driver)
# Creates a new windows printer driver
sub create_windows_driver
{
return &create_webmin_windows_driver(@_);
}

# create_driver(&printer, &driver)
# Creates a new local printer driver and returns the path
sub create_driver
{
return &create_webmin_driver(@_);
}

# delete_driver(name)
sub delete_driver
{
&delete_webmin_driver(@_);
}

# driver_input(&printer, &driver)
sub driver_input
{
local ($prn, $drv) = @_;

printf "<tr> <td><input type=radio name=drv value=0 %s> %s</td>\n",
	$drv->{'mode'} == 0 ? "checked" : "", $text{'webmin_none'};
print "<td>($text{'webmin_remotemsg'})</td> </tr>\n";

printf "<tr> <td><input type=radio name=drv value=2 %s> %s</td>\n",
	$drv->{'mode'} == 2 ? "checked" : "", $text{'webmin_model'};
print "<td><select name=iface>\n";
opendir(DIR, $config{'model_path'});
while($f = readdir(DIR)) {
	if ($f =~ /^\./) { next; }
	$path = "$config{'model_path'}/$f";
	printf "<option value=\"$path\" %s>$f</option>\n",
		$path eq $prn{'iface'} ? "selected" : "";
	}
closedir(DIR);
print "</select></td> </tr>\n";

if (&has_ghostscript()) {
	local $out = &backquote_command("$config{'gs_path'} -help 2>&1", 1);
	if ($out =~ /Available devices:\n((\s+.*\n)+)/) {
		print "<tr> <td valign=top>\n";
		printf "<input type=radio name=drv value=1 %s>\n",
			$drv->{'mode'} == 1 ? "checked" : "";
		print "$text{'webmin_driver'}</td> <td valign=top>";
		foreach $d (split(/\s+/, $1)) { $drvsupp{$d}++; }
		print "<select name=driver size=7>\n";
		foreach $d (&list_webmin_drivers()) {
			if ($drvsupp{$d->[0]}) {
				printf "<option %s>%s</option>\n",
				    $d->[1] eq $drv->{'type'} ? "selected" : "",
				    $d->[1];
				}
			}
		print "</select>&nbsp;&nbsp;";
		print "<select name=dpi size=7>\n";
		printf "<option value=\"\" %s>Default</option>\n",
			$drv->{'dpi'} ? "" : "selected";
		foreach $d (75, 100, 150, 200, 300, 600) {
			printf "<option value=\"$d\" %s>$d DPI</option>\n",
				$drv->{'dpi'} == $d ? "selected" : "";
			}
		print "</select></td> </tr>\n";
		}
	else {
		print "<tr> <td colspan=2>",
		      &text('webmin_edrivers', "<tt>$config{'gs_path'}</tt>"),
		      "</td> </tr>\n";
		}
	}
else {
	print "<tr> <td colspan=2>",
	      &text('webmin_egs', "<tt>$config{'gs_path'}</tt>"),
	      "</td> </tr>\n";
	}
return undef;
}

# parse_driver()
# Parse driver selection from %in and return a driver structure
sub parse_driver
{
if ($in{'drv'} == 0) {
	return { 'mode' => 0 };
	}
elsif ($in{'drv'} == 2) {
	(-x $in{'iface'}) || &error("'$in{'iface'}' does not exist");
	return { 'mode' => 2,
		 'program' => $in{'iface'} };
	}
elsif ($in{'drv'} == 1) {
	return { 'mode' => 1,
		 'type' => $in{'driver'},
		 'dpi' => $in{'dpi'} };
	}
}

1;

