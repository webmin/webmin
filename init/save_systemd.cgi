#!/usr/local/bin/perl
# Create, update or delete a systemd unit

require './init-lib.pl';
&error_setup($text{'systemd_err'});
$access{'bootup'} || &error($text{'edit_ecannot'});
&ReadParse();

# Select system or user scope before loading units.
$user_scope = $in{'new'} ? ($in{'userservice'} ? 1 : 0) :
	      ($in{'scope'} eq 'user' ? 1 : 0);
$unituser = &clean_systemd_unit_value($in{'unituser'});
if ($user_scope) {
	&get_systemd_user_details($unituser) ||
		&error($text{'systemd_euser'});
	@systemds = &list_systemd_user_services($unituser);
	}
else {
	@systemds = &list_systemd_services();
	}

# Load the existing unit for edits and destructive actions.
if (!$in{'new'}) {
	($u) = grep { $_->{'name'} eq $in{'name'} } @systemds;
	$u || &error($text{'systemd_egone'});
	$u->{'legacy'} && &error($text{'systemd_elegacy'});
	}

if ($in{'start'} || $in{'stop'} || $in{'restart'} || $in{'status'} ||
    $in{'logs'}) {
	# Stream runtime actions through mass_systemd.cgi.
	my $scopeargs = $user_scope ? "&scope=user&unituser=".
		&urlize($unituser) : "";
	&redirect("mass_systemd.cgi?d=".&urlize($in{'name'})."&".
		  ($in{'start'} ? "start=1" :
		   $in{'restart'} ? "restart=1" :
		   $in{'status'} ? "status=1" :
		   $in{'logs'} ? "logs=1" : "stop=1").
		  "&return=".&urlize($in{'name'}).$scopeargs);
	exit;
	}

if ($in{'delete'}) {
	# Delete the unit after trying to stop it and remove it from startup.
	if ($user_scope) {
		&disable_systemd_user_service($unituser, $in{'name'});
		&stop_systemd_user_service($unituser, $in{'name'});
		my ($ok, $out) =
			&delete_systemd_user_service($unituser, $in{'name'});
		$ok || &error_systemd_user_command($unituser, $out);
		&webmin_log("delete", "systemd-user", $in{'name'},
			    { 'user' => $unituser });
		}
	else {
		&disable_at_boot($in{'name'});
		&stop_systemd_service($in{'name'});
		&delete_systemd_service($in{'name'});
		&webmin_log("delete", "systemd", $in{'name'});
		}
	$redirect = &systemd_index_url($in{'name'}, $user_scope, $unituser);
	}
