# squid-lib.pl
# Functions for configuring squid.conf

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
do 'parser-lib.pl';
%access = &get_module_acl();
$auth_program = "$module_config_directory/squid-auth.pl";
$auth_database = "$module_config_directory/users";
@caseless_acl_types = ( "url_regex", "urlpath_regex", "proxy_auth_regex",
			"srcdom_regex", "dstdom_regex", "ident_regex" );

# Get the squid version
if (open(VERSION, "$module_config_directory/version")) {
	chop($squid_version = <VERSION>);
	close(VERSION);
	}

# choice_input(text, name, &config, default, [display, option]+)
# Display a number of radio buttons for selecting some option
sub choice_input
{
local($v, $vv, $rv, $i);
$v = &find_config($_[1], $_[2]);
$vv = $v ? $v->{'value'} : $_[3];
$rv = "<td><b>$_[0]</b></td> <td valign=top>";
for($i=4; $i<@_; $i+=2) {
	$rv .= "<input type=radio name=$_[1] value=\"".$_[$i+1]."\" ".
		($vv eq $_[$i+1] ? "checked" : "")."> $_[$i]\n";
	}
return $rv."</td>\n";
}

# select_input(text, name, &config, default, [display, option]+)
# Like choice_input, but uses a drop-down select field
sub select_input
{
local($v, $vv, $rv, $i);
$v = &find_config($_[1], $_[2]);
$vv = $v ? $v->{'value'} : $_[3];
$rv = "<td><b>$_[0]</b></td> <td valign=top><select name=$_[1]>";
for($i=4; $i<@_; $i+=2) {
	$rv .= "<option value=\"".$_[$i+1]."\" ".
		($vv eq $_[$i+1] ? "selected" : "")."> $_[$i]\n";
	}
return $rv."</select></td>\n";
}

# save_choice(name, default, &config)
# Save a selection from choice_input()
sub save_choice
{
if ($in{$_[0]} eq $_[1]) { &save_directive($_[2], $_[0], [ ]); }
else { &save_directive($_[2], $_[0], [{ 'name' => $_[0],
					'values' => [ $in{$_[0]} ] }]); }
}

# list_input(text, name, &config, type, [default])
# Display a list of values
sub list_input
{
local($v, $rv, @av);
foreach $v (&find_config($_[1], $_[2])) {
	push(@av, @{$v->{'values'}});
	}
if ($_[4]) {
	$opt = sprintf "<input type=radio name=$_[1]_def value=1 %s> $_[4]\n",
		@av ? "" : "checked";
	$opt .= sprintf "<input type=radio name=$_[1]_def value=0 %s>\n",
		@av ? "checked" : "";
	}
if ($_[3] == 0) {
	# text area
	$rv = "<td valign=top><b>$_[0]</b></td> <td valign=top>";
	if ($opt) { $rv .= "$opt Listed..<br>\n"; }
	$rv .= "<textarea name=$_[1] rows=3 cols=15>".
		join("\n", @av)."</textarea></td>\n";
	}
else {
	# one long text field
	$rv = "<td valign=top><b>$_[0]</b></td> <td colspan=3 valign=top>$opt";
	$rv .= "<input name=$_[1] size=50 value=\"".join(' ',@av)."\"></td>\n";
	}
return $rv;
}

# save_list(name, &checkfunc, &config)
sub save_list
{
local($v, @vals, $err);
if (!$in{"$_[0]_def"}) {
	@vals = split(/\s+/, $in{$_[0]});
	if ($_[1]) {
		foreach $v (@vals) {
			&check_error($_[1], $v);
			}
		}
	}
if (@vals) { &save_directive($_[2], $_[0],
		[{ 'name' => $_[0], values => \@vals }]); }
else { &save_directive($_[2], $_[0], [ ]); }
}

# check_error(&function, value)
sub check_error
{
return if (!$_[0]);
local $err = &{$_[0]}($_[1]);
if ($err) { &error($err); }
}

