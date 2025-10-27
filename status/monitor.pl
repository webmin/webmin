#!/usr/local/bin/perl
# monitor.pl
# Check all the monitors and send email if something is down

$no_acl_check++;
delete($ENV{'FOREIGN_MODULE_NAME'});
delete($ENV{'SCRIPT_NAME'});
delete($ENV{'SERVER_ROOT'});
delete($ENV{'LANG'});
require './status-lib.pl';

# Parse command-line args
while(@ARGV) {
	my $a = shift(@ARGV);
	if ($a eq "--force") {
		$force = 1;
		}
	elsif ($a eq "--debug") {
		$debug = 1;
		}
	elsif ($a !~ /^-/) {
		push(@only, $a);
		}
	else {
		die "usage: $0 [--force] [--debug] [monitor]*";
		}
	}
if ($debug) {
	open(DEBUG, ">&STDOUT");
	}
else {
	open(DEBUG, ">/dev/null");
	}

# Check if the monitor should be run now
@tm = localtime(time());
if ($force) {
	$by = "web";
	}
else {
	@hours = split(/\s+/, $config{'sched_hours'});
	!@hours || &indexof($tm[2], @hours) >= 0 || exit;
	@days = split(/\s+/, $config{'sched_days'});
	!@days || &indexof($tm[6], @days) >= 0 || exit;
	$by = "cron";
	}

# Check for list of monitors to limit refresh to
%onlycheck = map { $_, 1 } @only;

# Open status and number of fails files
&lock_file($oldstatus_file);
&read_file($oldstatus_file, \%oldstatus);
&lock_file($fails_file);
&read_file($fails_file, \%fails);
&lock_file($lastsent_file);
&read_file($lastsent_file, \%lastsent);

# Get the list of services, ordered so that those with dependencies are first
@services = &list_services();
@services = sort { &sort_func($a, $b) } @services;
if (keys %onlycheck) {
	@services = grep { $onlycheck{$_->{'id'}} } @services;
	}

