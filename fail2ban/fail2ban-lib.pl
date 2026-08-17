# Functions for configuring the fail2ban log analyser

BEGIN { push(@INC, ".."); };
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
use WebminCore;
&init_config();
our ($module_root_directory, %text, %config, %gconfig, $base_remote_user);
our %access = &get_module_acl();
our @all_files_for_lock;

# check_fail2ban()
# Returns undef if installed, or an appropriate error message if missing
sub check_fail2ban
{
-d $config{'config_dir'} || return &text('check_edir',
					 "<tt>$config{'config_dir'}</tt>");
-r "$config{'config_dir'}/fail2ban.conf" ||
	return &text('check_econf', "<tt>$config{'config_dir'}</tt>",
		     "<tt>fail2ban.conf</tt>");
&has_command($config{'client_cmd'}) ||
	return &text('check_eclient', "<tt>$config{'client_cmd'}</tt>");
&has_command($config{'server_cmd'}) ||
	return &text('check_eserver', "<tt>$config{'server_cmd'}</tt>");
return undef;
}

sub is_fail2ban_running
{
my ($pid) = &find_byname($config{'server_cmd'});
if (!$pid) {
	($pid) = &find_byname("fail2ban-server");
	}
return $pid;
}

# list_filters()
# Returns a list of all defined filter files, each of which contains multiple
# sections like [Definition]
sub list_filters
{
my $dir = "$config{'config_dir'}/filter.d";
my @rv;
foreach my $f (glob("$dir/*.conf")) {
	my @conf = &parse_config_file($f);
	my @lconf = &parse_config_file(&make_local_file($f));
	&merge_local_files(\@conf, \@lconf);
	if (@conf) {
		push(@rv, \@conf);
		}
	}
return @rv;
}

# list_actions()
# Returns a list of all defined action files, each of which contains multiple
# sections like [Definition] and [Init]
sub list_actions
{
my $dir = "$config{'config_dir'}/action.d";
my @rv;
foreach my $f (glob("$dir/*.conf")) {
	my @conf = &parse_config_file($f);
	my @lconf = &parse_config_file(&make_local_file($f));
	&merge_local_files(\@conf, \@lconf);
	if (@conf) {
		push(@rv, \@conf);
		}
	}
return @rv;
}

# list_jails()
# Returns a list of all sections from the jails file
sub list_jails
{
# Read the main config file
my @rv;
my $jfile = "$config{'config_dir'}/jail.conf";
if (-r $jfile) {
	push(@rv, &parse_config_file($jfile));
	}

my @lrv;
# Read separate config files under jail.d
my $jdir = "$config{'config_dir'}/jail.d";
if (-d $jdir) {
	foreach my $f (glob("$jdir/*.conf")) {
		push(@lrv, &parse_config_file($f));
		}
	}

# Read the main local file, and separate files under jail.d
my $jlfile = &make_local_file($jfile);
if (-r $jlfile) {
	push(@lrv, &parse_config_file($jlfile));
	}
if (-d $jdir) {
	foreach my $f (glob("$jdir/*.local")) {
		push(@lrv, &parse_config_file($f));
		}
	}

# Use local file entries to override the global config
&merge_local_files(\@rv, \@lrv);

return @rv;
}

# merge_local_files(&rv, &locals)
# Merges .local file entries in with .conf files
sub merge_local_files
{
my ($rv, $lrv) = @_;
foreach my $l (@$lrv) {
	my ($r) = grep { $_->{'name'} eq $l->{'name'} } @$rv;
	if ($r) {
		# Section exists in the global config, so put the local
		# directives first
		my $m = { %$l };
		$m->{'local'} = 1;
		$m->{'origfile'} = $r->{'file'};
		push(@{$m->{'members'}}, @{$r->{'members'}});
		$rv->[&indexof($r, @$rv)] = $m;
		}
	else {
		# Section does not exist, so just add it
		push(@$rv, $l);
		}
	}
}

# make_local_file(path)
sub make_local_file
{
my ($f) = @_;
$f =~ s/\.conf$/\.local/g;
return $f;
}

# get_config()
# Returns the global config as an array ref of directives
sub get_config
{
my $file = "$config{'config_dir'}/fail2ban.conf";
my @conf = &parse_config_file($file);
my @lconf = &parse_config_file(&make_local_file($file));
&merge_local_files(\@conf, \@lconf);
return \@conf;
}

