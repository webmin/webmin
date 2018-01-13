# Functions for parsing the system log for iptables entries
# XXX ipf support
#	XXX ipf missing some packets? large FTP transfer?
# XXX option to specify ports considered 'server' (by ranges)
#	XXX option to make ports without names not server ports
#	XXX use is_server_port function

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
if (&foreign_installed("syslog-ng")) {
	&foreign_require("syslog-ng", "syslog-ng-lib.pl");
	$syslog_module = "syslog-ng";
	}
elsif (&foreign_installed("syslog")) {
	&foreign_require("syslog", "syslog-lib.pl");
	$syslog_module = "syslog";
	}
else {
	$syslog_module = undef;
	}
&foreign_require("cron", "cron-lib.pl");
&foreign_require("net", "net-lib.pl");

%access = &get_module_acl();

$bandwidth_log = $config{'bandwidth_log'} || "/var/log/bandwidth";
$hours_dir = $config{'bandwidth_dir'} || "$module_config_directory/hours";
$cron_cmd = "$module_config_directory/rotate.pl";
$pid_file = "$module_config_directory/rotate.pid";

# list_hours()
# Returns a list of all hours for which traffic is available
sub list_hours
{
opendir(DIR, $hours_dir);
local @rv = grep { $_ =~ /^\d+$/ } readdir(DIR);
closedir(DIR);
return @rv;
}

# get_hour(num)
sub get_hour
{
if (!defined($hour_cache{$_[0]})) {
	local $file = "$hours_dir/$_[0]";
	local %hour;
	if (&read_file($file, \%hour)) {
		$hour_cache{$_[0]} = \%hour;
		}
	else {
		$hour_cache{$_[0]} = { 'hour' => $_[0] };
		}
	}
return $hour_cache{$_[0]};
}

# save_hour(hour)
sub save_hour
{
mkdir($hours_dir, 0755);
local $file = "$hours_dir/$_[0]->{'hour'}";
&write_file($file, $_[0]);
}

# find_rule(&table, chain, interface, dir)
sub find_rule
{
local ($table, $chain, $iface, $dir) = @_;
local $r;
local $dd = $dir eq "i" ? "IN" : "OUT";
foreach $r (@{$table->{'rules'}}) {
	next if ($r->{'chain'} ne $chain);
	local $da = $r->{$dir};
	if ($iface) {
		next if ($da->[1] ne $iface);
		}
	else {
		next if (!$da);
		}
	next if ($r->{'j'}->[1] ne 'LOG');
	next if ($r->{'args'} !~ /\-\-log\-prefix\s+BANDWIDTH_\Q$dd\E:/ &&
		 $r->{'args'} !~ /\-\-log\-prefix\s+"BANDWIDTH_\Q$dd\E:"/ &&
		 $r->{'logprefix'}->[1] ne "BANDWIDTH_$dd");
	return $r;
	}
return undef;
}

# find_sysconf(&conf)
# Returns the syslog entry for kernel debug messages to the log file
sub find_sysconf
{
local ($conf) = @_;
local $c;
local @ll = &get_loglevel();
foreach $c (@$conf) {
	next if (!$c->{'active'});
	next if ($c->{'file'} ne $bandwidth_log);
	next if ($c->{'sel'}->[0] ne $ll[0]);
	return $c;
	}
return undef;
}

# find_sysconf_ng(&conf)
# Returns the destination, filter and log objects for kernel debug messages
sub find_sysconf_ng
{
local ($conf) = @_;
local @dests = &syslog_ng::find("destination", $conf);
local ($dest) = grep { $_->{'value'} eq "d_bandwidth" } @dests;
local @filters = &syslog_ng::find("filter", $conf);
local ($filter) = grep { $_->{'value'} eq "f_bandwidth" } @filters;
local @logs = &syslog_ng::find("log", $conf);
local $log;
if ($dest && $filter) {
	foreach my $l (@logs) {
		local ($ldest) = &syslog_ng::find("destination",
						  $l->{'members'});
		local ($lfilter) = &syslog_ng::find("filter",
						    $l->{'members'});
		if ($ldest->{'value'} eq $dest->{'value'} &&
		    $lfilter->{'value'} eq $filter->{'value'}) {
			$log = $l;
			last;
			}
		}
	}
return ($dest, $filter, $log);
}

