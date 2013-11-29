# lpadmin-lib.pl
# Functions for configuring and adding printers

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
do "$config{'print_style'}-lib.pl";
if ($config{'driver_style'}) {
	do "$config{'driver_style'}-driver.pl";
	}
else {
	do "webmin-driver.pl";
	}
%access = &get_module_acl();

$drivers_directory = "$module_config_directory/drivers";

# dev_name(file)
sub dev_name
{
local($i);
for($i=0; $i<@device_files; $i++) {
	if ($device_files[$i] eq $_[0]) { return $device_names[$i]; }
	}
return $_[0];
}

# has_ghostscript()
# Does this system have ghostscript installed?
sub has_ghostscript
{
return &has_command($config{'gs_path'});
}

# has_smbclient()
# Does this system have smbclient installed?
sub has_smbclient
{
return &has_command($config{'smbclient_path'});
}

# has_hpnp()
# Does this system have hpnp installed?
sub has_hpnp
{
return &has_command($config{'hpnp_path'});
}

# create_webmin_driver(&printer, &driver)
# lpadmin drivers are files in /etc/webmin/lpadmin/drivers. Each is a
# dynamically generated shell script which calls GS
sub create_webmin_driver
{
# check for non-driver
if ($_[1]->{'mode'} == 0) {
	return undef;
	}
elsif ($_[1]->{'mode'} == 2) {
	return $_[1]->{'program'};
	}

local($drv, $d, $gsdrv, $res, $perl);
&lock_file($drivers_directory);
mkdir($drivers_directory, 0755);
&unlock_file($drivers_directory);
$drv = "$drivers_directory/$_[0]->{'name'}";

# Find ghostscript driver
if ($_[1]->{'mode'} == 3) {
	$gsdrv = 'uniprint';
	}
else {
	foreach $d (&list_webmin_drivers()) {
		if ($d->[1] eq $_[1]->{'type'}) {
			$gsdrv = $d->[0];
			}
		}
	}

# Create script to call GS
&open_lock_tempfile(DRV, ">$drv");
&print_tempfile(DRV, "#!/bin/sh\n");
&print_tempfile(DRV, "# Name: $_[0]->{'name'}\n");
&print_tempfile(DRV, "# Type: ",$_[1]->{'upp'} ? 'uniprint'
					       : $_[1]->{'type'},"\n");
&print_tempfile(DRV, "# DPI: ",$_[1]->{'upp'} ? $_[1]->{'upp'}
					      : $_[1]->{'dpi'},"\n");
if ($gconfig{'ld_env'}) {
	&print_tempfile(DRV, "$gconfig{'ld_env'}=$gconfig{'ld_path'}\n");
	}
&print_tempfile(DRV, "PATH=$gconfig{'path'}\n");
if ($config{'gs_fontpath'}) {
	&print_tempfile(DRV, "GS_FONTPATH=$config{'gs_fontpath'}\n");
	}
if ($config{'gs_lib'}) {
	&print_tempfile(DRV, "GS_LIB=$config{'gs_lib'}\n");
	}
&print_tempfile(DRV, "export $gconfig{'ld_env'} PATH GS_FONTPATH GS_LIB\n");
$res = $_[1]->{'upp'} ? "\@$_[1]->{'upp'}.upp" :
       $_[1]->{'dpi'} ? "-r$_[1]->{'dpi'}" : "";
$perl = &get_perl_path();
if ($config{'iface_arg'}) {
	for($i=0; $i<$config{'iface_arg'}-1; $i++) {
		&print_tempfile(DRV, "shift\n");
		}
	&print_tempfile(DRV, "cat \$* | $perl -e 'while(<STDIN>) { print if (!/^\\s*#####/); }' >/tmp/\$\$.gsin\n");
	}
else {
	&print_tempfile(DRV, "$perl -e 'while(<STDIN>) { print if (!/^\\s*#####/); }' >/tmp/\$\$.gsin\n");
	}
&print_tempfile(DRV, "$config{'gs_path'} -sOutputFile=/tmp/\$\$.gs -dSAFER -sDEVICE=$gsdrv $res -dNOPAUSE /tmp/\$\$.gsin </dev/null >/dev/null 2>&1\n");
&print_tempfile(DRV, "rm /tmp/\$\$.gsin\n");
&print_tempfile(DRV, "cat /tmp/\$\$.gs\n");
&print_tempfile(DRV, "rm /tmp/\$\$.gs\n");
&close_tempfile(DRV);
if ($config{'iface_owner'}) {
	&system_logged("chown '$config{'iface_owner'}' '$drv' >/dev/null 2>&1");
	}
&system_logged("chmod '$config{'iface_perms'}' '$drv' >/dev/null 2>&1");
return $drv;
}