# parse_config_file(file)
# Parses one file into a list of [] sections, each with multiple directives
sub parse_config_file
{
my ($file) = @_;
my $lref = &read_file_lines($file, 1);
my $lnum = 0;
my $fh = "CONF";
my $sect;
my @rv;
&open_readfile($fh, $file) || return ( );
while(<$fh>) {
	s/\r|\n//g;
	s/^\s*#.*$//;
	s/^\s;.*$//;
	if (/^\[([^\]]+)\]/) {
		# Start of a section
		$sect = { 'name' => $1,
			  'line' => $lnum,
		 	  'eline' => $lnum,
			  'file' => $file,
			  'members' => [] };
		push(@rv, $sect);
		}
	elsif (/^(\S+)\s*=\s*(.*)/ && $sect) {
		# A directive in a section
		my $dir = { 'name' => $1,
			    'value' => $2,
			    'line' => $lnum,
                            'eline' => $lnum,
                            'file' => $file,
			  };
		push(@{$sect->{'members'}}, $dir);
		$sect->{'eline'} = $lnum;
		&split_directive_values($dir);
		}
	elsif (/^\s+(\S.*)/ && $sect && @{$sect->{'members'}}) {
		# Continuation of a directive
		my $dir = $sect->{'members'}->[@{$sect->{'members'}} - 1];
		$dir->{'value'} .= "\n".$1;
		$dir->{'eline'} = $lnum;
		$sect->{'eline'} = $lnum;
		&split_directive_values($dir);
		}
	$lnum++;
	}
close($fh);
return @rv;
}

# split_directive_values(&dir)
# Populate the 'values' field by splitting up the 'value' field
sub split_directive_values
{
my ($dir) = @_;
my @w;
my $v = $dir->{'value'};
$v =~ s/\n/ /g;
while($v =~ /\S/) {
	if ($v =~ /^\s*([^\s\[]+\[[^\]]*\])\s*(.*)/) {
		push(@w, $1);
		$v = $2;
		}
	elsif ($v =~ /^\s*(\S+)\s*(.*)/) {
		push(@w, $1);
		$v = $2;
		}
	}
$dir->{'words'} = \@w;
}

# parse_action_definition(string)
# Splits an action definition into a name and list of option triples,
# each containing a name, parsed value and raw text chunk
sub parse_action_definition
{
my ($str) = @_;
return (undef, []) if (!defined($str));
if ($str =~ /^(\S.*\S)\[(.*)\]$/) {
	return ($1, [ &parse_action_options($2) ]);
	}
return ($str, []);
}

# parse_action_options(string)
# Parses action options, handling quoted values and comma/space separators
sub parse_action_options
{
my ($str) = @_;
my @rv;
my $len = length($str);
my $i = 0;
while ($i < $len) {
	while ($i < $len) {
		my $ch = substr($str, $i, 1);
		last if ($ch !~ /[\s,]/);
		$i++;
		}
	last if ($i >= $len);
	my $start = $i;

	my $name = "";
	while ($i < $len) {
		my $ch = substr($str, $i, 1);
		last if ($ch eq "=" || $ch =~ /[\s,]/);
		$name .= $ch;
		$i++;
		}
	last if (!length($name));

	while ($i < $len && substr($str, $i, 1) =~ /\s/) {
		$i++;
		}

	# Support option names without values, although most action
	# parameters are expected to be name=value pairs.
	if ($i >= $len || substr($str, $i, 1) ne "=") {
		while ($i < $len && substr($str, $i, 1) =~ /\s/) {
			$i++;
			}
		$i++ if ($i < $len && substr($str, $i, 1) eq ",");
		push(@rv, [ $name, undef, substr($str, $start, $i - $start) ]);
		next;
		}

	$i++;
	while ($i < $len && substr($str, $i, 1) =~ /\s/) {
		$i++;
		}

	my ($value, $ni) = &parse_action_option_value($str, $i);
	push(@rv, [ $name, $value, substr($str, $start, $ni - $start) ]);
	$i = $ni;
	}
return @rv;
}

