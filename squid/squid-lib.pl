# squid-lib.pl
# Functions for configuring squid.conf

BEGIN { push(@INC, ".."); };
use strict;
use warnings;
use WebminCore;
&init_config();
do 'parser-lib.pl';
our ($module_root_directory, %text, %config, %in, $module_config_directory);

our %access = &get_module_acl();
our $auth_program = "$module_config_directory/squid-auth.pl";
our $auth_database = "$module_config_directory/users";
our @caseless_acl_types = ( "url_regex", "urlpath_regex", "proxy_auth_regex",
			    "srcdom_regex", "dstdom_regex", "ident_regex" );

# Get the squid version
our $squid_version = &read_file_contents("$module_config_directory/version") || 0;
$squid_version =~ s/\r|\n//g;

# choice_input(text, name, &config, default, [display, option]+)
# Display a number of radio buttons for selecting some option
sub choice_input
{
my ($label, $name, $conf, $def, @opts) = @_;
my $v = &find_config($_[1], $_[2]);
my $vv = $v ? $v->{'value'} : $_[3];
my @opts2;
for(my $i=0; $i<@opts; $i+=2) {
	push(@opts2, [ $opts[$i+1], $opts[$i] ]);
	}
return &ui_table_row($label,
	&ui_radio($name, $vv, \@opts2));
}

# select_input(text, name, &config, default, [display, option]+)
# Like choice_input, but uses a drop-down select field
sub select_input
{
my ($label, $name, $conf, $def, @opts) = @_;
my $v = &find_config($_[1], $_[2]);
my $vv = $v ? $v->{'value'} : $_[3];
my @opts2;
for(my $i=0; $i<@opts; $i+=2) {
	push(@opts2, [ $opts[$i+1], $opts[$1] ]);
	}
return &ui_table_row($label,
	&ui_select($name, $vv, \@opts2));
}

# save_choice(name, default, &config)
# Save a selection from choice_input()
sub save_choice
{
my ($name, $def, $conf) = @_;
if ($in{$name} eq $def) {
	&save_directive($conf, $name, [ ]);
	}
else {
	&save_directive($conf, $name, [{ 'name' => $name,
					 'values' => [ $in{$name} ] }]);
	}
}

# list_input(text, name, &config, type, [default])
# Display a list of values
sub list_input
{
my ($label, $name, $conf, $type, $def) = @_;
my @av;
foreach my $v (&find_config($name, $conf)) {
	push(@av, @{$v->{'values'}});
	}
if ($type == 0) {
	# text area
	my $opt = "";
	if ($def) {
		$opt = &ui_radio($name."_def", @av ? 0 : 1,
			 [ [ 1, $def ], [ 0, $text{'ec_listed'} ] ])."<br>\n";
		}
	return &ui_table_row($label,
		$opt.&ui_textarea($name, join("\n", @av), 3, 20));
	}
else {
	# one long text field
	my $field = $def ? &ui_opt_textbox($name, join(' ',@av), 50, $def)
			 : &ui_textbox($name, join(' ',@av), 50);
	return &ui_table_row($label, $field, 3);
	}
}

# save_list(name, &checkfunc, &config)
sub save_list
{
my ($name, $func, $conf) = @_;
my @vals;
if (!$in{$name."_def"}) {
	@vals = split(/\s+/, $in{$_[0]});
	if ($func) {
		foreach my $v (@vals) {
			&check_error($func, $v);
			}
		}
	}
if (@vals) {
	&save_directive($conf, $name,
			[{ 'name' => $name, values => \@vals }]);
	}
else {
	&save_directive($conf, $name, [ ]);
	}
}

# check_error(&function, value)
sub check_error
{
my ($func, $value) = @_;
return if (!$func);
my $err = &$func($value);
if ($err) { &error($err); }
}

# address_input(text, name, &config, type)
# Display a text area for entering 0 or more addresses
sub address_input
{
my ($label, $name, $conf, $type) = @_;
my @av;
foreach my $v (&find_config($name, $conf)) {
	push(@av, @{$v->{'values'}});
	}
if ($type == 0) {
	# text area
	return &ui_table_row($label,
		&ui_textarea($name, join("\n", @av), 3, 30));
	}
else {
	# one long text field
	return &ui_table_row($label,
		&ui_textbox($name, join(' ',@av), 50), 3);
	}
}

