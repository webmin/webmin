# Functions for parsing the dovecot config file

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();

@supported_protocols = ( "imap", "pop3", "imaps", "pop3s" );
@supported_auths = ( "anonymous", "plain", "digest-md5", "cram-md5", "apop" );
@mail_envs = ( undef, "maildir:~/Maildir", "mbox:~/mail/:INBOX=/var/mail/%u",
	       "maildir:~/Maildir:mbox:~/mail/" );

# get_config()
# Returns a list of dovecot config entries
sub get_config
{
if (!length(@get_config_cache)) {
	@get_config_cache = ( );
	local $lnum = 0;
	local ($section, @sections);
	open(CONF, $config{'dovecot_config'});
	while(<CONF>) {
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
				     'eline' => $lnum };
			if ($oldsection) {
				$section->{'sectionname'} =
					$oldsection->{'name'};
				$section->{'sectionvalue'} =
					$oldsection->{'value'};
				}
			push(@get_config_cache, $section);
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
				       'line' => $lnum };
			if ($section) {
				$dir->{'sectionname'} = $section->{'name'};
				$dir->{'sectionvalue'} = $section->{'value'};
				push(@{$section->{'members'}}, $dir);
				$section->{'eline'} = $lnum;
				}
			push(@get_config_cache, $dir);
			}
		$lnum++;
		}
	close(CONF);
	}
return \@get_config_cache;
}

# find(name, &config, [disabled-mode], [sectionname], [sectionvalue])
# Mode 0=enabled, 1=disabled, 2=both
sub find
{
local ($name, $conf, $mode, $sname, $svalue) = @_;
local @rv = grep { !$_->{'section'} &&
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

# find_value(name, &config, [disabled-mode], [sectionname], [sectionvalue])
# Mode 0=enabled, 1=disabled, 2=both
sub find_value
{
local @rv = &find(@_);
if (wantarray) {
	return map { $_->{'value'} } @rv;
	}
else {
	return $rv[0]->{'value'};
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
local $lref = &read_file_lines($config{'dovecot_config'});
local $dir = ref($name) ? $name : &find($name, $conf, 0, $sname, $svalue);
local $newline = ref($name) ? "$name->{'name'} = $value" : "$name = $value";
if ($sname) {
	$newline = "  ".$newline;
	}
if ($dir && defined($value)) {
	# Updating some directive
	$lref->[$dir->{'line'}] = $newline;
	$dir->{'value'} = $value;
	}
elsif ($dir && !defined($value)) {
	# Deleting some directive
	splice(@$lref, $dir->{'line'}, 1);
	&renumber($conf, $dir->{'line'}, -1);
	@$conf = grep { $_ ne $dir } @$conf;
	}
elsif (!$dir && defined($value)) {
	# Adding some directive .. put it after the commented version, if any
	local $cmt = &find($name, $conf, 1, $sname, $svalue);
	if ($cmt) {
		# After comment
		splice(@$lref, $cmt->{'line'}+1, 0, $newline);
		&renumber($conf, $cmt->{'line'}+1, 1);
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
		local $line = $insect[$#insect]->{'line'}+1;
		splice(@$lref, $line, 0, $newline);
		&renumber($conf, $line, 1);
		push(@$conf, { 'name' => $name,
			       'value' => $value,
			       'line' => $line,
			       'sectionname' => $sname,
			       'sectionvalue' => $svalue });
		}
	else {
		# Need to put at end
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
local $lref = &read_file_lines($config{'dovecot_config'});
local $indent = "  " x $section->{'indent'};
local @newlines;
push(@newlines, $indent.$section->{'name'}." ".$section->{'value'}." {");
foreach my $m (@{$section->{'members'}}) {
	push(@newlines, $indent."  ".$m->{'name'}." = ".$m->{'value'});
	}
push(@newlines, $indent."}");
local $oldlen = $section->{'eline'} - $section->{'line'} + 1;
splice(@$lref, $section->{'line'}, $oldlen, @newlines);
&renumber($conf, $section->{'eline'}, scalar(@newlines)-$oldlen);
$section->{'eline'} = $section->{'line'} + scalar(@newlines) - 1;
}

# renumber(&conf, line, offset)
sub renumber
{
local ($conf, $line, $offset) = @_;
foreach my $c (@$conf) {
	$c->{'line'} += $offset if ($c->{'line'} >= $line);
	$c->{'eline'} += $offset if ($c->{'eline'} >= $line);
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
	local $out = &backquote_logged("$script stop 2>&1");
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
local $out = &backquote_logged("$cmd 2>&1");
return $? ? "<pre>$out</pre>" : undef;
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
local $out = `$config{'dovecot'} --version 2>&1`;
return $out =~ /([0-9\.]+)/ ? $1 : undef;
}

sub list_lock_methods
{
local ($forindex) = @_;
return ( "dotlock", "fcntl", "flock", $forindex ? ( ) : ( "lockf" ) );
}

1;

