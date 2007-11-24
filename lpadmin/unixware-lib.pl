# unixware-lib.pl
# Functions for UnixWare style printer management

$default_interface = "/usr/lib/lp/model/standard";

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
return &unique(@rv);
}

# get_printer(name, [nostatus])
# Returns a reference to an associative array of printer details
sub get_printer
{
local($stat, @rv, $body, $avl, $con, $sys, %prn, @jobs, $_, $out);
local $esc = quotemeta($_[0]);
$out = `lpstat -l -p $esc`;
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
if ($body =~ /Interface: (.*)/) { $prn{'iface'} = $1; }
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

if (!$_[1]) {
	# request availability
	$avl = `lpstat -a $esc 2>&1`;
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
$con = `lpstat -v $esc 2>&1`;
if ($con =~ /^device for \S+:\s+(\S+)/) { $prn{'dev'} = $1; }
elsif ($con =~ /^system for \S+:\s+(\S+)\s+\(as printer (\S+)\)/) {
	$prn{'rhost'} = $1;
	$prn{'rqueue'} = $2;
	$sys = `lpsystem -l $prn{'rhost'} 2>&1`;
	$sys =~ /Type:\s+(\S+)/; $prn{'rtype'} = $1;
	}

# Check if this is the default printer
`lpstat -d 2>&1` =~ /destination: (\S+)/;
if ($1 eq $prn{'name'}) { $prn{'default'} = 1; }

return \%prn;
}

sub get_jobs
{
local @jobs;

# Get used lang
local $lang = $gconfig{'lang'};

# Added 'env LANG=$lang'
local $esc = quotemeta($_[0]);
open(STAT, "env LANG=$lang lpstat -o $esc |");
while(<STAT>) {
# original line which does not work
#	if (/^(\S+-\d+)\s+(\S+)\s+(\d+)\s+(\S+ \d+ \d+:\d+)\s+(.*)/) {
#

# lang=es
  if ( $lang eq 'es' ) {
	if (/^(\S+-\d+)\s+(\S+)\s+(\d+)\s+(\S+ \d+ \S+ \S+ \d+ \d+:\d+:\d+)\s+(.*)/) {
		local(%job);
		$job{'id'} = $1;
		$job{'user'} = $2;
		$job{'size'} = $3;
		$job{'when'} = $4;
		$job{'printing'} = ($5 =~ /^en /);
		push(@jobs, \%job);
	}
  }
# lang=C (us)
  elsif ( $lang eq 'us' ) {
	if (/^(\S+-\d+)\s+(\S+)\s+(\d+)\s+(\S+ \S+ \d+ \d+:\d+:\d+ \S+ \d+)\s+(.*)/) {
		local(%job);
		$job{'id'} = $1;
		$job{'user'} = $2;
		$job{'size'} = $3;
		$job{'when'} = $4;
		$job{'printing'} = ($5 =~ /^on /);
		push(@jobs, \%job);
	}
  }
# short string (any language)
  elsif (/^(\S+-\d+)\s+(\S+)\s+(\d+)\s+\s+(.*)/) {
		local(%job);
		$job{'id'} = $1;
		$job{'user'} = $2;
		$job{'size'} = $3;
		$job{'when'} = $4;
		$job{'printing'} = ($5 =~ /^on /);
		push(@jobs, \%job);
		}
  }
close(STAT);
return @jobs;
}

# printer_support(option)
sub printer_support
{
return $_[0] !~ /^(msize|alias|riface|direct|rnoqueue|ipp)$/;
}

# list_classes()
# Returns an associative array of print classes
sub list_classes
{
local($stat, %rv);
$stat = `lpstat -c 2>&1`;
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

# call lpsystem if needed
local $tesc = quotemeta($prn{'rtype'});
local $resc = quotemeta($prn{'rhost'});
local $qesc = quotemeta($prn{'rqueue'});
if ($prn{'rhost'}) {
	$out = &backquote_logged("lpsystem -t $tesc $resc 2>&1");
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
	$cmd .= " -v $prn{'dev'}";
	$cmd .= " -i \"$prn{'iface'}\"";
	if ($prn{'banner'}) { $cmd .= " -o banner"; }
	else { $cmd .= " -o nobanner"; }
	}
else { $cmd .= " -s $resc!$qesc"; }
@ctype = @{$prn{'ctype'}};
if (@ctype) { $cmd .= " -I ".join(',' , @ctype); }
$out = &backquote_logged("$cmd 2>&1");
if ($?) { &error("lpadmin failed : <pre>$out</pre>"); }

# make the default
if ($prn{'default'}) {
	$out = &backquote_logged("lpadmin -d $esc 2>&1");
	if ($?) { &error("Failed to set default : <pre>$out</pre>"); }
	}

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
$out = &backquote_logged("cancel $iesc 2>&1");
if ($?) { &error("cancel failed : <pre>$out</pre>"); }
sleep(1);
}

# sched_running()
# Returns the pid if lpsched is running, 0 if not, -1 if cannot be stopped
sub sched_running
{
#@pid = &find_byname("lpsched");
#if (@pid) { return $pid[0]; }
#return 0;
return -1;
}

# start_sched()
# Start lpsched
sub start_sched
{
local $out = &backquote_logged("/usr/lib/lp/lpsched 2>&1");
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
&has_command("lpstat") || return &text('unixware_ecmd', "<tt>lpstat</tt>");
&has_command("/usr/lib/lp/lpsched") || return &text('unixware_ecmd', "<tt>lpsched</tt>");
return undef;
}

@device_files = ("/dev/lp0", "/dev/lp1", "/dev/lp2",
		 "/dev/tty1a", "/dev/tty2a", "/dev/null");
@device_names = (&text('unixware_paralel', "0"), &text('unixware_paralel', "1"),
		 &text('unixware_paralel', "2"), &text('unixware_serial', "A"),
		 &text('unixware_serial', "B"),	$text{'unixware_null'});

