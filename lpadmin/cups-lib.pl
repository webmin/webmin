# cups-lib.pl
# Functions for CUPS printer management

$lpstat = &has_command("lpstat.cups") ? "lpstat.cups" : "lpstat";
$lpadmin = &has_command("lpadmin.cups") ? "lpadmin.cups" : "lpadmin";
$lpr = &has_command("lpr.cups") ? "lpr.cups" : "lpr";
$lprm = &has_command("lprm.cups") ? "lprm.cups" : "lprm";
$lpq = &has_command("lpq.cups") ? "lpq.cups" : "lpq";

# list_printers()
# Returns an array of known printer names
sub list_printers
{
return () if (!&sched_running());
local(@rv, $_);
open(STAT, "$lpstat -v |");
while(<STAT>) {
	if (/\s+for\s+(\S+):/i) { push(@rv, $1); }
	}
close(STAT);
return &unique(@rv);
}

# get_printer(name, [nostatus])
# Returns a reference to an associative array of printer details
sub get_printer
{
local($stat, @rv, $body, $avl, $con, $sys, %prn, $_, $out);
local $esc = quotemeta($_[0]);
$out = &backquote_command("$lpstat -l -p $esc", 1);
return undef if ($out =~ /non-existent\s+printer/);
if ($out =~ /^printer\s+(\S+)\s+(\S+).*\n([\000-\377]*)$/) {
	# printer exists..
	$prn{'name'} = $1;
	$prn{'enabled'} = $2 ne "disabled";
	$body = $3;
	}
else {
	# no printer found
	return undef;
	}
if (!$prn{'enabled'} && $body =~ /^\s+(.*)/) {
	$prn{'enabled_why'} = lc($1) eq "paused" || lc($1) eq "reason unknown" ?
			      "" : $1;
	}
if ($body =~ /Description: (.*)/) { $prn{'desc'} = $1; }
if ($body =~ /Printer types: (.*)/) { $prn{'ptype'} = $1; }
if ($body =~ /Interface: (.*)/) { $prn{'iface'} = $1; }
if ($body =~ /Banner not required/) { $prn{'banner'} = 0; }
else { $prn{'banner'} = 1; }

if (!$_[1]) {
	# request availability
	$avl = &backquote_command("$lpstat -a $prn{'name'} 2>&1", 1);
	if ($avl =~ /^\S+\s+not accepting.*\n\s*(.*)/) {
		$prn{'accepting'} = 0;
		$prn{'accepting_why'} = lc($1) eq "reason unknown" ? "" : $1;
		}
	else { $prn{'accepting'} = 1; }
	}

# Try to find the device URI, from printers.conf or lpstat -v
local $uri;
foreach my $file ("/etc/printers.conf", "/etc/cups/printers.conf") {
	next if (!-r $file);
	local $lref = &read_file_lines($file);
	local $inprinter;
	foreach $l (@$lref) {
		if ($l =~ /^\s*<(Default)?Printer\s+(\S+)>/) {
			# Start of a new printer
			$inprinter = $2;
			}
		elsif ($l =~ /^\s*DeviceURI\s+(.*)/ &&
		       $inprinter eq $prn{'name'}) {
			$uri = $1;
			}
		}
	}
if (!$uri) {
	$con = &backquote_command("$lpstat -v $prn{'name'} 2>&1", 1);
	if ($con =~ /^device for \S+:\s+(\S+)/) {
		$uri = $1;
		}
	}

# request connection
if ($uri =~ /^(lpd|ipp):\/\/([^\s\/]+)\/(\S+)/) {
	$prn{'rhost'} = $2;
	$prn{'rqueue'} = $3;
	if ($1 eq 'ipp') {
		$prn{'rtype'} = 'ipp';
		$prn{'rhost'} =~ s/:631//;
		}
	else {
		$prn{'rhost'} =~ s/:515//;
		}
	}
elsif ($uri =~ /^socket:\/\/(\S+):(\d+)/) {
	$prn{'dhost'} = $1;
	$prn{'dport'} = $2;
	}
elsif ($uri =~ /^(file|serial|parallel|usb):([^\s\?]+)/) {
	$prn{'dev'} = $2;
	}
else {
	$prn{'dev'} = $uri;
	}

# Check if this is the default printer
if (&backquote_command("$lpstat -d 2>&1", 1) =~ /destination:\s+(\S+)/ &&
    $1 eq $prn{'name'}) {
	$prn{'default'} = 1;
	}

return \%prn;
}