# address_input(text, name, &config, type)
# Display a text area for entering 0 or more addresses
sub address_input
{
local($v, $rv, @av);
foreach $v (&find_config($_[1], $_[2])) {
	push(@av, @{$v->{'values'}});
	}
if ($_[3] == 0) {
	# text area
	$rv = "<td valign=top><b>$_[0]</b></td> <td valign=top>";
	$rv .= "<textarea name=$_[1] rows=3 cols=15>".
		join("\n", @av)."</textarea></td>\n";
	}
else {
	# one long text field
	$rv = "<td valign=top><b>$_[0]</b></td> <td colspan=3 valign=top>";
	$rv .= "<input name=$_[1] size=50 value=\"".join(' ',@av)."\"></td>\n";
	}
return $rv;
}

# save_address(name, config)
sub save_address
{
local($addr, @vals);
foreach $addr (split(/\s+/, $in{$_[0]})) {
	&check_ipaddress($addr) || &error(&text('lib_emsg1',$addr));
	push(@vals, $addr);
	}
if (@vals) { &save_directive($_[1], $_[0],
		[{ 'name' => $_[0], values => \@vals }]); }
else { &save_directive($_[1], $_[0], [ ]); }
}

# opt_input(text, name, &config, default, size, units)
# Display an optional field for entering something
sub opt_input
{
local($v, $rv);
$v = &find_config($_[1], $_[2]);
$rv = "<td valign=top><b>$_[0]</b></td> <td valign=top nowrap";
$rv .= $_[4] > 30 ? " colspan=3>\n" : ">\n";
$rv .= sprintf "<input type=radio name=$_[1]_def value=1 %s> $_[3]\n",
	$v ? "" : "checked";
$rv .= sprintf "<input type=radio name=$_[1]_def value=0 %s> ",
	$v ? "checked" : "";
$rv .= sprintf "<input name=$_[1] size=$_[4] value=\"%s\"> %s</td>\n",
	$v ? $v->{'value'} : "", $_[5];
return $rv;
}

# save_opt(name, &function, &config)
# Save an input from opt_input()
sub save_opt
{
if ($in{"$_[0]_def"}) { &save_directive($_[2], $_[0], [ ]); }
else {
	&check_error($_[1], $in{$_[0]});
	local $dir = { 'name' => $_[0], 'values' => [ $in{$_[0]} ] };
	&save_directive($_[2], $_[0], [ $dir ]);
	}
}

# opt_time_input(text, name, &config, default, size)
sub opt_time_input
{
local($v, $rv, $u, %ts );
$v = &find_config($_[1], $_[2]);
$rv = "<td valign=top><b>$_[0]</b></td> <td valign=top nowrap>\n";
$rv .= sprintf "<input type=radio name=$_[1]_def value=1 %s> $_[3]\n",
	$v ? "" : "checked";
$rv .= sprintf "<input type=radio name=$_[1]_def value=0 %s> ",
	$v ? "checked" : "";
$rv .= &time_fields($_[1], $_[4], $v ? @{$v->{'values'}} : ( ));
$rv .= "</td>\n";
return $rv;
}

# time_field(name, size, time, units)
sub time_fields
{
local ($rv, %ts);
%ts = (	"second"=>	$text{"lib_seconds"},
	"minute"=>	$text{"lib_minutes"},
	"hour"=>	$text{"lib_hours"},
	"day"=>		$text{"lib_days"},
	"week"=>	$text{"lib_weeks"},
	"fortnight"=>	$text{"lib_fortnights"},
	"month"=>	$text{"lib_months"},
	"year"=>	$text{"lib_years"},
	"decade"=>	$text{"lib_decades"} );
$rv .= sprintf "<input name=$_[0] size=$_[1] value=\"%s\">\n", $_[2];
$rv .= "<select name=$_[0]_u>\n";
foreach $u (keys %ts) {
	$rv .= sprintf "<option value=$u %s>$ts{$u}\n",
		$_[3] =~ /^$u/ ? "selected" : "";
	}
$rv .= "</select>\n";
return $rv;
}

# save_opt_time(name, &config)
sub save_opt_time
{
local %ts = ( "second"=>      $text{"lib_seconds"},
        "minute"=>      $text{"lib_minutes"},
        "hour"=>        $text{"lib_hours"},
        "day"=>         $text{"lib_days"},
        "week"=>        $text{"lib_weeks"},
        "fortnight"=>   $text{"lib_fortnights"},
        "month"=>       $text{"lib_months"},
        "year"=>        $text{"lib_years"},
        "decade"=>      $text{"lib_decades"} );

if ($in{"$_[0]_def"}) { &save_directive($_[1], $_[0], [ ]); }
elsif ($in{$_[0]} !~ /^[0-9\.]+$/) {
	&error(&text('lib_emsg2', $in{$_[0]}, $ts{$in{"$_[0]_u"}}) );
	}
else {
	local $dir = { 'name' => $_[0],
		       'values' => [ $in{$_[0]}, $in{"$_[0]_u"} ] };
	&save_directive($_[1], $_[0], [ $dir ]);
	}
}