# create_webmin_windows_driver(&printer, &driver)
# Create an interface program that can print to a remote windows printer
# using some printer driver
sub create_webmin_windows_driver
{
local($drv, $prog);
&lock_file($drivers_directory);
mkdir($drivers_directory, 0755);
&unlock_file($drivers_directory);
$drv = "$drivers_directory/$_[0]->{'name'}.smb";

# Create script to call smbclient
&open_lock_tempfile(DRV, ">$drv");
&print_tempfile(DRV, "#!/bin/sh\n");
&print_tempfile(DRV, "# Name: $_[0]->{'name'}\n");
&print_tempfile(DRV, "# Server: $_[1]->{'server'}\n");
&print_tempfile(DRV, "# Share: $_[1]->{'share'}\n");
&print_tempfile(DRV, "# User: $_[1]->{'user'}\n");
&print_tempfile(DRV, "# Password: $_[1]->{'pass'}\n");
&print_tempfile(DRV, "# Workgroup: $_[1]->{'workgroup'}\n");
&print_tempfile(DRV, "# Program: $_[1]->{'program'}\n");
if ($gconfig{'ld_env'}) {
	&print_tempfile(DRV, "$gconfig{'ld_env'}=$gconfig{'ld_path'}\n");
	}
&print_tempfile(DRV, "PATH=$gconfig{'path'}\n");
&print_tempfile(DRV, "export $gconfig{'ld_env'} PATH\n");
if (!$_[1]->{'program'}) {
	if ($config{'iface_arg'}) {
		for($i=0; $i<$config{'iface_arg'}-1; $i++) {
			&print_tempfile(DRV, "shift\n");
			}
		&print_tempfile(DRV, "cat \$* >/tmp/\$\$.smb\n");
		}
	else { &print_tempfile(DRV, "cat >/tmp/\$\$.smb\n"); }
	}
else {
	&print_tempfile(DRV, "$_[1]->{'program'} \"\$1\" \"\$2\" \"\$3\" \"\$4\" ",
		  "\"\$5\" \"\$6\" \"\$7\" \"\$8\" \"\$9\" ",
		  "\"\$10\" \"\$11\" \"\$12\" \"\$13\" >/tmp/\$\$.smb\n");
	&system_logged("chmod a+rx '$_[1]->{'program'}'");
	}
&print_tempfile(DRV, "$config{'smbclient_path'} '//$_[1]->{'server'}/$_[1]->{'share'}' ",
	  $_[1]->{'pass'} ? $_[1]->{'pass'} : "-N",
	  $_[1]->{'user'} ? " -U $_[1]->{'user'}" : "",
	  $_[1]->{'workgroup'} ? " -W $_[1]->{'workgroup'}" : "",
	  " -c \"print /tmp/\$\$.smb\"\n");
&print_tempfile(DRV, "rm /tmp/\$\$.smb\n");
&close_tempfile(DRV);
if ($config{'iface_owner'}) {
	&system_logged("chown '$config{'iface_owner'}' '$drv' >/dev/null 2>&1");
	}
&system_logged("chmod '$config{'iface_perms'}' '$drv' >/dev/null 2>&1");
return $drv;
}

