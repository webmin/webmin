# hpux-lib.pl
# Functions for hpux-style printer management

$hpux_iface_path = "/usr/spool/lp/interface";

# list_printers()
# Returns an array of known printer names
sub list_printers
{
local(@rv, $_);
open(STAT, "lpstat -p |");
while(<STAT>) {
	if (/^printer\s+(\S+)/) { push(@rv, $1); }
	}
close(STAT);

# make models executable
&system_logged("chmod 755 $config{'model_path'}/* >/dev/null 2>&1");

return &unique(@rv);
}

# get_printer(name, [nostatus])
# Returns a reference to an associative array of printer details
sub get_printer
{
local($stat, @rv, $body1, $body2, $avl, $con, $sys, %prn, $_, $out);
local $esc = quotemeta($_[0]);
$out = &backquote_command("lpstat -p$esc", 1);
if ($out =~ /^printer\s+(\S+)\s+(.*)\n(.*)\n(.*)$/) {
	# printer exists
	$prn{'name'} = $1;
	if ($2 =~ /enabled/) {$prn{'enabled'} = "enabled"};
        $body1 = $3;
        $body2 = $4;
	}
else {
	# no printer found
	return undef;
	}

# Interface
$prn{'iface'} = "$hpux_iface_path/$prn{'name'}";

# Description
local $wdrv = &is_windows_driver($prn{'iface'});
local $hdrv = &is_hpnp_driver($prn{'iface'});
$prn{'desc'} = $wdrv ? &grep_interface($wdrv->{'program'}) :
	       $hdrv ? &grep_interface($hdrv->{'program'}) :
		       &grep_interface($prn{'iface'});

# printer enabled?
if (!$prn{'enabled'} && $body1 =~ /^\s+(.*)/) {
	$prn{'enabled_why'} = $1 eq "reason unknown" ? "" : $1;
	}

if (!$_[1]) {
	# request availability
	$avl = &backquote_command("lpstat -a$esc 2>&1", 1);
	if ($avl =~ /^\S+\s+not accepting.*\n\s+(.*)/) {
		$prn{'accepting'} = 0;
		$prn{'accepting_why'} = $1;
		if ($prn{'accepting_why'} eq "reason unknown") {
			$prn{'accepting_why'} = "";
			}
		}
	else { $prn{'accepting'} = 1; }
	}

# request connection
$con = &backquote_command("lpstat -v$esc 2>&1", 1);
if ($con =~ /^device for \S+:\s+(\S+)\n\s+(remote to:)\s+(\S+)\s+(on)\s+(\S+)/) {
	$prn{'rhost'} = $5;
	$prn{'rqueue'} = $3;
	}
elsif ($con =~ /^device for \S+:\s+(\S+)/) { $prn{'dev'} = $1; }

# Check if this is the default printer
if (&backquote_command("lpstat -d 2>&1", 1) =~ /: (\S+)/ &&
    $1 eq $prn{'name'}) {
	$prn{'default'} = 1;
	}

return \%prn;
}

sub get_jobs
{
local $esc = quotemeta($_[0]);
open(STAT, "lpstat -o$esc |");
local($id, $user, $prio, $when, $printing);
while(<STAT>) {
	if (/^(\S+-\d+)\s+(\S+)\s+priority\s+(\S+)\s+(\S+.*\d+ \d+:\d+)\s+(.*)/) {
		$id = $1;
		$user = $2;
		$prio = $3;
 		$when = $4;
		$printing = ($5 =~ /^on /);
		}
	elsif (/^(\S+-\d+)\s+(\S+)\s+priority\s+(\S+)\s+from\s+(\S+)\s+(.*)/) {
		$id = $1;
		$user = "$2\@$4";
		$prio = $3;
		$when = "?";
		$printing = ($5 =~ /^on /);
		}
	elsif (/^(.*)\s+(\d+) bytes/) {
		local(%job);
		$job{'id'} = $id;
		$job{'user'} = $user;
		$job{'prio'} = $prio;
	 	$job{'when'} = $when;
		$job{'printing'} = $printing;
		$job{'file'} = $1;
 		$job{'size'} = $2;
		push(@jobs, \%job);
		}
	}
close(STAT);
return @jobs;
}

