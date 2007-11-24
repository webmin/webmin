# solaris-lib.pl
# Functions for solaris/hpux-style printer management

# Find lpsched command
# But first define the default.
$config{'lpschedcmd'} = "/usr/lib/lp/lpsched";
if (-x "/usr/lib/lpsched") {
	$config{'lpschedcmd'} = "/usr/lib/lpsched";
}

$interface_dir = "/usr/lib/lp/model";
$default_interface = "$interface_dir/standard";
$netstandard_interface = "$interface_dir/netstandard";
$foomatic_interface = "$interface_dir/standard_foomatic";
$foomatic_netstandard_interface = "$interface_dir/netstandard_foomatic";

# list_printers()
# Returns an array of known printer names
sub list_printers
{
return () if (!&sched_running());
local(@rv, $_);
if (open(CONF, "/etc/printers.conf")) {
	# Printers can be read from a file
	while(<CONF>) {
		s/\r|\n//g;
		s/#.*$//;
		if (/^(\S+):/ && $1 ne '_default') { push(@rv, $1); }
		}
	close(CONF);
	}
else {
	# Must use a command to get printers
	open(STAT, "lpstat -v |");
	while(<STAT>) {
		if (/\s+for\s+(\S+):/i && $1 ne '_default') { push(@rv, $1); }
		}
	close(STAT);
	}
return &unique(@rv);
}

# get_printer(name, [nostatus])
# Returns a reference to an associative array of printer details
sub get_printer
{
local($stat, @rv, $body, $avl, $con, $sys, %prn, $_, $out);
local $esc = quotemeta($_[0]);
$out = &backquote_command("lpstat -l -p $esc", 1);
if ($out =~ /^printer\s+(\S+)\s*(.*)\s+(enabled|disabled)\s+since\s+([^\.]*)\.\s+(.*)\.\n([\000-\377]*)$/) {
	# printer exists
	$prn{'name'} = $1;
	$prn{'enabled'} = $3 eq "enabled";
	$body = $6;
	}
elsif ($out =~ /^printer\s+(\S+)\s+waiting for auto-retry.\s+(\S+)\.\n([\000-\377]*)$/) {
	# printer has some problem
	$prn{'name'} = $1;
	$prn{'enabled'} = 1;
	$body = $3;
	}
else {
	# no printer found
	return undef;
	}
if (!$prn{'enabled'} && $body =~ /^\s+(.*)/) {
	$prn{'enabled_why'} = $1 eq "unknown reason" ? "" : $1;
	}
if ($body =~ /Description: (.*)/) { $prn{'desc'} = $1; }
if ($body =~ /Printer types: (.*)/) { $prn{'ptype'} = $1; }
if ($body =~ /Interface: (.*)/ && $1 ne $default_interface)
	{ $prn{'iface'} = $1; }
if ($body =~ /Banner not required/) { $prn{'banner'} = 0; }
else { $prn{'banner'} = 1; }
if ($body =~ /Content types: (.*)/) { $prn{'ctype'} = [ split(/[ ,]+/, $1) ]; }
if ($body =~ /Users (allowed|denied):\n((\s+\S+\n)+)/) {
	local(@l);
	@l = grep { $_ } split(/\s+/, $2);
	if ($1 eq "allowed") {
		if ($l[0] eq "(all)") { $prn{'allow_all'} = 1; }
		elsif ($l[0] eq "(none)") { $prn{'deny_all'} = 1; }
		else { $prn{'allow'} = \@l; }
		}
	else { $prn{'deny'} = \@l; }
	}
if ($body =~ /Options:\s*(.*)/) {
	local $opts = $1;
	local $o;
	foreach $o (split(/,\s*/, $opts)) {
		local ($on, $ov) = split(/=/, $o);
		$prn{'options'}->{$on} = $ov;
		}
	}
if ($body =~ /PPD:\s+(\S+)/ && $1 ne "none" && $1 ne "/dev/null") {
	$prn{'ppd'} = $1;
	}

if (!$_[1]) {
	# request availability
	$avl = &backquote_command("lpstat -a $esc 2>&1", 1);
	if ($avl =~ /^\S+\s+not accepting.*\n\s+(.*)/) {
		$prn{'accepting'} = 0;
		$prn{'accepting_why'} = $1;
		if ($prn{'accepting_why'} eq "unknown reason") {
			$prn{'accepting_why'} = "";
			}
		}
	else { $prn{'accepting'} = 1; }
	}

# request connection
$con = &backquote_command("lpstat -v $esc 2>&1", 1);
if ($con =~ /^device for \S+:\s+(\S+)/) {
	# Prints to a local file
	$prn{'dev'} = $1;
	if ($prn{'dev'} eq "/dev/null" &&
	    ($prn{'iface'} eq $netstandard_interface ||
	     $prn{'iface'} eq $foomatic_netstandard_interface)) {
		# Actually a remote TCP printer
		local ($dh, $dp) = split(/:/, $prn{'options'}->{'dest'});
		if ($dh) {
			$prn{'dhost'} = $dh;
			$prn{'dport'} = $dp;
			delete($prn{'dev'});
			delete($prn{'iface'});
			}
		}
	}
elsif ($con =~ /^system for \S+:\s+(\S+)\s+\(as printer (\S+)\)/ ||
       $con =~ /^system for \S+:\s+(\S+)/) {
	# Prints to a remote server
	$prn{'rhost'} = $1;
	$prn{'rqueue'} = $2 || $prn{'name'};
	$sys = &backquote_command("lpsystem -l $prn{'rhost'} 2>&1", 1);
	$sys =~ /Type:\s+(\S+)/; $prn{'rtype'} = $1;
	}

# Check if this is the default printer
if (!defined($default_printer)) {
	if (&backquote_command("lpstat -d 2>&1", 1) =~ /destination:\s+(\S+)/) {
		$default_printer = $1;
		}
	}
if ($default_printer eq $prn{'name'}) { $prn{'default'} = 1; }

return \%prn;
}

