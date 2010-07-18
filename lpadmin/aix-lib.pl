# aix-lib.pl
# Functions for AIX-style printer management

# get_qconfig()
sub get_qconfig
{
local @rv;
local $prn;
local $lnum = 0;
open(CONF, $config{'printcap_file'});
while(<CONF>) {
	s/\r|\n//g;
	s/^\s*#.*$//;	
	s/^\s*\*.*$//;	
	if (/^(\S+):\s*$/) {
		# Start of a new printer
		$prn = { 'name' => $1,
			  'line' => $lnum,
			  'eline' => $lnum };
		push(@rv, $prn);
		}
	elsif (/^\s+(\S+)\s*=\s*(.*)/ && $prn) {
		# Variable within a printer
		$prn->{'eline'} = $lnum;
		$prn->{'values'}->{lc($1)} = $2;
		}
	$lnum++;
	}
close(CONF);
return @rv;
}

# list_printers()
# Returns an array of known printer names
sub list_printers
{
local @qc = &get_qconfig();
local (@rv, $q);
foreach $q (@qc) {
	if ($q->{'values'}->{'device'}) {
		# A real printer
		push(@rv, $q->{'name'});
		}
	}
return &unique(@rv);
}

# get_printer(name, [nostatus])
# Returns a reference to an associative array of printer details
sub get_printer
{
if (!%enabled_cache) {
	%enabled_cache = &get_enabled();
	}

# Find the printer in qconfig
local @qc = &get_qconfig();
local %prn;
local ($real) = grep { $_->{'name'} eq $_[0] } @qc;
return undef if (!$real);
local ($device) = grep { $_->{'name'} eq $real->{'values'}->{'device'} &&
			    $_->{'line'} > $real->{'line'} } @qc;

# Construct info object
$prn{'name'} = $_[0];
$prn{'accepting'} = uc($real->{'values'}->{'up'}) ne 'FALSE';
$prn{'enabled'} = $enabled_cache{$_[0]};
$prn{'desc'} = $real->{'values'}->{'device'};		# XXX
if ($real->{'values'}->{'rq'}) {
	# Remote printer
	$prn{'rhost'} = $real->{'values'}->{'host'};
	$prn{'rqueue'} = $real->{'values'}->{'rq'};
	if ($real->{'values'}->{'s_statfilter'} =~ /bsdshort/) {
		$prn{'type'} = 'bsd';
		}
	elsif ($real->{'values'}->{'s_statfilter'} =~ /attshort/) {
		$prn{'type'} = 's5';
		}
	elsif ($real->{'values'}->{'s_statfilter'} =~ /aixv2short/) {
		$prn{'type'} = 'aix2';
		}
	else {
		# Assume AIX by default
		$prn{'type'} = 'aix';
		}
	}
elsif ($device->{'values'}->{'backend'} =~ /piojetd\s+(\S+)\s+(\d+)/) {
	# Jetdirect printer
	$prn{'dhost'} = $1;
	$prn{'dport'} = $2;
	}
else {
	# Local printer
	$prn{'dev'} = "/dev/$_[0]";		# XXX
	}
$prn{'banner'} = 1 if (lc($device->{'values'}->{'header'}) eq 'always');
if (!$prn{'dhost'} &&
    $device->{'values'}->{'backend'} !~ /(rembak|piojetd|piob)/) {
	$prn{'iface'} = $device->{'values'}->{'backend'};
	}
return \%prn;

# XXX user access control
# XXX default printer?
# XXX remote system type
}

# get_jobs(printer)
sub get_jobs
{
local @jobs;
local $esc = quotemeta($_[0]);
local $doneheader;
open(LPQ, "lpq -P$esc |");
while(<LPQ>) {
	s/\r|\n//g;
	if (/^\-\-\-/) {
		$doneheader++;
		}
	elsif ($doneheader &&
	       /^\s+(\S+)\s+(\d+)\s+(\S+)\s+(\S+)/) {
		local $job = { 'id' => $2,
			       'user' => $4,
			       'file' => $3,
			       'printing' => lc($1) eq "active" };
		push(@jobs, $job);
		}
	}
close(LPQ);
return @jobs;
}

# printer_support(option)
sub printer_support
{
return $_[0] !~ /^(why|allow|default|msize|ctype|alias|sysv|ipp|rnoqueue)$/;
}