# opt_bytes_input(text, name, &config, default, size)
sub opt_bytes_input
{
local($v, $rv, $u, %ss);
@ss = (	[ "KB", $text{'lib_kb'} ],
	[ "MB", $text{'lib_mb'} ],
	[ "GB", $text{'lib_gb'} ] );
$v = &find_config($_[1], $_[2]);
$rv = "<td valign=top><b>$_[0]</b></td> <td valign=top nowrap>\n";
$rv .= sprintf "<input type=radio name=$_[1]_def value=1 %s> $_[3]\n",
	$v ? "" : "checked";
$rv .= sprintf "<input type=radio name=$_[1]_def value=0 %s> ",
	$v ? "checked" : "";
$rv .= sprintf "<input name=$_[1] size=$_[4] value=\"%s\">\n",
	$v ? $v->{'values'}->[0] : "";
$rv .= "<select name=$_[1]_u>\n";
foreach $u (@ss) {
	$rv .= sprintf "<option value=$u->[0] %s>$u->[1]\n",
		$v && $v->{'values'}->[1] eq $u->[0] ? "selected" : "";
	}
$rv .= sprintf "<option value='' %s>bytes\n",
	$v && $v->{'values'}->[1] eq "" ? "selected" : "";
$rv .= "</select></td>\n";
return $rv;
}

# save_opt_bytes(name, &config)
sub save_opt_bytes
{
local %ss = ( "KB"=>  $text{'lib_kb'},
        "MB"=>  $text{'lib_mb'},
        "GB"=>  $text{'lib_gb'} );

if ($in{"$_[0]_def"}) { &save_directive($_[1], $_[0], [ ]); }
elsif ($in{$_[0]} !~ /^[0-9\.]+$/) {
	&error(&text('lib_emsg3', $in{$_[0]}, $ss{$in{"$_[0]_u"}}) );
	}
else {
	local $dir = { 'name' => $_[0],
		       'values' => [ $in{$_[0]}, $in{"$_[0]_u"} ] };
	&save_directive($_[1], $_[0], [ $dir ]);
	}
}

%acl_types = ("src", $text{'lib_aclca'},
	      "dst", $text{'lib_aclwsa'},
	      "srcdomain", $text{'lib_aclch'},
	      "dstdomain", $text{'lib_aclwsh'},
	      "time", $text{'lib_acldat'},
	      "url_regex", $text{'lib_aclur'},
	      "urlpath_regex", $text{'lib_aclupr'},
	      "port", $text{'lib_aclup'},
	      "proto", $text{'lib_aclup1'},
	      "method", $text{'lib_aclrm'},
	      "browser", $text{'lib_aclbr'},
	      "user", $text{'lib_aclpl'},
	      "arp", $text{'lib_aclarp'} );
if ($squid_version >= 2.0) {
	$acl_types{'src_as'} = $text{'lib_aclsan'};
	$acl_types{'dst_as'} = $text{'lib_acldan'};
	$acl_types{'proxy_auth'} = $text{'lib_aclea'};
	$acl_types{'srcdom_regex'} = $text{'lib_aclcr'};
	$acl_types{'dstdom_regex'} = $text{'lib_aclwsr'};
	}
if ($squid_version >= 2.2) {
	$acl_types{'ident'} = $text{'lib_aclru'};
	$acl_types{'myip'} = $text{'lib_aclpia'};
	delete($acl_types{'user'});
	}
if ($squid_version >= 2.3) {
	$acl_types{'maxconn'} = $text{'lib_aclmc'};
	$acl_types{'myport'} = $text{'lib_aclpp'};
	$acl_types{'snmp_community'} = $text{'lib_aclsc'};
	}