# create_hpnp_driver(&printer, &driver)
# Create an interface program that can print to a hpnp server using some
# interface program
sub create_hpnp_driver
{
local($drv, $prog);
&lock_file($drivers_directory);
mkdir($drivers_directory, 0755);
&unlock_file($drivers_directory);
$drv = "$drivers_directory/$_[0]->{'name'}.hpnp";

# Create script to call hpnp
&open_lock_tempfile(DRV, ">$drv");
&print_tempfile(DRV, "#!/bin/sh\n");
&print_tempfile(DRV, "# Name: $_[0]->{'name'}\n");
&print_tempfile(DRV, "# Server: $_[1]->{'server'}\n");
&print_tempfile(DRV, "# Port: $_[1]->{'port'}\n");
&print_tempfile(DRV, "# Program: $_[1]->{'program'}\n");
if ($gconfig{'ld_env'}) {
	&print_tempfile(DRV, "$gconfig{'ld_env'}=$gconfig{'ld_path'}\n");
	}
&print_tempfile(DRV, "PATH=$gconfig{'path'}\n");
&print_tempfile(DRV, "export $gconfig{'ld_env'} PATH\n");
if (!$_[1]->{'program'}) {
	if ($config{'iface_arg'}) {
		for($i=0; $i<$config{'iface_arg'}-1; $i++) {
			&print_tempfile(DRV, "shift\n");
			}
		&print_tempfile(DRV, "cat \$* >/tmp/\$\$.hpnp\n");
		}
	else { &print_tempfile(DRV, "cat >/tmp/\$\$.hpnp\n"); }
	}
else {
	&print_tempfile(DRV, "$_[1]->{'program'} \"\$1\" \"\$2\" \"\$3\" \"\$4\" ",
		  "\"\$5\" \"\$6\" \"\$7\" \"\$8\" \"\$9\" ",
		  "\"\$10\" \"\$11\" \"\$12\" \"\$13\" >/tmp/\$\$.hpnp\n");
	&system_logged("chmod a+rx '$_[1]->{'program'}'");
	}
&print_tempfile(DRV, "$config{'hpnp_path'} -x $_[1]->{'server'}",
	  $_[1]->{'port'} ? " -p $_[1]->{'port'}" : "",
	  " /tmp/\$\$.hpnp\n");
&print_tempfile(DRV, "rm /tmp/\$\$.hpnp\n");
&close_tempfile(DRV);
if ($config{'iface_owner'}) {
	&system_logged("chown $config{'iface_owner'} $drv >/dev/null 2>&1");
	}
&system_logged("chmod '$config{'iface_perms'}' '$drv' >/dev/null 2>&1");
&unlock_file($drv);
return $drv;
}

# is_webmin_driver(path)
# Returns a structure of driver information
sub is_webmin_driver
{
local($l, $i, $u, $desc);
if (!$_[0]) {
	return { 'mode' => 0,
		 'desc' => 'None' };
	}
if (&has_ghostscript()) {
	open(DRV, $_[0]);
	for($i=0; $i<4; $i++) { $l .= <DRV>; }
	close(DRV);
	if ($l =~ /# Name: (.*)\n# Type: (.*)\n# DPI: (.*)\n/) {
		if ($2 eq 'uniprint') {
			local $upp = $3;
			foreach $u (&list_uniprint()) {
				$desc = $u->[1] if ($u->[0] eq $upp);
				}
			$desc =~ s/,.*$//;
			return { 'mode' => 3,
				 'upp' => $upp,
				 'desc' => $desc ? $desc : $upp };
			}
		else {
			return { 'type' => $2,
				 'dpi' => $3,
				 'mode' => 1,
				 'desc' => $3 ? "$2 ($3 DPI)" : $2 };
			}
		}
	}
return { 'desc' => $_[0],
	 'prog' => $_[0],
	 'mode' => 2 };
}

