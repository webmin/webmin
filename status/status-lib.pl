# status-lib.pl
# Functions for getting the status of services

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
%access = &get_module_acl();
use Socket;

$services_dir = "$module_config_directory/services";
$cron_cmd = "$module_config_directory/monitor.pl";

$oldstatus_file = "$module_config_directory/oldstatus";
$fails_file = "$module_config_directory/fails";

$templates_dir = "$module_config_directory/templates";

%monitor_os_support = ( 'traffic' => { 'os_support' => '*-linux freebsd' },
		      );

@monitor_statuses = ( 'up', 'down', 'un', 'webmin', 'timed', 'isdown' );

# list_services()
# Returns a list of all services this module knows how to get status on.
# If this is the first time the function is called a default set of services
# will be setup.
sub list_services
{
my (%mod, @rv);
if (!-d $services_dir) {
	# setup initial services
	mkdir($module_config_directory, 0700);
	mkdir($services_dir, 0700);
	system("cp services/* $services_dir");
	}
map { $mod{$_}++ } &list_modules();
opendir(DIR, $services_dir);
while($f = readdir(DIR)) {
	next if ($f !~ /^(.*)\.serv$/);
	local $serv = &get_service($1);
	next if (!$serv || !$serv->{'type'} || !$serv->{'id'});
	if ($serv->{'depends'}) {
		local $d;
		map { $d++ if (!$mod{$_}) } split(/\s+/, $serv->{'depends'});
		push(@rv, $serv) if (!$d);
		}
	else {
		push(@rv, $serv);
		}
	}
closedir(DIR);
return @rv;
}

# get_service(id)
sub get_service
{
local %serv;
&read_file("$services_dir/$_[0].serv", \%serv);
$serv{'fails'} = 1 if (!defined($serv{'fails'}));
$serv{'_file'} = "$services_dir/$_[0].serv";
if (!defined($serv{'notify'})) {
	$serv{'notify'} = 'email pager snmp';
	}
$serv{'remote'} = "*" if (!$serv{'remote'} && !$serv{'groups'});
return $_[0] ne $serv{'id'} ? undef : \%serv;
}

# save_service(&serv)
sub save_service
{
mkdir($services_dir, 0755) if (!-d $services_dir);
&lock_file("$services_dir/$_[0]->{'id'}.serv");
&write_file("$services_dir/$_[0]->{'id'}.serv", $_[0]);
&unlock_file("$services_dir/$_[0]->{'id'}.serv");
}

# delete_service(serv)
sub delete_service
{
&lock_file("$services_dir/$_[0]->{'id'}.serv");
unlink("$services_dir/$_[0]->{'id'}.serv");
&unlock_file("$services_dir/$_[0]->{'id'}.serv");
}

# expand_remotes(&service)
# Given a service with direct and group remote hosts, returns a list of the
# names of all actual hosts (* means local)
sub expand_remotes
{
local @remote;
push(@remote, split(/\s+/, $_[0]->{'remote'}));
local @groupnames = split(/\s+/, $_[0]->{'groups'});
if (@groupnames) {
	&foreign_require("servers");
	local @groups = &servers::list_all_groups();
	foreach my $g (@groupnames) {
		local ($group) = grep { $_->{'name'} eq $g } @groups;
		if ($group) {
			push(@remote, @{$group->{'members'}});
			}
		}
	}
return &unique(@remote);
}

