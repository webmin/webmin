# solaris-driver.pl
# Functions for Solaris 10 printer drivers

$webmin_windows_driver = 1;
$cups_ppd_dir = "/etc/lp/ppd";
$lpoptions = &has_command("lpoptions.cups") ? "lpoptions.cups" : "lpoptions";

# is_windows_driver(path, &printer)
# Returns the server, share, username, password, workgroup, program
# if path is a webmin windows driver
sub is_windows_driver
{
return &is_webmin_windows_driver(@_);
}

# is_driver(path, &printer)
# Returns the driver name if some path is a Solaris driver, or undef
sub is_driver
{
local $ppd = $_[1]->{'ppd'} ? &parse_cups_ppd($_[1]->{'ppd'}) : undef;
if ($ppd && $ppd->{'NickName'}) {
	# Printer has a PPD file
	return { 'mode' => 1,
		 'manuf' => $ppd->{'Manufacturer'},
		 'model' => $ppd->{'ModelName'},
		 'nick' => $ppd->{'NickName'},
		 'desc' => $ppd->{'NickName'} };
	}
elsif ($_[1]->{'iface'}) {
	# Some other kind of interface file
	return { 'mode' => 2,
		 'file' => $_[1]->{'iface'},
		 'desc' => $_[1]->{'iface'} };
	}
else {
	# No driver
	return { 'mode' => 0,
		 'desc' => $text{'cups_none'} };
	}
}

# create_windows_driver(&printer, &driver)
sub create_windows_driver
{
return &create_webmin_windows_driver(@_);
}

# create_driver(&printer, &driver)
sub create_driver
{
local $drv = "$cups_ppd_dir/$_[0]->{'name'}.ppd";
if ($_[1]->{'mode'} == 0) {
	# No driver
	&system_logged("rm -f \"$drv\"");
	$_[0]->{'ppd'} = undef;
	return undef;
	}
elsif ($_[1]->{'mode'} == 2) {
	# A separate interface program
	&system_logged("rm -f \"$drv\"");
	$_[0]->{'ppd'} = undef;
	return $_[1]->{'file'};
	}
else {
	# A PPD driver, which replaces any interface program
	$_[0]->{'ppd'} = $_[1]->{'ppd'};
	return undef;
	}
}

# delete_driver(name)
sub delete_driver
{
&system_logged("rm -f \"$cups_ppd_dir/$_[0].ppd\"");
}

# driver_input(&printer, &driver)
sub driver_input
{
printf "<tr> <td><input type=radio name=mode value=0 %s> %s</td>\n",
	$_[1]->{'mode'} == 0 ? 'checked' : '', $text{'cups_none'};
print "<td>($text{'cups_nonemsg'})</td> </tr>\n";
printf "<tr> <td><input type=radio name=mode value=2 %s> %s</td>",
	$_[1]->{'mode'} == 2 ? 'checked' : '', $text{'cups_prog'};
printf "<td><input name=program size=40 value='%s'></td> </tr>\n",
	$_[1]->{'mode'} == 2 ? $_[0]->{'iface'} : '';

# Display all the CUPS drivers
printf "<tr> <td valign=top><input type=radio name=mode value=1 %s> %s</td>\n",
	$_[1]->{'mode'} == 1 ? 'checked' : '', $text{'cups_driver'};
print "<td><select name=ppd size=10>\n";
local (@ppds, $d, $f, $ppd, %cache, $outofdate, @files, %donefile);
open(FIND, "find '$config{'model_path'}' -type f -print |");
while(<FIND>) {
	chop;
	/([^\/]+)$/;
	next if ($donefile{$1}++);
	push(@files, $_);
	}
close(FIND);
&read_file("$module_config_directory/ppd-cache", \%cache);
foreach $f (@files) {
	if (!defined($cache{$f})) {
		$outofdate = $f;
		last;
		}
	}
if ($outofdate || scalar(keys %cache) != scalar(@files)) {
	# Cache is out of date
	undef(%cache);
	local %donecache;
	foreach $f (@files) {
		local $ppd = &parse_cups_ppd($f);
		$cache{$f} = $ppd->{'NickName'}
			if (!$donecache{$ppd->{'NickName'}}++);
		}
	&write_file("$module_config_directory/ppd-cache", \%cache);
	}
local %done;
foreach $f (sort { $cache{$a} cmp $cache{$b} } keys %cache) {
	if ($cache{$f} && !$done{$cache{$f}}++) {
		printf "<option value=%s %s>%s\n",
			$f, $_[1]->{'nick'} eq $cache{$f} ? 'selected' : '',
			$cache{$f};
		$currppd = $f if ($_[1]->{'nick'} eq $cache{$f});
		}
	}
print "</select>\n";
print "</td> </tr>\n";
return undef;
}

# parse_driver()
# Parse driver selection from %in and return a driver structure
sub parse_driver
{
if ($in{'mode'} == 0) {
	return { 'mode' => 0 };
	}
elsif ($in{'mode'} == 2) {
	$in{'program'} =~ /^(\S+)/ && -x $1 ||
		&error(&text('cups_eprog', $in{'program'}));
	return { 'mode' => 2,
		 'file' => $in{'program'} };
	}
elsif ($in{'mode'} == 1) {
	# CUPS printer driver
	local $ppd = &parse_cups_ppd($in{'ppd'});
	local $rv = { 'mode' => 1,
		      'ppd' => $in{'ppd'},
		      'nick' => $ppd->{'NickName'},
		      'manuf' => $ppd->{'Manufacturer'},
		      'model' => $ppd->{'ModelName'} };
	return $rv;
	}
}

1;