# is_webmin_windows_driver(path)
# Returns a structure containing information about a windows driver, or undef
# Returns the server, share, username, password, workgroup, program
# if path is a webmin windows driver
sub is_webmin_windows_driver
{
local($i, $l);
if (!&has_smbclient()) { return undef; }
open(DRV, $_[0]);
for($i=0; $i<8; $i++) { $l .= <DRV>; }
close(DRV);
if ($l =~ /# Name: (.*)\n# Server: (.*)\n# Share: (.*)\n# User: (.*)\n# Password: (.*)\n# Workgroup: (.*)\n# Program: (.*)\n/) {
	return { 'server' => $2,
		 'share' => $3,
		 'user' => $4,
		 'pass' => $5,
		 'workgroup' => $6,
		 'program' => $7 };
	}
elsif ($l =~ /# Name: (.*)\n# Server: (.*)\n# Share: (.*)\n# User: (.*)\n# Password: (.*)\n# Program: (.*)\n/) {
	return { 'server' => $2,
		 'share' => $3,
		 'user' => $4,
		 'pass' => $5,
		 'program' => $7 };
	}
else { return undef; }
}

# delete_webmin_driver(name)
# Delete the drivers for some printer
sub delete_webmin_driver
{
&lock_file("$drivers_directory/$_[0]");
&lock_file("$drivers_directory/$_[0].smb");
&lock_file("$drivers_directory/$_[0].hpnp");
unlink("$drivers_directory/$_[0]");
unlink("$drivers_directory/$_[0].smb");
unlink("$drivers_directory/$_[0].hpnp");
&unlock_file("$drivers_directory/$_[0]");
&unlock_file("$drivers_directory/$_[0].smb");
&unlock_file("$drivers_directory/$_[0].hpnp");
}

# is_hpnp_driver(path, &printer)
# Returns a structure of hpnp details if path is a webmin hpnp driver
sub is_hpnp_driver
{
local($i, $l);
if (!&has_hpnp()) { return undef; }
open(DRV, $_[0]);
for($i=0; $i<5; $i++) { $l .= <DRV>; }
close(DRV);
if ($l =~ /# Name: (.*)\n# Server: (.*)\n# Port: (.*)\n# Program: (.*)\n/) {
	return { 'server' => $2,
		 'port' => $3,
		 'program' => $4 };
	}
else { return undef; }
}

# webmin_driver_input(&printer, &driver)
sub webmin_driver_input
{
local ($prn, $drv) = @_;

printf "<tr> <td><input type=radio name=drv value=0 %s> %s</td>\n",
	$drv->{'mode'} == 0 ? "checked" : "", $text{'webmin_none'};
print "<td>($text{'webmin_nonemsg'})</td> </tr>\n";

printf "<tr> <td><input type=radio name=drv value=2 %s> %s</td>\n",
	$drv->{'mode'} == 2 ? "checked" : "", $text{'webmin_prog'};
printf "<td><input name=iface value=\"%s\" size=35></td> </tr>\n",
	$drv->{'mode'} == 2 ? $drv->{'prog'} : "";

if (&has_ghostscript()) {
	local $out = &backquote_command("$config{'gs_path'} -help 2>&1", 1);
	if ($out =~ /Available devices:\n((\s+.*\n)+)/i) {
		print "<tr> <td valign=top>\n";
		printf "<input type=radio name=drv value=1 %s>\n",
			$drv->{'mode'} == 1 ? "checked" : "";
		print "$text{'webmin_driver'}</td> <td valign=top>";
		foreach $d (split(/\s+/, $1)) { $drvsupp{$d}++; }
		print "<select name=driver size=7>\n";
		foreach $d (&list_webmin_drivers()) {
			if ($drvsupp{$d->[0]}) {
				printf "<option value='%s' %s>%s&nbsp;&nbsp;&nbsp;(%s)</option>\n",
				    $d->[1],
				    $d->[1] eq $drv->{'type'} ? "selected" : "",
				    $d->[1], $d->[0];
				}
			}
		print "</select>&nbsp;&nbsp;";
		print "<select name=dpi size=7>\n";
		printf "<option value=\"\" %s>Default</option>\n",
			$drv->{'dpi'} ? "" : "selected";
		foreach $d (75, 100, 150, 200, 300, 600, 720, 1440) {
			printf "<option value=\"$d\" %s>$d DPI</option>\n",
				$drv->{'dpi'} == $d ? "selected" : "";
			}
		print "</select></td> </tr>\n";

		if ($drvsupp{'uniprint'}) {
			print "<tr> <td valign=top>\n";
			printf "<input type=radio name=drv value=3 %s>\n",
				$drv->{'mode'} == 3 ? "checked" : "";
			print "$text{'webmin_uniprint'}</td> <td valign=top>";
			print "<select name=uniprint size=5>\n";
			foreach $u (&list_uniprint()) {
				printf "<option value=%s %s>%s</option>\n",
				    $u->[0],
				    $u->[0] eq $drv->{'upp'} ? 'selected' : '',
				    $u->[1];
				}
			print "</select></td> </tr>\n";
			}
		}
	else {
		print "<tr> <td colspan=2>",
		      &text('webmin_edrivers', "<tt>$config{'gs_path'}</tt>"),
		      "</td> </tr>\n";
		}
	}
elsif ($config{'gs_path'}) {
	print "<tr> <td colspan=2>",
	      &text('webmin_egs', "<tt>$config{'gs_path'}</tt>"),
	      "</td> </tr>\n";
	}
return undef;
}