# Check for services that are down
$nowunix = time();
$now = &make_date($nowunix);
($nowdate, $nowtime) = split(/\s+/, $now);
$thishost = &get_system_hostname();
$ecount = 0;
foreach $serv (@services) {
	print DEBUG "$serv->{'id'}:\n";
	if ($serv->{'nosched'} == 1) {
		# Scheduled checking totally disabled
		print DEBUG "  Scheduled checking disabled\n";
		delete($oldstatus{$serv->{'id'}});
		next;
		}
	@remotes = &expand_remotes($serv);
	print DEBUG "  Remote servers ",join(" ", @remotes),"\n";

	# Check if we depend on something that is down
	if ($serv->{'depend'} && defined($oldstatus{$serv->{'depend'}})) {
		print DEBUG "  Depends on $serv->{'depend'}\n";
		$depend = &get_service($serv->{'depend'});
		$depstats = &expand_oldstatus($oldstatus{$serv->{'depend'}},
					      $depend);
		@depremotes = split(/\s+/, $depend->{'remote'});
		if ($depstats->{$depremotes[0]} != 1) {
			# It is .. mark all as failed dependencies
			print DEBUG "  Dependency has failed\n";
			$oldstatus{$serv->{'id'}} = 
				join(" ", map { "$_=-4" } @remotes);
			next;
			}
		}

	# Find the current status
	$warn = $serv->{'nosched'} == 0 ? $config{'sched_warn'} :
		$serv->{'nosched'} - 2;
	@stats = &service_status($serv);
	$oldstats = &expand_oldstatus($oldstatus{$serv->{'id'}}, $serv);

	# Find the notification modes
	%notify = map { $_, 1 } split(/\s+/, $serv->{'notify'});

	# If the number of fails before warning is > 1, then the status may
	# still be considered OK even if it is down right now
	local $up = $stat->{'up'};
	if ($up != 1 && $serv->{'fails'} > 1) {
		$fails{$serv->{'id'}}++;
		if ($fails{$serv->{'id'}} < $serv->{'fails'}) {
			# Not really down yet
			$up = 1;
			}
		}
	else {
		$fails{$serv->{'id'}} = 0;
		}

	# Check for a status change or failure on each monitored host,
	# and perform the appropriate action
	$newstats = { };
	$newvalues = { };
	$newvalues_nice = { };
	foreach $r (@remotes) {
		# Work out the hostname
		local $host = $r eq "*" ? $thishost : $r;
		$o = $oldstats->{$r};
		print DEBUG "  Checking on server $host\n";

		# Get the up/down status
		local ($stat) = grep { $_->{'remote'} eq $r } @stats;
		if (!$stat) {
			print DEBUG "  Failed to find status for $r!\n";
			next;
			}
		print DEBUG "  Status $stat->{'up'}\n";
		print DEBUG "  Failure count $serv->{'fails'}\n"
			if ($serv->{'fails'});
		print DEBUG "  Description $stat->{'desc'}\n"
			if ($stat->{'desc'});
		print DEBUG "  Value $stat->{'value'}\n"
			if (defined($stat->{'value'}));

		# If the number of fails before warning is > 1, then the status
		# may still be considered OK even if it is down right now
		local $up = $stat->{'up'};
		local $fid = $serv->{'id'}."-".$r;
		if ($up != 1 && $serv->{'fails'} > 1) {
			# Not up, but more than one failure is needed for it to
			# be considered down for alerting purposes.
			$fails{$fid}++;
			if ($fails{$fid} < $serv->{'fails'}) {
				# Not really down yet
				$up = 1;
				}
			}
		else {
			$fails{$fid} = 0;
			}

		$thisemail = undef;
		$suffix = undef;
		$out = undef;
		if ($warn == 0 && $up == 0 && $o) {
			# Service has just gone down
			$suffix = "down";
			$out = &run_on_command($serv, $serv->{'ondown'}, $r);
			}
		elsif ($warn == 1 && $up != $o &&
		       (defined($o) || $up == 0)) {
			# Service has changed status
			if ($up == 0) {
				# A monitor has gone down
				$suffix = "down";
				$out = &run_on_command($serv, $serv->{'ondown'}, $r);
				}
			elsif ($up == 1 && $o != -4) {
				# A monitor has come back up after being down
				$suffix = "up";
				$out = &run_on_command($serv, $serv->{'onup'}, $r);
				}
			elsif ($up == -1) {
				# Detected that a program the monitor depends on
				# is not installed
				$suffix = "un";
				}
			elsif ($up == -2) {
				# Cannot contact remote Webmin
				$suffix = "webmin";
				}
			elsif ($up == -3) {
				# Monitor function timed out
				$suffix = "timed";
				$out = &run_on_command($serv,
						       $serv->{'ontimeout'}, $r);
				}
			}
		elsif ($warn == 2 && $up == 0) {
			# Service is down now
			$suffix = "isdown";
			$out = &run_on_command($serv, $serv->{'ondown'}, $r);
			}
		elsif ($warn == 3 && $up == 1) {
			# Service is up now
			$suffix = "isup";
			$out = &run_on_command($serv, $serv->{'onup'}, $r);
			}

		# If something happened, notify people
		if ($suffix &&
		    $nowunix - $lastsent{$serv->{'id'}} > $config{'email_interval'} * 60) {
			$subj = &text('monitor_sub_'.$suffix,
				      $serv->{'desc'}, $host);
			if ($notify{'pager'}) {
				$pager_msg .= &make_message($suffix, $host,
							$serv, 'pager', $stat);
				}
			if ($notify{'sms'}) {
				$sms_msg .= &make_message($suffix, $host,
							$serv, 'sms', $stat);
				}
			if ($notify{'snmp'}) {
				push(@snmp_msg, &make_message($suffix, $host,
							$serv, 'snmp', $stat));
				}
			if ($notify{'email'}) {
				$thisemail .= &make_message($suffix, $host,
							$serv, 'email', $stat);
				if ($out) {
					$thisemail .= $out;
					}
				$thisemail .= "\n";
				$ecount++;
				}
			if ($notify{'webhook'}) {
				push(@webhooks, [ $serv, $stat, $suffix, $host ]);
				}
			$lastsent{$serv->{'id'}} = $nowunix;
			}
		$newstats->{$r} = $up;
		$newvalues->{$r} = $stat->{'value'};
		$newvalues_nice->{$r} = $stat->{'nice_value'};

		if ($serv->{'email'} && $thisemail) {
			# If this service has an extra email address specified,
			# send to it
			print DEBUG "  Sending email to $serv->{'email'}\n";
			my $err = &send_status_email($thisemail,
			  $config{'subject_mode'} ? $subj : &text('monitor_sub', $subj),
			  $serv->{'email'});
			print DEBUG $err ? "  Email failed : $err\n"
					 : "  Done\n";
			}

		$email .= $thisemail;
		if ($config{'sched_single'} && $email) {
			# Force the sending of one email and page per report
			my $e = $config{'sched_email'};
			$e = $gconfig{'webmin_email_to'} if ($e eq '*');
			print DEBUG "  Sending email to $e\n";
			my $err = &send_status_email(
				$email,
				$config{'subject_mode'} ? $subj :
				  &text('monitor_sub', $subj),
				$e);
			print DEBUG $err ? "  Email failed : $err\n"
					 : "  Done\n";
			undef($email);
			if ($pager_msg) {
				print DEBUG "  Sending page\n";
				my $err = &send_status_pager($pager_msg);
				undef($pager_msg);
				print DEBUG $err ? "  Page failed : $err\n"
						 : "  Done\n";
				}
			if ($sms_msg) {
				print DEBUG "  Sending SMS\n";
				my $err = &send_status_sms($sms_msg);
				undef($sms_msg);
				print DEBUG $err ? "  SMS failed : $err\n"
						 : "  Done\n";
				}
			}

		# If any SNMP messages are defined, send them
		if (@snmp_msg) {
			print DEBUG "  Sending SNMP trap\n";
			my $err = &send_status_trap(@snmp_msg);
			undef(@snmp_msg);
			print DEBUG $err ? "  Trap failed : $err\n"
					 : "  Done\n";
			}
		}

	# Log the status
	$newstatus_str = join(" ", map { "$_=$newstats->{$_}" } @remotes);
	$newvalues_str = join("/", map { "$_=$newvalues->{$_}" } @remotes);
	$newvalues_nice_str = join("/", map { "$_=$newvalues_nice->{$_}" } @remotes);
	%history = ( 'time' => $nowunix,
		     'new' => $newstatus_str,
		     'value' => $newvalues_str,
		     'nice_value' => $newvalues_nice_str,
		     'by' => $by );
	if (defined($oldstatus{$serv->{'id'}})) {
		$history{'old'} = $oldstatus{$serv->{'id'}};
		}
	&add_history($serv, \%history);

	# Update old status hash
	$oldstatus{$serv->{'id'}} = $newstatus_str;

	# If successful, clear the last-sent time
	if ($ok == 1) {
		delete($lastsent{$serv->{'id'}});
		}
	}

