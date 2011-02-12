# cups-driver.pl
# Functions for CUPS printer drivers

$webmin_windows_driver = 0;
$cups_ppd_dir = "/etc/cups/ppd";
$lpoptions = &has_command("lpoptions.cups") ? "lpoptions.cups" : "lpoptions";

# is_windows_driver(path, &printer)
# Returns the server, share, username, password, workgroup, program
# if path is a webmin windows driver
sub is_windows_driver
{
if ($_[1]->{'dev'} =~ /^smb:\/\/(\S*):(\S*)\@(\S*)\/(\S*)\/(\S*)$/) {
	return { 'user' => $1,
		 'pass' => $2,
		 'workgroup' => $3,
		 'server' => $4,
		 'share' => $5,
		 'program' => $_[0] };
	}
elsif ($_[1]->{'dev'} =~ /^smb:\/\/(\S*):(\S*)\@(\S*)\/(\S*)$/) {
	return { 'user' => $1,
		 'pass' => $2,
		 'server' => $3,
		 'share' => $4,
		 'program' => $_[0] };
	}
elsif ($_[1]->{'dev'} =~ /^smb:\/\/(\S*)\/(\S*)\/(\S*)$/) {
	return { 'workgroup' => $1,
		 'server' => $2,
		 'share' => $3,
		 'program' => $_[0] };
	}
elsif ($_[1]->{'dev'} =~ /^smb:\/\/(\S*)\/(\S*)$/) {
	return { 'server' => $1,
		 'share' => $2,
		 'program' => $_[0] };
	}
else {
	return undef;
	}
}

# is_driver(path, &printer)
# Returns the driver name if some path is a CUPS driver, or undef
sub is_driver
{
if (!$_[0] || !-r $_[0]) {
	return { 'mode' => 0,
		 'desc' => $text{'cups_none'} };
	}
local $ppd = &parse_cups_ppd($_[0]);
if ($ppd->{'NickName'}) {
	# Looks like a CUPS PPD file!
	return { 'mode' => 1,
		 'manuf' => $ppd->{'Manufacturer'},
		 'model' => $ppd->{'ModelName'},
		 'nick' => $ppd->{'NickName'},
		 'desc' => "$ppd->{'Manufacturer'} $ppd->{'ModelName'}" };
	}
else {
	# Some other kind of interface file
	return { 'mode' => 2,
		 'file' => $_[0],
		 'desc' => $_[0] };
	}
}

# create_windows_driver(&printer, &driver)
sub create_windows_driver
{
if ($_[1]->{'workgroup'} && $_[1]->{'user'}) {
	$_[0]->{'dev'} = "smb://$_[1]->{'user'}:$_[1]->{'pass'}\@$_[1]->{'workgroup'}/$_[1]->{'server'}/$_[1]->{'share'}";
	}
elsif ($_[1]->{'workgroup'}) {
	$_[0]->{'dev'} = "smb://$_[1]->{'workgroup'}/$_[1]->{'server'}/$_[1]->{'share'}";
	}
elsif ($_[1]->{'user'}) {
	$_[0]->{'dev'} = "smb://$_[1]->{'user'}:$_[1]->{'pass'}\@$_[1]->{'server'}/$_[1]->{'share'}";
	}
else {
	$_[0]->{'dev'} = "smb://$_[1]->{'server'}/$_[1]->{'share'}";
	}
return $_[1]->{'program'};
}

# create_driver(&printer, &driver)
sub create_driver
{
local $drv = "$cups_ppd_dir/$_[0]->{'name'}.ppd";
undef($cups_driver_options);
if ($_[1]->{'mode'} == 0) {
	&unlink_file($drv);
	return undef;
	}
elsif ($_[1]->{'mode'} == 2) {
	&unlink_file($drv);
	return $_[1]->{'file'};
	}
else {
	# Copy the driver into place
	if ($_[1]->{'ppd'} =~ /\.gz$/) {
		&system_logged("gunzip -c ".quotemeta($_[1]->{'ppd'}).
			       " >".quotemeta($drv));
		}
	else {
		&copy_source_dest($_[1]->{'ppd'}, $drv);
		}
	chmod(0777, $drv);
	$cups_driver_options = $_[1]->{'opts'};	# for modify_printer
	return $drv;
	}
}

# delete_driver(name)
sub delete_driver
{
&unlink_file("$cups_ppd_dir/$_[0].ppd");
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
local (@ppds, $d, $f, $ppd, %cache, $outofdate, @files, %donefile);
local $findver = &backquote_command("find --version 2>&1", 1);
local $flag = $findver =~ /GNU\s+find\s+version\s+([0-9\.]+)/i && $1 >= 4.2 ?
		"-L" : "";
foreach my $mp (split(/\s+/, $config{'model_path'})) {
	&open_execute_command(FIND, "find $flag ".quotemeta($mp).
				    " -type f -print", 1, 1);
	while(<FIND>) {
		chop;
		next if (/\.xml$/);	# Ignore XML PPD sources
		/([^\/]+)$/;
		next if ($donefile{$1}++);
		push(@files, $_);
		}
	close(FIND);
	}
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
		local $nn = $ppd->{'NickName'};
		$cache{$f} = $donecache{$nn} ? "duplicate" : $ppd->{'NickName'};
		$donecache{$nn}++;
		}
	&write_file("$module_config_directory/ppd-cache", \%cache);
	}
local %done;
print "<td><select name=ppd size=10>\n";
foreach $f (sort { $cache{$a} cmp $cache{$b} } keys %cache) {
	if ($cache{$f} && $cache{$f} ne "duplicate" &&
	    !$done{$cache{$f}}++) {
		printf "<option value=%s %s>%s\n",
			$f, $_[1]->{'nick'} eq $cache{$f} ? 'selected' : '',
			$cache{$f};
		$currppd = $f if ($_[1]->{'nick'} eq $cache{$f});
		}
	}
print "</select>\n";

# Display driver option inputs
if ($currppd) {
	local $ppd = &parse_cups_ppd($currppd);
	print "<br><b>",&text('cups_opts', $ppd->{'NickName'}),
	      "</b><table>\n";
	open(OPTS, "$lpoptions -p '$_[0]->{'name'}' -l 2>/dev/null |");
	while(<OPTS>) {
		if (/^(\S+)\/([^:]+):\s*(.*)/ && $1 ne "PageRegion") {
			print "<tr>\n" if ($i%2 == 0);
			local $code = $1;
			local $disp = $2;
			local @opts = split(/\s+/, $3);
			print "<td><b>$disp:</b></td>\n";
			print "<td><select name=ppd_$code>\n";
			foreach $o (@opts) {
				local $sel = ($o =~ s/^\*//);
				printf "<option value='%s' %s>%s\n",
					$o, $sel ? "selected" : "",
					$ppd->{$code}->{$o} ?
					  $ppd->{$code}->{$o} : $o;
				}
			print "</select></td>\n";
			print "<tr>\n" if ($i%2 == 1);
			}
		}
	close(OPTS);
	print "</table>\n";
	}

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
	foreach $i (keys %in) {
		$rv->{'opts'}->{$1} = $in{$i} if ($i =~ /^ppd_(.*)$/);
		}
	return $rv;
	}
}

1;

