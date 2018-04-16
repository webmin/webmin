# Functions for parsing the dovecot config file

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();

@supported_auths = ( "anonymous", "plain", "digest-md5", "cram-md5", "apop" );
@mail_envs = ( undef, "maildir:~/Maildir", "mbox:~/mail/:INBOX=/var/mail/%u",
	       "maildir:~/Maildir:mbox:~/mail/" );

# get_config_file()
# Returns the full path to the first valid config file
sub get_config_file
{
foreach my $f (split(/\s+/, $config{'dovecot_config'})) {
	return $f if (-r $f);
	}
return undef;
}

# get_config()
# Returns a list of dovecot config entries
sub get_config
{
if (!scalar(@get_config_cache)) {
	@get_config_cache = &read_config_file(&get_config_file());
	}
return \@get_config_cache;
}

# read_config_file(filename, [&include-parent-rv])
# Convert a file into a list od directives
sub read_config_file
{
local ($file, $incrv) = @_;
local $filedir = $file;
$filedir =~ s/\/[^\/]+$//;
local $lnum = 0;
local ($section, @sections);
open(CONF, $file);
local @lines = <CONF>;
close(CONF);
local $_;
local @rv;
local $section;
foreach (@lines) {
	s/\r|\n//g;
	if (/^\s*(#?)\s*([a-z0-9\_]+)\s*(\S*)\s*\{\s*$/) {
		# Start of a section .. add this as a value too
		local $oldsection = $section;
		if ($section) {
			push(@sections, $section);	# save old
			}
		$section = { 'name' => $2,
			     'value' => $3,
			     'enabled' => !$1,
			     'section' => 1,
			     'members' => [ ],
			     'indent' => scalar(@sections),
			     'line' => $lnum,
			     'eline' => $lnum,
			     'file' => $file, };
		if ($oldsection) {
			$section->{'sectionname'} =
				$oldsection->{'name'};
			$section->{'sectionvalue'} =
				$oldsection->{'value'};
			}
		push(@rv, $section);
		}
	elsif (/^\s*(#?)\s*}\s*$/ && $section) {
		# End of a section
		$section->{'eline'} = $lnum;
		$section->{'eline'} = $lnum;
		if (@sections) {
			$section = pop(@sections);
			}
		else {
			$section = undef;
			}
		}
	elsif (/^\s*(#?)([a-z0-9\_]+)\s+=\s*(.*)/) {
		# A directive inside a section
		local $dir = { 'name' => $2,
			       'value' => $3,
			       'enabled' => !$1,
			       'line' => $lnum,
			       'file' => $file, };
		if ($section) {
			$dir->{'sectionname'} = $section->{'name'};
			$dir->{'sectionvalue'} = $section->{'value'};
			push(@{$section->{'members'}}, $dir);
			$section->{'eline'} = $lnum;
			}

		# Fix up references to other variables
		my @w = split(/\s+/, $dir->{'value'});
		my $changed;
		foreach my $w (@w) {
			if ($w =~ /^\$(\S+)/) {
				my $var = $1;
				my ($prev) = grep { $_->{'name'} eq $var } @rv;
				if (!$prev && $incrv) {
					($prev) = grep { $_->{'name'} eq $var }
						       @$incrv;
					}
				if ($prev) {
					$w = $prev->{'value'};
					$changed = 1;
					}
				else {
					$w = undef;
					$changed = 1;
					}
				}
			}
		if ($changed) {
			@w = grep { defined($_) } @w;
			$dir->{'value'} = join(" ", @w);
			}
		push(@rv, $dir);
		}
	elsif (/^\s*!(include|include_try)\s+(\S+)/) {
		# Include file(s)
		local $glob = $2;
		if ($glob !~ /^\//) {
			$glob = $filedir."/".$glob;
			}
		foreach my $i (glob($glob)) {
			push(@rv, &read_config_file($i, \@rv));
			}
		}
	$lnum++;
	}
return @rv;
}

# find(name, &config, [disabled-mode], [sectionname], [sectionvalue], [first])
# Mode 0=enabled, 1=disabled, 2=both
sub find
{
local ($name, $conf, $mode, $sname, $svalue, $first) = @_;
local @rv = grep { !$_->{'section'} &&
		   $_->{'name'} eq $name &&
		   ($mode == 0 && $_->{'enabled'} ||
		    $mode == 1 && !$_->{'enabled'} || $mode == 2) } @$conf;
if (defined($sname)) {
	# If a section was requested, limit to it
	@rv = grep { $_->{'sectionname'} eq $sname &&
		     $_->{'sectionvalue'} eq $svalue } @rv;
	}
if (wantarray) {
	return @rv;
	}
elsif ($first) {
	return $rv[0];
	}
else {
	return $rv[$#rv];
	}
}

# find_value(name, &config, [disabled-mode], [sectionname], [sectionvalue])
# Mode 0=enabled, 1=disabled, 2=both
sub find_value
{
local @rv = &find(@_);
if (wantarray) {
	return map { $_->{'value'} } @rv;
	}
elsif (!@rv) {
	return undef;
	}
else {
	# Prefer the last one that isn't self-referential
	my @unself = grep { $_->{'value'} !~ /\$\Q$name\E/ } @rv;
	@rv = @unself if (@unself);
	return $rv[$#rv]->{'value'};
	}
}

# find_section(name, &config, [disabled-mode], [sectionname], [sectionvalue])
# Returns a Dovecot config section object
sub find_section
{
local ($name, $conf, $mode, $sname, $svalue) = @_;
local @rv = grep { $_->{'section'} &&
		   $_->{'name'} eq $name &&
		   ($mode == 0 && $_->{'enabled'} ||
		    $mode == 1 && !$_->{'enabled'} || $mode == 2) } @$conf;
if (defined($sname)) {
	# If a section was requested, limit to it
	@rv = grep { $_->{'sectionname'} eq $sname &&
		     $_->{'sectionvalue'} eq $svalue } @rv;
	}
return wantarray ? @rv : $rv[0];
}

# save_directive(&conf, name|&dir, value, [sectionname], [sectionvalue])
# Updates one directive in the config file
sub save_directive
{
local ($conf, $name, $value, $sname, $svalue) = @_;
local $dir;
if (ref($name)) {
	# Old directive given
	$dir = $name;
	}
else {
	# Find by name, by prefer those that aren't self-referential
	my @dirs = &find($name, $conf, 0, $sname, $svalue, 1);
	($dir) = grep { $_->{'value'} !~ /\$\Q$name\E/ } @dirs;
	if (!$dir) {
		$dir = $dirs[0];
		}
	}
local $newline = ref($name) ? "$name->{'name'} = $value" : "$name = $value";
if ($sname) {
	$newline = "  ".$newline;
	}
if ($dir && defined($value)) {
	# Updating some directive
	local $lref = &read_file_lines($dir->{'file'});
	$lref->[$dir->{'line'}] = $newline;
	$dir->{'value'} = $value;
	}
elsif ($dir && !defined($value)) {
	# Deleting some directive
	local $lref = &read_file_lines($dir->{'file'});
	splice(@$lref, $dir->{'line'}, 1);
	&renumber($conf, $dir->{'line'}, $dir->{'file'}, -1);
	@$conf = grep { $_ ne $dir } @$conf;
	}
elsif (!$dir && defined($value)) {
	# Adding some directive .. put it after the commented version, if any
	local $cmt = &find($name, $conf, 1, $sname, $svalue);
	if ($cmt) {
		# After comment
		local $lref = &read_file_lines($cmt->{'file'});
		splice(@$lref, $cmt->{'line'}+1, 0, $newline);
		&renumber($conf, $cmt->{'line'}+1, $cmt->{'file'}, 1);
		push(@$conf, { 'name' => $name,
			       'value' => $value,
			       'line' => $cmt->{'line'}+1,
			       'sectionname' => $sname,
			       'sectionvalue' => $svalue });
		}
	elsif ($sname) {
		# Put at end of section
		local @insect = grep { $_->{'sectionname'} eq $sname &&
				       $_->{'sectionvalue'} eq $svalue } @$conf;
		@insect || &error("Failed to find section $sname $svalue !");
		local $lref = &read_file_lines($insect[$#insect]->{'file'});
		local $line = $insect[$#insect]->{'line'}+1;
		splice(@$lref, $line, 0, $newline);
		&renumber($conf, $line, $insect[$#insect]->{'file'}, 1);
		push(@$conf, { 'name' => $name,
			       'value' => $value,
			       'line' => $line,
			       'sectionname' => $sname,
			       'sectionvalue' => $svalue });
		}
	else {
		# Need to put at end of main config
		local $lref = &read_file_lines(&get_config_file());
		push(@$lref, $newline);
		push(@$conf, { 'name' => $name,
			       'value' => $value,
			       'line' => scalar(@$lref)-1,
			       'sectionname' => $sname,
			       'sectionvalue' => $svalue });
		}
	}
}

# save_section(&conf, &section)
# Updates one section in the config file
sub save_section
{
local ($conf, $section) = @_;
local $lref = &read_file_lines($section->{'file'});
local $indent = "  " x $section->{'indent'};
local @newlines;
push(@newlines, $indent.$section->{'name'}." ".$section->{'value'}." {");
foreach my $m (@{$section->{'members'}}) {
	push(@newlines, $indent."  ".$m->{'name'}." = ".$m->{'value'});
	}
push(@newlines, $indent."}");
local $oldlen = $section->{'eline'} - $section->{'line'} + 1;
splice(@$lref, $section->{'line'}, $oldlen, @newlines);
&renumber($conf, $section->{'eline'}, $section->{'file'},
	  scalar(@newlines)-$oldlen);
$section->{'eline'} = $section->{'line'} + scalar(@newlines) - 1;
}

# renumber(&conf, line, file, offset)
sub renumber
{
local ($conf, $line, $file, $offset) = @_;
foreach my $c (@$conf) {
	if ($c->{'file'} eq $file) {
		$c->{'line'} += $offset if ($c->{'line'} >= $line);
		$c->{'eline'} += $offset if ($c->{'eline'} >= $line);
		}
	}
}

# is_dovecot_running()
# Returns the PID if the server process is active, undef if not
sub is_dovecot_running
{
# Try the configured PID file first
local $pid =&check_pid_file($config{'pid_file'});
return $pid if ($pid);

# Look in the base dir
local $base = &find_value("base_dir", &get_config(), 2);
return &check_pid_file("$base/master.pid");
}

# get_initscript()
# Returns the full path to the Dovecot init script
sub get_initscript
{
if ($config{'init_script'}) {
	&foreign_require("init", "init-lib.pl");
	if ($init::init_mode eq "init") {
		return &init::action_filename($config{'init_script'});
		}
	}
return undef;
}

# stop_dovecot()
# Attempts to stop the dovecot server process, returning an error message or
# undef if successful
sub stop_dovecot
{
local $script = &get_initscript();
if ($script) {
	local $out = &backquote_logged("$script stop 2>&1 </dev/null");
	return $? ? "<pre>$out</pre>" : undef;
	}
else {
	local $pid = &is_dovecot_running();
	if ($pid && kill('TERM', $pid)) {
		return undef;
		}
	else {
		return $text{'stop_erunning'};
		}
	}
}

# start_dovecot()
# Attempts to start the dovecot server process, returning an error message or
# undef if successful
sub start_dovecot
{
local $script = &get_initscript();
local $cmd = $script ? "$script start" : $config{'dovecot'};
local $temp = &transname();
&system_logged("$cmd >$temp 2>&1 </dev/null &");
sleep(1);
local $out = &read_file_contents($temp);
&unlink_file($temp);
return &is_dovecot_running() ? undef : "<pre>$out</pre>";
}

# apply_configration()
# Stop and re-start the Dovecot server
sub apply_configuration
{
local $pid = &is_dovecot_running();
if ($pid) {
	&stop_dovecot();
	local $err;
	for(my $i=0; $i<5; $i++) {
		$err = &start_dovecot();
		last if (!$err);
		sleep(1);
		}
	return $err;
	}
else {
	return $text{'stop_erunning'};
	}
}

# getdef(name, [&mapping])
# Returns 'Default (value)' for some config
sub getdef
{
local $def = &find_value($_[0], &get_config(), 1);
if (defined($def)) {
	local $map;
	if ($_[1]) {
		($map) = grep { $_->[0] eq $def } @{$_[1]};
		}
	if (defined($map)) {
		return "$text{'default'} ($map->[1])";
		}
	elsif ($def) {
		return "$text{'default'} ($def)";
		}
	}
return $text{'default'};
}

# get_dovecot_version()
# Returns the dovecot version number, or undef if not available
sub get_dovecot_version
{
local $out = &backquote_command("$config{'dovecot'} --version 2>&1");
return $out =~ /([0-9\.]+)/ ? $1 : undef;
}

# version_atleast(ver)
# Returns 1 if running at least some version or above
sub version_atleast
{
local ($wantver) = @_;
local $ver = &get_dovecot_version();
return 0 if (!$ver);
return &compare_version_numbers($wantver, $ver) >= 0;
}

sub list_lock_methods
{
local ($forindex) = @_;
return ( "dotlock", "fcntl", "flock", $forindex ? ( ) : ( "lockf" ) );
}

# lock_dovecot_files([&conf])
# Lock all files in the Dovecot config
sub lock_dovecot_files
{
local ($conf) = @_;
$conf ||= &get_config();
foreach my $f (&unique(map { $_->{'file'} } @$conf)) {
	&lock_file($f);
	}
}

# unlock_dovecot_files([&conf])
# Release lock on all files
sub unlock_dovecot_files
{
local ($conf) = @_;
$conf ||= &get_config();
foreach my $f (reverse(&unique(map { $_->{'file'} } @$conf))) {
	&unlock_file($f);
	}
}

# get_supported_protocols()
# Returns the list of usable protocols for the current Dovecot version
sub get_supported_protocols
{
if (&get_dovecot_version() >= 2) {
	return ( "imap", "pop3", "lmtp" );
	}
else {
	return ( "imap", "pop3", "imaps", "pop3s" );
	}
}

1;
r