# Close oldstatus, fails and lastsent files
&write_file($oldstatus_file, \%oldstatus);
&unlock_file($oldstatus_file);
&write_file($fails_file, \%fails);
&unlock_file($fails_file);
&write_file($lastsent_file, \%lastsent);
&unlock_file($lastsent_file);

# Send the email and page with all messages, if necessary
if ($ecount && !$config{'sched_single'}) {
	my $e = $config{'sched_email'};
	$e = $gconfig{'webmin_email_to'} if ($e eq '*');
	print DEBUG "Sending email to $e\n";
	my $err = &send_status_email(
		$email,
		$config{'subject_mode'} ? $text{'monitor_sub2'} :
		$ecount == 1 ? &text('monitor_sub', $subj) :
			       &text('monitor_sub3', $ecount),
		$e);
	print DEBUG $err ? "Email failed : $err\n" : "Done\n";
	}
if ($pager_msg && !$config{'sched_single'}) {
	print DEBUG "Sending page\n";
	my $err = &send_status_pager($pager_msg);
	print DEBUG $err ? "Page failed : $err\n" : "Done\n";
	}
if ($sms_msg && !$config{'sched_single'}) {
	print DEBUG "Sending SMS\n";
	my $err = &send_status_sms($sms_msg);
	print DEBUG $err ? "SMS failed : $err\n" : "Done\n";
	}