# get_jobs(printer)
sub get_jobs
{
local @jobs;
if ($_[0] =~ /\-/ || $config{'always_lpq'}) {
	# Apparently lpq must be used if the printer name contains a -
	local $esc = quotemeta($_[0]);
	local $lpq = &has_command("lpq") || "/usr/ucb/lpq";
	open(LPQ, "$lpq -P$esc |");
	while(<LPQ>) {
		s/\r|\n//g;
		if (/^Rank\s+Owner\s+/i) { $doneheader++; }
		elsif ($doneheader &&
		       /^(\S+)\s+(\S+)\s+(\d+)\s+(.*\S)\s+(\d+)\s+(\S+)$/) {
			local(%job);
			$job{'id'} = $3;
			$job{'user'} = $2;
			$job{'size'} = $5;
			$job{'file'} = $4;
			$job{'printing'} = ($1 eq "active");
			push(@jobs, \%job);
			}
		}
	close(LPQ);
	}
else {
	# Can use the normal lpstat command
	local $esc = quotemeta($_[0]);
	open(STAT, "lpstat -o $esc |");
	while(<STAT>) {
		if (/^(\S+-(\d+))\s+(\S+)\s+(\d+)\s+(\S+ \d+ \d+:\d+)\s+(.*)/) {
			local(%job, $d, $f, @pf);
			$job{'id'} = $1;
			local $id = $2;
			$job{'user'} = $3;
			$job{'size'} = $4;
			$job{'when'} = $5;
			$job{'printing'} = ($6 =~ /^on /);
			if ($job{'user'} =~ /(\S+)\!/ &&
			    -d ($d="/var/spool/lp/tmp/$1")) {
				opendir(DIR, $d);
				foreach $f (readdir(DIR)) {
					push(@pf, "$d/$f")
						if ($f =~ /^$id-[1-9]/);
					}
				closedir(DIR);
				$job{'printfile'} = @pf ? \@pf : undef;
				}
			push(@jobs, \%job);
			}
		}
	close(STAT);
	}
return @jobs;
}