if ($squid_version >= 2.4) {
	$acl_types{'req_mime_type'} = $text{'lib_aclrmt'};
	$acl_types{'proxy_auth_regex'} = $text{'lib_aclear'};
	}
if ($squid_version >= 2.5) {
	$acl_types{'rep_mime_type'} = $text{'lib_aclrpmt'};
	$acl_types{'ident_regex'} = $text{'lib_aclrur'};
	$acl_types{'external'} = $text{'lib_aclext'};
	$acl_types{'max_user_ip'} = $text{'lib_aclmuip'};
	}

# restart_button()
# Returns HTML for a link to put in the top-right corner of every page
sub restart_button
{
return undef if ($config{'restart_pos'} == 2);
local $pid = &is_squid_running();
local $args = "redir=".&urlize(&this_url())."&pid=$pid";
if ($pid) {
	return ($access{'restart'} ? "<a href=\"restart.cgi?$args\">$text{'lib_buttac'}</a><br>\n" : "").
	       ($access{'start'} ? "<a href=\"stop.cgi?$args\">$text{'lib_buttss'}</a>\n" : "");
	}
else {
	return $access{'start'} ? "<a href=\"start.cgi?$args\">$text{'lib_buttss1'}</a>\n" : "";
	}
}

# is_squid_running()
# Returns the process ID if squid is running
sub is_squid_running
{
local $conf = &get_config();
local ($pidstruct, $pidfile);
$pidstruct = &find_config("pid_filename", $conf);
if (!$pidstruct) {
	$pidstruct = &find_config("pid_filename", $conf, 2);
	}
$pidfile = $pidstruct ? $pidstruct->{'values'}->[0] : $config{'pid_file'};
if ($pidfile eq "none" || !$pidfile) {
	local ($pid) = &find_byname("squid");
	return $pid;
	}
else {
	return &check_pid_file($pidfile);
	}
}

# this_url()
# Returns the URL in the apache directory of the current script
sub this_url
{
local($url);
$url = $ENV{'SCRIPT_NAME'};
if (defined($ENV{'QUERY_STRING'})) { $url .= "?$ENV{'QUERY_STRING'}"; }
return $url;
}