# save_address(name, config)
sub save_address
{
my ($name, $conf) = @_;
my @vals;
foreach my $addr (split(/\s+/, $in{$name})) {
	&check_ipaddress($addr) || &error(&text('lib_emsg1', $addr));
	push(@vals, $addr);
	}
if (@vals) {
	&save_directive($conf, $name,
			[{ 'name' => $name, values => \@vals }]);
	}
else {
	&save_directive($conf, $name, [ ]);
	}
}

# opt_input(text, name, &config, default, size, units)
# Display an optional field for entering something
sub opt_input
{
my ($label, $name, $conf, $def, $size, $units) = @_;
my $v = &find_config($_[1], $_[2]);
return &ui_table_row($label,
	&ui_opt_textbox($name, $v ? $v->{'value'} : undef, $size,
			$def)." ".$units,
	$size > 30 ? 3 : 1);
}

# save_opt(name, &function, &config)
# Save an input from opt_input()
sub save_opt
{
my ($name, $func, $conf) = @_;
if ($in{$name."_def"}) {
	&save_directive($conf, $name, [ ]);
	}
else {
	&check_error($func, $in{$name});
	my $dir = { 'name' => $name, 'values' => [ $in{$name} ] };
	&save_directive($conf, $name, [ $dir ]);
	}
}

# opt_time_input(text, name, &config, default, size)
sub opt_time_input
{
my ($label, $name, $conf, $def, $size) = @_;
my $v = &find_config($name, $conf);
return &ui_table_row($label,
	&ui_radio($name."_def", $v ? 0 : 1,
	  [ [ 1, $def ],
	    [ 0, &time_fields($name, $size, $v ? @{$v->{'values'}} : ( )) ] ]));
}

# time_fields(name, size, time, units)
sub time_fields
{
my ($name, $size, $time, $units) = @_;
my @ts = ( [ "second" =>	$text{"lib_seconds"} ],
	   [ "minute" =>	$text{"lib_minutes"} ],
	   [ "hour" =>		$text{"lib_hours"} ],
	   [ "day" =>		$text{"lib_days"} ],
	   [ "week" =>		$text{"lib_weeks"} ],
	   [ "fortnight" => 	$text{"lib_fortnights"} ],
	   [ "month" =>		$text{"lib_months"} ],
	   [ "year" =>		$text{"lib_years"} ],
	   [ "decade" =>	$text{"lib_decades"} ] );
$units =~ s/s$//;
return &ui_textbox($name, $time, $size)." ".
       &ui_select($name."_u", $units, \@ts);
}

# save_opt_time(name, &config)
sub save_opt_time
{
my ($name, $conf) = @_;
my %ts = ( "second" =>     $text{"lib_seconds"},
           "minute" =>     $text{"lib_minutes"},
           "hour" =>       $text{"lib_hours"},
           "day" =>        $text{"lib_days"},
           "week" =>       $text{"lib_weeks"},
           "fortnight" =>  $text{"lib_fortnights"},
           "month" =>      $text{"lib_months"},
           "year" =>       $text{"lib_years"},
           "decade" =>     $text{"lib_decades"} );

if ($in{$name."_def"}) {
	&save_directive($conf, $name, [ ]);
	}
elsif ($in{$name} !~ /^[0-9\.]+$/) {
	&error(&text('lib_emsg2', $in{$name}, $ts{$in{$name."_u"}}) );
	}
else {
	my $dir = { 'name' => $name,
		    'values' => [ $in{$name}, $in{$name."_u"} ] };
	&save_directive($conf, $name, [ $dir ]);
	}
}

# opt_bytes_input(text, name, &config, default, size)
sub opt_bytes_input
{
my ($label, $name, $conf, $def, $size) = @_;
my @ss = ( [ "KB", $text{'lib_kb'} ],
	   [ "MB", $text{'lib_mb'} ],
	   [ "GB", $text{'lib_gb'} ] );
my $v = &find_config($name, $conf);
my $input = &ui_textbox($name, $v ? $v->{'values'}->[0] : "", $size)." ".
	    &ui_select($name."_u", $v ? $v->{'values'}->[1] : "", \@ss);
return &ui_table_row($label,
	&ui_radio($name."_def", $v ? 0 : 1,
		  [ [ 1, $def ], [ 0, $input ] ]));
}

# save_opt_bytes(name, &config)
sub save_opt_bytes
{
my ($name, $conf) = @_;
my %ss = ( "KB" => $text{'lib_kb'},
           "MB" => $text{'lib_mb'},
           "GB" => $text{'lib_gb'} );

if ($in{$name."_def"}) {
	&save_directive($conf, $name, [ ]);
	}
elsif ($in{$name} !~ /^[0-9\.]+$/) {
	&error(&text('lib_emsg3', $in{$name}, $ss{$in{$name."_u"}}) );
	}
else {
	my $dir = { 'name' => $name,
		    'values' => [ $in{$name}, $in{$name."_u"} ] };
	&save_directive($conf, $name, [ $dir ]);
	}
}