# find_cron_job()
# Returns the cron job used for bandwidth counting, or undef
sub find_cron_job
{
local @jobs = &cron::list_cron_jobs();
local ($job) = grep { $_->{'user'} eq 'root' &&
		      $_->{'command'} eq $cron_cmd &&
		      $_->{'active'} } @jobs;
return $job;
}

# date_input(day, month, year, prefix)
sub date_input
{
return &ui_textbox("$_[3]_day", $_[0], 2)."/".
       &ui_select("$_[3]_month", $_[1],
		  [ map { [ $_, $text{"smonth_".$_} ] } (1 .. 12) ])."/". 
       &ui_textbox("$_[3]_year", $_[2], 4).
       &date_chooser_button("$_[3]_day", "$_[3]_month", "$_[3]_year");
}

# hourmin_input(hour, min, prefix)
sub hourmin_input
{
return &ui_textbox("$_[2]_hour", $_[0], 2).":".
       &ui_textbox("$_[2]_min", $_[1], 2);
}

# detect_firewall_system()
# Guesses which firewall is installed
sub detect_firewall_system
{
local $m;
foreach $m ("shorewall", "firewall", "ipfw", "ipfilter") {
	return $m if (&check_firewall_system($m));
	}
return undef;
}

# check_firewall_system(type)
# Returns 1 if some firewall is installed
sub check_firewall_system
{
# XXX shorewall check should look for actual rules?
return &foreign_installed($_[0], 1);
}

sub check_rules
{
local $cfunc = "check_".$config{'firewall_system'}."_rules";
return &$cfunc(@_);
}

sub setup_rules
{
local $sfunc = "setup_".$config{'firewall_system'}."_rules";
return &$sfunc(@_);
}

sub delete_rules
{
local $dfunc = "delete_".$config{'firewall_system'}."_rules";
return &$dfunc(@_);
}

sub process_line
{
local $pfunc = "process_".$config{'firewall_system'}."_line";
return &$pfunc(@_);
}

sub pre_process
{
local $pfunc = "pre_".$config{'firewall_system'}."_process";
if (defined(&$pfunc)) {
	&$pfunc(@_);
	}
}

sub get_loglevel
{
local $lfunc = "get_".$config{'firewall_system'}."_loglevel";
return &$lfunc(@_);
}

# is_server_port(num)
sub is_server_port
{
}

############### functions for IPtables #################

# check_firewall_rules()
# Returns 1 if the IPtables rules needed are setup, 0 if not
sub check_firewall_rules
{
&foreign_require("firewall", "firewall-lib.pl");
&foreign_require("firewall", "firewall4-lib.pl");
local @tables = &firewall::get_iptables_save();
local ($filter) = grep { $_->{'name'} eq 'filter' } @tables;

local $inrule = &find_rule($filter, "INPUT", $config{'iface'}, "i");
local $outrule = &find_rule($filter, "OUTPUT", $config{'iface'}, "o");
local $fwdinrule = &find_rule($filter, "FORWARD", $config{'iface'}, "i");
local $fwdoutrule = &find_rule($filter, "FORWARD", $config{'iface'}, "o");
return $inrule && $outrule && $fwdinrule && $fwdoutrule;
}

