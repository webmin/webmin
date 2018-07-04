# status-lib.pl
# Functions for getting the status of services

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
%access = &get_module_acl();
use Socket;

# Wrapper command for cron job
$cron_cmd = "$module_config_directory/monitor.pl";

# Config directory for monitors
$services_dir = "$module_config_directory/services";

# File storing last status of each monitor
$oldstatus_file = "$module_config_directory/oldstatus";
if (!-r $oldstatus_file) {
	$oldstatus_file = "$module_var_directory/oldstatus";
	}

# Failure count file for each monitor
$fails_file = "$module_config_directory/fails";
if (!-r $fails_file) {
	$fails_file = "$module_var_directory/fails";
	}

# Last email sent for each monitor
$lastsent_file = "$module_config_directory/lastsent";
if (!-r $lastsent_file) {
	$lastsent_file = "$module_var_directory/lastsent";
	}

# Directory of historic results for each monitor
$history_dir = "$module_config_directory/history";
if (!-d $history_dir) {
	$history_dir = "$module_var_directory/history";
	}

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
	my $serv = &get_service($1);
	next if (!$serv || !$serv->{'type'} || !$serv->{'id'});
	if ($serv->{'depends'}) {
		my $d;
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
my %serv;
read_file("$services_dir/$_[0].serv", \%serv) || return undef;
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
my ($serv) = @_;
mkdir($services_dir, 0755) if (!-d $services_dir);
&lock_file("$services_dir/$serv->{'id'}.serv");
&write_file("$services_dir/$serv->{'id'}.serv", $serv);
&unlock_file("$services_dir/$serv->{'id'}.serv");
}

# delete_service(&serv)
sub delete_service
{
my ($serv) = @_;
&unlink_logged("$services_dir/$serv->{'id'}.serv");
&unlink_logged("$history_dir/$serv->{'id'}");
}