# create_printer(&details)
# Create a new printer
sub create_printer
{
local $lref = &read_file_lines($config{'printcap_file'});
push(@$lref, &qconfig_real_lines($_[0]));
push(@$lref, &qconfig_device_lines($_[0]));
&flush_file_lines();
&enable_disable($_[0]);
}

# modify_printer(&details)
# Change an existing printer
sub modify_printer
{
# Find old entry
local @qc = &get_qconfig();
local ($real) = grep { $_->{'name'} eq $_[0]->{'name'} } @qc;
$real || &error("Failed to find old printer!");
local ($device) = grep { $_->{'name'} eq $real->{'values'}->{'device'} &&
			    $_->{'line'} > $real->{'line'} } @qc;

# Update lines in file
local $lref = &read_file_lines($config{'printcap_file'});
if ($device) {
	splice(@$lref, $device->{'line'},
	       $device->{'eline'} - $device->{'line'} + 1,
	       &qconfig_device_lines($_[0], $device));
	}
else {
	splice(@$lref, $real->{'eline'} + 1, 0,
	       &qconfig_device_lines($_[0]));
	}
splice(@$lref, $real->{'line'}, $real->{'eline'} - $real->{'line'} + 1,
       &qconfig_real_lines($_[0], $real));
&flush_file_lines();
&enable_disable($_[0]);
}

# enable_disable(&printer)
# Enable or disable some printer
sub enable_disable
{
local %ena = &get_enabled();
if ($_[0]->{'enabled'} && !$ena{$_[0]->{'name'}}) {
	&system_logged("enable ".quotemeta($_[0]->{'name'}));
	}
elsif (!$_[0]->{'enabled'} && $ena{$_[0]->{'name'}}) {
	&system_logged("disable ".quotemeta($_[0]->{'name'}));
	}
}

# get_enabled()
# Returns a hash from printer names to their enabled statuses
sub get_enabled
{
local %ena;
open(ENA, "lpstat -s -W |");
while(<ENA>) {
	s/\r|\n//g;
	next if (/^Queue|\-\-\-\-/);
	if (/^\s*(\S+)\s+(\S+)\s+(\S+)/) {
		$ena{$1} = $3 eq 'READY';
		}
	}
close(ENA);
return %ena;
}

# delete_printer(name)
# Deletes some existing printer
sub delete_printer
{
# Find old entry
local @qc = &get_qconfig();
local ($real) = grep { $_->{'name'} eq $_[0] } @qc;
local ($device) = grep { $_->{'name'} eq $real->{'values'}->{'device'} &&
			    $_->{'line'} > $real->{'line'} } @qc;

# Take lines out of file
local $lref = &read_file_lines($config{'printcap_file'});
if ($device) {
	splice(@$lref, $device->{'line'},
	       $device->{'eline'} - $device->{'line'} + 1);
	}
splice(@$lref, $real->{'line'},
       $real->{'eline'} - $real->{'line'} + 1);
&flush_file_lines();
}

# qconfig_real_lines(&printer, [&old-real])
sub qconfig_real_lines
{
local $real = $_[1] || { 'name' => $_[0]->{'name'},
			 'values' => { } };
$_[0]->{'desc'} ||= "$_[0]->{'name'}_device";
$real->{'values'}->{'device'} = $_[0]->{'desc'};
if ($_[0]->{'accepting'}) {
	delete($real->{'values'}->{'up'});
	}
else {
	$real->{'values'}->{'up'} = 'FALSE';
	}
if ($_[0]->{'rhost'}) {
	$real->{'values'}->{'host'} = $_[0]->{'rhost'};
	$real->{'values'}->{'rq'} = $_[0]->{'rqueue'};
	if ($_[0]->{'type'} eq 'bsd') {
		$real->{'values'}->{'s_statfilter'} = "/usr/lpd/bsdshort";
		$real->{'values'}->{'l_statfilter'} = "/usr/lpd/bsdlong";
		}
	elsif ($_[0]->{'type'} eq 's5') {
		$real->{'values'}->{'s_statfilter'} = "/usr/lpd/attshort";
		$real->{'values'}->{'l_statfilter'} = "/usr/lpd/attlong";
		}
	elsif ($_[0]->{'type'} eq 'aix2') {
		$real->{'values'}->{'s_statfilter'} = "/usr/lpd/aixv2short";
		$real->{'values'}->{'l_statfilter'} = "/usr/lpd/aixv2long";
		}
	else {
		$real->{'values'}->{'s_statfilter'} = "/usr/lpd/aixshort";
		$real->{'values'}->{'l_statfilter'} = "/usr/lpd/aixlong";
		}
	}
else {
	delete($real->{'values'}->{'host'});
	delete($real->{'values'}->{'rq'});
	delete($real->{'values'}->{'s_statfilter'});
	delete($real->{'values'}->{'l_statfilter'});
	}
return &qconfig_lines($real);
}