# printer_support(option)
sub printer_support
{
return $_[0] !~ /^(msize|alias|riface|rnoqueue|ipp)$/;
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
&modify_printer($_[0]);
}

# modify_printer(&details)
# Change an existing printer
sub modify_printer
{
local(%prn, $cmd, $out);
%prn = %{$_[0]};
local $old = &get_printer($prn{'name'});

# call lpsystem if needed
local $tesc = quotemeta($prn{'rtype'});
local $resc = quotemeta($prn{'rhost'});
local $qesc = quotemeta($prn{'rqueue'});
if ($prn{'rhost'}) {
	$out = &backquote_logged(
		"lpsystem -t $tesc $resc 2>&1");
	if ($?) { &error("lpsystem failed : <pre>$out</pre>"); }
	}

# call lpadmin
local $esc = quotemeta($prn{'name'});
local $desc = quotemeta($prn{'desc'}) || "''";
$cmd = "lpadmin -p $esc -D $desc";
if ($prn{'allow_all'}) { $cmd .= " -u allow:all"; }
elsif ($prn{'deny_all'}) { $cmd .= " -u deny:all"; }
elsif ($prn{'allow'}) {
	&system_logged("lpadmin -p $esc -u deny:all >/dev/null 2>&1");
	$cmd .= " -u allow:".join(',', map { quotemeta($_) } @{$prn{'allow'}});
	}
elsif ($prn{'deny'}) {
	&system_logged("lpadmin -p $esc -u allow:all >/dev/null 2>&1");
	$cmd .= " -u deny:".join(',', map { quotemeta($_) } @{$prn{'deny'}});
	}
if ($prn{'dev'}) {
	# Just printing to a device file
	local $vesc = quotemeta($prn{'dev'});
	$cmd .= " -v $vesc";
	if ($prn{'iface'}) {
		local $iesc = quotemeta($prn{'iface'});
		$cmd .= " -i $iesc";
		}
	else {
		if ($prn{'ppd'}) {
			$cmd .= " -i $foomatic_interface";
			}
		else {
			$cmd .= " -i $default_interface";
			}
		}
	if ($prn{'banner'}) { $cmd .= " -o banner"; }
	else { $cmd .= " -o nobanner"; }
	}
elsif ($prn{'dhost'}) {
	# Printing to a remote host
	local $hesc = quotemeta($prn{'dhost'});
	local $pesc = quotemeta($prn{'dport'});
	$cmd .= " -v /dev/null -o dest=$hesc:$pesc -o protocol=tcp";
	if ($prn{'ppd'}) {
		$cmd .= " -i $foomatic_netstandard_interface";
		}
	else {
		$cmd .= " -i $netstandard_interface";
		}
	if ($prn{'banner'}) { $cmd .= " -o banner"; }
	else { $cmd .= " -o nobanner"; }
	}
else {
	# Printing to remote LPR server
	$cmd .= " -s $resc!$qesc";
	}

# Add any content types
local @ctype = @{$prn{'ctype'}};
if (@ctype) {
	$cmd .= " -I ".join(',' , @ctype);
	}

# Add PPD option
if ($_[0]->{'ppd'}) {
	$cmd .= " -n ".quotemeta($_[0]->{'ppd'});
	}
elsif ($old->{'ppd'}) {
	# Need to clear out PPD .. but how?
	$cmd .= " -n /dev/null";
	}

local $out = &backquote_logged("cd / ; $cmd 2>&1");
if ($?) { &error("lpadmin failed : <pre>$out ($cmd)</pre>"); }

# make the default
if ($prn{'default'}) {
	$out = &backquote_logged("cd / ; lpadmin -d $esc 2>&1");
	if ($?) { &error("Failed to set default : <pre>$out</pre>"); }
	}

# Build filter table 
&open_execute_command(STAT, "/usr/bin/ls -1 /etc/lp/fd/*.fd", 1, 1);
while(<STAT>) {
	$file = substr($_, rindex($_, "/") +1, -4 );
	&system_logged("/usr/sbin/lpfilter -f $file -F /etc/lp/fd/$file.fd");
        }
close(STAT);

# enable or disable
if ($prn{'enabled'}) { $cmd = "enable $esc"; }
elsif ($prn{'enabled_why'}) {
	local $wesc = quotemeta($prn{'enabled_why'});
	$cmd = "enable $esc ; disable -r $wesc $esc";
	}
else { $cmd = "enable $esc ; disable $esc"; }
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
$out = &backquote_logged("lpadmin -x $esc 2>&1");
if ($?) { &error("lpadmin failed : <pre>$out</pre>"); }
}

