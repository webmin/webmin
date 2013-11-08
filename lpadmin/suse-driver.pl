# suse-driver.pl
# Functions for APS print filters, as used by SUSE

@paper_sizes = ( [ 'a4', 'A4' ],
		 [ 'a4dj', 'A4 inkjet' ],
		 [ 'a3', 'A3' ],
		 [ 'letter', 'US Letter' ],
		 [ 'letterdj', 'US Letter inkjet' ],
		 [ 'note', 'Note' ],
		 [ 'legal', 'Legal' ],
		 [ 'ledger', 'Ledger' ],
		 [ 'a0', 'A0' ],
		 [ 'a1', 'A1' ],
		 [ 'a2', 'A2' ],
		 [ 'a5', 'A5' ],
		 [ 'a6', 'A6' ],
		 [ 'a7', 'A7' ],
		 [ 'a8', 'A8' ],
		 [ 'a9', 'A9' ],
		 [ 'a10', 'A10' ],
		 [ 'b0', 'B0' ],
		 [ 'b1', 'B1' ],
		 [ 'b2', 'B2' ],
		 [ 'b3', 'B3' ],
		 [ 'b4', 'B4' ],
		 [ 'b5', 'B5' ],
		 [ 'archE', 'archE' ],
		 [ 'archD', 'archD' ],
		 [ 'archC', 'archC' ],
		 [ 'archB', 'archB' ],
		 [ 'archA', 'archA' ],
		 [ 'flsa', 'flsa' ],
		 [ 'flse', 'flse' ],
		 [ 'halfletter', 'Half Letter' ],
		 [ '11x17', '11x17' ] );
$apsfilter_dir = "/var/lib/apsfilter/bin";
$apsfilter_prog = "/var/lib/apsfilter/apsfilter";
$apsfilter_config = "/var/lib/apsfilter/template/apsfilterrc.gs_device_name";
$apsfilter_base = "/etc/apsfilterrc";
$driver_dir = "/etc/gs.upp";
$webmin_windows_driver = 1;

open(DRIVERS, "$module_root_directory/drivers");
while(<DRIVERS>) {
	if (/^(\S+)\s+(.*)/) {
		$driver{$1} = $2 if (!$driver{$1});
		}
	}
close(DRIVERS);
open(STP, "stp");
while(<STP>) {
	if (/^(\S+)\s+(.*)/) {
		$stp{$1} = $2 if (!$stp{$1});
		}
	}
close(STP);
foreach $u (&list_uniprint()) {
	$u->[1] =~ s/,.*$//;
	$driver{"$u->[0].upp"} = $u->[1];
	}

# is_windows_driver(path, %driver)
# Returns a driver structure if some path is a windows driver
sub is_windows_driver
{
return &is_webmin_windows_driver(@_);
}

# is_driver(path, &printer)
# Returns a structure containing the details of a driver
sub is_driver
{
if (!$_[0]) {
	return { 'mode' => 0,
		 'desc' => "$text{'suse_none'}" };
	}
elsif ($_[0] =~ /$apsfilter_dir\/([^-]+)-([^-]+)-([^-]+)-([^-]+)-([^-]+)$/) {
	# Looks like an APS driver from suse (old style)
	local $rv =  {	'mode' => 1,
			'device' => $1,
		 	'paper' => $2,
		 	'method' => $3,
			'colour' => $4,
			'res' => $5 };
	local $desc = $driver{$rv->{'device'}} ? $driver{$rv->{'device'}} :
		      $rv->{'device'} =~ /^PS_/ ? "Postscript"
						: $rv->{'device'};
	$rv->{'desc'} = $rv->{'res'} ? "$desc ($rv->{'res'} DPI)" : $desc;
	return $rv;
	}
#elsif ($_[0] =~ /$apsfilter_dir\/([^-]+)--([^-]+)-([^-]+)$/ &&
#       -r "$driver_dir/$1") {
#	# Looks like a new-style APS suse driver
#	local $rv = { 'mode' => 3,
#		      'method' => $2 };
#	open(GS, "$driver_dir/$1");
#	while(<GS>) {
#		s/\r|\n//g;
#		if (/^-sDEVICE=(\S+)/) { $rv->{'device'} = $1; }
#		elsif (/^-sPAPERSIZE=(\S+)/) { $rv->{'paper'} = $1; }
#		elsif (/^-sCOLOR=(\S+)/) { $rv->{'colour'} = $1; }
#		elsif (/^-r(\S+)/) { $rv->{'res'} = $1; }
#		elsif (/^-supModel="(.*)"/) { $rv->{'desc'} = $1; }
#		elsif (/^-sModel="(.*)"/) { $rv->{'model'} = $1; }
#		elsif (/^\@(\S+\.upp)/) { $rv->{'device'} = $1; }
#		else { push(@{$rv->{'extra'}}, $_); }
#		}
#	close(GS);
#	return $rv;
#	}
elsif ($_[0] =~ /$apsfilter_dir\/([^-]+)-([^-]+)-([^-]+)$/) {
	# Null APS driver?
	return { 'mode' => 0,
		 'desc' => 'None' };
	}
else {
	# Some other kind of driver
	return { 'mode' => 2,
		 'file' => $_[0],
		 'desc' => $_[0] };
	}
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
local ($prn, $drv) = @_;
if ($drv->{'mode'} == 0) {
	return undef;
	}
elsif ($drv->{'mode'} == 2) {
	return $drv->{'file'};
	}
else {
	local $device;
	if ($drv->{'device'} eq 'ps') {
		$device = "PS_$drv->{'res'}dpi";
		}
	else {
		$device = $drv->{'device'};
		}
	local $aps = "$apsfilter_dir/$device-$drv->{'paper'}-".
		     "$drv->{'method'}-$drv->{'colour'}-$drv->{'res'}";
	&lock_file($aps);
	symlink($apsfilter_prog, $aps);
	&unlock_file($aps);
	if (!-r "$apsfilter_base.$device") {
		&lock_file("$apsfilter_base.$device");
		local $conf = &read_file_contents($apsfilter_config);
		$conf =~ s/<gs_device_name>/$device/g;
		&open_tempfile(CONF, ">$apsfilter_base.$device");
		&print_tempfile(CONF, $conf);
		&close_tempfile(CONF);
		&unlock_file("$apsfilter_base.$device");
		}
	return $aps;
	}
}