our %acl_types = ("src", $text{'lib_aclca'},
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
my $args = "redir=".&urlize(&this_url());
if (&is_squid_running()) {
	return ($access{'restart'} ?
		"<a href=\"restart.cgi?$args\">$text{'lib_buttac'}</a><br>\n" :
	        "").
	       ($access{'start'} ?
		"<a href=\"stop.cgi?$args\">$text{'lib_buttss'}</a>\n" : "");
	}
else {
	return $access{'start'} ?
		"<a href=\"start.cgi?$args\">$text{'lib_buttss1'}</a>\n" : "";
	}
}

# is_squid_running()
# Returns the process ID if squid is running
sub is_squid_running
{
my $conf = &get_config();

# Find all possible PID files
my @pidfiles;
my $pidstruct = &find_config("pid_filename", $conf);
push(@pidfiles, $pidstruct->{'values'}->[0]) if ($pidstruct);
my $def_pidstruct = &find_config("pid_filename", $conf);
push(@pidfiles, $def_pidstruct->{'values'}->[0]) if ($def_pidstruct);
push(@pidfiles, $config{'pid_file'}) if ($config{'pid_file'});
@pidfiles = grep { $_ ne "none" } @pidfiles;

# Try check one
foreach my $pidfile (@pidfiles) {
	my $pid = &check_pid_file($pidfile);
	return $pid if ($pid);
	}

if (!@pidfiles) {
	# Fall back to checking for Squid process
	my ($pid) = &find_byname("squid");
	return $pid;
	}

return 0;
}

# this_url()
# Returns the URL in the apache directory of the current script
sub this_url
{
my $url = $ENV{'SCRIPT_NAME'};
if (defined($ENV{'QUERY_STRING'})) {
	$url .= "?$ENV{'QUERY_STRING'}";
	}
return $url;
}