# setup_firewall_rules(iface)
# If any IPtables rules are missing, add them
sub setup_firewall_rules
{
&foreign_require("firewall", "firewall-lib.pl");
&foreign_require("firewall", "firewall4-lib.pl");
local @tables = &firewall::get_iptables_save();
local ($filter) = grep { $_->{'name'} eq 'filter' } @tables;
$filter ||= { 'name' => 'filter',
	      'defaults' => { 'INPUT' => 'ACCEPT',
			      'OUTPUT' => 'ACCEPT',
			      'FORWARD' => 'ACCEPT' },
	      'rules' => [ ],
	    };
local $inrule = &find_rule($filter, "INPUT", $config{'iface'}, "i");
local $outrule = &find_rule($filter, "OUTPUT", $config{'iface'}, "o");
local $fwdinrule = &find_rule($filter, "FORWARD", $config{'iface'}, "i");
local $fwdoutrule = &find_rule($filter, "FORWARD", $config{'iface'}, "o");
local $missingrule = !$inrule || !$outrule || !$fwdinrule || !$fwdoutrule;
if (!$inrule) {
	splice(@{$filter->{'rules'}}, 0, 0,
	       { 'chain' => 'INPUT',
		 'j' => [ undef, 'LOG' ],
		 'i' => [ undef, $_[0] ],
		 'args' => "--log-level 7 --log-prefix BANDWIDTH_IN:" });
	}
if (!$outrule) {
	splice(@{$filter->{'rules'}}, 0, 0,
	       { 'chain' => 'OUTPUT',
		 'j' => [ undef, 'LOG' ],
		 'o' => [ undef, $_[0] ],
		 'args' => "--log-level 7 --log-prefix BANDWIDTH_OUT:" });
	}
if (!$fwdinrule) {
	splice(@{$filter->{'rules'}}, 0, 0,
	       { 'chain' => 'FORWARD',
		 'j' => [ undef, 'LOG' ],
		 'i' => [ undef, $_[0] ],
		 'args' => "--log-level 7 --log-prefix BANDWIDTH_IN:" });
	}
if (!$fwdoutrule) {
	splice(@{$filter->{'rules'}}, 0, 0,
	       { 'chain' => 'FORWARD',
		 'j' => [ undef, 'LOG' ],
		 'o' => [ undef, $_[0] ],
		 'args' => "--log-level 7 --log-prefix BANDWIDTH_OUT:" });
	}

if ($missingrule) {
	# Save and apply
	&lock_file($firewall::iptables_save_file);
	&firewall::run_before_command();
	&firewall::save_table($filter);
	&firewall::run_after_command();
	&unlock_file($firewall::iptables_save_file);
	return &firewall::apply_configuration();
	}
return undef;
}

# delete_firewall_rules()
# Delete firewall rules for bandwidth logging
sub delete_firewall_rules
{
&foreign_require("firewall", "firewall-lib.pl");
&foreign_require("firewall", "firewall4-lib.pl");
local @tables = &firewall::get_iptables_save();
local ($filter) = grep { $_->{'name'} eq 'filter' } @tables;
local $inrule = &find_rule($filter, "INPUT", $config{'iface'}, "i");
local $outrule = &find_rule($filter, "OUTPUT", $config{'iface'}, "o");
local $fwdinrule = &find_rule($filter, "FORWARD", $config{'iface'}, "i");
local $fwdoutrule = &find_rule($filter, "FORWARD", $config{'iface'}, "o");
local $anyrule = $inrule || $outrule || $fwdinrule || $fwdoutrule;
if ($anyrule) {
	@{$filter->{'rules'}} = grep { $_ ne $inrule &&
				       $_ ne $outrule &&
				       $_ ne $fwdinrule &&
				       $_ ne $fwdoutrule }@{$filter->{'rules'}};

	# Save and apply firewall
	&lock_file($firewall::iptables_save_file);
	&firewall::run_before_command();
	&firewall::save_table($filter);
	&firewall::run_after_command();
	&unlock_file($firewall::iptables_save_file);
	return &firewall::apply_configuration();
	}
return undef;
}