# get_jobs(printer)
sub get_jobs
{
local (@jobs, $htype);
local $esc = quotemeta($_[0]);
open(LPQ, "$lpq -P$esc |");
while(<LPQ>) {
	s/\r|\n//g;
	next if (/^Rank/i || /^$_[0]/);
	if (/^(\S+)\s+(\S+)\s+(\d+)\s+(.*\S)\s+(\d+)\s+(\S.*)$/ ||
	    /^(\S+)\s+(\S{1,8}?)\s*(\d+)\s+(.*\S)\s+(\d+)\s+(\S.*)$/) {
		# Normal lpq output
		local(%job, $f, @pq);
		$job{'id'} = $3;
		$job{'user'} = $2;
		$job{'size'} = $5;
		$job{'file'} = $4;
		$job{'printing'} = ($1 eq "active");
		local $d = $config{'spool_dir'};
		opendir(DIR, $d);
		while($f = readdir(DIR)) {
			if ($f =~ /^d(\d+)\-(\d+)$/ && $1 == $job{'id'}) {
				push(@pq, "$d/$f");
				local @st = stat("$d/$f");
				if (@st) {
					$job{'time'} ||= $st[9];
					}
				}
			}
		closedir(DIR);
		$job{'printfile'} = @pq ? \@pq : undef;
		if ($job{'time'}) {
			$job{'when'} = &make_date($job{'time'});
			}
		push(@jobs, \%job);
		}
	}
close(LPQ);
return @jobs;
}

# printer_support(option)
sub printer_support
{
return $_[0] !~ /^(msize|alias|rnoqueue|ctype|sysv|allow)$/;
}

# list_classes()
# Returns an associative array of print classes
sub list_classes
{
local($stat, %rv);
$stat = &backquote_command("$lpstat -c 2>&1", 1);
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
&modify_printer($_[0]);
}

# modify_printer(&details)
# Change an existing printer
sub modify_printer
{
local(%prn, $cmd, $out);
%prn = %{$_[0]};

# call lpadmin
local $esc = quotemeta($prn{'name'});
local $desc = quotemeta($prn{'desc'}) || "''";
$cmd = "$lpadmin -p $esc -D $desc";
local $vesc = quotemeta($prn{'dev'});
if ($prn{'dev'} =~ /\/dev\/tty/) {
	$cmd .= " -v serial:$vesc";
	}
elsif ($prn{'dev'} =~ /\/dev\/lp/) {
	$cmd .= " -v parallel:$vesc";
	}
elsif ($prn{'dev'} =~ /\/dev\/usb/) {
	$cmd .= " -v usb:$vesc";
	}
elsif ($prn{'dev'}) {
	$cmd .= " -v $vesc";
	}
elsif ($prn{'rhost'}) {
	local $resc = quotemeta($prn{'rhost'});
	local $qesc = quotemeta($prn{'rqueue'});
	if ($prn{'rtype'} eq 'ipp') {
		$cmd .= " -v ipp://$resc/$qesc";
		}
	else {
		$cmd .= " -v lpd://$resc/$qesc";
		}
	}
else {
	local $resc = quotemeta($prn{'dhost'});
	local $pesc = quotemeta($prn{'dport'});
	$cmd .= " -v socket://$resc:$pesc";
	}
if ($prn{'iface'}) {
	local $iesc = quotemeta($prn{'iface'});
	$cmd .= " -i $iesc";
	}
foreach $o (keys %$cups_driver_options) {
	$cmd .= " -o ".quotemeta($o)."=".quotemeta($cups_driver_options->{$o});
	}
$out = &backquote_logged("cd / ; $cmd 2>&1");
if ($?) { &error("$lpadmin failed : <pre>$out</pre>"); }

# make the default
if ($prn{'default'}) {
	$out = &backquote_logged("cd / ; $lpadmin -d $esc 2>&1");
	if ($?) { &error("Failed to set default : <pre>$out</pre>"); }
	}

# enable or disable
local $enable = &has_command("cupsenable") || &has_command("enable");
local $disable = &has_command("cupsdisable") || &has_command("disable");
if ($prn{'enabled'}) { $cmd = "$enable $esc"; }
elsif ($prn{'enabled_why'}) {
	local $wesc = quotemeta($prn{'enabled_why'});
	$cmd = "$enable $esc ; $disable -r $wesc $esc";
	}
else { $cmd = "$enable $esc ; $disable $esc"; }
$out = &backquote_logged("$cmd 2>&1");

# accepting or rejecting requests
if ($prn{'accepting'}) { $cmd = "accept $esc"; }
elsif ($prn{'accepting_why'}) {
	local $wesc = quotemeta($prn{'accepting_why'});
	$cmd = "accept $esc ; reject -r $wesc $esc";
	}
else { $cmd = "accept $esc ; reject $esc"; }
$out = &backquote_logged("$cmd 2>&1");
}