# list_auth_users(file)
sub list_auth_users
{
my ($file) = @_;
my @rv;
my $lnum = 0;
my $fh = "USERS";
&open_readfile($fh, $file);
while(<$fh>) {
	if (/^(#*)([^:]+):(\S+)/) {
		push(@rv, { 'user' => $2, 'pass' => $3,
			    'enabled' => !$1, 'line' => $lnum });
		}
	$lnum++;
	}
close($fh);
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
my ($conf) = @_;
if ($squid_version < 2) {
	my $ceu = &find_config("cache_effective_user", $conf);
	if ($ceu) {
		return ($ceu->{'values'}->[0], $ceu->{'values'}->[1]);
		}
	return (undef, undef);
	}
else {
	my $ceu = &find_config("cache_effective_user", $_[0]);
	my $ceg = &find_config("cache_effective_group", $_[0]);
	return ($ceu->{'values'}->[0], $ceg ? $ceg->{'values'}->[0]
					    : $ceu->{'values'}->[1]);
	}
}

# chown_files(user, group, config)
# Change ownership of all squid log and cache directories
sub chown_files
{
my ($user, $group, $conf) = @_;
my @list = ( $config{'log_dir'} );

# add pidfile
my $pidfile;
if (my $str = &find_config("pid_filename", $conf)) {
	$pidfile = $str->{'values'}->[0];
	}
else {
	$pidfile = $config{'pid_file'};
	}
push(@list, $pidfile);

# add other log directories
foreach my $d ("cache_access_log", "access_log", "cache_log",
	       "cache_store_log", "cache_swap_log") {
	my $str;
	if (($str = &find_config($d, $conf)) &&
	    $str->{'values'}->[0] =~ /^(\S+)\/[^\/]+$/) {
		push(@list, $1);
		}
	}

# add cache directories
if (my @str = &find_config("cache_dir", $conf)) {
	foreach my $str (@str) {
		if ($squid_version >= 2.3) {
			push(@list, $str->{'values'}->[1]);
			}
		else {
			push(@list, $str->{'values'}->[0]);
			}
		}
	}
else {
	push(@list, $config{'cache_dir'});
	}
system("chown -Rf $user:$group ".join(" ",@list)." >/dev/null 2>&1");
}

# can_access(file)
sub can_access
{
my ($file) = @_;
my @f = grep { $_ ne '' } split(/\//, $file);
return 1 if ($access{'root'} eq '/');
my @a = grep { $_ ne '' } split(/\//, $access{'root'});
for(my $i=0; $i<@a; $i++) {
	return 0 if ($a[$i] ne $f[$i]);
	}
return 1;
}

# get_auth_file(&config)
sub get_auth_file
{
if ($squid_version >= 2.5) {
	my @auth = &find_config("auth_param", $_[0]);
	my ($program) = grep { $_->{'values'}->[0] eq 'basic' &&
			       $_->{'values'}->[1] eq 'program' } @auth;
	return $program ? $program->{'values'}->[3] : undef;
	}
else {
	my $authprog = &find_value("authenticate_program", $_[0]);
	return $authprog && $authprog =~ /(\S+)\s+(\/\S+)$/ ? $2 : undef;
	}
}

# parse_external(&external_acl_type)
sub parse_external
{
my ($acltype) = @_;
my @v = @{$acltype->{'values'}};
my $rv = { 'name' => $v[0] };
my $i;
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

# check_cache(&config, &caches, [include-disabled])
# Returns 1 if the cache directory looks OK, 0 if not. Also fills in the 
# caches list
sub check_cache
{
my ($conf, $cachesrv, $distoo) = @_;
my (@caches, $coss);
my @cachestruct = &find_config("cache_dir", $conf);
my $disabled = 0;
if ($distoo && !@cachestruct) {
	# Check disabled cache directives, but exclude ones that don't exist
	@cachestruct = &find_config("cache_dir", $conf, 1);
	@cachestruct = grep { -e $_->{'values'}->[1] } @cachestruct;
	$disabled = 1 if (@cachestruct);
	}
if (@cachestruct) {
	if ($squid_version >= 2.3) {
		@caches = map { $_->{'values'}->[1] } @cachestruct;
		}
	else {
		@caches = map { $_->{'values'}->[0] } @cachestruct;
		}
	@caches = grep { /^\// } @caches;
	($coss) = grep { $_->{'values'}->[0] eq "coss" } @cachestruct;
	}
if (!@caches) {
	@caches = ( $config{'cache_dir'} );
	}
@$cachesrv = @caches;
if ($coss) {
	# Allow COSS files too
	foreach my $c (@caches) {
		return 0 if (!-f $c && (!-d $c || (!-d "$c/00" && !-r "$c/rock")));
		}
	}
else {
	# Check for dirs only
	foreach my $c (@caches) {
		return 0 if (!-d $c || (!-d "$c/00" && !-r "$c/rock"));
		}
	}
return 1;
}

# get_squid_port()
# Returns the port Squid is listening on
sub get_squid_port
{
my $conf = &get_config();
my $port;
if ($squid_version >= 2.3) {
	LOOP: foreach my $p (&find_config("http_port", $conf)) {
		foreach my $v (@{$p->{'values'}}) {
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
	my $out = &backquote_logged("$config{'squid_restart'} 2>&1");
	return "<pre>".&html_escape($out)."</pre>" if ($?);
	}
else {
	my $out = &backquote_logged("$config{'squid_path'} -f $config{'squid_conf'} -k reconfigure 2>&1");
	return "<pre>".&html_escape($out)."</pre>"
		if ($? && $out !~ /warning/i);
	}
return undef;
}

# list_cachemgr_actions()
# Returns a list of actions for use in the cachemgr_passwd directive
sub list_cachemgr_actions
{
return ("5min" ,"60min" ,"asndb" ,"authenticator" ,"cbdata" ,"client_list" ,"comm_incoming" ,"config" ,"counters" ,"delay" ,"digest_stats" ,"dns" ,"events" ,"filedescriptors" ,"fqdncache" ,"histograms" ,"http_headers" ,"info" ,"io" ,"ipcache" ,"mem" ,"menu" ,"netdb" ,"non_peers" ,"objects" ,"offline_toggle" ,"pconn" ,"peer_select" ,"redirector" ,"refresh" ,"server_list" ,"shutdown" ,"store_digest" ,"storedir" ,"utilization" ,"via_headers" ,"vm_objects");
}

# get_all_config_files()
# Returns all files from the Squid config
sub get_all_config_files
{
# Add main config file
my @rv = ( $config{'squid_conf'} );

# Add users file
my $conf = &get_config();
my $file = &get_auth_file($conf);
push(@rv, $file) if ($file);

# Add files from ACLs
my @acl = &find_config("acl", $conf);
foreach my $a (@acl) {
	if ($a->{'values'}->[2] =~ /^"(.*)"$/ || $a->{'values'}->[3] =~ /^"(.*)"$/) {
		push(@rv, $1);
		}
	}

return &unique(@rv);
}

1;