foreach $w (@webhooks) {
	print DEBUG "Calling webhook for $w->[0]->{'id'} on $w->[3]\n";
	$err = &send_status_webhook(@$w);
	print DEBUG $err ? "Webhook failed : $err\n" : "Done\n";
	}

# send_status_email(text, subject, email-to)
sub send_status_email
{
local ($text, $subject, $to) = @_;
return undef if (!$to);
&foreign_require("mailboxes", "mailboxes-lib.pl");

# Construct and send the email (using correct encoding for body)
local $from = $config{'sched_from'} ? $config{'sched_from'}
				    : &mailboxes::get_from_address();
eval {
	local $main::error_must_die = 1;
	&mailboxes::send_text_mail($from, $to, undef, $subject, $text,
		$config{'sched_smtp'},
		$config{'sched_smtp'} ?
			( $config{'smtp_user'}, $config{'smtp_pass'} ) :
			( undef, undef ));
	};
return $@;
}

# send_status_pager(text)
# Send some message with the pager command, if configured
sub send_status_pager
{
local ($text) = @_;
return if (!$config{'sched_pager'});
return if (!$config{'pager_cmd'});
my $out = &backquote_command(
	"$config{'pager_cmd'} ".quotemeta($config{'sched_pager'})." ".
	quotemeta($text)." 2>&1 </dev/null");
return $? ? $out : undef;
}

# send_status_sms(text)
sub send_status_sms
{
local ($text) = @_;
return undef if (!$text || !$config{'sched_carrier'} || !$config{'sched_sms'});
&foreign_require("mailboxes", "mailboxes-lib.pl");

local $from = $config{'sched_from'} ? $config{'sched_from'}
				    : &mailboxes::get_from_address();
local ($carrier) = grep { $_->{'id'} eq $config{'sched_carrier'} }
			&list_sms_carriers();
return undef if (!$carrier);
local $email = $config{'sched_sms'}."\@".$carrier->{'domain'};
local $subject = $config{'sched_subject'};
if ($subject eq "*") {
	$subject = $text;
	$text = undef;
	}
eval {
	local $main::error_must_die = 1;
	&mailboxes::send_text_mail($from, $email, undef, $subject, $text,
				   $config{'sched_smtp'});
	};
return $@;
}