# qconfig_device_lines(&printer, [&old-device])
sub qconfig_device_lines
{
local $device = $_[1] || { 'name' => $_[0]->{'desc'},
			   'values' => { } };
if ($_[0]->{'rhost'}) {
	$device->{'values'}->{'backend'} = "/usr/lib/lpd/rembak";
	}
elsif ($_[0]->{'dhost'}) {
	$device->{'values'}->{'backend'} = "/usr/lib/lpd/pio/etc/piojetd $_[0]->{'dhost'} $_[0]->{'dport'}";
	if (!$device->{'values'}->{'file'}) {
		local $dfile = "/var/spool/lpd/pio/\@local/dev/hp\@$_[0]->{'dhost'}#hpJetDirect#$_[0]->{'dport'}";
		$device->{'values'}->{'file'} = $dfile;
		&open_tempfile(DFILE, ">$dfile");
		&print_tempfile(DFILE, "desc\t=\thpJetDirect\n");
		&close_tempfile(DFILE);
		}
	}
elsif ($_[0]->{'iface'}) {
	$device->{'values'}->{'backend'} = $_[0]->{'iface'};
	}
else {
	$device->{'values'}->{'backend'} = "/usr/lib/lpd/piobe";
	}
if ($_[0]->{'banner'}) {
	$device->{'values'}->{'header'} = "always";
	}
else {
	$device->{'values'}->{'header'} = "never";
	}
return &qconfig_lines($device);
}

sub qconfig_lines
{
local @rv = ( "$_[0]->{'name'}:" );
local $k;
foreach $k (keys %{$_[0]->{'values'}}) {
	push(@rv, "\t$k = $_[0]->{'values'}->{$k}");
	}
return @rv;
}

# cancel_job(printer, id)
# Cancels some print job
sub cancel_job
{
local $esc = quotemeta($_[0]);
local $iesc = quotemeta($_[1]);
local $out = &backquote_logged("lprm -P $esc $iesc 2>&1");
if ($?) { &error("cancel failed : <pre>$out</pre>"); }
sleep(1);
}

# sched_running()
# Returns the pid if lpsched is running, 0 if not, -1 if cannot be stopped
sub sched_running
{
local @qpid = &find_byname("qdaemon");
local @lpid = &find_byname("lpd");
if (@qpid && @lpid) { return $qpid[0]; }
return 0;
}

# start_sched()
# Start lpsched
sub start_sched
{
local $s;
foreach $s ("qdaemon", "lpd") {
	if (!&find_byname($s)) {
		local $out = &backquote_logged("/usr/bin/startsrc -s$s 2>&1");
		if ($?) { &error("failed to start $s : <tt>$out</tt>"); }
		}
	}
}

# stop_sched(pid)
# Stop the running lpsched process
sub stop_sched
{
local $s;
foreach $s ("qdaemon", "lpd") {
	if (&find_byname($s)) {
		local $out = &backquote_logged("/usr/bin/stopsrc -s$s 2>&1");
		if ($?) { &error("failed to start $s : <tt>$out</tt>"); }
		}
	}
}

# print_command(printer, file)
# Returns the command to print some file on some printer
sub print_command
{
local $esc = quotemeta($_[0]);
local $fesc = quotemeta($_[1]);
return "lpr -P $esc $fesc";
}

# check_print_system()
sub check_print_system
{
&has_command("qdaemon") || return &text('aix_ecmd', "<tt>qdaemon</tt>");
return undef;
}

# validate_printer(&printer)
# Performs extra OS-specific printer validation, and returns an error message
# if there is a problem
sub validate_printer
{
return $text{'aix_edesc'} if ($_[0]->{'desc'} !~ /^[a-z0-9\-\.\_\@]*$/i);
return undef;
}

sub remote_printer_types
{
return ( [ 'aix', 'AIX' ], [ 'bsd', 'BSD' ],
	 [ 's5', 'ATT SysV' ], [ 'aix2', 'AIX v2' ] );
}

@device_files = ("/dev/lp0", "/dev/lp1", "/dev/null" );
@device_names = (&text('aix_port', "0"), &text('aix_port', "1"),
		 $text{'solaris_null'});