# service_status(&service, [from-cgi])
# Gets the status of a service, possibly on another server. If called in
# an array content, the status of all hosts for this monitor are returned.
sub service_status
{
local $t = $_[0]->{'type'};
local @rv;
foreach $r (&expand_remotes($_[0])) {
	local $rv;
	local $main::error_must_die = 1;
	eval {
		local $SIG{'ALRM'} = sub { die "status alarm\n" };
		alarm(60);	# wait at most 60 secs for a result
		if ($r ne "*") {
			# Make a remote call to another webmin server
			&remote_error_setup(\&remote_error);
			$remote_error_msg = undef;
			&remote_foreign_require($r, 'status', 'status-lib.pl')
				if (!$done_remote_status{$r}++);
			local $webmindown = $s->{'type'} eq 'alive' ? 0 : -2;
			if ($remote_error_msg) {
				$rv = { 'up' => $webmindown,
					 'desc' => "$text{'mon_webmin'} : $remote_error_msg" };
				}
			else {
				local %s = %{$_[0]};
				$s{'remote'} = '*';
				$s{'groups'} = undef;
				($rv) = &remote_foreign_call($r, 'status',
					    'service_status', \%s, $_[1]);
				if ($remote_error_msg) {
					$rv = { 'up' => $webmindown, 'desc' =>
					    "$text{'mon_webmin'} : $remote_error_msg" };
					}
				}
			}
		elsif ($t =~ /^(\S+)::(\S+)$/) {
			# Call to another module
			local ($mod, $mtype) = ($1, $2);
			&foreign_require($mod, "status_monitor.pl");
			$rv = &foreign_call($mod, "status_monitor_status",
					    $mtype, $_[0], $_[1]);
			}
		else {
			# Just include and use the local monitor library
			do "${t}-monitor.pl" if (!$done_monitor{$t}++);
			local $func = "get_${t}_status";
			$rv = &$func($_[0],
				     $_[0]->{'clone'} ? $_[0]->{'clone'} : $t,
				     $_[1]);
			}
		alarm(0);
		};
	if ($@ =~ /status alarm/) {
		push(@rv, { 'up' => -3,
			    'remote' => $r });
		}
	elsif ($@) {
		# A real error happened
		die $@;
		}
	else {
		$rv->{'remote'} = $r;
		push(@rv, $rv);
		}
	}
return wantarray ? @rv : $rv[0];
}

sub remote_error
{
$remote_error_msg = join("", @_);
}

# list_modules()
# Returns a list of all modules available on this system
sub list_modules
{
return map { $_->{'dir'} } grep { &check_os_support($_) }
	&get_all_module_infos();
}

# list_handlers()
# Returns a list of the module's monitor type handlers, and those
# defined in other modules.
sub list_handlers
{
local ($f, @rv);
opendir(DIR, ".");
while($f = readdir(DIR)) {
	if ($f =~ /^(\S+)-monitor\.pl$/) {
		local $m = $1;
		local $oss = $monitor_os_support{$m};
		next if ($oss && !&check_os_support($oss));
		push(@rv, [ $m, $text{"type_$m"} ]);
		}
	}
closedir(DIR);
local $m;
foreach $m (&get_all_module_infos()) {
	local $mdir = defined(&module_root_directory) ?
		&module_root_directory($m->{'dir'}) :
		"$root_directory/$m->{'dir'}";
	if (-r "$mdir/status_monitor.pl" &&
	    &check_os_support($m)) {
		&foreign_require($m->{'dir'}, "status_monitor.pl");
		local @mms = &foreign_call($m->{'dir'}, "status_monitor_list");
		push(@rv, map { [ $m->{'dir'}."::".$_->[0], $_->[1] ] } @mms);
		}
	}
return @rv;
}

