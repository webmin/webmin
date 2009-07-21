# irix-lib.pl
# Functions for irix-style printer management

$irix_iface_path = "/var/spool/lp/interface";

# list_printers()
# Returns an array of known printer names
sub list_printers
{
local(@rv, $_);
open(STAT, "/usr/bin/lpstat -p |");
while(<STAT>) {
	if (/^printer\s+(\S+)/) { push(@rv, $1); }
	}
close(STAT);
return &unique(@rv);
}

# get_printer(name, [nostatus])
# Returns a reference to an associative array of printer details
sub get_printer
{
local($stat, @rv, $body, $body, $avl, $con, $sys, %prn, $_, $out);
local $esc = quotemeta($_[0]);
$out = &backquote_command("/usr/bin/lpstat -p$esc", 1);
if ($out =~ /^printer\s+(\S+)\s*(.*)\s+(enabled|disabled)\s+since\s+(.+?)\n?(.*)?$/) {
	# printer exists
	$prn{'name'} = $1;
	$prn{'enabled'} = $3 eq "enabled";
	$body = $5;
	}
else {
	# no printer found
	return undef;
	}

# Interface
$prn{'iface'} = "$irix_iface_path/$prn{'name'}";

# Description
local $wdrv = &is_windows_driver($prn{'iface'});
local $hdrv = &is_hpnp_driver($prn{'iface'});
$prn{'desc'} = $wdrv ? &grep_interface($wdrv->{'program'}) :
	            $hdrv ? &grep_interface($hdrv->{'program'}) :
		         &grep_interface($prn{'iface'});

# printer enabled?
if (!$prn{'enabled'} && $body =~ /^\s+(.*)/) {
	$prn{'enabled_why'} = $1 eq "reason unknown" ? "" : $1;
	}

if (!$_[1]) {
	# request availability
	$avl = &backquote_command("/usr/bin/lpstat -a$esc 2>&1", 1);
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
$con = &backquote_command("/usr/bin/lpstat -v$esc 2>&1", 1);
if ($con =~ /^device for \S+:\s+(\S+)\n\s+(remote to:)\s+(\S+)\s+(on)\s+(\S+)/) {
	$prn{'rhost'} = $5;
	$prn{'rqueue'} = $3;
	}
elsif ($con =~ /^device for \S+:\s+(\S+)/) { $prn{'dev'} = $1; }

# Check if this is the default printer
if (&backquote_command("$lpstat -d 2>&1", 1) =~ /destination:\s+(\S+)/ &&
    $1 eq $prn{'name'}) {
	$prn{'default'} = 1;
	}

return \%prn;
}

sub get_jobs
{
local @jobs;
local $esc = quotemeta($_[0]);
open(STAT, "/usr/bin/lpstat -o$esc |");
while(<STAT>) {
	if (/^(\S+-\d+)\s+(\S+)\s+(\d+)\s+(\S+ \d+ \d+:\d+)\s+(.*)/) {
		local(%job, $d, $f, @pf);
		$job{'id'} = $1;
#		local $id = $2;
		$job{'user'} = $2;
		$job{'size'} = $3;
		$job{'when'} = $4;
		$job{'printing'} = ($5 =~ /^on /);
#		if ($job{'user'} =~ /(\S+)\!/ &&
#		    -d ($d="/var/spool/lp/tmp/$1")) {
#			opendir(DIR, $d);
#			foreach $f (readdir(DIR)) {
#				push(@pf, "$d/$f") if ($f =~ /^$id-[1-9]/);
#				}
#			closedir(DIR);
#			$job{'printfile'} = @pf ? \@pf : undef;
#			}

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
$stat = &backquote_command("/usr/bin/lpstat -c 2>&1", 1);
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
#local $wdrv = &is_windows_driver($prn{'iface'});
#local $hdrv = &is_hpnp_driver($prn{'iface'});
#$scheduler = &sched_running();
#$dummy = "webmin.tmp"; `touch $config{'model_path'}/$dummy`;

# create lpadmin command
local $esc = quotemeta($prn{'name'});
$cmd = "/usr/lib/lpadmin -p$esc";

## remote unix printer
if ($prn{'rhost'}) {
	if ($prn{'iface'}) {
		&error("lpadmin failed : <pre>No model allowed for remote unix printer.</pre>");
	}
   &copy_netface_driver($_[0]);
	$cmd .= " -i$irix_iface_path/$esc.tmp";
	$cmd .= " -v/dev/null";
	}

## remote windows printer
#elsif ($wdrv) {
#	$cmd .= " -m$dummy";
#	$cmd .= " -v/dev/null";
#	}

## remote HPNP printer
#elsif ($hdrv) {
#	$cmd .= " -m$dummy";
#	$cmd .= " -v/dev/null";
#	}

## local printer with webmin driver
#elsif ($prn{'iface'} eq "$drivers_directory/$prn{'name'}") {
#	$cmd .= " -m$dummy";
#	$cmd .= " -v".quotemeta($prn{'dev'});
#	}

## local printer with IRIX model
elsif ($prn{'iface'} =~ $config{'model_path'}) {
	$model = substr($prn{'iface'}, length($config{'model_path'}) + 1);
	$cmd .= " -m$model";
	$cmd .= " -v".quotemeta($prn{'dev'});
	}
else {
	&error("lpadmin failed : <pre>Action not supported.</pre>");
	}

# stop scheduler
#$out = &backquote_logged("/usr/lib/lpshut 2>&1");

# call lpadmin
$out = &backquote_logged("$cmd 2>&1");
if ($?) { &error("lpadmin failed : <pre>$out</pre>"); }

if ($prn{'rhost'}) {
  &unlink_file("$irix_iface_path/$prn{'name'}.tmp");
}

## Link to windows webmin driver
#&lock_file("$irix_iface_path/$prn{'name'}");
#if ($wdrv) {
#	`rm $irix_iface_path/$prn{'name'}`;
#	`ln -s $drivers_directory/$prn{'name'}.smb $irix_iface_path/$prn{'name'}`;
#	}

## Link to webmin hpnp driver
#if ($hdrv) {
#	`rm $irix_iface_path/$prn{'name'}`;
#	`ln -s $drivers_directory/$prn{'name'}.hpnp $irix_iface_path/$prn{'name'}`;
#	}

## Link to webmin driver
#if ($prn{'iface'} eq "$drivers_directory/$prn{'name'}" && !$wdrv) {
#	`rm $irix_iface_path/$prn{'name'}`;
#	`ln -s $drivers_directory/$prn{'name'} $irix_iface_path/$prn{'name'}`;
#	}
#&unlock_file("$irix_iface_path/$prn{'name'}");
#&lock_file("$config{'model_path'}/$dummy");
#`rm $config{'model_path'}/$dummy`;
#&unlock_file("$config{'model_path'}/$dummy");

# start scheduler
#if ($scheduler) {
#	$out = &backquote_logged("/usr/lib/lpsched 2>&1");
#	if ($?) { &error("lpsched failed : <pre>$out</pre>"); }
#	}

#change printer parameters
&modify_printer($_[0]);
}

# copy_netface_driver(&prn)
# Copies netface driver to interfaces directory and changes
# remote host address, name and type of remote printer.
sub copy_netface_driver {
  local (%prn);
%prn = %{$_[0]};
  my ($cmd, $rname, $rtype, $nettype, $driver_file ) = ();

  if ( $prn{'rtype'} eq "s5" ) {
    $nettype = "sgi";
    $cmd = "/usr/bsd/rsh -l lp $prn{'rhost'} "
         . "\'grep \"^NAME\" $irix_iface_path/$prn{'rqueue'}\'";
    $rname = &backquote_logged("$cmd");
    if ($?) { &error("Failed to read remote printer's name : <pre>$rname</pre>"); }
    $cmd = "/usr/bsd/rsh -l lp $prn{'rhost'} "
         . "\'grep \"^TYPE\" $irix_iface_path/$prn{'rqueue'}\'";
    $rtype = &backquote_logged("$cmd");
    if ($?) { &error("Failed to read remote printer's type : <pre>$rtype</pre>"); }
  } else {
    $nettype = "bsd";
    $rname = "BSD Printer";
    $rtype = "PostScript";
  }  
  undef local $/;
  open (NETFACE,"<$config{'model_path'}/netface") or &error("Failed to open netface driver."); 
  $driver_file = <NETFACE>;
  close (NETFACE);

  $driver_file =~ s/^TYPE=unknown/$rtype/m;
  $driver_file =~ s/^NAME=/$rname/m;
  $driver_file =~ s/^NETTYPE=/NETTYPE=$nettype/m;
  $driver_file =~ s/^HOSTNAME=/HOSTNAME=$prn{'rhost'}/m;
  $driver_file =~ s/^HOSTPRINTER=/HOSTPRINTER=$prn{'rqueue'}/m;
  
  &open_tempfile(INTERFACE,">$irix_iface_path/$prn{'name'}.tmp", 1) ||
	&error("Failed to open interface for $prn{'name'}."); 
  &print_tempfile(INTERFACE, $driver_file);
  &close_tempfile(INTERFACE);  
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
	$out = &backquote_logged("/usr/lib/lpadmin -d$esc 2>&1");
	if ($?) { &error("Failed to set default : <pre>$out</pre>"); }
	}

# enable or disable
if ($prn{'enabled'}) { $cmd = "/usr/bin/enable $esc"; }
elsif ($prn{'enabled_why'}) {
	local $wesc = quotemeta($prn{'enabled_why'});
	$cmd = "/usr/bin/enable $esc ; /usr/bin/disable -r$wesc $esc";
	}
else { $cmd = "/usr/bin/enable $esc ; /usr/bin/disable $esc"; }
$out = &backquote_logged("$cmd 2>&1");

# accepting or rejecting requests
if ($prn{'accepting'}) { $cmd = "/usr/lib/accept $esc"; }
elsif ($prn{'accepting_why'}) {
	local $wesc = quotemeta($prn{'accepting_why'});
	$cmd = "/usr/lib/accept $esc ; /usr/lib/reject -r$wesc $esc";
	}
else { $cmd = "/usr/lib/accept $esc ; /usr/lib/reject $esc"; }
$out = &backquote_logged("$cmd 2>&1");
}

# delete_printer(name)
# Deletes some existing printer
sub delete_printer
{
local($out, $scheduler);
#$scheduler = &sched_running();
local $esc = quotemeta($_[0]);

# delete print jobs
$out = &backquote_logged("/usr/bin/cancel -a $esc  2>&1");
if ($?) { &error("cancel failed : <pre>$out</pre>"); }

# call lpadmin
$out = &backquote_logged("/usr/lib/lpadmin -x$esc 2>&1");
if ($?) { &error("lpadmin failed : <pre>$out</pre>"); }
}

# cancel_job(printer, id)
# Cancels some print job
sub cancel_job
{
local($out);
local $iesc = quotemeta($_[1]);
$out = &backquote_logged("/usr/bin/cancel $iesc 2>&1");
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
my $cmd = "/usr/lib/lpshut > /dev/null 2>&1;"
        . "/sbin/killall lpautoenable;"
        . "rm -f /var/spool/lp/SCHEDLOCK /var/spool/lp/FIFO;"
        . "/usr/lib/lpsched 2>&1";
local $out = &backquote_logged($cmd);
if ($?) { &error("failed to start lpsched : <tt>$out</tt>"); }
}

# stop_sched(pid)
# Stop the running lpsched process
sub stop_sched
{
local $out = &backquote_logged("/usr/lib/lpshut 2>&1");
if ($?) { &error("lpshut failed : <tt>$out</tt>"); }
}

# print_command(printer, file)
# Returns the command to print some file on some printer
sub print_command
{
local $esc = quotemeta($_[0]);
local $fesc = quotemeta($_[1]);
return "lp -d$esc $fesc";
}

# check_print_system()
sub check_print_system
{
&has_command("lpstat") || return &text('irix_ecmd', "<tt>lpstat</tt>");
-d $irix_iface_path || return &text('irix_eiface',"<tt>$irix_iface_path</tt>");
return undef;
}

@device_files = ("/dev/plp", 
       "/dev/ttyd1", "/dev/ttyd2",
		 "/dev/null");
@device_names = ("Parallel", 
		 "Serial 1", "Serial 2",
		 "Null Device");
