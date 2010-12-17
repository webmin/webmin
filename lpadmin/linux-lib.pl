# linux-lib.pl
# Functions for printcap-style printer management

# list_printers()
# Returns a list of known printer names
sub list_printers
{
local($l, @rv);
foreach $l (&list_printcap()) {
	$l->{'name'} =~ /^([^\|]+)/;
	push(@rv, $1);
	}
return @rv;
}

# get_printer(name, [nostatus])
sub get_printer
{
local($l, %prn, @w, @n, $w, %cap, @jobs);
foreach $l (&list_printcap()) {
	@n = split(/\|/, $l->{'name'});
	if ($n[0] eq $_[0]) {
		# found the printer.. get info from printcap
		$prn{'name'} = $n[0];
		if (@n > 2) { $prn{'alias'} = [ @n[1..$#n-1] ]; }
		if (@n > 1) { $prn{'desc'} = $n[$#n]; }
		$prn{'iface'} = $l->{'if'};
		$prn{'banner'} = !defined($l->{'sh'});
		$prn{'dev'} = $l->{'lp'};
		$prn{'rhost'} = $l->{'rm'};
		$prn{'rqueue'} = $l->{'rp'};
		$prn{'msize'} = $l->{'mx'};
		$prn{'comment'} = $l->{'comment'};
		$prn{'ro'} = $l->{'file'} eq $config{'ro_printcap_file'};

		if (!$_[1]) {
			# call lpc to get status
			local $esc = quotemeta($prn{'name'});
			$out = &backquote_command("lpc status $esc 2>&1", 1);
			$prn{'accepting'} = ($out =~ /queuing is enabled/);
			$prn{'enabled'} = ($out =~ /printing is enabled/);
			}

		return \%prn;
		}
	}
return undef;
}

# get_jobs(printer)
sub get_jobs
{
local (@jobs, $htype);
local $esc = quotemeta($_[0]);
open(LPQ, "lpq -P$esc |");
while(<LPQ>) {
	chop;
	if (/^\s*Rank\s+Owner\s+\S+\s+Job/) { $htype = 2; }
	elsif (/^Rank\s+Owner\s+/) { $htype = 1; }
	elsif ($htype == 1 &&
	       /^(\S+)\s+(\S+)\s+(\d+)\s+(.*\S)\s+(\d+)\s+(\S+)$/) {
		# Normal lpq output
		local(%job, $f, @pq);
		$job{'id'} = $3;
		$job{'user'} = $2;
		$job{'size'} = $5;
		$job{'file'} = $4;
		$job{'printing'} = ($1 eq "active");
		local $d = "$config{'spool_dir'}/$_[0]";
		opendir(DIR, $d);
		while($f = readdir(DIR)) {
			if ($f =~ /df.(\d+)/ && $1 == $job{'id'}) {
				push(@pq, "$d/$f");
				}
			}
		closedir(DIR);
		$job{'printfile'} = @pq ? \@pq : undef;
		push(@jobs, \%job);
		}
	elsif ($htype == 2 &&
	       /^\s*(\S+)\s+(\S+)\s+(\S+)\s+(\d+)\s+(\S+)\s+(\S+)\s+(\d*)\s+(\S+)\s+(\S+)\s+(\S+)$/) {
		# PLP lpq output
		local(%job);
		$job{'id'} = $4;
		$job{'user'} = $2;
		$job{'size'} = $4;
		$job{'file'} = $6;
		push(@jobs, \%job);
		}
	}
close(LPQ);
return @jobs;
}

sub printer_support
{
return $_[0] !~ /^(why|allow|default|ctype|sysv|direct|ipp)$/;
}


# create_printer(&details)
# Create a new printer in /etc/printcap
sub create_printer
{
local(%cap);
$cap{'sd'} = "$config{'spool_dir'}/$_[0]->{'name'}";
&lock_file($cap{'sd'});
mkdir($cap{'sd'}, 0755);
&unlock_file($cap{'sd'});

&lock_file($config{'printcap_file'});
local $lref = &read_file_lines($config{'printcap_file'});
push(@$lref, &make_printcap($_[0], \%cap));
&flush_file_lines($config{'printcap_file'});
&unlock_file($config{'printcap_file'});

&apply_status($_[0]);
}

# modify_printer(&details)
sub modify_printer
{
local(@old, $o, $old, @cap);
&lock_file($config{'printcap_file'});
@old = &list_printcap();
foreach $o (@old) {
	$o->{'name'} =~ /^([^\|]+)/;
	if ($1 eq $_[0]->{'name'}) {
		# found current details
		$old = $o;
		last;
		}
	}
if (!$old) { &error("Printer '$_[0]->{'name'}' no longer exists"); }

&lock_file($config{'printcap_file'});
local $lref = &read_file_lines($config{'printcap_file'});
splice(@$lref, $old->{'line'}, $old->{'eline'} - $old->{'line'} + 1,
       &make_printcap($_[0], $old));
&flush_file_lines($config{'printcap_file'});
&unlock_file($config{'printcap_file'});

&apply_status($_[0]);
}

# delete_printer(name)
sub delete_printer
{
local(@old, $o, $old, @cap);
&lock_file($config{'printcap_file'});
@old = &list_printcap();
foreach $o (@old) {
	$o->{'name'} =~ /^([^\|]+)/;
	if ($1 eq $_[0]) {
		# found current details
		$old = $o;
		last;
		}
	}
if (!$old) { &error("Printer '$_[0]' no longer exists"); }

&lock_file($config{'printcap_file'});
local $lref = &read_file_lines($config{'printcap_file'});
splice(@$lref, $old->{'line'}, $old->{'eline'} - $old->{'line'} + 1);
&flush_file_lines($config{'printcap_file'});
&unlock_file($config{'printcap_file'});

if ($old->{'sd'} eq "$config{'spool_dir'}/$_[0]") {
	system("rm -rf '$old->{'sd'}'");
	}
}

# cancel_job(printer, job)
# Calls lprm to remove some job
sub cancel_job
{
local($out);
local $esc = quotemeta($_[0]);
local $iesc = quotemeta($_[1]);
$out = &backquote_logged("lprm -P$esc $iesc 2>&1");
if ($?) { &error("lprm failed : $out"); }
}

# make_printcap(&details, &old)
# Updates or creates a printcap line
sub make_printcap
{
local(%prn, %cap, $a, $rv, $c);
%prn = %{$_[0]}; %cap = %{$_[1]};
$cap{'if'} = $prn{'iface'} ? $prn{'iface'} : undef;
$cap{'sh'} = $prn{'banner'} ? undef : "";
$cap{'lp'} = $prn{'dev'} ? $prn{'dev'} : undef;
$cap{'rm'} = $prn{'rhost'} ? $prn{'rhost'} : undef;
$cap{'rp'} = $prn{'rqueue'} ? $prn{'rqueue'} : undef;
$cap{'mx'} = defined($prn{'msize'}) ? $prn{'msize'} : undef;
$rv = $prn{'comment'}."\n" if ($prn{'comment'});
$rv .= $prn{'name'};
foreach $a (@{$prn{'alias'}}) { $rv .= "|$a"; }
$rv .= "|$prn{'desc'}" if ($prn{'desc'});
foreach $c (keys %cap) {
	if ($c =~ /^(\S\S)(#?)$/ && defined($cap{$c})) {
		if ($cap{$c} eq "") { $rv .= ":$c"; }
		elsif ($cap{$c} =~ /^\d+$/) { $rv .= ":$c#$cap{$c}"; }
		else { $rv .= ":$c=$cap{$c}"; }
		}
	}
$rv .= ":";
return $rv;
}

# list_printcap()
# Returns an array of associative arrays containing printcap fields
sub list_printcap
{
return @list_printcap_cache if (scalar(@list_printcap_cache));
local(@rv, @line, @comment, @eline, @sline, $line, $cont, $lnum, $i,
      %done, $capfile);
foreach $capfile ($config{'printcap_file'}, $config{'ro_printcap_file'}) {
	next if (!$capfile || $done{$capfile}++);
	open(CAP, $capfile);
	$lnum = 0;
	while($line = <CAP>) {
		$line =~ s/\s+$//g;	# remove trailing spaces/newline
		if ($line =~ /^(##.*)/) {
			# special commented line .. keep it
			$comment[@line] = $line;
			}
		else {
			$line =~ s/^#.*$//g;	# remove comments
			$line =~ s/^\s+//g;	# remove leading spaces
			if ($line =~ /\S/) {
				local $ncont = ($line =~ s/\\$//g);
				if ($cont) {
					$line[$#line] .= $line;
					$eline[@line - 1] = $lnum;
					}
				else {
					push(@line, $line);
					$eline[@line - 1] = $sline[@line - 1] = $lnum;
					}
				$cont = $ncont;
				}
			else {
				# only keep comments immediately before an entry
				$comment[@line] = undef;
				}
			}
		$lnum++;
		}
	close(CAP);
	for($i=0; $i<@line; $i++) {
		local(%cap);
		@w = split(/:+/, $line[$i]);
		$cap{'name'} = $w[0];
		$cap{'line'} = $sline[$i] - ($comment[$i] ? 1 : 0);
		$cap{'eline'} = $eline[$i];
		$cap{'comment'} = $comment[$i];
		$cap{'file'} = $capfile;
		foreach $w (@w[1..$#w]) {
			if ($w =~ /^([A-z0-9]+)[=#](.*)$/) { $cap{$1} = $2; }
			elsif ($w =~ /^([A-z0-9]+)$/) { $cap{$w} = ""; }
			}
		push(@rv, \%cap);
		}
	}
@list_printcap_cache = @rv;
return @rv;
}

# apply_status(&details)
# Calls lpc to enable or disable a printer.
# Restarting lpd doesn't seem to be necessary?
sub apply_status
{
local($out);
local $esc = quotemeta($_[0]->{'name'});
$out = &backquote_command("lpc status $esc 2>&1", 1);
if ($_[0]->{'enabled'} && $out !~ /printing is enabled/)
	{ &backquote_logged("lpc up $esc"); }
elsif (!$_[0]->{'enabled'} && $out =~ /printing is enabled/)
	{ &backquote_logged("lpc down $esc"); }
if ($_[0]->{'accepting'} && $out !~ /queuing is enabled/)
	{ &backquote_logged("lpc enable $esc"); }
elsif (!$_[0]->{'accepting'} && $out =~ /queuing is enabled/)
	{ &backquote_logged("lpc disable $esc"); }
}

# sched_running()
# Returns the pid if lpsched is running, 0 if not, -1 if cannot be stopped
sub sched_running
{
@pid = &find_byname("lpd");
if (@pid) { return $pid[0]; }
return 0;
}

# start_sched()
# Start lpsched
sub start_sched
{
local $out = &backquote_logged("lpd 2>&1");
if ($?) { &error("failed to start lpd : <tt>$out</tt>"); }
}

# stop_sched(pid)
# Stop the running lpsched process
sub stop_sched
{
local @pid = &find_byname("lpd");
&kill_logged('TERM', @pid) || &error("Failed to stop lpd : $!");
}

# print_command(printer, file)
# Returns the command to print some file on some printer
sub print_command
{
local $esc = quotemeta($_[0]);
local $fesc = quotemeta($_[1]);
return "lpr -P$esc $fesc";
}

# check_print_system()
sub check_print_system
{
&has_command("lpr") || return &text('linux_ecmd', "<tt>lpr</tt>");
-d $config{'spool_dir'} || return &text('linux_espool', "<tt>$config{'spool_dir'}</tt>");
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
		 $text{'linux_null'}, &text('linux_usb', 1),
		 &text('linux_usb', 2), &text('linux_usb', 3),
		 &text('linux_usb', 4));