# parse_webmin_driver()
# Parse driver selection from %in and return a driver structure
sub parse_webmin_driver
{
if ($in{'drv'} == 0) {
	return { 'mode' => 0 };
	}
elsif ($in{'drv'} == 2) {
	my @iface = split(/\s+/, $in{'iface'});
	-x $iface[0] || &error(&text('webmin_edriver', $iface[0]));
	return { 'mode' => 2,
		 'program' => $in{'iface'} };
	}
elsif ($in{'drv'} == 1) {
	return { 'mode' => 1,
		 'type' => $in{'driver'},
		 'dpi' => $in{'dpi'} };
	}
elsif ($in{'drv'} == 3) {
	return { 'mode' => 3,
		 'upp' => $in{'uniprint'} };
	}
}



# list_webmin_drivers()
sub list_webmin_drivers
{
local(@rv, $_);
open(DRIVERS, "$module_root_directory/drivers");
while(<DRIVERS>) {
	/^(\S+)\s+(.*)/;
	push(@rv, [ $1, $2 ]);
	}
close(DRIVERS);
return @rv;
}

# can_edit_printer(printer)
sub can_edit_printer
{
foreach $p (split(/\s+/, $access{'printers'})) {
	return 1 if ($p eq '*' || $p eq $_[0]);
	}
return 0;
}

# can_edit_jobs(printer, user)
sub can_edit_jobs
{
local $rv = 0;
if ($access{'cancel'} == 1) {
	$rv = 1;
	}
elsif ($access{'cancel'} == 0) {
	$rv = 0;
	}
else {
	foreach $p (split(/\s+/, $access{'jobs'})) {
		$rv = 1 if ($p eq $_[0]);
		}
	}
if ($rv) {
	if ($access{'user'} eq '*') {
		return 1;
		}
	elsif ($access{'user'} eq $_[1]) {
		return 1;
		}
	elsif (!$access{'user'} && $remote_user eq $_[1]) {
		return 1;
		}
	}
return 0;
}