# delete_printer(name)
# Deletes some existing printer
sub delete_printer
{
local($out);
local $esc = quotemeta($_[0]);
$out = &backquote_logged("$lpadmin -x $esc 2>&1");
if ($?) { &error("$lpadmin failed : <pre>$out</pre>"); }
}

# cancel_job(printer, id)
# Cancels some print job
sub cancel_job
{
local($out);
local $esc = quotemeta($_[0]);
local $iesc = quotemeta($_[1]);
$out = &backquote_logged("$lprm -P$esc $iesc 2>&1");
if ($?) { &error("$lprm failed : <pre>$out</pre>"); }
sleep(1);
}

# sched_running()
# Returns the pid if lpsched is running, 0 if not, -1 if cannot be stopped
sub sched_running
{
@pid = &find_byname("cups");
if (@pid) { return $pid[0]; }
return 0;
}

# start_sched()
# Start lpsched
sub start_sched
{
local $out = &backquote_logged("cupsd 2>&1");
if ($?) { &error("failed to start cups : <tt>$out</tt>"); }
sleep(3);
}

# stop_sched(pid)
# Stop the running lpsched process
sub stop_sched
{
local @pid = ( &find_byname("cupsd") );
&kill_logged('TERM', @pid) || &error("Failed to stop cups : $!");
}

# print_command(printer, file)
# Returns the command to print some file on some printer
sub print_command
{
local $esc = quotemeta($_[0]);
local $fesc = quotemeta($_[1]);
return "$lpr -P$esc $fesc";
}

# check_print_system()
# Returns an error message if CUPS is not installed
sub check_print_system
{
&has_command($lpstat) || return &text('cups_ecmd', "<tt>$lpstat</tt>");
&has_command($lpadmin) || return &text('cups_ecmd', "<tt>$lpadmin</tt>");
return undef;
}

if (-r "/dev/lp0") {
	@device_files = ("/dev/lp0", "/dev/lp1", "/dev/lp2", "/dev/lp3",
			 "/dev/ttyS0", "/dev/ttyS1", "/dev/null");
	}
else {
	@device_files = ("/dev/lp1", "/dev/lp2", "/dev/lp2", "/dev/lp3",
			 "/dev/ttyS0", "/dev/ttyS1", "/dev/null");
	}
if (-r "/dev/usblp0") {
	push(@device_files, "/dev/usblp0", "/dev/usblp1",
			    "/dev/usblp2", "/dev/usblp3");
	}
elsif (-r "/dev/usb/lp0") {
	push(@device_files, "/dev/usb/lp0", "/dev/usb/lp1",
			    "/dev/usb/lp2", "/dev/usb/lp3");
	}
@device_names = (&text('linux_paralel', "1"), &text('linux_paralel', "2"),
		 &text('linux_paralel', "3"), &text('linux_paralel', "4"),
		 &text('linux_serial', "1"), &text('linux_serial', "2"),
		 $text{'linux_null'},  &text('linux_usb', 1),
		 &text('linux_usb', 2), &text('linux_usb', 3),
		 &text('linux_usb', 4));