# process_firewall_line(line, &hours, time-now)
# Process an IPtables firewall line, and returns 1 if successful
sub process_firewall_line
{
local ($line, $hours, $time_now) = @_;
my @time_now = localtime($time_now);
if ($line =~ /^(\S+)\s+(\d+)\s+(\d+):(\d+):(\d+).*BANDWIDTH_(IN|OUT):(IN=.*)/) {
	# Found a valid line
	local ($mon, $day, $hr, $min, $sec) = ($1, $2, $3, $4, $5);
	local $dir = lc($6);
	local %line;
	local $w;
	foreach $w (split(/\s+/, $7)) {
		($n, $v) = split(/=/, $w);
		if ($n) {
			$line{lc($n)} = $v;
			}
		}

	# Work out the real time
	local $tm = timelocal($sec, $min, $hr, $day,
			      &month_to_number($mon), $time_now[5]);
	if ($tm > $time_now + 24*60*60) {
		# Was really last year
		$tm = timelocal($sec, $min, $hr, $day,
				&month_to_number($mon), $time_now[5]-1);
		}
	local $htm = int($tm/(60*60));

	# Update the appropriate counters
	local $hour = &get_hour($htm);
	if (&indexof($hour, @$hours) < 0) {
		push(@$hours, $hour);
		}
	local $port;
	if ($line{'proto'} eq 'TCP' || $line{'proto'} eq 'UDP') {
		if ($dir eq "in") {
			$port = '_'.$line{'dpt'}.'_'.$line{'spt'};
			}
		else {
			$port = '_'.$line{'spt'}.'_'.$line{'dpt'};
			}
		}
	local $host = $dir eq "in" ? $line{'dst'} : $line{'src'};
	local $key = $host.'_'.$line{'proto'}.$port;
	local ($in, $out) = split(/ /, $hour->{$key});
	if ($dir eq "in") {
		$in += $line{'len'};
		}
	else {
		$out += $line{'len'};
		}
	$hour->{$key} = int($in)." ".int($out);
	return 1;
	}
else {
	return 0;
	}
}

# get_firewall_loglevel()
sub get_firewall_loglevel
{
return ( "kern.=debug" );
}

############### functions for ipfw #################

sub check_ipfw_rules
{
&foreign_require("ipfw", "ipfw-lib.pl");
local $rules = &ipfw::get_config();
local $rule = &find_ipfw_rule($rules, $config{'iface'});
return $rule ? 1 : 0;
}

# setup_ipfw_rules(iface)
# Add the logging rule used for ipfw
sub setup_ipfw_rules
{
&foreign_require("ipfw", "ipfw-lib.pl");
local $rules = &ipfw::get_config();
local $rule = &find_ipfw_rule($rules, $config{'iface'});
if (!$rule) {
	# Add the rule
	local $num = 100;
	if (@$rules && $rules->[0]->{'num'} < 100) {
		$num = int($rules->[0]->{'num'} / 2);
		}
	$rule = { 'action' => 'count',
		  'log' => 1,
		  'proto' => 'all',
		  'from' => 'any',
		  'to' => 'any',
		  'num' => $num,
		  'via' => $_[0] };
	splice(@$rules, 0, 0, $rule);
	&ipfw::save_config($rules);

	# Apply config
	return &ipfw::apply_rules($rules);
	}
return undef;
}

# delete_ipfw_rules()
# Delete the logging rule used for ipfw
sub delete_ipfw_rules
{
&foreign_require("ipfw", "ipfw-lib.pl");
local $rules = &ipfw::get_config();
local $rule = &find_ipfw_rule($rules, $config{'iface'});
if ($rule) {
	@$rules = grep { $_ ne $rule } @$rules;
	&ipfw::save_config($rules);
	return &ipfw::apply_rules();
	}
return undef;
}

# find_ipfw_rule(&rules, iface)
sub find_ipfw_rule
{
local ($rule) = grep { ($_->{'action'} eq 'allow' ||
			$_->{'action'} eq 'count') &&
		       $_->{'log'} &&
		       ($_->{'proto'} eq 'all' || $_->{'proto'} eq 'ip') &&
		       $_->{'from'} eq 'any' &&
		       $_->{'to'} eq 'any' &&
		       $_->{'via'} eq $_[1] } @{$_[0]};
return $rule;
}

# pre_ipfw_process()
# Called before processing of the logs, to get the average packet size
sub pre_ipfw_process
{
&foreign_require("ipfw", "ipfw-lib.pl");
local $active = &ipfw::get_config("$ipfw::config{'ipfw'} show |", \$out);
local $rule = &find_ipfw_rule($active, $config{'iface'});
if ($rule && $rule->{'count1'}) {
	$average_packet_size = $rule->{'count2'} / $rule->{'count1'};
	system("$ipfw::config{'ipfw'} zero $rule->{'num'} >/dev/null 2>&1");
	}
else {
	$average_packet_size = 1;
	}
}