# list_uniprint()
# Returns a list of uniprint drivers support by the installed ghostscript
sub list_uniprint
{
local (@rv, $f, $d);
local $out = &backquote_command("$config{'gs_path'} -help 2>&1", 1);
if ($out =~ /Search path:\n((\s+.*\n)+)/i) {
	foreach $d (split(/\s+/, $1)) {
		next if ($d !~ /^\//);
		opendir(DIR, $d);
		while($f = readdir(DIR)) {
			next if ($f !~ /^(.*)\.upp$/);
			local $upp = $1;
			open(UPP, "$d/$f");
			local $line = <UPP>;
			close(UPP);
			next if ($line !~ /upModel="(.*)"/i);
			push(@rv, [ $upp, $1 ]);
			}
		closedir(DIR);
		}
	}
return sort { $a->[0] cmp $b->[0] } @rv;
}

sub log_info
{
local ($drv, $wdrv, $hdrv);
if (!$webmin_windows_driver) {
	$wdrv = &is_webmin_windows_driver($_[0]->{'iface'}, $_[0]);
	}
$wdrv = &is_windows_driver($_[0]->{'iface'}, $_[0]) if (!$wdrv);
$hdrv = &is_hpnp_driver($_[0]->{'iface'}, $_[0]);
local $iface = $wdrv ? $wdrv->{'program'} :
	       $hdrv ? $hdrv->{'program'} : $_[0]->{'iface'};

if (!$webmin_print_driver) {
	$drv = &is_webmin_driver($iface, $_[0]);
	}
$drv = &is_driver($iface, $_[0])
	if ($drv->{'mode'} == 0 || $drv->{'mode'} == 2);
$drv->{'desc'} =~ s/\([^\)]+\)$//;

return { 'driver' => $drv->{'desc'},
	 'mode' => $drv->{'mode'},
	 'dest' => $wdrv ? "\\\\$wdrv->{'server'}\\$wdrv->{'share'}" :
		   $hdrv ? "HPNP $hdrv->{'server'}:$hdrv->{'port'}" :
		   $_[0]->{'rhost'} ? "$_[0]->{'rhost'}:$_[0]->{'rqueue'}" :
		   $_[0]->{'dhost'} ? "$_[0]->{'dhost'}:$_[0]->{'dport'}" :
		   &dev_name($_[0]->{'dev'}) };
}

# parse_cups_ppd(file)
# Converts a CUPS-style .ppd file into a hash of names and values
sub parse_cups_ppd
{
local ($file) = @_;
local %ppd;
if ($file =~ /\.gz$/) {
	open(PPD, "gunzip -c ".quotemeta($file)." |");
	}
else {
	open(PPD, $file);
	}
while(<PPD>) {
	if (/^\s*\*(\S+):\s*"(.*)"/ || /^\s*\*(\S+):\s*(\S+)/) {
		$ppd{$1} = $2;
		}
	elsif (/^\s*\*(\S+)\s+(\S+)\/([^:]+):/) {
		$ppd{$1}->{$2} = $3 if (!defined($ppd{$1}->{$2}));
		}
	}
close(PPD);
return \%ppd;
}

# list_cluster_servers()
# Returns a list of servers on which printers are managed
sub list_cluster_servers
{
&foreign_require("servers", "servers-lib.pl");
local %ids = map { $_, 1 } split(/\s+/, $config{'servers'});
return grep { $ids{$_->{'id'}} } &servers::list_servers();
}

# add_cluster_server(&server)
sub add_cluster_server
{
local @sids = split(/\s+/, $config{'servers'});
$config{'servers'} = join(" ", @sids, $_[0]->{'id'});
&save_module_config();
}

# delete_cluster_server(&server)
sub delete_cluster_server
{
local @sids = split(/\s+/, $config{'servers'});
$config{'servers'} = join(" ", grep { $_ != $_[0]->{'id'} } @sids);
&save_module_config();
}

# server_name(&server)
sub server_name
{
return $_[0]->{'desc'} ? $_[0]->{'desc'} : $_[0]->{'host'};
}

# save_printer_cluster(new, &printer, &driver, &connection, webmin-driver, mode)
# Creates or updates the specified printer on all cluster hosts, and returns a
# list of error messages
sub save_on_cluster
{
return ( ) if (!$config{'servers'});
return ( ) if (&is_readonly_mode());
local ($new, $prn, $drv, $conn, $webmin, $mode) = @_;
&remote_error_setup(\&slave_error_handler);
local $slave;
local @slaveerrs;
foreach $slave (&list_cluster_servers()) {
	# Connect to server
        $slave_error = undef;
        &remote_foreign_require($slave, "lpadmin", "lpadmin-lib.pl");
        if ($slave_error) {
                push(@slaveerrs, [ $slave, $slave_error ]);
                next;
                }

	# Create the driver and the printer
	local $err = &remote_foreign_call($slave,
		"lpadmin", "save_printer_and_driver",
		$new, $prn, $drv, $conn, $webmin, $mode);
	if ($slave_error) {
                push(@slaveerrs, [ $slave, $slave_error ]);
		}
	elsif ($err == 1) {
		push(@slaveerrs, [ $slave, &text('save_edup', $prn->{'name'}) ]);
		}
	elsif ($err == 2) {
		push(@slaveerrs, [ $slave, $text{'save_evalid'} ]);
		}
	elsif ($err == 3) {
		push(@slaveerrs, [ $slave, &text('save_egone', $prn->{'name'}) ]);
		}
	}
return @slaveerrs;
}