# send_status_trap(msg, ...)
# Send an SNMP trap for some message, if configured
sub send_status_trap
{
return undef if (!$config{'snmp_server'});

# Connect to SNMP server
eval "use Net::SNMP qw(OCTET_STRING)";
if (!$@) {
	# Using the Net::SNMP module
	local ($session, $error) = Net::SNMP->session(
		"-hostname" => $config{'snmp_server'},
		"-port" => 162,
		"-version" => $config{'snmp_version'},
		"-community" => $config{'snmp_community'},
		);
	if ($error) {
		return "SNMP connect failed : $error";
		}

	# Build OIDs list
	local (@oids, $m);
	foreach $m (@_) {
		local $oid = $config{'snmp_trap'};
		push(@oids, $oid, 4, $m);
		}

	# Send off a trap
	local $rv;
	if ($config{'snmp_version'} == 1) {
		$rv = $session->trap(
			"-varbindlist" => \@oids);
		}
	elsif ($config{'snmp_version'} >= 2) {
		@oids = ( "1.3.6.1.2.1.1.3.0", 67, 0,
			  "1.3.6.1.6.3.1.1.4.1.0", 6, $oids[0],
			  @oids );
		$rv = $session->snmpv2_trap(
			"-varbindlist" => \@oids);
		}
	if (!$rv) {
		return "trap failed! : ",$session->error();
		}
	return undef;
	}
eval "use SNMP_Session";
if (!$@) {
	# Using the SNMP::Session module
	eval "use BER";
	local $session = $config{'snmp_version'} == 1 ?
			SNMP_Session->open($config{'snmp_server'},
					   $config{'snmp_community'}, 162) :
			SNMPv2c_Session->open($config{'snmp_server'},
					   $config{'snmp_community'}, 162);
	if (!$session) {
		return "SNMP connect to $config{'snmp_server'} failed";
		}

	local $rv;
	if ($config{'snmp_version'} == 1) {
		local @myoid= ( 1,3,6,1,4,1 );
		local @oids;
		foreach my $m (@_) {
			push(@oids, [
				encode_oid(split(/\./, $config{'snmp_trap'})),
				encode_string($m) ]);
			}
		$rv = $session->trap_request_send(
			encode_oid(@myoid),
			encode_ip_address(&to_ipaddress(&get_system_hostname())),
			encode_int(2),
			encode_int(0),
			encode_timeticks(0),
			@oids
			);
		}
	elsif ($config{'snmp_version'} == 2) {
		@oids = ( "1.3.6.1.2.1.1.3.0", 67, 0,
			  "1.3.6.1.6.3.1.1.4.1.0", 6, $oids[0],
			  @oids );
		$rv = $session->v2_trap_request_send(\@oids, 0);
		}
	if (!$rv) {
		return "trap failed!";
		}
	
	return undef;
	}
return "No SNMP perl module found";
}

# send_status_webhook(&monitor, &status, what, host)
# Make an HTTP call with monitor details and status as params
sub send_status_webhook
{
my ($serv, $stat, $suffix, $host) = @_;
return undef if (!$config{'sched_webhook'});
my %params = ( 'status_value' => $stat->{'value'},
	       'status_nice_value' => $stat->{'nice_value'},
	       'status_desc' => $stat->{'desc'},
	       'status' => $text{'mon_'.$suffix},
	       'host' => $host,
	       $suffix => 1,
	     );
foreach my $k (keys %$serv) {
	next if ($k =~ /^_/);
	next if ($serv->{$k} eq "");
	$params{'service_'.$k} = $serv->{$k};
	}
my ($host, $port, $page, $ssl) = &parse_http_url($config{'sched_webhook'});
my $params = join("&", map { $_."=".&urlize($params{$_}) } keys %params);
print DEBUG "Calling webhook URL $config{'sched_webhook'} $params\n";
if ($params) {
	$page .= ($page !~ /\?/ ? "?" : "&");
	$page .= $params;
	}
my ($out, $err);
&http_download($host, $port, $page, \$out, \$err, undef, $ssl, undef, undef,
	       5, 0, 1);
return $err;
}