# list_auth_users(file)
sub list_auth_users
{
local(@rv, $lnum); $lnum = 0;
open(USERS, $_[0]);
while(<USERS>) {
	if (/^(#*)([^:]+):(\S+)/) {
		push(@rv, { 'user' => $2, 'pass' => $3,
			    'enabled' => !$1, 'line' => $lnum });
		}
	$lnum++;
	}
close(USERS);
if ($config{'sort_conf'}) {
	return sort { $a->{'user'} cmp $b->{'user'} } @rv;
	}
else {
	return @rv;
	}
}

# get_squid_user(&config)
# Returns the effective user and group (if any)
sub get_squid_user
{
if ($squid_version < 2) {
	local $ceu = &find_config("cache_effective_user", $_[0]);
	if ($ceu) { return ($ceu->{'values'}->[0], $ceu->{'values'}->[1]); }
	return (undef, undef);
	}
else {
	local $ceu = &find_config("cache_effective_user", $_[0]);
	local $ceg = &find_config("cache_effective_group", $_[0]);
	return ($ceu->{'values'}->[0], $ceg ? $ceg->{'values'}->[0]
					    : $ceu->{'values'}->[1]);
	}
}

# chown_files(user, group, config)
# Change ownership of all squid log and cache directories
sub chown_files
{
local(@list, $pidstruct, $pidfile);
@list = ( $config{'log_dir'} );

# add pidfile
if ($str = &find_config("pid_filename", $_[2])) {
	$pidfile = $str->{'values'}->[0];
	}
else { $pidfile = $config{'pid_file'}; }
push(@list, $pidfile);

# add other log directories
foreach $d ("cache_access_log", "access_log", "cache_log",
	    "cache_store_log", "cache_swap_log") {
	if (($str = &find_config($d, $_[2])) &&
	    $str->{'values'}->[0] =~ /^(\S+)\/[^\/]+$/) {
		push(@list, $1);
		}
	}

# add cache directories
if (@str = &find_config("cache_dir", $_[2])) {
	foreach $str (@str) {
		push(@list, $str->{'values'}->[0]);
		}
	}
else { push(@list, $config{'cache_dir'}); }
system("chown -Rf $_[0]:$_[1] ".join(" ",@list)." >/dev/null 2>&1");
}

# can_access(file)
sub can_access
{
local @f = grep { $_ ne '' } split(/\//, $_[0]);
return 1 if ($access{'root'} eq '/');
local @a = grep { $_ ne '' } split(/\//, $access{'root'});
local $i;
for($i=0; $i<@a; $i++) {
	return 0 if ($a[$i] ne $f[$i]);
	}
return 1;
}

# get_auth_file(&config)
sub get_auth_file
{
if ($squid_version >= 2.5) {
	local @auth = &find_config("auth_param", $_[0]);
	local ($program) = grep { $_->{'values'}->[0] eq 'basic' &&
				  $_->{'values'}->[1] eq 'program' } @auth;
	return $program ? $program->{'values'}->[3] : undef;
	}
else {
	local $authprog = &find_value("authenticate_program", $_[0]);
	return $authprog =~ /(\S+)\s+(\/\S+)$/ ? $2 : undef;
	}
}

# parse_external(&external_acl_type)
sub parse_external
{
local @v = @{$_[0]->{'values'}};
local $rv = { 'name' => $v[0] };
for($i=1; $v[$i] =~ /^(\S+)=(\S+)$/; $i++) {
	$rv->{'opts'}->{$1} = $2;
	}
if ($v[$i] =~ /^\"(.*)\"$/) {
	$rv->{'format'} = $1;
	}
else {
	$rv->{'format'} = $v[$i];
	}
$i++;
$rv->{'program'} = $v[$i++];
$rv->{'args'} = [ @v[$i .. $#v] ];
return $rv;
}

# check_cache(&config, &caches)
# Returns 1 if the cache directory looks OK, 0 if not. Also fills in the 
# caches list
sub check_cache
{
local (@cachestruct, @caches, $c);
if (@cachestruct = &find_config("cache_dir", $_[0])) {
	if ($squid_version >= 2.3) {
		@caches = map { $_->{'values'}->[1] } @cachestruct;
		}
	else {
		@caches = map { $_->{'values'}->[0] } @cachestruct;
		}
	}
else {
	@caches = ( $config{'cache_dir'} );
	}
@{$_[1]} = @caches;
foreach $c (@caches) {
	return 0 if (!-d $c || !-d "$c/00");
	}
return 1;
}

# get_squid_port()
# Returns the port Squid is listening on
sub get_squid_port
{
local $conf = &get_config();
local $port;
if ($squid_version >= 2.3) {
	local ($p, $v);
	LOOP: foreach $p (&find_config("http_port", $conf)) {
		foreach $v (@{$p->{'values'}}) {
			if ($v =~ /^(\d+)$/) {
				$port = $1;
				}
			elsif ($v =~ /^(\S+):(\d+)$/) {
				$port = $2;
				}
			last LOOP if ($port);
			}
		}
	}
else {
	$port = &find_value("http_port", $conf);
	}
return defined($port) ? $port : 3128;
}

# apply_configuration()
# Activate the current Squid configuration
sub apply_configuration
{
if ($config{'squid_restart'}) {
	local $out = &backquote_logged("$config{'squid_restart'} 2>&1");
	return "<pre>$out</pre>" if ($?);
	}
else {
	$out = &backquote_logged("$config{'squid_path'} -f $config{'squid_conf'} -k reconfigure 2>&1");
	return "<pre>$out</pre>" if ($? && $out !~ /warning/i);
	}
return undef;
}

# list_cachemgr_actions()
# Returns a list of actions for use in the cachemgr_passwd directive
sub list_cachemgr_actions
{
return ("5min" ,"60min" ,"asndb" ,"authenticator" ,"cbdata" ,"client_list" ,"comm_incoming" ,"config" ,"counters" ,"delay" ,"digest_stats" ,"dns" ,"events" ,"filedescriptors" ,"fqdncache" ,"histograms" ,"http_headers" ,"info" ,"io" ,"ipcache" ,"mem" ,"menu" ,"netdb" ,"non_peers" ,"objects" ,"offline_toggle" ,"pconn" ,"peer_select" ,"redirector" ,"refresh" ,"server_list" ,"shutdown" ,"store_digest" ,"storedir" ,"utilization" ,"via_headers" ,"vm_objects");
}

1;