# expand_remotes(&service)
# Given a service with direct and group remote hosts, returns a list of the
# names of all actual hosts (* means local)
sub expand_remotes
{
my @remote;
push(@remote, split(/\s+/, $_[0]->{'remote'}));
my @groupnames = split(/\s+/, $_[0]->{'groups'});
if (@groupnames) {
	&foreign_require("servers");
	my @groups = &servers::list_all_groups();
	foreach my $g (@groupnames) {
		my ($group) = grep { $_->{'name'} eq $g } @groups;
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
my $t = $_[0]->{'type'};
my @rv;
foreach $r (&expand_remotes($_[0])) {
	my $rv;
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
			my $webmindown = $s->{'type'} eq 'alive' ? 0 : -2;
			if ($remote_error_msg) {
				$rv = { 'up' => $webmindown,
					 'desc' => "$text{'mon_webmin'} : $remote_error_msg" };
				}
			else {
				my %s = %{$_[0]};
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
			my ($mod, $mtype) = ($1, $2);
			&foreign_require($mod, "status_monitor.pl");
			$rv = &foreign_call($mod, "status_monitor_status",
					    $mtype, $_[0], $_[1]);
			}
		else {
			# Just include and use the local monitor library
			do "${t}-monitor.pl" if (!$done_monitor{$t}++);
			my $func = "get_${t}_status";
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
my ($f, @rv);
opendir(DIR, ".");
while($f = readdir(DIR)) {
	if ($f =~ /^(\S+)-monitor\.pl$/) {
		my $m = $1;
		my $oss = $monitor_os_support{$m};
		next if ($oss && !&check_os_support($oss));
		push(@rv, [ $m, $text{"type_$m"} ]);
		}
	}
closedir(DIR);
foreach my $m (&get_all_module_infos()) {
	my $mdir = defined(&module_root_directory) ?
		&module_root_directory($m->{'dir'}) :
		"$root_directory/$m->{'dir'}";
	if (-r "$mdir/status_monitor.pl" &&
	    &check_os_support($m)) {
		&foreign_require($m->{'dir'}, "status_monitor.pl");
		my @mms = &foreign_call($m->{'dir'}, "status_monitor_list");
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
	foreach my $m (@_[1..$#_]) {
		&remote_foreign_check($_[0]->{'remote'}, $m, 1) ||
			&error(&text('depends_remote', "<tt>$m</tt>",
				     "<tt>$_[0]->{'remote'}</tt>"));
		}
	}
else {
	# Check on this server
	foreach my $m (@_[1..$#_]) {
		my %minfo = &get_module_info($m);
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
foreach my $p (&proc::list_processes()) {
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
my ($m, $c) = @_;
print $m $c;
my $r = <$m>;
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
my $job;
foreach my $j (&cron::list_cron_jobs()) {
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
	my $njob;
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
my (@rv, $i);
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
my ($o, $serv) = @_;
my @remotes = split(/\s+/, $serv->{'remote'});
if ($o =~ /^\-?(\d+)$/) {
	return { $remotes[0] => $o };
	}
else {
	my %rv;
	foreach my $hs (split(/\s+/, $o)) {
		my ($h, $s) = split(/=/, $hs);
		$rv{$h} = $s;
		}
	return \%rv;
	}
}

# nice_remotes(&monitor, [max])
sub nice_remotes
{
my ($s, $max) = @_;
$max ||= 3;
my @remotes = map { $_ eq "*" ? $text{'index_local'}
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
my ($group) = @_;
my $mems = scalar(@{$group->{'members'}});
return $group->{'name'}." (".
       &text($mems == 0 ? 'mon_empty' :
	     $mems == 1 ? 'mon_onemem' : 'mon_members', $mems).")";
}

# list_notification_modes()
# Returns a list of available notification modes (like email, sms, etc..)
sub list_notification_modes
{
my @rv = ( "email" );
if ($config{'pager_cmd'} && $config{'sched_pager'}) {
	push(@rv, "pager");
	}
if ($config{'snmp_server'}) {
	my $gotmod = 0;
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
	   'desc' => 'AT&T SMS',
	   'domain' => 'txt.att.net' },
	 { 'id' => 'attmms',
	   'desc' => 'AT&T MMS',
	   'domain' => 'mms.att.net' },
	 { 'id' => 'oldcingular',
	   'desc' => 'Cingular',
	   'domain' => 'cingularme.com',
	   'alpha' => 1 },
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
           'domain' => 'mmail.co.uk' },
         { 'id' => 'rogers',
           'desc' => 'Rogers Canada',
           'domain' => 'pcs.rogers.com' },
         { 'id' => 'skytel',
           'desc' => 'Skytel',
           'domain' => 'skytel.com' },
	 { 'id' => 'telus',
	   'desc' => 'Telus Canada',
	   'domain' => 'msg.telus.com' },
         { 'id' => 'cricket',
           'desc' => 'Cricket',
           'domain' => 'sms.mycricket.com' },
        );
}

# list_templates()
# Returns a list of hash refs, one for each email template
sub list_templates
{
opendir(DIR, $templates_dir) || return ( );
my @rv;
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
my ($id) = @_;
my %tmpl;
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
my ($tmpl) = @_;
$tmpl->{'id'} ||= time().$$;
$tmpl->{'file'} = "$templates_dir/$tmpl->{'id'}";
my %write = %$tmpl;
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
my ($tmpl) = @_;
&unlink_logged($tmpl->{'file'});
}

# set_monitor_environment(&serv)
# Sets environment variables based on some monitor
sub set_monitor_environment
{
my ($serv) = @_;
foreach my $k (keys %$serv) {
	if (!ref($serv->{$k})) {
		$ENV{'STATUS_'.uc($k)} = $serv->{$k};
		}
	}
}

# reset_monitor_environment(&serv)
# Undoes the call to set_monitor_environment
sub reset_monitor_environment
{
my ($serv) = @_;
foreach my $k (keys %$serv) {
	if (!ref($serv->{$k})) {
		delete($ENV{'STATUS_'.uc($k)});
		}
	}
}

# list_history(&serv, [max-tail-lines], [max-head-lines])
# Lists history entries for some service. Each is a hash ref with keys
# old - Previous status, in host=status format
# new - New status, in host=status format
# time - Time at which history was logged
# value - Optional value at that time (such as memory used)
# by - Can be 'web' for update from web UI, or 'cron' for background
sub list_history
{
my ($serv, $maxtail, $maxhead) = @_;
my $hfile = "$history_dir/$serv->{'id'}";
return ( ) if (!-r $hfile);
if ($maxtail) {
	open(HFILE, "tail -".quotemeta($maxtail)." ".quotemeta($hfile)." |");
	}
else {
	open(HFILE, $hfile);
	}
my @rv;
while(my $line = <HFILE>) {
	$line =~ s/\r|\n//g;
	my %h = map { split(/=/, $_, 2) } split(/\t+/, $line);
	if ($h{'time'}) {
		push(@rv, \%h);
		}
	last if ($maxhead && scalar(@rv) >= $maxhead);
	}
close(HFILE);
return @rv;
}

# add_history(&serv, &history)
# Adds a history entry for some service
sub add_history
{
my ($serv, $h) = @_;
if (!-d $history_dir) {
	&make_dir($history_dir, '0700');
	}
my $hfile = "$history_dir/$serv->{'id'}";
&lock_file($hfile, 1);
my ($first) = &list_history($serv, undef, 1);
my $cutoff = time() - $config{'history_purge'}*24*60*60;
if ($first && $first->{'time'} < $cutoff-(24*60*60)) {
	# First entry is more than a day older than the cutoff .. remove all
	# entries older than the custoff
	my @oldh = &list_history($serv);
	&open_tempfile(HFILE, ">$hfile", 0, 1);
	foreach my $oh (@oldh) {
		if ($oh->{'time'} > $cutoff) {
			&print_tempfile(HFILE,
			  join("\t", map { $_."=".$oh->{$_} } keys %$oh)."\n");
			}
		}
	&close_tempfile(HFILE);
	}
&open_tempfile(HFILE, ">>$hfile", 0, 1);
&print_tempfile(HFILE, join("\t", map { $_."=".$h->{$_} } keys %$h)."\n");
&close_tempfile(HFILE);
&unlock_file($hfile, 1);
}

# get_status_icon(up)
# Given a status code, return the image path to it
sub get_status_icon
{
my ($up) = @_;
return $gconfig{'webprefix'}.
       "/".$module_name."/images/".($up == 1 ? "up.gif" :
		  $up == -1 ? "not.gif" :
		  $up == -2 ? "webmin.gif" :
		  $up == -3 ? "timed.gif" :
		  $up == -4 ? "skip.gif" :
		  	      "down.gif");
}

sub status_to_string
{
my ($up) = @_;
return $up == 1 ? $text{'mon_up'} :
       $up == -1 ? $text{'mon_not'} :
       $up == -2 ? $text{'mon_webmin'} :
       $up == -3 ? $text{'mon_timeout'} :
       $up == -4 ? $text{'mon_skip'} :
                   "<font color=#ff0000>$text{'mon_down'}</font>";
}

1;

