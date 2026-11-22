# status-lib.pl
# Functions for getting the status of services

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
%access = &get_module_acl();
use Socket;

# Wrapper command for cron job
$cron_cmd = "$module_config_directory/monitor.pl";
$full_cron_cmd = $cron_cmd." >/dev/null 2>&1";

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

%monitor_deprecated = ( 'dnsadmin' => 1 );

@monitor_statuses = ( 'up', 'down', 'un', 'webmin', 'timed', 'isdown' );

$mysql_variant = "mysql";
if (&foreign_check("mysql")) {
	# Fix MySQL / MariaDB
	&foreign_require("mysql");
	if ($mysql::mysql_version =~ /mariadb/i) {
		$mysql_variant = "mariadb";
		}
	}
if ($mysql_variant eq "mariadb") {
	$text{'type_mysql'} =~ s/MySQL/MariaDB/g;
	}

# list_services()
# Returns configured monitors whose required modules are available.
# Creates default monitors if the services directory does not exist.
sub list_services
{
my (%mod, @rv);
if (!-d $services_dir) {
	# Initialize monitor storage
	mkdir($module_config_directory, 0700);
	# Serialize initialization and preserve an existing directory
	&lock_file($services_dir);
	if (mkdir($services_dir, 0700)) {
		# Seed only the directory created by this call
		system("cp $module_root_directory/services/* $services_dir");
		}
	&unlock_file($services_dir);
	}
map { $mod{$_}++ } &list_modules();
opendir(DIR, $services_dir);
while($f = readdir(DIR)) {
	next if ($f !~ /^(.*)\.serv$/);
	my $serv = &get_service($1);
	next if (!$serv || !$serv->{'type'} || !$serv->{'id'});
	if ($serv->{'default'} && $serv->{'id'} eq 'mysql' &&
	    $mysql_variant eq "mariadb") {
		$serv->{'desc'} =~ s/MySQL/MariaDB/g;
		}
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

# dashboard_visible_monitors(&acl, [&monitor, ...])
# Filters monitor hashrefs by dashboard ACL. Missing limits or * allow
# all; an empty saved list allows none.
sub dashboard_visible_monitors
{
my ($acl, @monitors) = @_;
return @monitors if (!defined($acl->{'dashboard_monitors'}) ||
		     $acl->{'dashboard_monitors'} eq '*');
my %allowed = map { $_ => 1 } split(/\s+/, $acl->{'dashboard_monitors'});
return grep { $allowed{$_->{'id'}} } @monitors;
}

# module_dashboard_monitors([&data], [&skip-modules])
# Returns services from accessible modules with status_dashboard=1.
# Passes dashboard options, or {}, to each hook; skip-modules is an arrayref.
# Prefixes IDs with module:: and sets provider and remote for local services.
sub module_dashboard_monitors
{
my ($data, $skip) = @_;
my %skip = map { $_ => 1 } @{$skip || []};
my @rv;
foreach my $m (&get_all_module_infos()) {
	# Only ask modules that opted in and that this user may use
	my $mod = $m->{'dir'};
	next if (!$m->{'status_dashboard'} || $skip{$mod} || $m->{'cloneof'} ||
		 !-r (&module_root_directory($mod)."/status_monitor.pl") ||
		 !&foreign_available($mod));
	&foreign_require($mod, "status_monitor.pl");
	next if (!&foreign_defined($mod, "status_monitor_dashboard"));
	foreach my $s (&foreign_call($mod, "status_monitor_dashboard",
				     $data || {})) {
		# Keep provider IDs distinct and mark these as local services
		push(@rv, { %$s, 'id' => $mod.'::'.$s->{'id'},
			    'provider' => $mod, 'remote' => '*' });
		}
	}
return @rv;
}

# match_dashboard_services(&monitors, &provided)
# Maps monitor IDs to supplied services for shared status and actions.
# Matches an explicit dashboard_service ID, or an unambiguous type.
sub match_dashboard_services
{
my ($services, $provided) = @_;
my %byid = map { $_->{'id'} => $_ } @$provided;

# A shared type cannot distinguish multiple service instances
my %bytype;
foreach my $p (@$provided) {
	next if (!$p->{'type'});
	$bytype{$p->{'type'}} = exists($bytype{$p->{'type'}}) ? undef : $p;
	}

my %controls;
foreach my $s (@$services) {
	my $p = $s->{'dashboard_service'} ? $byid{$s->{'dashboard_service'}}
					  : $bytype{$s->{'type'}};
	if ($p && $s->{'remote'} eq '*' && !$s->{'groups'} &&
	    !$s->{'clone'}) {
		# Pair only local monitors without groups or module clones
		$controls{$s->{'id'}} = $p;
		}
	}
return %controls;
}

# monitor_action_buttons(&monitor, up)
# Returns POST forms from the owning module's status_monitor_actions hook.
# Start, stop and restart use icons; other actions show their labels.
# These forms must not be nested inside another form.
sub monitor_action_buttons
{
my ($s, $up) = @_;

# Hide controls for unavailable or remote checks and restricted users.
# Missing action permissions inherit the monitor-edit permission.
my $can = defined($access{'actions'}) ? $access{'actions'} : $access{'edit'};
return ( ) if (!defined($up) || $up < 0 || $s->{'remote'} ne '*' ||
	       $s->{'groups'} || !$can || &is_readonly_mode());

# Resolve module::type; supplied services and clones override the owner
my ($mod, $type) = split(/::/, $s->{'type'} || '', 2);
$type ||= $mod;
$mod = $s->{'provider'} || $s->{'clone'} || $mod;
# Require access to the module and an action hook
return ( ) if (!$mod ||
	       !-r (&module_root_directory($mod)."/status_monitor.pl") ||
	       !&foreign_available($mod));
&foreign_require($mod, "status_monitor.pl");
return ( ) if (!&foreign_defined($mod, "status_monitor_actions"));

my %icons = ( 'start' => 'play', 'stop' => 'stop', 'restart' => 'refresh' );
my @rv;
foreach my $a (&foreign_call($mod, "status_monitor_actions",
			     $type, $s, $up)) {
	my ($kind, $label, $cgi, $fields) = @$a;

	# Leave return handling to the action CGI; this may be a sidebar render
	my %send = %{$fields || {}};
	my $form = &ui_form_start(&get_webprefix()."/$mod/$cgi", "post").
		   join("", map { &ui_tag('input', undef,
					  { 'type' => 'hidden', 'name' => $_,
					    'value' => $send{$_} }) }
				sort(keys(%send)));

	# Use the label as an icon tooltip, or as text for an unknown action
	my $icon = $icons{$kind};
	my $button = &ui_action_button(
		$icon ? '' : $label, 'neutral',
		{ 'type' => 'submit', 'size' => 'small',
		  'icon' => $icon || '', 'title' => $icon ? $label : undef });
	push(@rv, $form.$button.&ui_form_end(undef, undef, 1));
	}
return @rv;
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
my ($serv, $fromcgi) = @_;
my $t = $serv->{'type'};
my @rv;
foreach $r (&expand_remotes($serv)) {
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
			my $webmindown = $serv->{'type'} eq 'alive' ? 0 : -2;
			if ($remote_error_msg) {
				$rv = { 'up' => $webmindown,
					 'desc' => "$text{'mon_webmin'} : $remote_error_msg" };
				}
			else {
				my %s = %{$serv};
				$s{'remote'} = '*';
				$s{'groups'} = undef;
				($rv) = &remote_foreign_call($r, 'status',
					    'service_status', \%s, $fromcgi);
				if ($remote_error_msg) {
					$rv = { 'up' => $webmindown, 'desc' =>
					    "$text{'mon_webmin'} : $remote_error_msg" };
					}
				}
			}
		elsif ($t =~ /^(\S+)::(\S+)$/) {
			# Call to another module
			my ($mod, $mtype) = ($1, $2);
			$mod = $serv->{'clone'} if ($serv->{'clone'});
			&foreign_require($mod, "status_monitor.pl");
			$rv = &foreign_call($mod, "status_monitor_status",
					    $mtype, $serv, $fromcgi);
			}
		else {
			# Just include and use the local monitor library
			my $mfile = "$module_root_directory/${t}-monitor.pl";
			if (-r $mfile && !$done_monitor{$t}++) {
				do $mfile;
				$done_monitor_err{$t} = "$@" if ($@);
				}
			my $func = "get_${t}_status";
			if (defined(&$func)) {
				$rv = &$func($serv,
				     $serv->{'clone'} ? $serv->{'clone'} : $t,
				     $fromcgi);
				}
			else {
				# Monitor type is unknown, or its program
				# failed to load
				$rv = { 'up' => -1 };
				$rv->{'desc'} = &text('mon_eload', $mfile,
						      $done_monitor_err{$t})
					if ($done_monitor_err{$t});
				}
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
# defined in other modules. Each is a array ref with ID, description
# and deprecated fields.
sub list_handlers
{
my ($f, @rv);
opendir(DIR, ".");
while($f = readdir(DIR)) {
	if ($f =~ /^(\S+)-monitor\.pl$/) {
		my $m = $1;
		my $oss = $monitor_os_support{$m};
		next if ($oss && !&check_os_support($oss));
		my $dep = $monitor_deprecated{$m} ? 1 : 0;
		push(@rv, [ $m, $text{"type_$m"}, $dep ]);
		}
	}
closedir(DIR);
foreach my $m (&get_all_module_infos()) {
	my $mdir = &module_root_directory($m->{'dir'});
	if (-r "$mdir/status_monitor.pl" &&
	    &check_os_support($m) &&
	    !$m->{'cloneof'}) {
		&foreign_require($m->{'dir'}, "status_monitor.pl");
		# Action-only modules do not define new monitor types
		next if (!&foreign_defined($m->{'dir'}, "status_monitor_list"));
		my @mms = &foreign_call($m->{'dir'}, "status_monitor_list");
		push(@rv, map { [ $m->{'dir'}."::".$_->[0], $_->[1], $_->[2] ] } @mms);
		}
	}
return @rv;
}

# depends_check(&service, [module]+)
sub depends_check
{
my ($serv, @mods) = @_;
return if ($serv->{'id'});	# only check for new services
if ($serv->{'remote'}) {
	# Check on the remote server
	foreach my $m (@mods) {
		&remote_foreign_check($serv->{'remote'}, $m, 1) ||
			&error(&text('depends_remote', "<tt>$m</tt>",
				     "<tt>$serv->{'remote'}</tt>"));
		}
	}
else {
	# Check on this server
	foreach my $m (@mods) {
		my %minfo = &get_module_info($m);
		%minfo || &error(&text('depends_mod', "<tt>$m</tt>"));
		&check_os_support(\%minfo, undef, undef, 1) ||
			&error(&text('depends_os', "<tt>$minfo{'desc'}</tt>"));
		}
	$_[0]->{'depends'} = join(" ", @mods);
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
	$job = $j if ($j->{'user'} eq 'root' &&
		      ($j->{'command'} eq $cron_cmd ||
		       $j->{'command'} eq $full_cron_cmd));
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
		  'command' => $full_cron_cmd };
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

# nice_remotes(&monitor)
sub nice_remotes
{
my ($s) = @_;
my @remotes = map { $_ eq "*" ? $text{'index_local'}
			         : &html_escape($_) }
		     split(/\s+/, $s->{'remote'});
foreach my $g (split(/\s+/, $s->{'groups'})) {
	push(@remotes, &text('index_group', $g));
	}
return join("<br>", @remotes);
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
if ($config{'sched_webhook'}) {
	push(@rv, "webhook");
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
           'domain' => 'txt.bell.ca' },
         { 'id' => 'luckymobile',
           'desc' => 'Lucky Mobile',
           'domain' => 'txt.bell.ca' },
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
         { 'id' => 'googlefi',
           'desc' => 'Google Fi',
           'domain' => 'msg.fi.google.com' },
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
	open(HFILE, "<".$hfile);
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
return &get_webprefix().
       "/".$module_name."/images/".($up == 1 ? "up.svg" :
		  $up == -1 ? "not.svg" :
		  $up == -2 ? "webmin.svg" :
		  $up == -3 ? "timed.svg" :
		  $up == -4 ? "skip.svg" :
		  	      "down.svg");
}

# status_to_state(up)
# Returns widget state, icon and severity for a status code. Higher
# severity is worse, so multiple hosts can share one summary status.
sub status_to_state
{
my ($up) = @_;
return $up == 1 ? ( 'success', 'check-circle', 0 ) :
       $up == -1 ? ( 'neutral', 'minus', 1 ) :
       $up == -4 ? ( 'neutral', 'minus', 1 ) :
       $up == -2 ? ( 'warning', 'warning', 2 ) :
       $up == -3 ? ( 'warning', 'clock', 2 ) :
		   ( 'danger', 'x-circle', 3 );
}

# status_to_text(up, [&monitor])
# Returns plain status text, using the monitor type's wording if available
sub status_to_text
{
my ($up, $serv) = @_;
if ($serv) {
	# Ask the monitor type for its own message
	do $serv->{'type'}."-monitor.pl" if (!$done_monitor{$serv->{'type'}}++);
	my $f = "get_".$serv->{'type'}."_upmsg";
	my $msg = defined(&$f) ? &$f($up) : undef;
	return $msg if (defined($msg));
	}
# Fall back to the standard status names
return $up == 1 ? $text{'mon_up'} :
       $up == -1 ? $text{'mon_not'} :
       $up == -2 ? $text{'mon_webmin'} :
       $up == -3 ? $text{'mon_timeout'} :
       $up == -4 ? $text{'mon_skip'} :
		   $text{'mon_down'};
}

# status_to_string(up, [&monitor])
# Returns status text, coloring the standard Down message with the theme
sub status_to_string
{
my ($up, $serv) = @_;
my $msg = &status_to_text($up, $serv);
my ($state) = &status_to_state($up);
return $state eq 'danger' && $msg eq $text{'mon_down'} ?
	&ui_text_color($msg, 'danger') : $msg;
}

1;