elsif ($in{'new'}) {
	# Normalize the unit name and suffix before checking for clashes.
	my %creatable_types = map { $_, 1 } &get_systemd_creatable_unit_types();
	my $unittype = $in{'unittype'} || 'service';
	$creatable_types{$unittype} || &error($text{'systemd_eunittype'});
	my $creatable_piped = join('|', map { quotemeta($_) }
				       &get_systemd_creatable_unit_types());
	if ($in{'name'} =~ /\.($creatable_piped)$/i) {
		lc($1) eq $unittype || &error($text{'systemd_eunittype'});
		$in{'name'} =~ s/\.($creatable_piped)$/\.$unittype/i;
		}
	else {
		$in{'name'} .= ".".$unittype;
		}
	&valid_systemd_unit_name($in{'name'}) ||
		&error($text{'systemd_ename'});
	($clash) = grep { $_->{'name'} eq $in{'name'} } @systemds;
	$clash && &error($text{'systemd_eclash'});
	$in{'desc'} || &error($text{'systemd_edesc'});

	# Services use explicit command fields; other unit types accept only the
	# body of their type-specific section, which is wrapped server-side.
	if ($unittype eq 'service') {
		$in{'atstart'} =~ /\S/ || &error($text{'systemd_estart'});
		}
	else {
		$in{'unitconf'} = &clean_systemd_unit_body($in{'unitconf'});
		$in{'unitconf'} = "" if (!defined($in{'unitconf'}));
		$in{'unitconf'} =~ /^\s*\[/m &&
			&error($text{'systemd_eunitconfsection'});
		my %empty_ok = ( 'target' => 1 );
		$empty_ok{$unittype} || $in{'unitconf'} =~ /\S/ ||
			&error($text{'systemd_eunitconf'});
		}

	# Parse optional scalar settings into %opts.
	foreach my $o ('before', 'after', 'wants', 'requires', 'conflicts',
		       'onfailure', 'onsuccess', 'type', 'env', 'envfile',
		       'user', 'group', 'killmode', 'workdir', 'restart',
		       'restartsec', 'watchdogsec', 'timeout',
		       'timeoutstartsec',
		       'timeoutstopsec', 'limitnofile', 'logstd', 'logerr',
		       'syslogid', 'protectsystem', 'readwritepaths',
		       'wantedby') {
		if (defined($in{$o})) {
			$in{$o} =~ s/\r|\n/ /g;
			$in{$o} =~ s/^\s+//;
			$in{$o} =~ s/\s+$//;
			$opts{$o} = $in{$o} if ($in{$o} =~ /\S/);
			}
		}

	# Keep one command hook per input line.
	foreach my $o ('startpre', 'startpost', 'stoppost') {
		if (defined($in{$o})) {
			$in{$o} =~ s/\r//g;
			$in{$o} =~ s/^\s+//;
			$in{$o} =~ s/\s+$//;
			$opts{$o} = $in{$o} if ($in{$o} =~ /\S/);
			}
		}
	foreach my $o ('reload', 'pidfile') {
		$in{$o} = "" if (!defined($in{$o}));
		$in{$o} =~ s/\r//g;
		$in{$o} =~ s/\n/ /g if ($o eq 'pidfile');
		$in{$o} =~ s/^\s+//;
		$in{$o} =~ s/\s+$//;
		}

	# Boolean options are emitted only when enabled.
	foreach my $o ('nonewprivs', 'privatetmp') {
		$opts{$o} = 1 if ($in{$o});
		}
	my %duration_text = (
		'restartsec' => $text{'systemd_restartsec'},
		'watchdogsec' => $text{'systemd_watchdogsec'},
		'timeout' => $text{'systemd_timeout'},
		'timeoutstartsec' => $text{'systemd_timeout'},
		'timeoutstopsec' => $text{'systemd_timeoutstop'},
		);

	# Service-only options are validated against systemd's expected value
	# shapes, so invalid units fail on save instead of on daemon-reload.
	if ($unittype eq 'service') {
		foreach my $o ('restartsec', 'watchdogsec', 'timeout',
			       'timeoutstartsec', 'timeoutstopsec') {
			!$opts{$o} || &valid_systemd_duration($opts{$o}) ||
				&error(&text('systemd_eduration', $duration_text{$o}));
			}
		!$in{'pidfile'} || &valid_systemd_path($in{'pidfile'}, 0, 0) ||
			&error(&text('systemd_epath', $text{'systemd_pidfile'}));
		!$opts{'workdir'} || &valid_systemd_path($opts{'workdir'}, 1, 1) ||
			&error(&text('systemd_epath', $text{'systemd_workdir'}));
		!$opts{'envfile'} || &valid_systemd_path($opts{'envfile'}, 1, 0) ||
			&error(&text('systemd_epath', $text{'systemd_envfile'}));
		!$opts{'limitnofile'} ||
			$opts{'limitnofile'} =~ /^(infinity|\d+)(:(infinity|\d+))?$/i ||
			&error($text{'systemd_elimitnofile'});
		foreach my $o ('logstd', 'logerr') {
			!$opts{$o} || &valid_systemd_output($opts{$o}) ||
				&error(&text('systemd_eoutput', $text{'systemd_'.$o}));
			}
		!$opts{'protectsystem'} ||
			$opts{'protectsystem'} =~ /^(true|full|strict)$/ ||
			&error($text{'systemd_eprotectsystem'});
		if ($opts{'readwritepaths'}) {
			foreach my $p (&split_quoted_string($opts{'readwritepaths'})) {
				&valid_systemd_path($p, 1, 0, 1) ||
					&error(&text('systemd_ereadwritepath', $p));
				}
			}
		}

	# User units already run as the owning user, so User=/Group= must not be
	# written into the unit file.
	if ($user_scope) {
		delete($opts{'user'});
		delete($opts{'group'});
		}
	$opts{'wantedby'} ||= &get_systemd_default_install_target(
		$unittype, $user_scope);

	# Create the unit file in the selected scope.  When requested, linger is
	# enabled first so daemon-reload has a user manager to talk to.
	if ($user_scope) {
		if ($in{'linger'}) {
			my ($lok, $lout) = &set_systemd_user_linger($unituser, 1);
			$lok || &error_systemd_user_command($unituser, $lout);
			my ($mok, $mout) = &start_systemd_user_manager($unituser);
			$mok || &error_systemd_user_command($unituser, $mout);
			}
		my ($ok, $out);
		if ($unittype eq 'service') {
			($ok, $out) = &create_systemd_user_service(
				$unituser, $in{'name'}, $in{'desc'}, $in{'atstart'},
				$in{'atstop'}, $in{'reload'}, undef, $in{'pidfile'},
				$in{'remain'}, \%opts);
			}
		else {
			($ok, $out) = &create_systemd_user_unit(
				$unituser, $in{'name'}, $unittype, $in{'desc'},
				$in{'unitconf'}, \%opts);
			}
		$ok || &error_systemd_user_command($unituser, $out);
		}
	else {
		if ($unittype eq 'service') {
			&create_systemd_service($in{'name'}, $in{'desc'},
						$in{'atstart'}, $in{'atstop'},
						$in{'reload'}, undef, $in{'pidfile'},
						$in{'remain'}, \%opts);
			}
		else {
			&create_systemd_unit($in{'name'}, $unittype,
					     $in{'desc'}, $in{'unitconf'},
					     \%opts);
			}
		}

	# Enable or disable startup after the unit has been written and reloaded.
	if ($user_scope) {
		my ($ok, $out);
		if ($in{'boot'} == 0) {
			($ok, $out) =
				&disable_systemd_user_service($unituser,
							      $in{'name'});
			}
		else {
			($ok, $out) =
				&enable_systemd_user_service($unituser,
							     $in{'name'});
			}
		$ok || &error_systemd_user_command($unituser, $out);
		}
	else {
		if ($in{'boot'} == 0) {
			&disable_at_boot($in{'name'});
			}
		else {
			&enable_at_boot($in{'name'});
			}
		}

	# Return to the edit page for the newly created unit in the same scope.
	if ($user_scope) {
		&webmin_log("create", "systemd-user", $in{'name'},
			    { 'user' => $unituser });
		$redirect = "edit_systemd.cgi?scope=user&unituser=".
			&urlize($unituser)."&name=".&urlize($in{'name'});
		}
	else {
		&webmin_log("create", "systemd", $in{'name'});
		$redirect = "edit_systemd.cgi?name=".&urlize($in{'name'});
		}
	}
else {
	# Save the raw unit file contents from the edit form.
	$in{'data'} =~ /\S/ || &error($text{'systemd_econf'});
	$in{'data'} =~ s/\r//g;
	if ($user_scope) {
		# User unit writes go through a privilege-dropped helper.  Linger is
		# disabled only after daemon-reload succeeds, so the reload is not cut
		# off from the user manager.
		my $disable_linger;
		my ($wok, $wout) =
			&write_systemd_user_unit_file($unituser, $u->{'file'},
						      $in{'data'});
		$wok || &error($wout);
		if (defined($in{'linger'})) {
			if ($in{'linger'}) {
				my ($lok, $lout) =
					&set_systemd_user_linger($unituser, 1);
				$lok || &error_systemd_user_command($unituser, $lout);
				my ($mok, $mout) =
					&start_systemd_user_manager($unituser);
				$mok || &error_systemd_user_command($unituser, $mout);
				}
			else {
				$disable_linger = 1;
				}
			}
		my ($ok, $out) = &restart_systemd_user($unituser);
		$ok || &error_systemd_user_command($unituser, $out);
		if ($disable_linger) {
			my ($lok, $lout) = &set_systemd_user_linger($unituser, 0);
			$lok || &error_systemd_user_command($unituser, $lout);
			}
		}
	else {
		# System units are root-owned and can be updated directly.
		&open_lock_tempfile(CONF, ">$u->{'file'}");
		&print_tempfile(CONF, $in{'data'});
		&close_tempfile(CONF);
		&restart_systemd();
		}

	# Apply startup state changes after saving the config.
	if (defined($in{'boot'})) {
		if ($user_scope) {
			my ($ok, $out);
			if ($in{'boot'} == 0) {
				($ok, $out) =
					&disable_systemd_user_service(
						$unituser, $in{'name'});
				}
			else {
				($ok, $out) =
					&enable_systemd_user_service(
						$unituser, $in{'name'});
				}
			$ok || &error_systemd_user_command($unituser, $out);
			}
		else {
			if ($in{'boot'} == 0) {
				&disable_at_boot($in{'name'});
				}
			else {
				&enable_at_boot($in{'name'});
				}
			}
		}

	# Log the edit and return to the same scoped edit page.
	if ($user_scope) {
		&webmin_log("modify", "systemd-user", $in{'name'},
			    { 'user' => $unituser });
		$redirect = "edit_systemd.cgi?scope=user&unituser=".
			&urlize($unituser)."&name=".&urlize($in{'name'});
		}
	else {
		&webmin_log("modify", "systemd", $in{'name'});
		$redirect = "edit_systemd.cgi?name=".&urlize($in{'name'});
		}
	}
&redirect($redirect || "");

# error_systemd_user_command(user, output)
# Shows a systemctl --user or loginctl failure with escaped command output.
sub error_systemd_user_command
{
my ($user, $out) = @_;
$out ||= $text{'systemd_euser'};
&error(&text('systemd_eusercmd',
	     &ui_tag('tt', &html_escape($user)),
	     &ui_tag('pre', &html_escape($out))));
}

# valid_systemd_duration(value)
# Returns 1 if a value matches systemd's duration syntax used by timeout fields.
sub valid_systemd_duration
{
my ($value) = @_;
my $unit = qr/usec|us|msec|ms|seconds?|sec|s|minutes?|min|m|hours?|hr|h|days?|d|weeks?|w|months?|M|years?|y/i;
$value =~ s/^\s+//;
$value =~ s/\s+$//;
return 1 if ($value =~ /^infinity$/i);
return 0 if ($value !~ /\S/);
while ($value =~ /\G\s*\d+(?:\.\d+)?\s*(?:$unit)?/gc) {
	}
return defined(pos($value)) && pos($value) == length($value);
}

# valid_systemd_path(value, allow-dash, allow-tilde, allow-plus)
# Returns 1 if a unit-file path option is absolute or explicitly allowed.
sub valid_systemd_path
{
my ($value, $allow_dash, $allow_tilde, $allow_plus) = @_;
$value =~ s/^\s+//;
$value =~ s/\s+$//;
$value =~ s/^-// if ($allow_dash);
$value =~ s/^\+// if ($allow_plus);
return 0 if ($value =~ /[\r\n\0=\s]/);
return 1 if ($value =~ /^\//);
return 1 if ($allow_tilde && $value =~ /^~/);
return 0;
}

# valid_systemd_output(value)
# Returns 1 if a StandardOutput/StandardError value is a safe systemd target.
sub valid_systemd_output
{
my ($value) = @_;
return 0 if ($value =~ /[\r\n\0=\s]/);
return 1 if ($value =~ /^\//);
return 1 if ($value =~ /^(inherit|null|tty|journal|kmsg|journal\+console|kmsg\+console|socket|fd:[A-Za-z0-9_.:-]+|file:\/\S+|append:\/\S+|truncate:\/\S+)$/);
return 0;
}