# parse_action_option_value(string, index)
# Returns an option value and the next parse position
sub parse_action_option_value
{
my ($str, $i) = @_;
my $len = length($str);
my $value = "";
if ($i < $len) {
	my $quote = substr($str, $i, 1);
	if ($quote eq "'" || $quote eq "\"") {
		$i++;
		while ($i < $len) {
			my $ch = substr($str, $i, 1);
			if ($ch eq "\\") {
				if ($i+1 < $len) {
					my $next = substr($str, $i+1, 1);
					if ($next eq $quote || $next eq "\\") {
						$value .= $next;
						$i += 2;
						next;
						}
					}
				$value .= $ch;
				$i++;
				next;
				}
			if ($ch eq $quote) {
				$i++;
				last;
				}
			$value .= $ch;
			$i++;
			}
		}
	else {
		while ($i < $len) {
			my $ch = substr($str, $i, 1);
			last if ($ch eq "," || $ch =~ /\s/);
			$value .= $ch;
			$i++;
			}
		}
	}
while ($i < $len && substr($str, $i, 1) =~ /\s/) {
	$i++;
	}
$i++ if ($i < $len && substr($str, $i, 1) eq ",");
return ($value, $i);
}

# create_section(file, &section)
# Add a new section to a file
sub create_section
{
my ($file, $sect) = @_;
my $lref = &read_file_lines($file);
$sect->{'file'} = $file;
$sect->{'line'} = scalar(@$lref);
push(@$lref, &section_lines($sect));
$sect->{'eline'} = scalar(@$lref);
&flush_file_lines($file);
}

# modify_section(file, &section)
# Update the first line (only) for some section
sub modify_section
{
my ($file, $sect) = @_;
my $lref = &read_file_lines($file);
my @lines = &section_lines($sect);
$lref->[$sect->{'line'}] = $lines[0];
&flush_file_lines($file);
}

# delete_section(file, &section, [keep-file])
# Remove a section and all directives from a file
sub delete_section
{
my ($file, $sect, $keepfile) = @_;
my $lref = &read_file_lines($file);
splice(@$lref, $sect->{'line'}, $sect->{'eline'} - $sect->{'line'} + 1);
my $empty = 1;
foreach my $l (@$lref) {
	my $ll = $l;
	$ll =~ s/^\s*#.*//;
	$empty = 0 if ($ll =~ /\S/);
	}
if ($empty && !$keepfile) {
	# File is now empty, so delete it
	&unflush_file_lines($file);
	&unlink_file($file);
	}
else {
	# Save the file
	&flush_file_lines($file);
	}
}

# section_lines(&section)
# Returns all the lines of text for some section plus directives
sub section_lines
{
my ($sect) = @_;
my @rv;
push(@rv, "[".$sect->{'name'}."]");
foreach my $m (@{$sect->{'members'}}) {
	push(@rv, &directive_lines($m));
	}
return @rv;
}

# directive_lines(&directive)
# Returns all lines of text for some directive
sub directive_lines
{
my ($dir) = @_;
my @rv;
my @v = ref($dir->{'value'}) eq 'ARRAY' ? @{$dir->{'value'}}
					: split(/\n/, $dir->{'value'});
push(@rv, $dir->{'name'}." = ".shift(@v));
push(@rv, map { "        ".$_ } @v);	# Continuation
return @rv;
}