# process_ipfw_line(line, &hours, time-now)
# Process a BSD IPFW firewall line, and returns 1 if successful
sub process_ipfw_line
{
local ($line, $hours, $time_now) = @_;
if ($line =~ /^(\S+)\s+(\d+)\s+(\d+):(\d+):(\d+).*ipfw:\s+\S+\s+(Accept|Count)\s+(\S+)\s+(\S+)\s+(\S+)\s+(in|out)\s+via\s+(\S+)/) {
	# Found a valid line
	local ($mon, $day, $hr, $min, $sec) = ($1, $2, $3, $4, $5);
	local ($proto, $src, $dest, $dir, $iface) = ($7, $8, $9, $10, $11);
	local ($srchost, $srcport) = split(/:/, $src);
	local ($desthost, $destport) = split(/:/, $dest);
	$proto =~ s/:.*//;
	return undef if ($iface ne $config{'iface'});

	# Work out the real time
	local $tm = timelocal($sec, $min, $hr, $day,
			      &month_to_number($mon), $time_now[5]);
	if ($tm > $time_now + 24*60*60) {
		# Was really last year
		$tm = timelocal($sec, $min, $hr, $day,
				&month_to_number($mon), $time_now[5]-1);
		}
	local $htm = int($tm/(60*60));

	# Update the appropriate counters
	local $hour = &get_hour($htm);
	if (&indexof($hour, @$hours) < 0) {
		push(@$hours, $hour);
		}
	local $port;
	if ($proto eq 'TCP' || $proto eq 'UDP') {
		if ($dir eq "in") {
			$port = '_'.$destport.'_'.$srcport;
			}
		else {
			$port = '_'.$srcport.'_'.$destport;
			}
		}
	local $host = $dir eq "in" ? $desthost : $srchost;
	local $key = $host.'_'.$proto.$port;
	local ($in, $out) = split(/ /, $hour->{$key});
	if ($dir eq "in") {
		$in += $average_packet_size;
		}
	else {
		$out += $average_packet_size;
		}
	$hour->{$key} = int($in)." ".int($out);
	return 1;
	}
else {
	return 0;
	}
}



# get_ipfw_loglevel()
sub get_ipfw_loglevel
{
return ( "security.*", "kern.debug" );
}

############### functions for Shorewall #################

sub check_shorewall_rules
{
&foreign_require("shorewall", "shorewall-lib.pl");
local $lref = &read_file_lines("$shorewall::config{'config_dir'}/start");
local $rule1 = &find_shorewall_rule($lref, "INPUT", "-i", $config{'iface'});
local $rule2 = &find_shorewall_rule($lref, "FORWARD", "-i", $config{'iface'});
local $rule3 = &find_shorewall_rule($lref, "FORWARD", "-o", $config{'iface'});
local $rule4 = &find_shorewall_rule($lref, "OUTPUT", "-o", $config{'iface'});
return defined($rule1) && defined($rule2) && defined($rule3) && defined($rule4);
}

# setup_shorewall_rules(iface)
# Add lines to the Shorewall start script to add logging IPtables rules
sub setup_shorewall_rules
{
&foreign_require("shorewall", "shorewall-lib.pl");
local $lref = &read_file_lines("$shorewall::config{'config_dir'}/start");
local $rule1 = &find_shorewall_rule($lref, "INPUT", "-i", $_[0]);
local $rule2 = &find_shorewall_rule($lref, "FORWARD", "-i", $_[0]);
local $rule3 = &find_shorewall_rule($lref, "FORWARD", "-o", $_[0]);
local $rule4 = &find_shorewall_rule($lref, "OUTPUT", "-o", $_[0]);
local $gotall = defined($rule1) && defined($rule2) &&
		defined($rule3) && defined($rule4);
if (!defined($rule1)) {
	push(@$lref, "run_iptables -I INPUT -i $_[0] -j LOG --log-prefix BANDWIDTH_IN: --log-level debug");
	}
if (!defined($rule2)) {
	push(@$lref, "run_iptables -I FORWARD -i $_[0] -j LOG --log-prefix BANDWIDTH_IN: --log-level debug");
	}
if (!defined($rule3)) {
	push(@$lref, "run_iptables -I FORWARD -o $_[0] -j LOG --log-prefix BANDWIDTH_OUT: --log-level debug");
	}
if (!defined($rule4)) {
	push(@$lref, "run_iptables -I OUTPUT -o $_[0] -j LOG --log-prefix BANDWIDTH_OUT: --log-level debug");
	}
&flush_file_lines();

if (!$gotall) {
	# Apply config with a shorewall restart
	&shorewall::run_before_apply_command();
	local $out = &backquote_logged("$shorewall::config{'shorewall'} restart 2>&1");
	return "<pre>$out</pre>" if ($?);
	&shorewall::run_after_apply_command();
	}
return undef;
}