# cancel_job(printer, id)
# Cancels some print job
sub cancel_job
{
local($out);
local $iesc = quotemeta($_[1]);
if ($_[0] =~ /\-/ || $config{'always_lpq'}) {
	# lprm must be used if printer name contains a -
	local $esc = quotemeta($_[0]);
	local $lprm = &has_command("lprm") || "/usr/ucb/lprm";
	$out = &backquote_logged("$lprm -P$esc $iesc 2>&1");
	if ($?) { &error("cancel failed : <pre>$out</pre>"); }
	}
else {
	$out = &backquote_logged("cancel $iesc 2>&1");
	if ($?) { &error("cancel failed : <pre>$out</pre>"); }
	}
sleep(1);
}

# sched_running()
# Returns the pid if lpsched is running, 0 if not, -1 if cannot be stopped
sub sched_running
{
local @pid = &find_byname("lpsched");
if (@pid) { return $pid[0]; }
return 0;
}

# start_sched()
# Start lpsched
sub start_sched
{
local $out = &backquote_logged("$config{'lpschedcmd'} 2>&1");
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
local $fesc = quotemeta($_[1]);
return "lp -d $esc $fesc";
}

# check_print_system()
sub check_print_system
{
local $lpschedcmd = $config{'lpschedcmd'};
&has_command("lpstat") || return &text('solaris_ecmd', "<tt>lpstat</tt>");
&has_command("$lpschedcmd") || return &text('solaris_ecmd', "<tt>$lpschedcmd</tt>");
return undef;
}

#
# get_device_files()
#
sub get_device_files
{

local @files;
#
# There are a string of files that could be used here, include only the
# ones that actually exist.  Start with the parallel ports, and then the
# term ports, lp and printers/*.

$devlist = "/dev/bpp*";
$devlist .= " /dev/ecpp*";
$devlist .= " /dev/term/*";
$devlist .= " /dev/lp*";
$devlist .= " /dev/printers/*";
open(DEV, "/bin/find $devlist -print 2>/dev/null |");
while(<DEV>) {
        push (@files, $_);
	}
close(DEV);
#
# And also include /dev/null
#
push (@files, "/dev/null");
return @files;

}

#
# get_device_names(@files)
#
sub get_device_names
{
local @files = @_;
local @names;
#
# There are a string of files that could be used here, include only the
# ones that actually exist.  Start with the parallel ports, and then the
# term ports, lp and printers/*.

for (@files) {
	if (/bpp/) { push(@names, "$text{'solaris_paralel'} - $_"); }
	elsif (/ecpp/) { push(@names, "$text{'solaris_paralel'} - $_"); }
	elsif (/term\/a/) { push(@names, &text('solaris_serial', 'A') . " - $_"); }
	elsif (/term\/b/) { push(@names, &text('solaris_serial', 'B') . " - $_"); }
	elsif (/null/) { push(@names, "$text{'solaris_null'} - $_"); }
	else { push(@names, "$_"); }
}

return @names;

}

@device_files = &get_device_files();
@device_names = &get_device_names(@device_files);