# save_directive(name, value|&values|&directive, &section)
# Updates one directive in a section
sub save_directive
{
my ($name, $v, $sect) = @_;
my $dir;
if (ref($v) eq 'HASH') {
	$dir = $v;
	}
elsif (ref($v) eq 'ARRAY') {
	$dir = { 'name' => $name,
		 'value' => $v };
	}
elsif (defined($v)) {
	$dir = { 'name' => $name,
		 'value' => $v };
	}
else {
	$dir = undef;
	}
my $old = &find($name, $sect);
my $oldlen = $old ? $old->{'eline'} - $old->{'line'} + 1 : undef;
my $oldidx = $old ? &indexof($old, @{$sect->{'members'}}) : -1;
my $file = $old ? $old->{'file'} : $sect->{'file'};
my $lref = &read_file_lines($file);
my @dirlines = defined($dir) ? &directive_lines($dir) : ();
if ($old && defined($dir) && $old->{'value'} ne $dir->{'value'}) {
	# Update existing
	if ($sect->{'local'} && $old->{'file'} ne $sect->{'file'}) {
		# Section is in a local file, so to override we need to
		# add a new line in the local file
		&unflush_file_lines($file);
		$file = $sect->{'file'};
		$lref = &read_file_lines($file);
		splice(@$lref, $sect->{'eline'}+1, 0, @dirlines);
		$dir->{'line'} = $sect->{'eline'}+1;
		$dir->{'file'} = $sect->{'file'};
		$sect->{'eline'} += scalar(@dirlines);
		$dir->{'eline'} = $sect->{'eline'};
		}
	else {
		# Just update the existing line
		splice(@$lref, $old->{'line'}, $oldlen, @dirlines);
		$dir->{'line'} = $old->{'line'};
		$dir->{'eline'} = $dir->{'line'} + scalar(@dirlines) - 1;
		$dir->{'file'} = $sect->{'file'};
		if ($oldidx >= 0) {
			$sect->{'members'}->[$oldidx] = $dir;
			}
		my $offset = scalar(@dirlines) - $oldlen;
		foreach my $m (@{$sect->{'members'}}) {
			next if ($m eq $dir || $m eq $old);
			if ($m->{'line'} > $old->{'line'}) {
				$m->{'line'} += $offset;
				$m->{'eline'} += $offset;
				}
			}
		}
	}
elsif (!$old && defined($dir)) {
	# Add new
	if (!$sect->{'local'} && $file =~ /^(.*)\.conf$/) {
		# New directives should go in a .local file. We can assume at
		# this point that it doesn't exist yet, or that there is no
		# section in it. So convert this section object to local.
		my $lfile = $1.".local";
		&unflush_file_lines($file);
		$file = $lfile;
		$lref = &read_file_lines($file);
		$sect->{'line'} = $sect->{'eline'} = scalar(@$lref);
		$sect->{'file'} = $file;
		splice(@$lref, $sect->{'eline'}, 0, "[$sect->{'name'}]");
		splice(@$lref, $sect->{'eline'}+1, 0, @dirlines);
		$dir->{'line'} = $sect->{'eline'}+1;
		$dir->{'file'} = $sect->{'file'};
		$sect->{'eline'} += scalar(@dirlines);
		$dir->{'eline'} = $sect->{'eline'};
		}
	else {
		# Just add to the file the section is in (which will be local)
		splice(@$lref, $sect->{'eline'}+1, 0, @dirlines);
		$dir->{'line'} = $sect->{'eline'}+1;
		$dir->{'file'} = $sect->{'file'};
		$sect->{'eline'} += scalar(@dirlines);
		$dir->{'eline'} = $sect->{'eline'};
		}
	}
elsif ($old && !defined($dir)) {
	# Remove existing
	splice(@$lref, $old->{'line'}, $oldlen);
	$sect->{'eline'} -= $oldlen;
	if ($oldidx >= 0) {
		splice(@{$sect->{'members'}}, $oldidx, 1);
		}
	foreach my $m (@{$sect->{'members'}}) {
		next if ($m eq $old);
		if ($m->{'line'} > $old->{'line'}) {
			$m->{'eline'} -= $oldlen;
			$m->{'line'} -= $oldlen;
			}
		}
	}
&flush_file_lines($file);
}

sub find_value
{
my ($name, $object) = @_;
my @rv = map { $_->{'value'} } &find($name, $object);
return wantarray ? @rv : $rv[0];
}

sub find
{
my ($name, $object) = @_;
my $members = ref($object) eq 'HASH' ? $object->{'members'} : $object;
my @rv = grep { lc($_->{'name'}) eq $name } @$members;
return wantarray ? @rv : $rv[0];
}

# filename_to_name(file)
# Given a filename like /etc/fail2ban/foo.d/bar.conf , return bar
sub filename_to_name
{
my ($file) = @_;
$file =~ s/^.*\///;
$file =~ s/\.[^\.]+$//;
return $file;
}