# delete_driver(name)
sub delete_driver
{
}

# driver_input(&printer, &driver)
sub driver_input
{
local ($prn, $drv) = @_;
local ($found, $d);

printf "<tr> <td><input type=radio name=mode value=0 %s> %s</td>\n",
	$drv->{'mode'} == 0 ? "checked" : "", $text{'suse_none'};
print "<td>($text{'suse_nonemsg'})</td> </tr>\n";

printf "<tr> <td><input type=radio name=mode value=2 %s> %s</td>\n",
	$drv->{'mode'} == 2 ? "checked" : "", $text{'suse_prog'};
printf "<td><input name=iface value=\"%s\" size=35></td> </tr>\n",
	$drv->{'mode'} == 2 ? $drv->{'file'} : "";

if ($drv->{'mode'} == 2 || 1) {
	# Show input for old-style suse printer
	printf "<tr> <td valign=top><input type=radio name=mode value=1 %s>\n",
		$drv->{'mode'} == 1 ? "checked" : "";
	print "$text{'suse_driver'}</td> <td><table width=100%>";

	print "<tr> <td valign=top><b>$text{'suse_printer'}</b></td>\n";
	print "<td colspan=3><select size=10 name=device>\n";
	printf "<option value=ps %s>Postscript</option>\n",
		$drv->{'device'} =~ /^PS_/ ? 'selected' : '';
	$found++ if ($drv->{'device'} =~ /^PS_/);
	foreach $d (&list_uniprint()) {
		local $u = "$d->[0].upp";
		printf "<option value=%s %s>%s</option>\n",
			$u, $drv->{'device'} eq $u ? 'selected' : '', $d->[1];
		$found++ if ($drv->{'device'} eq $u);
		}
	local $out = &backquote_command("$config{'gs_path'} -help 2>&1", 1);
	$out =~ /Available devices:\n((\s+.*\n)+)/i;
	foreach $d (split(/\s+/, $1)) {
		if ($driver{$d}) {
			printf "<option value=%s %s>%s</option>\n",
				$d, $drv->{'device'} eq $d ? 'selected' : '',
				$driver{$d};
			$found++ if ($drv->{'device'} eq $d);
			}
		}
	print "<option selected value=$drv->{'device'}>$drv->{'device'}</option>\n"
		if (!$found && $drv->{'device'});
	print "</select></td> </tr>\n";

	print "<tr> <td><b>$text{'suse_res'}</b></td>\n";
	print "<td><input name=res size=8 value='$drv->{'res'}'></td>\n";

	print "<td><b>$text{'suse_colour'}</b></td>\n";
	printf "<td><input name=colour type=radio value=color %s> %s\n",
		$drv->{'colour'} eq 'mono' ? '' : 'checked', $text{'yes'};
	printf "<input name=colour type=radio value=color %s> %s</td> </tr>\n",
		$drv->{'colour'} eq 'mono' ? 'checked' : '', $text{'no'};

	print "<tr> <td><b>$text{'suse_paper'}</b></td>\n";
	print "<td><select name=paper>\n";
	foreach $p (@paper_sizes) {
		printf "<option value=%s %s>%s</option>\n",
			$p->[0], $drv->{'paper'} eq $p->[0] ? 'selected' : '',
			$p->[1];
		}
	print "</select></td>\n";

	print "<td><b>$text{'suse_method'}</b></td>\n";
	printf "<td><input type=radio name=method value=auto %s> %s\n",
		$drv->{'method'} eq 'ascii' ? '' : 'checked',
		$text{'suse_auto'};
	printf "<input type=radio name=method value=ascii %s> %s</td> </tr>\n",
		$drv->{'method'} eq 'ascii' ? 'checked' : '',
		$text{'suse_ascii'};

	print "</table></td> </tr>\n";
	}
else {
	# Show input for new-style suse printer (NOT DONE YET!)
	printf "<tr> <td valign=top><input type=radio name=mode value=3 %s>\n",
		$drv->{'mode'} == 3 ? "checked" : "";
	print "$text{'suse_yast2'}</td> <td><table width=100%>";

	print "<tr> <td valign=top><b>$text{'suse_printer'}</b></td>\n";
	print "<td colspan=3><select size=10 name=device>\n";
	printf "<option value=ps %s>Postscript</option>\n",
		$drv->{'device'} eq 'PS' ? 'selected' : '';
	$found++ if ($drv->{'device'} eq 'PS');
	local $out = &backquote_command("$config{'gs_path'} -help 2>&1", 1);
	$out =~ /Available devices:\n((\s+.*\n)+)/i;
	foreach $d (split(/\s+/, $1)) {
		if ($d ne 'stp' && $driver{$d}) {
			printf "<option value=%s %s>%s</option>\n",
				$d, $drv->{'device'} eq $d ? 'selected' : '',
				$driver{$d};
			$found++ if ($drv->{'device'} eq $d);
			}
		}
	foreach $d (&list_uniprint()) {
		local $u = "$d->[0].upp";
		printf "<option value=%s %s>%s</option>\n",
			$u, $drv->{'device'} eq $u ? 'selected' : '', $d->[1];
		$found++ if ($drv->{'device'} eq $u);
		}
	foreach $s (sort { $a cmp $b } keys %stp) {
		printf "<option value=%s.stp %s>%s</option>\n",
			$s, $drv->{'device'} eq 'stp' &&
			    $drv->{'model'} eq $s ? 'selected' : '', $stp{$s};
		$found++ if ($drv->{'device'} eq 'stp' &&
			     $drv->{'model'} eq $s);
		}
	print "<option selected value=$drv->{'device'}>$drv->{'device'}</option>\n"
		if (!$found && $drv->{'device'});
	print "</select></td> </tr>\n";

	print "<tr> <td><b>$text{'suse_colour'}</b></td>\n";
	printf "<td><input name=colour type=radio value=color %s> %s\n",
		$drv->{'colour'} eq 'mono' ? '' : 'checked', $text{'yes'};
	printf "<input name=colour type=radio value=color %s> %s</td>\n",
		$drv->{'colour'} eq 'mono' ? 'checked' : '', $text{'no'};

	print "<td><b>$text{'suse_paper'}</b></td>\n";
	print "<td><select name=paper>\n";
	foreach $p (@paper_sizes) {
		printf "<option value=%s %s>%s</option>\n",
			$p->[0], $drv->{'paper'} eq $p->[0] ? 'selected' : '',
			$p->[1];
		}
	print "</select></td> </tr>\n";

	print "<tr> <td><b>$text{'suse_res'}</b></td>\n";
	printf "<td><input type=radio name=res_def value=1 %s> %s\n",
		$drv->{'res'} ? '' : 'checked', $text{'suse_auto'};
	printf "<input type=radio name=res_def value=0 %s>\n",
		$drv->{'res'} ? 'checked' : '';
	print "<input name=res size=8 value='$drv->{'res'}'></td>\n";

	print "<td><b>$text{'suse_method'}</b></td>\n";
	print "<td><select name=method>\n";
	foreach $m ('auto', 'ascii', 'raw') {
		printf "<option value=%s %s>%s</option>\n",
			$m, $drv->{'method'} eq $m ? 'selected' : '',
			$text{"suse_$m"};
		}
	print "</select></td> </tr>\n";

	print "<tr> <td><b>$text{'suse_extra'}</b></td>\n";
	print "<td colspan=3><input name=extra size=50 value='",
	      join(" ", @{$drv->{'extra'}}),"'></td> </tr>\n";

	print "</table></td> </tr>\n";
	}
}

# parse_driver()
# Parse driver selection from %in and return a driver structure
sub parse_driver
{
if ($in{'mode'} == 0) {
	return { 'mode' => 0 };
	}
elsif ($in{'mode'} == 2) {
	(-x $in{'iface'}) || &error(&text('suse_eprog', $in{'iface'}));
	return { 'mode' => 2,
		 'file' => $in{'iface'} };
	}
elsif ($in{'mode'} == 3) {
	# New suse printer (NOT DONE YET!)
	# All the other odd files created by yast2 need to be supported
	$in{'device'} || &error($text{'suse_edriver'});
	$in{'res_def'} || $in{'res'} =~ /^\d+$/ ||
		$in{'res'} =~ /^\d+x\d+$/ || &error($text{'suse_eres'});
	}
elsif ($in{'mode'} == 1) {
	# Old-style suse printer
	$in{'device'} || &error($text{'suse_edriver'});
	$in{'res'} =~ /^\d+$/ || &error(&text('suse_eres', $in{'res'}));
	return { 'mode' => 1,
		 'device' => $in{'device'},
		 'paper' => $in{'paper'},
		 'method' => $in{'method'},
		 'colour' => $in{'colour'},
		 'res' => $in{'res'} };
	}
}

1;