sub delete_shorewall_rules
{
&foreign_require("shorewall", "shorewall-lib.pl");
local $lref = &read_file_lines("$shorewall::config{'config_dir'}/start");
local $rule1 = &find_shorewall_rule($lref, "INPUT", "-i", $config{'iface'});
splice(@$lref, $rule1, 1) if (defined($rule1));
local $rule2 = &find_shorewall_rule($lref, "FORWARD", "-i", $config{'iface'});
splice(@$lref, $rule2, 1) if (defined($rule2));
local $rule3 = &find_shorewall_rule($lref, "FORWARD", "-o", $config{'iface'});
splice(@$lref, $rule3, 1) if (defined($rule3));
local $rule4 = &find_shorewall_rule($lref, "OUTPUT", "-o", $config{'iface'});
splice(@$lref, $rule4, 1) if (defined($rule4));
&flush_file_lines();

if (defined($rule1) || defined($rule2) || defined($rule3) || defined($rule4)) {
	# Apply config with a shorewall restart
	&shorewall::run_before_apply_command();
	local $out = &backquote_logged("$shorewall::config{'shorewall'} restart 2>&1");
	return "<pre>$out</pre>" if ($?);
	&shorewall::run_after_apply_command();
	}
return undef;
}

# find_shorewall_rule(&lref, chain, dir, iface)
# Returns the line indexes of the shorewall start script entries that add
# the extra logging IPtables rules
sub find_shorewall_rule
{
local ($lref, $chain, $dir, $iface) = @_;
local $io = $dir eq "-i" ? "BANDWIDTH_IN:" : "BANDWIDTH_OUT:";
local (@rv, $i);
for($i=0; $i<@$lref; $i++) {
	if ($lref->[$i] =~ /^run_iptables\s+-I\s+$chain\s+$dir\s+$iface\s+-j\s+LOG\s+--log-prefix\s+$io\s+--log-level\s+debug/) {
		return $i;
		}
	}
return undef;
}

# get_shorewall_loglevel()
sub get_shorewall_loglevel
{
return ( "kern.=debug" );
}

sub process_shorewall_line
{
return &process_firewall_line(@_);
}

############### functions for ipfilter #################

sub check_ipfilter_rules
{
&foreign_require("ipfilter", "ipfilter-lib.pl");
local $rules = &ipfilter::get_config();
local $rule1 = &find_ipfilter_rule($rules, $config{'iface'}, "in");
local $rule2 = &find_ipfilter_rule($rules, $config{'iface'}, "out");
return $rule1 && $rule2;
}