# run_on_command(&serv, command, remote-host)
sub run_on_command
{
local ($serv, $cmd, $r) = @_;
$r = undef if ($r eq "*");
return undef if (!$cmd);
local $out;
if ($serv->{'runon'} && $r) {
	# Run on the remote host
	$remote_error_msg = undef;
	&remote_foreign_call($r, "status",
		"set_monitor_environment", $serv);
	&remote_error_setup(\&remote_error_callback);
	if ($config{'output'}) {
		$out = &remote_foreign_call($r, "status",
			"backquote_command", "($cmd) 2>&1 </dev/null");
		}
	else {
		&remote_foreign_call($r, "status",
			"execute_command", $cmd);
		}
	&remote_error_setup(undef);
	&remote_foreign_call($r, "status",
		"reset_monitor_environment", $serv);
	if ($remote_error_msg) {
		return &text('monitor_runerr', $cmd, $r,
			     $remote_error_msg);
		}
	return &text('monitor_run1', $cmd, $r)."\n".$out;
	}
else {
	# Just run locally
	&set_monitor_environment($serv);
	if ($config{'output'}) {
		$out = &backquote_command("($cmd) 2>&1 </dev/null");
		}
	else {
		&execute_command($cmd);
		}
	&reset_monitor_environment($serv);
	return &text('monitor_run2', $cmd)."\n".$out;
	}
}

sub remote_error_callback
{
$remote_error_msg = $_[0];
}

# Returns 1 if b should be first, -1 if a should be first, 0 if same
sub sort_func
{
local ($a, $b) = @_;
if ($a->{'id'} eq $b->{'id'}) {
	return 0;
	}
elsif (!$a->{'depend'} && !$b->{'depend'}) {
	return $a->{'desc'} cmp $b->{'desc'};
	}
elsif ($a->{'depend'} && !$b->{'depend'}) {
	return 1;
	}
elsif (!$a->{'depend'} && $b->{'depend'}) {
	return -1;
	}
else {
	return $a->{'depend'} eq $b->{'id'} ? 1 :
	       $b->{'depend'} eq $a->{'id'} ? -1 :
		$a->{'desc'} cmp $b->{'desc'};
	}
}

# quoted_encode(text)
sub quoted_encode
{
local $t = $_[0];
$t =~ s/([=\177-\377])/sprintf("=%2.2X",ord($1))/ge;
return $t;
}

# make_message(status, host, &server, type, &status)
# Returns the message for some email, SMS or SNMP. May use a template, or
# the built-in default.
sub make_message
{
local ($suffix, $host, $serv, $type, $stat) = @_;
local $tmpl = $serv->{'tmpl'} ? &get_template($serv->{'tmpl'}) : undef;
if ($tmpl && $tmpl->{$type}) {
	# Construct from template
	local %hash = ( 'DESC' => $serv->{'desc'},
			'HOST' => $host || &get_system_hostname(),
			'DATE' => $nowdate,
			'TIME' => $nowtime,
			'STATUS' => $text{'mon_'.$suffix},
			uc($suffix) => 1,
		      );
	foreach my $s (@monitor_statuses) {
		$hash{uc($s)} ||= 0;
		}
	if ($stat) {
		foreach my $k ('value', 'nice_value', 'desc') {
			$hash{'STATUS_'.uc($k)} = $stat->{$k} ? $stat->{$k} : "";
			}
		}
	foreach my $k (keys %$serv) {
		$hash{'SERVICE_'.uc($k)} = $serv->{$k};
		}
	local $rv = &substitute_template($tmpl->{$type}, \%hash);
	$rv =~ s/[\r\n]+$//;
	$rv .= "\n";
	return $rv;
	}
else {
	# Use built-in
	if ($type eq 'sms') {
		return &text('monitor_pager_'.$suffix,
			     $host, $serv->{'desc'}, $now);
		}
	elsif ($type eq 'pager') {
		return &text('monitor_pager_'.$suffix,
			     $host, $serv->{'desc'}, $now);
		}
	elsif ($type eq 'snmp') {
		return &text('monitor_snmp_'.$suffix,
			     $host, $serv->{'desc'});
		}
	elsif ($type eq 'email') {
		my $rv = &text('monitor_email_'.$suffix,
			       $host, $serv->{'desc'}, $now)."\n";
		if ($stat->{'desc'}) {
			$rv .= &text('monitor_email_stat',
				     $stat->{'desc'})."\n";
			}
		return $rv;
		}
	}
}