# find_jail_by_filter(&filter)
# returns the jail objects using a filter
sub find_jail_by_filter
{
my ($filter) = @_;
my $fname = &filename_to_name($filter->[0]->{'file'});
my @rv;
foreach my $jail (&list_jails()) {
	my $jfilter = &find_value("filter", $jail);
	if ($jfilter eq $fname) {
		push(@rv, $jail);
		}
	}
return @rv;
}

# find_jail_by_action(&action)
# returns the jail objects using an action
sub find_jail_by_action
{
my ($action) = @_;
my $aname = &filename_to_name($action->[0]->{'file'});
my @rv;
foreach my $jail (&list_jails()) {
	my $jaction = &find("action", $jail);
	next if (!$jaction);
	my @jactions = map { /^([^\[]+)/; $1 } @{$jaction->{'words'}};
	if (&indexof($aname, @jactions) >= 0) {
		push(@rv, $jail);
		}
	}
return @rv;
}

# start_fail2ban_server()
# Attempts to start the server process, returning undef on success or an error message
# on failure.
sub start_fail2ban_server
{
if ($config{'init_script'}) {
	&foreign_require("init");
	foreach my $init (split(/\s+/, $config{'init_script'})) {
		my ($ok, $out) = &init::start_action($init);
		return $out if (!$ok);
		}
	return undef;
	}
else {
	my $out = &backquote_logged("$config{'client_cmd'} -x start 2>&1 </dev/null");
	return $? ? $out : undef;
	}
}

# stop_fail2ban_server()
# Attempts to stop the server process, returning undef on success or an error message
# on failure.
sub stop_fail2ban_server
{
if ($config{'init_script'}) {
	&foreign_require("init");
	foreach my $init (split(/\s+/, $config{'init_script'})) {
		my ($ok, $out) = &init::stop_action($init);
		return $out if (!$ok);
		}
	return undef;
	}
else {
	my $out = &backquote_logged("$config{'client_cmd'} stop 2>&1 </dev/null");
	return $? ? $out : undef;
	}
}

# restart_fail2ban_server()
# Force the fail2ban server to re-read its config
sub restart_fail2ban_server
{
my ($force_restart) = @_;
my $out;
$out = &backquote_logged("$config{'client_cmd'} reload 2>&1 </dev/null")
	if (!$force_restart);
if ($? || $force_restart) {
	&stop_fail2ban_server();
	$out = &start_fail2ban_server();
}
return $? ? $out : undef;
}

# list_all_config_files()
# Returns a list of all Fail2Ban config files
sub list_all_config_files
{
my @rv;
push(@rv, "$config{'config_dir'}/fail2ban.local");
push(@rv, "$config{'config_dir'}/fail2ban.conf");
push(@rv, glob("$config{'config_dir'}/filter.d/*.conf"));
push(@rv, glob("$config{'config_dir'}/filter.d/*.local"));
push(@rv, glob("$config{'config_dir'}/action.d/*.conf"));
push(@rv, glob("$config{'config_dir'}/action.d/*.local"));
push(@rv, "$config{'config_dir'}/jail.conf");
push(@rv, "$config{'config_dir'}/jail.local");
push(@rv, glob("$config{'config_dir'}/jail.d/*.conf"));
push(@rv, glob("$config{'config_dir'}/jail.d/*.local"));
return grep { -r $_ || $_ =~ /fail2ban\.local$/ } @rv;
}

sub lock_all_config_files
{
@all_files_for_lock = &list_all_config_files();
foreach my $f (@all_files_for_lock) {
	&lock_file($f);
	}
}

sub unlock_all_config_files
{
foreach my $f (reverse(@all_files_for_lock)) {
	&unlock_file($f);
	}
@all_files_for_lock = ();
}

# get_fail2ban_version()
# Returns the version number, or undef if it cannot be found
sub get_fail2ban_version
{
my $out = &backquote_command("$config{'client_cmd'} -V 2>/dev/null </dev/null");
return !$? && $out =~ /v?([0-9\.]+)/ ? $1 : undef;
}

# supports_bantime_increment([version])
# Returns 1 if the installed Fail2Ban version supports incremental ban times
sub supports_bantime_increment
{
my ($version) = @_;
$version = &get_fail2ban_version() if (!defined($version));
return 0 if (!defined($version) || $version eq "");
return &compare_version_numbers($version, "0.11.1") >= 0;
}

# canonical_fail2ban_boolean(value)
# Converts the boolean spellings accepted by Fail2Ban to true or false
sub canonical_fail2ban_boolean
{
my ($value) = @_;
return "" if (!defined($value) || $value eq "");
return "true" if ($value =~ /^(1|on|true|yes)$/i);
return "false" if ($value =~ /^(0|off|false|no)$/i);
return $value;
}

# valid_fail2ban_duration(value, [allow-zero])
# Returns 1 for a safe subset of Fail2Ban duration expressions
sub valid_fail2ban_duration
{
my ($value, $allow_zero) = @_;
return 0 if (!defined($value) || $value eq "");
return 0 if ($value =~ /[\r\n]/);
my $number = qr/\d+(?:\.\d+)?/;
my $unit = qr/(?:s|sec(?:ond)?s?|m|min(?:ute)?s?|h|hour(?:s)?|d|day(?:s)?|w|week(?:s)?|mo|mon|month(?:s)?|y|year(?:s)?)/i;
return 0 if ($value !~ /^\s*(?:$number\s*$unit\s*)+$/ &&
		   $value !~ /^\s*$number\s*$/);
return 1 if ($allow_zero);
my @numbers = $value =~ /(\d+(?:\.\d+)?)/g;
return scalar(grep { $_ > 0 } @numbers) ? 1 : 0;
}

# valid_positive_fail2ban_duration(value)
# Returns 1 for a safe, positive Fail2Ban duration expression
sub valid_positive_fail2ban_duration
{
return &valid_fail2ban_duration($_[0], 0);
}

# valid_nonnegative_fail2ban_duration(value)
# Returns 1 for a safe Fail2Ban duration expression, including zero
sub valid_nonnegative_fail2ban_duration
{
return &valid_fail2ban_duration($_[0], 1);
}

# valid_bantime_factor(value)
# Returns 1 for a positive numeric incremental-ban growth factor
sub valid_bantime_factor
{
my ($value) = @_;
return defined($value) &&
	$value =~ /^(?:\d+(?:\.\d+)?|\.\d+)$/ && $value > 0;
}

# validate_bantime_increment_inputs(&input)
# Returns a language key for the first invalid incremental-ban option
sub validate_bantime_increment_inputs
{
my ($input) = @_;
foreach my $f ("bantime_increment", "bantime_overalljails") {
	my $value = $input->{$f};
	return "jail_e".$f if (defined($value) && $value ne "" &&
					$value !~ /^(true|false)$/);
	}
if (!$input->{'bantime_factor_def'} &&
    !&valid_bantime_factor($input->{'bantime_factor'})) {
	return "jail_ebantime_factor";
	}
if (!$input->{'bantime_maxtime_def'} &&
    !&valid_positive_fail2ban_duration($input->{'bantime_maxtime'})) {
	return "jail_ebantime_maxtime";
	}
if (!$input->{'bantime_rndtime_def'} &&
    !&valid_nonnegative_fail2ban_duration($input->{'bantime_rndtime'})) {
	return "jail_ebantime_rndtime";
	}
return undef;
}

# save_bantime_increment_options(&input, &jail)
# Saves incremental-ban options using the standard jail directive handling
sub save_bantime_increment_options
{
my ($input, $jail) = @_;
&save_directive("bantime.increment",
	$input->{'bantime_increment'} eq "" ? undef :
		$input->{'bantime_increment'}, $jail);
&save_directive("bantime.factor",
	$input->{'bantime_factor_def'} ? undef :
		$input->{'bantime_factor'}, $jail);
&save_directive("bantime.maxtime",
	$input->{'bantime_maxtime_def'} ? undef :
		$input->{'bantime_maxtime'}, $jail);
&save_directive("bantime.overalljails",
	$input->{'bantime_overalljails'} eq "" ? undef :
		$input->{'bantime_overalljails'}, $jail);
&save_directive("bantime.rndtime",
	$input->{'bantime_rndtime_def'} ? undef :
		$input->{'bantime_rndtime'}, $jail);
}

# Unblock given IP in given jail
sub unblock_jailed_ip
{
my ($jail, $ip) = @_;
my $cmd = "$config{'client_cmd'} set ".quotemeta($jail)." unbanip ".quotemeta($ip)." 2>&1 </dev/null";
my $out = &backquote_logged($cmd);
if ($?) {
	&error(&text('status_err_unban', &html_escape($ip)) . " : $out");
	}
}

# Unblock all IPs in given jail
sub unblock_jail
{
my ($jail) = @_;
my $cmd = "$config{'client_cmd'} reload --unban ".quotemeta($jail)." 2>&1 </dev/null";
my $out = &backquote_logged($cmd);
if ($?) {
	&error(&text('status_err_unbanjail', &html_escape($jail)) . " : $out");
	}
}

# Convert human readable time to seconds
sub time_to_seconds
{
my ($time) = @_;
my $seconds;
my ($number, $unit) = $time =~ /^(\d+)\s*(year|years|month|months|week|weeks|day|days|hour|hours|min|minute|minutes|sec|second|seconds|y|mo|w|d|h|m|s)$/;
if ($number && $unit) {
	$seconds = $number if ($unit =~ /^s/);
	$seconds = $number * 60 if ($unit =~ /^m$|^min/);
	$seconds = $number * 3600 if ($unit =~ /^h/);
	$seconds = $number * 86400 if ($unit =~ /^d/);
	$seconds = $number * 604800 if ($unit =~ /^w/);
	$seconds = $number * 2629800 if ($unit =~ /^mo/);
	$seconds = $number * 31557600 if ($unit =~ /^y/);
	}
else {
	$seconds = int($time);
	}
return $seconds;
}

# Convert seconds to human readable time
sub seconds_to_time {
    my ($seconds) = @_;
    my ($number, $unit) = $seconds =~ /^(\d+)\s*(year|years|month|months|week|weeks|day|days|hour|hours|min|minute|minutes|sec|second|seconds|y|mo|w|d|h|m|s)$/;
    return $seconds if ($unit);
    my $time;
    if ($seconds >= 31557600) {
	my $years = int($seconds / 31557600);
        $time = $years . " " .
		($years > 1 ? $text{'config_dbpurgeagecusyrs'} :
			$text{'config_dbpurgeagecusyr'});
    } elsif ($seconds >= 2629800) {
	my $months = int($seconds / 2629800);
        $time = $months . " " .
		($months > 1 ? $text{'config_dbpurgeagecusmos'} :
			$text{'config_dbpurgeagecusmo'});
    } elsif ($seconds >= 604800) {
	my $weeks = int($seconds / 604800);
        $time = $weeks . " " .
		($weeks > 1 ? $text{'config_dbpurgeagecuswks'} :
			$text{'config_dbpurgeagecuswk'});
    } elsif ($seconds >= 86400) {
	my $days = int($seconds / 86400);
        $time = $days . " " .
		($days > 1 ? $text{'config_dbpurgeagecusdays'} :
			$text{'config_dbpurgeagecusday'});
    } elsif ($seconds >= 3600) {
	my $hours = int($seconds / 3600);
        $time = $hours . " " .
		($hours > 1 ? $text{'config_dbpurgeagecushrs'} :
			$text{'config_dbpurgeagecushr'});
    } elsif ($seconds >= 60) {
	my $minutes = int($seconds / 60);
        $time = $minutes . " " .
		($minutes > 1 ? $text{'config_dbpurgeagecusmins'} :
			$text{'config_dbpurgeagecusmin'});
    } else {
        $time = $seconds . " " .
		(int($seconds / 60) > 1 ? $text{'config_dbpurgeagecussecs'} :
			$text{'config_dbpurgeagecussec'});
    }
    return $time;
}

# Test if given format is correct
sub time_to_seconds_error
{
my ($time) = @_;
my ($seconds) = $time =~ /^(\d+)$/;
return 0 if ($seconds);
my ($number, $unit) = $time =~ /^(\d+)\s*(year|years|month|months|week|weeks|day|days|hour|hours|min|minute|minutes|sec|second|seconds|y|mo|w|d|h|m|s)$/;
return 0 if ($number && $unit);
my ($ewrongunit) = $time =~ /^\d+\s*(\S+)\s*$/;
return &text('config_ewrongunit', $ewrongunit) if ($ewrongunit);
return $text{'config_ewrongtime'} if ($time !~ /^(\d+)$/ || $time == 0);
return 0;
}

1;