# depends_check(&service, [module]+)
sub depends_check
{
return if ($_[0]->{'id'});	# only check for new services
if ($_[0]->{'remote'}) {
	# Check on the remote server
	foreach $m (@_[1..$#_]) {
		&remote_foreign_check($_[0]->{'remote'}, $m, 1) ||
			&error(&text('depends_remote', "<tt>$m</tt>",
				     "<tt>$_[0]->{'remote'}</tt>"));
		}
	}
else {
	# Check on this server
	foreach $m (@_[1..$#_]) {
		local %minfo = &get_module_info($m);
		%minfo || &error(&text('depends_mod', "<tt>$m</tt>"));
		&check_os_support(\%minfo, undef, undef, 1) ||
			&error(&text('depends_os', "<tt>$minfo{'desc'}</tt>"));
		}
	$_[0]->{'depends'} = join(" ", @_[1..$#_]);
	}
}

# find_named_process(regexp)
sub find_named_process
{
foreach $p (&proc::list_processes()) {
	$p->{'args'} =~ s/\s.*$//; $p->{'args'} =~ s/[\[\]]//g;
	if ($p->{'args'} =~ /$_[0]/) {
		return $p;
		}
	}
return undef;
}

# smtp_command(handle, command)
sub smtp_command
{
local ($m, $c) = @_;
print $m $c;
local $r = <$m>;
if ($r !~ /^[23]\d+/) {
	&error(&text('sched_esmtpcmd', "<tt>$c</tt>", "<tt>$r</tt>"));
	}
}

# setup_cron_job()
# Create a cron job based on the module's configuration
sub setup_cron_job
{
&lock_file($cron_cmd);
&foreign_require("cron");
local ($j, $job);
foreach $j (&cron::list_cron_jobs()) {
	$job = $j if ($j->{'user'} eq 'root' && $j->{'command'} eq $cron_cmd);
	}
if ($job) {
	&lock_file(&cron::cron_file($job));
	&cron::delete_cron_job($job);
	&unlock_file(&cron::cron_file($job));
	unlink($cron_cmd);
	}
if ($config{'sched_mode'}) {
	# Create the program that cron calls
	&cron::create_wrapper($cron_cmd, $module_name, "monitor.pl");

	# Setup the actual cron job
	local $njob;
	$njob = { 'user' => 'root', 'active' => 1,
		  'hours' => '*', 'days' => '*',
		  'months' => '*', 'weekdays' => '*',
		  'command' => $cron_cmd };
	if ($config{'sched_period'} == 0) {
		$njob->{'mins'} = &make_interval(60);
		}
	elsif ($config{'sched_period'} == 1) {
		$njob->{'hours'} = &make_interval(24);
		$njob->{'mins'} = 0;
		}
	elsif ($config{'sched_period'} == 2) {
		$njob->{'days'} = &make_interval(31, 1);
		$njob->{'hours'} = $njob->{'mins'} = 0;
		}
	elsif ($config{'sched_period'} == 3) {
		$njob->{'months'} = &make_interval(12, 1);
		$njob->{'days'} = 1;
		$njob->{'hours'} = $njob->{'mins'} = 0;
		}
	&lock_file(&cron::cron_file($njob));
	&cron::create_cron_job($njob);
	&unlock_file(&cron::cron_file($njob));
	}
&unlock_file($cron_cmd);
}

# make_interval(length, offset2)
sub make_interval
{
local (@rv, $i);
for($i=$config{'sched_offset'}+$_[1]; $i<$_[0]; $i+=$config{'sched_int'}) {
	push(@rv,$i);
	}
return join(",", @rv);
}

# expand_oldstatus(oldstatus, &serv)
# Converts an old-status string like *=1 foo.com=2 into a hash. If the string
# contains just one number, it is assumed to be for just the first remote host
sub expand_oldstatus
{
local ($o, $serv) = @_;
local @remotes = split(/\s+/, $serv->{'remote'});
if ($o =~ /^\-?(\d+)$/) {
	return { $remotes[0] => $o };
	}
else {
	local %rv;
	foreach my $hs (split(/\s+/, $o)) {
		local ($h, $s) = split(/=/, $hs);
		$rv{$h} = $s;
		}
	return \%rv;
	}
}

# nice_remotes(&monitor, [max])
sub nice_remotes
{
local ($s, $max) = @_;
$max ||= 3;
local @remotes = map { $_ eq "*" ? $text{'index_local'}
			         : &html_escape($_) }
		     split(/\s+/, $s->{'remote'});
foreach my $g (split(/\s+/, $s->{'groups'})) {
	push(@remotes, &text('index_group', $g));
	}
return @remotes > $max ? join(", ", @remotes[0..$max]).", ..."
		       : join(", ", @remotes);
}

sub group_desc
{
local ($group) = @_;
local $mems = scalar(@{$group->{'members'}});
return $group->{'name'}." (".
       &text($mems == 0 ? 'mon_empty' :
	     $mems == 1 ? 'mon_onemem' : 'mon_members', $mems).")";
}

# list_notification_modes()
# Returns a list of available notifcation modes (like email, sms, etc..)
sub list_notification_modes
{
local @rv = ( "email" );
if ($config{'pager_cmd'} && $config{'sched_pager'}) {
	push(@rv, "pager");
	}
if ($config{'snmp_server'}) {
	local $gotmod = 0;
	eval "use Net::SNMP";
	$gotmod++ if (!$@);
	eval "use SNMP_Session";
	$gotmod++ if (!$@);
	push(@rv, "snmp") if ($gotmod);
	}
if ($config{'sched_carrier'} && $config{'sched_sms'}) {
	push(@rv, "sms");
	}
return @rv;
}

# list_sms_carriers()
# Returns a list of information about carriers to whom we can send SMS
sub list_sms_carriers
{
return ( { 'id' => 'tmobile',
	   'desc' => 'T-Mobile',
	   'domain' => 'tmomail.net' },
	 { 'id' => 'cingular',
	   'desc' => 'AT&T',
	   'domain' => 'txt.att.net' },
	 { 'id' => 'verizon',
	   'desc' => 'Verizon',
	   'domain' => 'vtext.com' },
	 { 'id' => 'sprint',
	   'desc' => 'Sprint PCS',
	   'domain' => 'messaging.sprintpcs.com' },
	 { 'id' => 'nextel',
	   'desc' => 'Nextel',
	   'domain' => 'messaging.nextel.com' },
	 { 'id' => 'alltel',
	   'desc' => 'Alltel',
	   'domain' => 'message.alltel.com' },
         { 'id' => 'boost',
	   'desc' => 'Boost Mobile',
	   'domain' => 'myboostmobile.com' },
	 { 'id' => 'virgin',
	   'desc' => 'Virgin Mobile',
	   'domain' => 'vmobl.com' },
	 { 'id' => 'cbell',
	   'desc' => 'Cincinnati Bell',
	   'domain' => 'gocbw.com' },
         { 'id' => 'tcom',
           'desc' => 'T-COM',
           'domain' => 'sms.t-online.de' },
         { 'id' => 'vodafone',
           'desc' => 'Vodafone UK',
           'domain' => 'vodafone.net' },
         { 'id' => 'vodafonejapan',
           'desc' => 'Vodafone Japan',
           'domain' => 't.vodafone.ne.jp' },
         { 'id' => 'bellcanada',
           'desc' => 'Bell Canada',
           'domain' => 'txt.bellmobility.ca' },
         { 'id' => 'bellsouth',
           'desc' => 'Bell South',
           'domain' => 'sms.bellsouth.com' },
         { 'id' => 'cellularone',
           'desc' => 'Cellular One',
           'domain' => 'mobile.celloneusa.com' },
         { 'id' => 'o2',
           'desc' => 'O2',
           'domain' => 'o2imail.co.uk' },
         { 'id' => 'rogers',
           'desc' => 'Rogers Canada',
           'domain' => 'pcs.rogers.com' },
         { 'id' => 'skytel',
           'desc' => 'Skytel',
           'domain' => 'skytel.com' },
        );
}

# list_templates()
# Returns a list of hash refs, one for each email template
sub list_templates
{
opendir(DIR, $templates_dir) || return ( );
local @rv;
foreach my $f (readdir(DIR)) {
	if ($f =~ /^\d+$/) {
		push(@rv, &get_template($f));
		}
	}
closedir(DIR);
return @rv;
}

# get_template(id)
# Returns the hash ref for a specific template, by ID
sub get_template
{
local ($id) = @_;
local %tmpl;
&read_file("$templates_dir/$id", \%tmpl) || return undef;
$tmpl{'id'} = $id;
$tmpl{'file'} = "$templates_dir/$id";
$tmpl{'email'} =~ s/\\n/\n/g;
$tmpl{'email'} =~ s/\\\\/\\/g;
return \%tmpl;
}

# save_template(&template)
# Creates or saves an email template. Also does locking.
sub save_template
{
local ($tmpl) = @_;
$tmpl->{'id'} ||= time().$$;
$tmpl->{'file'} = "$templates_dir/$tmpl->{'id'}";
local %write = %$tmpl;
$write{'email'} =~ s/\\/\\\\/g;
$write{'email'} =~ s/\n/\\n/g;
if (!-d $templates_dir) {
	&make_dir($templates_dir, 0755);
	}
&lock_file($tmpl->{'file'});
&write_file($tmpl->{'file'}, \%write);
&unlock_file($tmpl->{'file'});
}

# delete_template(&template)
# Removes an existing template. Also does locking.
sub delete_template
{
local ($tmpl) = @_;
&unlink_logged($tmpl->{'file'});
}

1;