# delete_on_cluster(&printer)
# Deletes the specified printer on all cluster hosts, and returns a list of
# error messages.
sub delete_on_cluster
{
return ( ) if (!$config{'servers'});
return ( ) if (&is_readonly_mode());
local ($prn) = @_;
&remote_error_setup(\&slave_error_handler);
local $slave;
local @slaveerrs;
foreach $slave (&list_cluster_servers()) {
	# Connect to server
        $slave_error = undef;
        &remote_foreign_require($slave, "lpadmin", "lpadmin-lib.pl");
        if ($slave_error) {
                push(@slaveerrs, [ $slave, $slave_error ]);
                next;
                }

	# Call the delete function
	local $err = &remote_foreign_call($slave,
		"lpadmin", "delete_printer_and_driver", $prn);
	if ($slave_error) {
                push(@slaveerrs, [ $slave, $slave_error ]);
		}
	elsif ($err == 3) {
		push(@slaveerrs, [ $slave, &text('save_egone', $prn->{'name'}) ]);
		}
	}
return @slaveerrs;
}

# save_printer_and_driver(new, &printer, &driver, &connection, webmin-driver, mode)
# Attempts to setup or modify a printer and driver. Returns 0 if OK, 1 if the
# printer already exists, 2 if some print system error occurred, or 3 if it
# doesn't exist but should.
sub save_printer_and_driver
{
local ($new, $prn, $drv, $conn, $webmin, $mode) = @_;
if ($new && &get_printer($prn->{'name'})) {
	return 1;
	}
elsif (!$new && !&get_printer($prn->{'name'})) {
	return 2;
	}
local $dfunc = $webmin ? \&create_webmin_driver : \&create_driver;
if ($mode <= 2 || $mode == 5) {
	# Device, file or LPR host
	$prn->{'iface'} = &$dfunc($prn, $drv);
	}
elsif ($mode == 3) {
	# Windows server
	$prn->{'dev'} = "/dev/null";
	$prn->{'iface'} = $webmin ? &create_webmin_windows_driver($prn, $conn)
				  : &create_windows_driver($prn, $conn);
	}
elsif ($mode == 4) {
	# HPNP server
	$prn->{'dev'} = "/dev/null";
	$prn->{'iface'} = &create_hpnp_driver($prn, $conn);
	}

# Call os-specific validation function
if (defined(&validate_printer)) {
	local $err = &validate_printer($prn);
	return 2 if ($err);
	}

# Actually create or update it
if ($new) {
	&create_printer($prn);
	}
else {
	&modify_printer($prn);
	}
&system_logged("$config{'apply_cmd'} >/dev/null 2>&1 </dev/null")
	if ($config{'apply_cmd'});
return 0;
}

# delete_printer_and_driver(&printer)
# Deletes a printer, returning 1 if it could not be found, or 0 if everything
# went OK.
sub delete_printer_and_driver
{
local ($prn) = @_;
&delete_printer($prn->{'name'});
&delete_driver($prn->{'name'});
&delete_webmin_driver($prn->{'name'});
}

sub slave_error_handler
{
$slave_error = $_[0];
}

# delete_from_acls(name)
# Remove some named printer from all ACLs
sub delete_from_acls
{
local ($name) = @_;
local $wusers;
&read_acl(undef, \%wusers);
foreach my $u (keys %wusers) {
	my %uaccess = &get_module_acl($u);
	if ($uaccess{'printers'} ne '*') {
		$uaccess{'printers'} =
			join(' ', grep { $_ ne $name }
				  split(/\s+/, $uaccess{'printers'}));
		&save_module_acl(\%uaccess, $u);
		}
	}
}

1;