# grep_interface($iface)
# try to find a description in the interface/model
sub grep_interface
{
local($iface, $desc, $out);
$iface = $_[0];

local $drv = &is_driver($iface);
if ($drv->{'mode'} == 1) {
	$desc = $drv->{'desc'};
	}
elsif ($drv->{'mode'} == 2) {
	$out = &backquote_command("head $drv->{'prog'} | grep -e interface -e Printer -e /model/", 1);
	if ($out =~ /interface for\s+(.*)/) { $desc = $1; }
	elsif ($out =~ /\s+(\S.*)interface/) { $desc = $1; }
	elsif ($out =~ /Printer Command Language level\s+(\S+)/) { $desc = "PCL$1"; }
	elsif ($out =~ /\/model\/(\S+).*/) { $desc = $1; }
	elsif ($out =~ /^#\s+(.*)/) { $desc = $1; }
	else { $desc = "None"; }
	}
else {
	$desc = "None";
	}
return $desc;
}

# printer_support(option)
sub printer_support
{
return $_[0] !~ /^(allow|alias|ctype|banner|desc|editdest|msize|direct|rnoqueue|ipp)$/;
}

# list_classes()
# Returns an associative array of print classes
sub list_classes
{
local($stat, %rv);
$stat = &backquote_command("lpstat -c 2>&1", 1);
while($stat =~ /^members of class (\S+):\n((\s+\S+\n)+)([\000-\377]*)$/) {
	$stat = $4;
	$rv{$1} = [ grep { $_ ne "" } split(/\s+/, $2) ];
	}
return \%rv;
}

# create_printer(&details)
# Create a new printer
sub create_printer
{
local(%prn, $cmd, $out, $model, $dummy, $scheduler);
%prn = %{$_[0]};
local $wdrv = &is_windows_driver($prn{'iface'});
local $hdrv = &is_hpnp_driver($prn{'iface'});
$scheduler = &sched_running();
$dummy = "webmin.tmp";
&system_logged("touch $config{'model_path'}/$dummy");

# create lpadmin command
local $esc = quotemeta($prn{'name'});
$cmd = "lpadmin -p$esc";

## remote unix printer
if ($prn{'rhost'}) {
	if ($prn{'iface'}) {
		&error("lpadmin failed : <pre>No model allowed for remote unix printer.</pre>");
	}
	$cmd .= " -orm".quotemeta($prn{'rhost'});
	$cmd .= " -orp".quotemeta($prn{'rqueue'});
	$cmd .= " -mrmodel";
	$cmd .= " -ocmrcmodel";
	$cmd .= " -osmrsmodel";
	$cmd .= " -v/dev/null";
	$cmd .= " -orc";
	if ($prn{'rtype'} =~ /^BSD$/) {
		$cmd .= " -ob3";
		}
	}

## remote windows printer
elsif ($wdrv) {
	$cmd .= " -m$dummy";
	$cmd .= " -v/dev/null";
	$cmd .= " -g0";
	}

## remote HPNP printer
elsif ($hdrv) {
	$cmd .= " -m$dummy";
	$cmd .= " -v/dev/null";
	$cmd .= " -g0";
	}

## local printer with webmin driver
elsif ($prn{'iface'} eq "$drivers_directory/$prn{'name'}") {
	$cmd .= " -m$dummy";
	$cmd .= " -v".quotemeta($prn{'dev'});
	$cmd .= " -g0";
	}

## local printer with HP-UX model
elsif ($prn{'iface'} =~ $config{'model_path'}) {
	$model = substr($prn{'iface'}, length($config{'model_path'}) + 1);
	$cmd .= " -m$model";
	$cmd .= " -v".quotemeta($prn{'dev'});
	$cmd .= " -g0";
	}
else {
	&error("lpadmin failed : <pre>Action not supported.</pre>");
	}

# stop scheduler
$out = &backquote_logged("lpshut 2>&1");

# call lpadmin
$out = &backquote_logged("$cmd 2>&1");
if ($?) { &error("lpsched failed : <pre>$out</pre>"); }

## Link to windows webmin driver
&lock_file("$hpux_iface_path/$prn{'name'}");
if ($wdrv) {
	&unlink_file("$hpux_iface_path/$prn{'name'}");
	&symlink_file("$drivers_directory/$prn{'name'}.smb",
			"$hpux_iface_path/$prn{'name'}");
	}

## Link to webmin hpnp driver
if ($hdrv) {
	&unlink_file("$hpux_iface_path/$prn{'name'}");
	&symlink_file("$drivers_directory/$prn{'name'}.hpnp",
			"$hpux_iface_path/$prn{'name'}");
	}

## Link to webmin driver
if ($prn{'iface'} eq "$drivers_directory/$prn{'name'}" && !$wdrv) {
	&unlink_file("$hpux_iface_path/$prn{'name'}");
	&symlink_file("$drivers_directory/$prn{'name'}",
			"$hpux_iface_path/$prn{'name'}");
	}
&unlock_file("$hpux_iface_path/$prn{'name'}");

&lock_file("$config{'model_path'}/$dummy");
&unlink_file("$config{'model_path'}/$dummy");
&unlock_file("$config{'model_path'}/$dummy");

# start scheduler
if ($scheduler) {
	$out = &backquote_logged("lpsched 2>&1");
	if ($?) { &error("lpsched failed : <pre>$out</pre>"); }
	}

&modify_printer($_[0]);
}

# modify_printer(&details)
# Change an existing printer
sub modify_printer
{
local(%prn, $cmd, $out);
%prn = %{$_[0]};

# make the default
local $esc = quotemeta($prn{'name'});
if ($prn{'default'}) {
	$out = &backquote_logged("lpadmin -d$esc 2>&1");
	if ($?) { &error("Failed to set default : <pre>$out</pre>"); }
	}

# enable or disable
if ($prn{'enabled'}) { $cmd = "enable $esc"; }
elsif ($prn{'enabled_why'}) {
	local $wesc = quotemeta($prn{'enabled_why'});
	$cmd = "enable $esc ; disable -r$wesc $esc";
	}
else { $cmd = "enable $esc ; disable $esc"; }
$out = &backquote_logged("$cmd 2>&1");

# accepting or rejecting requests
if ($prn{'accepting'}) { $cmd = "accept $esc"; }
elsif ($prn{'accepting_why'}) {
	local $wesc = quotemeta($prn{'accepting_why'});
	$cmd = "accept $esc ; reject -r$wesc $esc";
	}
else { $cmd = "accept $esc ; reject $esc"; }
$out = &backquote_logged("$cmd 2>&1");
}

# delete_printer(name)
# Deletes some existing printer
sub delete_printer
{
local($out, $scheduler);
$scheduler = &sched_running();

# delete print jobs
local $esc = quotemeta($_[0]);
$out = &backquote_logged("cancel $esc -a 2>1");
if ($?) { &error("cancel failed : <pre>$out</pre>"); }

# stop scheduler
$out = &backquote_logged("lpshut 2>&1");

# call lpadmin
$out = &backquote_logged("lpadmin -x$esc 2>&1");
if ($?) { &error("lpadmin failed : <pre>$out</pre>"); }

# start scheduler
if ($scheduler) {
	$out = &backquote_logged("lpsched 2>&1");
	if ($?) { &error("lpsched failed : <pre>$out</pre>"); }
	}
}

# cancel_job(printer, id)
# Cancels some print job
sub cancel_job
{
local($out);
local $esc = quotemeta($_[1]);
$out = &backquote_logged("cancel $esc 2>&1");
if ($?) { &error("cancel failed : <pre>$out</pre>"); }
sleep(1);
}

# sched_running()
# Returns 1 if running and 0 if not running
sub sched_running
{
local $out = &backquote_command("lpstat -r 2>&1", 1);
if ($out =~ /not/) { return 0; }
else { return 1; }
}

# start_sched()
# Start lpsched
sub start_sched
{
local $out = &backquote_logged("lpsched 2>&1");
if ($?) { &error("failed to start lpsched : <tt>$out</tt>"); }
}

# stop_sched(pid)
# Stop the running lpsched process
sub stop_sched
{
local $out = &backquote_logged("lpshut 2>&1");
if ($?) { &error("lpshut failed : <tt>$out</tt>"); }
}

# print_command(printer, file)
# Returns the command to print some file on some printer
sub print_command
{
local $esc = quotemeta($_[0]);
local $iesc = quotemeta($_[1]);
return "lp -d $esc $iesc";
}

# check_print_system()
sub check_print_system
{
&has_command("lpstat") || return &text('hpux_ecmd', "<tt>lpstat</tt>");
-d $hpux_iface_path || return &text('hpux_eiface',"<tt>$hpux_iface_path</tt>");
return undef;
}

@device_files = ("/dev/c1t0d0_lp", "/dev/c2t0d0_lp",
		 "/dev/c0p0_lp", "/dev/c0p1_lp",
		 "/dev/c0p2_lp", "/dev/c0p3_lp",
		 "/dev/c0p4_lp", "/dev/c0p4_lp",
		 "/dev/c0p5_lp", "/dev/c0p5_lp",
		 "/dev/c1p0_lp",
		 "/dev/null");
@device_names = (&text('hpux_paralel', "c1t0d0"), &text('hpux_paralel', "c2t0d0"),
		 &text('hpux_serial', "c0p0"), &text('hpux_serial', "c0p1"),
		 &text('hpux_serial', "c0p2"), &text('hpux_serial', "c0p3"),
		 &text('hpux_serial', "c0p4"), &text('hpux_serial', "c0p5"),
		 &text('hpux_serial', "c0p6"), &text('hpux_serial', "c0p7"),
		 &text('hpux_serial', "c1p0"), $text{'hpux_null'});