# setup_ipfilter_rules(iface)
# Add the logging rule used for ipfilter
sub setup_ipfilter_rules
{
&foreign_require("ipfilter", "ipfilter-lib.pl");
local $rules = &ipfilter::get_config();
local $rule1 = &find_ipfilter_rule($rules, $_[0], "in");
local $rule2 = &find_ipfilter_rule($rules, $_[0], "out");
local $gotall = $rule1 && $rule2;
if (!$rule1) {
	$rule1 = { 'action' => 'log',
		   'on' => $_[0],
		   'log-level' => 'local7.debug',
		   'dir' => 'in',
		   'all' => 1,
		   'active' => 1 };
	if (@$rules) {
		&ipfilter::insert_rule($rule1, $rules->[0]);
		}
	else {
		&ipfilter::create_rule($rule1);
		}
	}
if (!$rule2) {
	$rule2 = { 'action' => 'log',
		   'on' => $_[0],
		   'log-level' => 'local7.debug',
		   'dir' => 'out',
		   'all' => 1,
		   'active' => 1 };
	if (@$rules) {
		&ipfilter::insert_rule($rule2, $rules->[0]);
		}
	else {
		&ipfilter::create_rule($rule2);
		}
	}

if (!$gotall) {
	# Apply config
	return &ipfilter::apply_configuration();
	}
return undef;
}

# delete_ipfilter_rules()
# Delete the logging rules used for ipfilter
sub delete_ipfilter_rules
{
&foreign_require("ipfilter", "ipfilter-lib.pl");
local $rules = &ipfilter::get_config();
local $rule1 = &find_ipfilter_rule($rules, $config{'iface'}, "in");
local $rule2 = &find_ipfilter_rule($rules, $config{'iface'}, "out");
&ipfilter::delete_rule($rule1) if ($rule1);
&ipfilter::delete_rule($rule2) if ($rule2);
if ($rule1 || $rule2) {
	return &ipfilter::apply_configuration();
	}
return undef;
}

# find_ipfilter_rule(&rules, iface, dir)
sub find_ipfilter_rule
{
local ($rule) = grep { $_->{'action'} eq 'log' &&
		       $_->{'on'} eq $_[1] &&
		       $_->{'all'} &&
		       $_->{'active'} &&
		       $_->{'log-level'} eq "local7.debug" &&
		       $_->{'dir'} eq $_[2] } @{$_[0]};
return $rule;
}

# process_ipfilter_line(line, &hours, time-now)
# Process a IPFilter firewall line, and returns 1 if successful
sub process_ipfilter_line
{
local ($line, $hours, $time_now) = @_;
if ($line =~ /^(\S+)\s+(\d+)\s+(\d+):(\d+):(\d+).*ipmon\S*:.*\s$config{'iface'}\s+\S+\s+\S+\s+(\S+)\s+->\s+(\S+)\s+\S+\s+(\S+)\s+len\s+(\d+)\s+\(?(\d+)\)?.*(IN|OUT)/) {
	# Found a valid line
	local ($mon, $day, $hr, $min, $sec) = ($1, $2, $3, $4, $5);
	local ($src, $dest, $proto, $len, $dir) = ($6, $7, uc($8), $10, lc($11));
	local ($srchost, $srcport) = split(/,/, $src);
	local ($desthost, $destport) = split(/,/, $dest);
	$proto =~ s/:.*//;
	local $len = 1024;

	# Work out the real time
	local $tm = timelocal($sec, $min, $hr, $day,
			      &month_to_number($mon), $time_now[5]);
	if ($tm > $time_now + 24*60*60) {
		# Was really last year
		$tm = timelocal($sec, $min, $hr, $day,
				&month_to_number($mon), $time_now[5]-1);
		}
	local $htm = int($tm/(60*60));

	# Update the appropriate counters
	local $hour = &get_hour($htm);
	if (&indexof($hour, @$hours) < 0) {
		push(@$hours, $hour);
		}
	local $port;
	if ($proto eq 'TCP' || $proto eq 'UDP') {
		if ($dir eq "in") {
			$port = '_'.$destport.'_'.$srcport;
			}
		else {
			$port = '_'.$srcport.'_'.$destport;
			}
		}
	local $host = $dir eq "in" ? $dest : $src;
	local $key = $host.'_'.$proto.$port;
	local ($in, $out) = split(/ /, $hour->{$key});
	if ($dir eq "in") {
		$in += $len;
		}
	else {
		$out += $len;
		}
	$hour->{$key} = int($in)." ".int($out);
	return 1;
	}
else {
	return 0;
	}
}

# get_ipfilter_loglevel()
sub get_ipfilter_loglevel
{
return ( "local7.debug" );
}

1;

