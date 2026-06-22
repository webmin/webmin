#!/usr/local/bin/perl
# Create, update or delete a systemd unit

use strict;
use warnings;
use Symbol qw(gensym);

require './systemd-lib.pl'; ## no critic

our (%access, %config, %in, %text);

# All failures on this page should use systemd-specific wording.
error_setup($text{'systemd_err'});
ReadParse();

# Select system or user scope before loading units.
my $user_scope = $in{'new'} ? ($in{'userservice'} ? 1 : 0) :
		 ($in{'scope'} eq 'user' ? 1 : 0);
my $unituser = clean_unit_value($in{'unituser'});
my $edit_dropin = !$in{'new'} && $in{'dropin'} ? 1 : 0;
my $dropin_file = $edit_dropin ? clean_unit_value($in{'dropfile'}) : "";
my $dropin_info;
my (@units, $u, $redirect);
if ($user_scope) {
	# User units must always be tied to a real Unix account.
	get_user_details($unituser) ||
		error($text{'systemd_euser'});
	systemd_can_view_scope(1, $unituser) ||
		systemd_acl_error('pview_user');
	@units = list_user_units($unituser);
	}
else {
	# System units are managed through the system manager.
	systemd_can_view_scope(0) || systemd_acl_error('pview');
	@units = list_units();
	}

# Load the existing unit for edits and destructive actions.
if (!$in{'new'}) {
	valid_unit_name($in{'name'}) ||
		error($text{'systemd_ename'});

	# The target unit must exist in the selected scope before it can be edited.
	($u) = grep { $_->{'name'} eq $in{'name'} } @units;
	$u || error($text{'systemd_egone'});
	if ($edit_dropin && $dropin_file) {
		$dropin_info = $user_scope ?
			user_dropin_config_file_info($unituser, $dropin_file) :
			system_dropin_config_file_info($dropin_file);
		$dropin_info && $dropin_info->{'unit'} eq $in{'name'} ||
			error($text{'systemd_edropinfile'});
		$dropin_file = $dropin_info->{'file'};
		}
	}

if ($in{'stock_unit'}) {
	# Leaving the override editor is navigation only; do not save form data.
	redirect($user_scope ?
		"edit_unit.cgi?scope=user&unituser=".urlize($unituser).
			"&name=".urlize($in{'name'}) :
		"edit_unit.cgi?name=".urlize($in{'name'}));
	exit;
	}

# Runtime actions do not save the form; they stream through mass_units.cgi.
if (!$in{'new'} &&
    ($in{'start'} || $in{'stop'} || $in{'restart'} || $in{'status'} ||
    $in{'props'} || $in{'deps'} || $in{'logs'})) {
	if ($in{'start'}) {
		systemd_can_runtime('start',
				     $user_scope, $unituser) ||
			systemd_acl_error('pstart');
		}
	elsif ($in{'stop'}) {
		systemd_can_runtime('stop',
				     $user_scope, $unituser) ||
			systemd_acl_error('pstop');
		}
	elsif ($in{'restart'}) {
		systemd_can_runtime('restart',
				     $user_scope, $unituser) ||
			systemd_acl_error('prestart');
		}
	elsif ($in{'logs'}) {
		systemd_can_logs($user_scope, $unituser) ||
			systemd_acl_error('plogs');
		}
	else {
		systemd_can_inspect($user_scope, $unituser) ||
			systemd_acl_error('pstatus');
		}
	# Stream runtime actions through mass_units.cgi.
	my $scopeargs = $user_scope ? "&scope=user&unituser=".
		urlize($unituser) : "";
	my $dropinargs = $edit_dropin ? "&returndropin=1" : "";
	$dropinargs .= "&returndropfile=".urlize($dropin_file)
		if ($dropin_file);
	my $returnindexargs =
		(!$edit_dropin && !unit_file_editable($u) &&
		 ($in{'stop'} || $in{'restart'})) ? "&returnindex=1" : "";
	redirect("mass_units.cgi?d=".urlize($in{'name'})."&".
		($in{'start'} ? "start=1" :
		 $in{'restart'} ? "restart=1" :
		 $in{'status'} ? "status=1" :
		 $in{'props'} ? "props=1" :
		 $in{'deps'} ? "deps=1" :
		   $in{'logs'} ? "logs=1" : "stop=1").
		  "&return=".urlize($in{'name'}).$scopeargs.$dropinargs.
		  $returnindexargs);
	exit;
	}

if ($in{'override'}) {
	# Create the standard override file if needed, then open that drop-in.
	systemd_can_dropin($user_scope, $unituser) ||
		systemd_acl_error($user_scope ? 'pdropin_user' : 'pdropin');
	unit_file_editable($u) || error($text{'systemd_ereadonly'});
	my $base_data = $user_scope ?
		read_user_unit_file($unituser, $u->{'file'}) :
		read_file_contents($u->{'file'});
	defined($base_data) ||
		error($user_scope ? $text{'systemd_euserunitfile'} :
				    $text{'manual_eread'});
	my $dropfile = $user_scope ?
		user_dropin_file($unituser, $in{'name'}) :
		system_dropin_file($in{'name'});
	$dropfile || error($text{'systemd_edropinfile'});

	# Existing override files are preserved; the button becomes an opener.
	if ($user_scope) {
		user_dropin_file_safe($unituser, $dropfile, 0) ||
			error($text{'systemd_edropinfile'});
		if (!-f $dropfile) {
			my $template =
				dropin_template($dropfile, $u->{'file'},
						$base_data);
			my ($ok, $out) = write_user_dropin_file(
				$unituser, $in{'name'}, $template);
			$ok || error($out);
			webmin_log("override", "systemd-user", $in{'name'},
				    { 'user' => $unituser });
			}
		$redirect = "edit_unit.cgi?scope=user&unituser=".
			urlize($unituser)."&name=".urlize($in{'name'}).
			"&dropin=1";
		}
	else {
		my $dir = $dropfile;
		$dir =~ s{/[^/]+$}{};
		error($text{'systemd_edropinfile'})
			if (-l $dir || (-e $dir && !-d $dir) ||
			    -l $dropfile || (-e $dropfile && !-f $dropfile));
		if (!-f $dropfile) {
			my $template =
				dropin_template($dropfile, $u->{'file'},
						$base_data);
			my ($ok, $out) =
				write_system_dropin_file($in{'name'},
							  $template);
			$ok || error($out);
			webmin_log("override", "systemd", $in{'name'});
			}
		$redirect = "edit_unit.cgi?name=".urlize($in{'name'}).
			"&dropin=1";
		}
	}
elsif ($in{'delete_override'}) {
	# Drop-in deletes are available only from the override editor.
	systemd_can_dropin($user_scope, $unituser) ||
		systemd_acl_error($user_scope ? 'pdropin_user' : 'pdropin');
	$edit_dropin || error($text{'systemd_edropinfile'});
	$dropin_file && error($text{'systemd_edropinfile'});
	unit_file_editable($u) || error($text{'systemd_ereadonly'});
	if ($user_scope) {
		my ($ok, $out) =
			delete_user_dropin_file($unituser, $in{'name'});
		$ok || error($out);
		($ok, $out) = reload_user_manager($unituser);
		$ok || error_user_command($unituser, $out);
		webmin_log("deleteoverride", "systemd-user", $in{'name'},
			    { 'user' => $unituser });
		$redirect = "edit_unit.cgi?scope=user&unituser=".
			urlize($unituser)."&name=".urlize($in{'name'});
		}
	else {
		my ($ok, $out) = delete_system_dropin_file($in{'name'});
		$ok || error($out);
		reload_manager();
		webmin_log("deleteoverride", "systemd", $in{'name'});
		$redirect = "edit_unit.cgi?name=".urlize($in{'name'});
		}
	}
elsif ($in{'delete'}) {
	# Delete the unit after trying to stop it and remove it from startup.
	systemd_can_delete($user_scope, $unituser) ||
		systemd_acl_error($user_scope ? 'pdelete_user' : 'pdelete');
	if ($user_scope) {
		# User-unit deletion goes through helpers that drop to the owner.
		disable_user_unit($unituser, $in{'name'});
		stop_user_unit($unituser, $in{'name'});
		my ($ok, $out) =
			delete_user_unit($unituser, $in{'name'});
		$ok || error_user_command($unituser, $out);
		webmin_log("delete", "systemd-user", $in{'name'},
			    { 'user' => $unituser });
		}
	else {
		# Stop and disable are best-effort, but deletion must be reported.
		disable_unit($in{'name'});
		stop_unit($in{'name'});
		my ($ok, $out) = delete_system_unit($in{'name'});
		$ok || error($out);
		webmin_log("delete", "systemd", $in{'name'});
		}
	$redirect = index_url($in{'name'}, $user_scope, $unituser);
	}
elsif ($in{'new'}) {
	systemd_can_create($user_scope, $user_scope ? $unituser : undef) ||
		systemd_acl_error($user_scope ? 'pcreate_user' : 'pcreate');
	# Normalize the unit name and suffix before checking for clashes.
	my @creatable_unit_types = get_creatable_unit_types($user_scope);
	my %creatable_types = map { $_, 1 } @creatable_unit_types;
	my $unittype = $in{'unittype'} || 'service';
	$creatable_types{$unittype} || error($text{'systemd_eunittype'});
	$in{'name'} = clean_unit_value($in{'name'});
	$in{'name'} = "" if (!defined($in{'name'}));

	# Guided fields are rendered into the correct type-specific section.
	my ($derived_name, $structured_body);
	foreach my $o ('timer_oncalendar', 'timer_onbootsec',
		       'timer_onunitactivesec', 'timer_randomizeddelaysec',
		       'timer_accuracysec', 'timer_unit', 'timer_persistent',
		       'socket_listenstream', 'socket_listendatagram',
		       'socket_listenfifo', 'socket_user', 'socket_group',
		       'socket_mode', 'socket_service', 'socket_accept',
		       'path_exists', 'path_existsglob', 'path_changed',
		       'path_modified', 'path_directorynotempty',
		       'path_makedirectory', 'path_unit',
		       'mount_what', 'mount_where', 'mount_type',
		       'mount_options', 'automount_mount', 'automount_where',
		       'automount_idle', 'automount_mode',
		       'swap_what', 'swap_priority', 'swap_options',
		       'swap_timeoutsec', 'slice_cpuweight',
		       'slice_memorymax', 'slice_tasksmax', 'slice_ioweight') {
		$in{$o} = clean_unit_value($in{$o});
		$in{$o} = "" if (!defined($in{$o}));
		}
	my $raw_unitconf = clean_unit_body($in{'unitconf'});
	$raw_unitconf = "" if (!defined($raw_unitconf));
	$raw_unitconf =~ /^\s*\[/m &&
		error($text{'systemd_eunitconfsection'});

	if ($unittype eq 'timer') {
		my %timer_labels = (
			'timer_onbootsec' => $text{'systemd_timeronbootsec'},
			'timer_onunitactivesec' =>
				$text{'systemd_timeronunitactivesec'},
			'timer_randomizeddelaysec' =>
				$text{'systemd_timerrandomizeddelaysec'},
			'timer_accuracysec' => $text{'systemd_timeraccuracysec'},
			);
		foreach my $o ('timer_onbootsec', 'timer_onunitactivesec',
			       'timer_randomizeddelaysec',
			       'timer_accuracysec') {
			!$in{$o} || valid_duration($in{$o}) ||
				error(text('systemd_eduration', $timer_labels{$o}));
			}
		!$in{'timer_unit'} || valid_unit_name($in{'timer_unit'}) ||
			error($text{'systemd_etimerunit'});
		my $has_timer = $in{'timer_oncalendar'} ||
				$in{'timer_onbootsec'} ||
				$in{'timer_onunitactivesec'} ||
				$in{'timer_persistent'} ||
				$in{'timer_randomizeddelaysec'} ||
				$in{'timer_accuracysec'} ||
				$in{'timer_unit'};
		my $has_trigger = $in{'timer_oncalendar'} ||
				  $in{'timer_onbootsec'} ||
				  $in{'timer_onunitactivesec'};
		$has_trigger || $raw_unitconf =~ /\S/ ||
			error($text{'systemd_etimertrigger'});
		$structured_body = render_timer_body({
			'oncalendar' => $in{'timer_oncalendar'},
			'onbootsec' => $in{'timer_onbootsec'},
			'onunitactivesec' => $in{'timer_onunitactivesec'},
			'persistent' => $in{'timer_persistent'},
			'randomizeddelaysec' =>
				$in{'timer_randomizeddelaysec'},
			'accuracysec' => $in{'timer_accuracysec'},
			'unit' => $in{'timer_unit'},
			}) if ($has_timer);
		}
	elsif ($unittype eq 'socket') {
		# User managers create filesystem sockets as the owning user.
		if ($user_scope) {
			$in{'socket_user'} = "";
			$in{'socket_group'} = "";
			}
		foreach my $o ('socket_listenstream',
			       'socket_listendatagram') {
			!$in{$o} || $in{$o} =~ /^\S+$/ ||
				error($text{'systemd_esocketlisten'});
			}
		!$in{'socket_listenfifo'} ||
			valid_path($in{'socket_listenfifo'}, 0, 0, 0) ||
			error(text('systemd_epath',
				   $text{'systemd_socketlistenfifo'}));
		!$in{'socket_mode'} || $in{'socket_mode'} =~ /^[0-7]{3,4}$/ ||
			error($text{'systemd_esocketmode'});
		!$in{'socket_service'} ||
			(valid_unit_name($in{'socket_service'}) &&
			 $in{'socket_service'} =~ /\.service$/) ||
			error($text{'systemd_esocketservice'});
		my $has_listener = $in{'socket_listenstream'} ||
				   $in{'socket_listendatagram'} ||
				   $in{'socket_listenfifo'};
		$has_listener || $raw_unitconf =~ /\S/ ||
			error($text{'systemd_esocketlisten'});
		my $has_socket = $has_listener || $in{'socket_accept'} ||
				 $in{'socket_user'} || $in{'socket_group'} ||
				 $in{'socket_mode'} || $in{'socket_service'};
		$structured_body = render_socket_body({
			'listenstream' => $in{'socket_listenstream'},
			'listendatagram' => $in{'socket_listendatagram'},
			'listenfifo' => $in{'socket_listenfifo'},
			'accept' => $in{'socket_accept'},
			'user' => $in{'socket_user'},
			'group' => $in{'socket_group'},
			'mode' => $in{'socket_mode'},
			'service' => $in{'socket_service'},
			}) if ($has_socket);
		}
	elsif ($unittype eq 'path') {
		my %path_labels = (
			'path_exists' => $text{'systemd_pathexists'},
			'path_existsglob' => $text{'systemd_pathexistsglob'},
			'path_changed' => $text{'systemd_pathchanged'},
			'path_modified' => $text{'systemd_pathmodified'},
			'path_directorynotempty' =>
				$text{'systemd_pathdirectorynotempty'},
			);
		foreach my $o ('path_exists', 'path_existsglob',
			       'path_changed', 'path_modified',
			       'path_directorynotempty') {
			!$in{$o} || valid_path($in{$o}, 0, 0, 0) ||
				error(text('systemd_epath', $path_labels{$o}));
			}
		!$in{'path_unit'} || valid_unit_name($in{'path_unit'}) ||
			error($text{'systemd_epathunit'});
		my $has_path = $in{'path_exists'} || $in{'path_existsglob'} ||
			       $in{'path_changed'} ||
			       $in{'path_modified'} ||
			       $in{'path_directorynotempty'};
		$has_path || $raw_unitconf =~ /\S/ ||
			error($text{'systemd_epathtrigger'});
		$structured_body = render_path_body({
			'exists' => $in{'path_exists'},
			'existsglob' => $in{'path_existsglob'},
			'changed' => $in{'path_changed'},
			'modified' => $in{'path_modified'},
			'directorynotempty' => $in{'path_directorynotempty'},
			'makedirectory' => $in{'path_makedirectory'},
			'unit' => $in{'path_unit'},
			}) if ($has_path || $in{'path_makedirectory'} ||
			       $in{'path_unit'});
		}
	elsif ($unittype eq 'mount' &&
	    ($in{'mount_what'} || $in{'mount_where'} ||
	     $in{'mount_type'} || $in{'mount_options'})) {
		$in{'mount_what'} =~ /\S/ ||
			error($text{'systemd_emountwhat'});
		valid_path($in{'mount_where'}, 0, 0, 0) ||
			error(text('systemd_epath',
				   $text{'systemd_mountwhere'}));
		$derived_name = path_unit_name($in{'mount_where'}, 'mount') ||
			error(text('systemd_epath',
				   $text{'systemd_mountwhere'}));
		$structured_body = render_mount_body(
			$in{'mount_what'}, $in{'mount_where'},
			$in{'mount_type'}, $in{'mount_options'});
		}
	elsif ($unittype eq 'automount' &&
	       ($in{'automount_mount'} || $in{'automount_where'} ||
		$in{'automount_idle'} || $in{'automount_mode'})) {
		my $selected = $in{'automount_mount'};
		if ($selected) {
			valid_creatable_unit_name($selected, $user_scope) &&
				$selected =~ /\.mount$/ ||
				error($text{'systemd_eautomountmount'});
			my ($mount) = grep { $_->{'name'} eq $selected } @units;
			$mount || error($text{'systemd_eautomountmount'});
			$in{'automount_where'} = mount_unit_where(
				$mount, $user_scope ? $unituser : undef);
			}
		valid_path($in{'automount_where'}, 0, 0, 0) ||
			error(text('systemd_epath',
				   $text{'systemd_automountwhere'}));
		!$in{'automount_idle'} || valid_duration($in{'automount_idle'}) ||
			error(text('systemd_eduration',
				   $text{'systemd_automountidle'}));
		!$in{'automount_mode'} ||
			$in{'automount_mode'} =~ /^[0-7]{3,4}$/ ||
			error($text{'systemd_eautomountmode'});
		my $mount_name =
			path_unit_name($in{'automount_where'}, 'mount') ||
			error(text('systemd_epath',
				   $text{'systemd_automountwhere'}));
		my ($mount) = grep { $_->{'name'} eq $mount_name } @units;
		$mount || error($text{'systemd_eautomountmount'});
		$derived_name =
			path_unit_name($in{'automount_where'}, 'automount') ||
			error(text('systemd_epath',
				   $text{'systemd_automountwhere'}));
		$structured_body = render_automount_body(
			$in{'automount_where'}, $in{'automount_idle'},
			$in{'automount_mode'});
		}
	elsif ($unittype eq 'swap') {
		!$in{'swap_what'} || valid_path($in{'swap_what'}, 0, 0, 0) ||
			error(text('systemd_epath', $text{'systemd_swapwhat'}));
		!$in{'swap_priority'} || $in{'swap_priority'} =~ /^-?\d+$/ ||
			error($text{'systemd_eswappriority'});
		!$in{'swap_timeoutsec'} || valid_duration($in{'swap_timeoutsec'}) ||
			error(text('systemd_eduration',
				   $text{'systemd_swaptimeoutsec'}));
		$in{'swap_what'} || $raw_unitconf =~ /\S/ ||
			error($text{'systemd_eswapwhat'});
		$structured_body = render_swap_body({
			'what' => $in{'swap_what'},
			'priority' => $in{'swap_priority'},
			'options' => $in{'swap_options'},
			'timeoutsec' => $in{'swap_timeoutsec'},
			}) if ($in{'swap_what'} || $in{'swap_priority'} ||
			       $in{'swap_options'} || $in{'swap_timeoutsec'});
		}
	elsif ($unittype eq 'slice') {
		foreach my $o ('slice_cpuweight', 'slice_ioweight') {
			!$in{$o} || ($in{$o} =~ /^\d+$/ &&
				     $in{$o} >= 1 && $in{$o} <= 10000) ||
				error($text{'systemd_esliceweight'});
			}
		foreach my $o ('slice_memorymax', 'slice_tasksmax') {
			!$in{$o} || $in{$o} =~ /^(infinity|\S+)$/ ||
				error($text{'systemd_eslicelimit'});
			}
		$structured_body = render_slice_body({
			'cpuweight' => $in{'slice_cpuweight'},
			'memorymax' => $in{'slice_memorymax'},
			'tasksmax' => $in{'slice_tasksmax'},
			'ioweight' => $in{'slice_ioweight'},
			}) if ($in{'slice_cpuweight'} ||
			       $in{'slice_memorymax'} ||
			       $in{'slice_tasksmax'} ||
			       $in{'slice_ioweight'});
		}
	$in{'name'} ||= $derived_name if ($derived_name);

	# Users may type the suffix or choose it from the dropdown; keep them equal.
	my $creatable_piped = join('|', map { quotemeta($_) }
				       @creatable_unit_types);
	if ($in{'name'} =~ /\.($creatable_piped)$/i) {
		lc($1) eq $unittype || error($text{'systemd_eunittype'});
		$in{'name'} =~ s/\.($creatable_piped)$/\.$unittype/i;
		}
	else {
		$in{'name'} .= ".".$unittype;
		}
	valid_creatable_unit_name($in{'name'}, $user_scope) ||
		error($text{'systemd_ename'});
	if ($derived_name && $in{'name'} ne $derived_name) {
		error($unittype eq 'mount' ?
		      $text{'systemd_emountname'} :
		      $text{'systemd_eautomountname'});
		}

	# Refuse to overwrite an existing unit in the selected manager.
	my ($clash) = grep { $_->{'name'} eq $in{'name'} } @units;
	$clash && error($text{'systemd_eclash'});
	$in{'desc'} || error($text{'systemd_edesc'});

	# Services use explicit command fields; other unit types accept only the
	# body of their type-specific section, which is wrapped server-side.
	if ($unittype eq 'service') {
		$in{'atstart'} =~ /\S/ || error($text{'systemd_estart'});
		}
	else {
		$in{'unitconf'} = "";
		if (defined($structured_body) && $structured_body =~ /\S/) {
			$in{'unitconf'} = $structured_body;
			$in{'unitconf'} .= "\n" if ($raw_unitconf =~ /\S/);
			}
		$in{'unitconf'} .= $raw_unitconf;
		my %empty_ok = ( 'target' => 1, 'slice' => 1 );
		$empty_ok{$unittype} || $in{'unitconf'} =~ /\S/ ||
			error($text{'systemd_eunitconf'});
		}

	# Parse optional scalar settings into %opts.
	my %opts;
	$in{'restart'} = $in{'restart_policy'}
		if ($in{'new'} && defined($in{'restart_policy'}));

	# These options map to single-line unit directives, so line breaks collapse.
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

	# Reload and PID file use dedicated service fields rather than %opts.
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
		# Validate duration-like values before writing them to the unit file.
		foreach my $o ('restartsec', 'watchdogsec', 'timeout',
			       'timeoutstartsec', 'timeoutstopsec') {
			!$opts{$o} || valid_duration($opts{$o}) ||
				error(text('systemd_eduration', $duration_text{$o}));
			}
		!$in{'pidfile'} || valid_path($in{'pidfile'}, 0, 0) ||
			error(text('systemd_epath', $text{'systemd_pidfile'}));
		!$opts{'workdir'} || valid_path($opts{'workdir'}, 1, 1) ||
			error(text('systemd_epath', $text{'systemd_workdir'}));
		!$opts{'envfile'} || valid_path($opts{'envfile'}, 1, 0) ||
			error(text('systemd_epath', $text{'systemd_envfile'}));
		!$opts{'limitnofile'} ||
			$opts{'limitnofile'} =~ /^(infinity|\d+)(:(infinity|\d+))?$/i ||
			error($text{'systemd_elimitnofile'});
		foreach my $o ('logstd', 'logerr') {
			!$opts{$o} || valid_output($opts{$o}) ||
				error(text('systemd_eoutput', $text{'systemd_'.$o}));
			}
		!$opts{'protectsystem'} ||
			$opts{'protectsystem'} =~ /^(true|full|strict)$/ ||
			error($text{'systemd_eprotectsystem'});

		# ReadWritePaths can contain several shell-style path words.
		if ($opts{'readwritepaths'}) {
			foreach my $p (split_quoted_string($opts{'readwritepaths'})) {
				valid_path($p, 1, 0, 1) ||
					error(text('systemd_ereadwritepath', $p));
				}
			}
		}

	# User units already run as the owning user, so User=/Group= must not be
	# written into the unit file.
	if ($user_scope) {
		delete($opts{'user'});
		delete($opts{'group'});
		}
	$opts{'wantedby'} ||= get_default_install_target(
		$unittype, $user_scope);

	# Render the unit once, then write the same bytes to the selected scope.
	my %unit = ( 'type' => $unittype,
		     'description' => $in{'desc'},
		     'options' => \%opts );
	if ($unittype eq 'service') {
		$unit{'service'} = { 'start' => $in{'atstart'},
				     'stop' => $in{'atstop'},
				     'reload' => $in{'reload'},
				     'pidfile' => $in{'pidfile'},
				     'remain' => $in{'remain'} };
		}
	else {
		$unit{'body'} = $in{'unitconf'};
		}
	my $unit_data = render_unit(\%unit);

	# Create the unit file in the selected scope. When requested, linger is
	# enabled first so daemon-reload has a user manager to talk to.
	if ($user_scope) {
		# Linger is optional on create, but enabling it also starts the manager.
		if ($in{'linger'}) {
			systemd_can_linger($unituser) ||
				systemd_acl_error('plinger');
			my ($lok, $lout) = set_user_linger($unituser, 1);
			$lok || error_user_command($unituser, $lout);
			my ($mok, $mout) = start_user_manager($unituser);
			$mok || error_user_command($unituser, $mout);
			}
		my ($ok, $out, $kind) = create_user_unit(
			$unituser, $in{'name'}, $unit_data);
		if (!$ok) {
			$kind && $kind ne 'command' ?
				error($out) : error_user_command($unituser, $out);
			}
		}
	else {
		# System-scope units are written under the local systemd unit root.
		my ($ok, $out) = create_system_unit($in{'name'}, $unit_data);
		$ok || error($out);
		}

	# Enable or disable startup after the unit has been written and reloaded.
	if (defined($in{'boot'}) &&
	    systemd_can_boot($user_scope, $unituser)) {
		if ($user_scope) {
			my ($ok, $out);

			# User enable/disable failures include the systemctl output.
			if ($in{'boot'} == 0) {
				($ok, $out) =
					disable_user_unit($unituser,
							  $in{'name'});
				}
			else {
				($ok, $out) =
					enable_user_unit($unituser,
							 $in{'name'});
				}
			$ok || error_user_command($unituser, $out);
			}
		else {
			# System enable/disable uses the existing Webmin error path.
			if ($in{'boot'} == 0) {
				my ($ok, $out) = disable_unit($in{'name'});
				$ok || error($out);
				}
			else {
				my ($ok, $out) = enable_unit($in{'name'});
				$ok || error($out);
				}
			}
		}

	# Log the create event, then return to the configured destination.
	if ($user_scope) {
		webmin_log("create", "systemd-user", $in{'name'},
			    { 'user' => $unituser });
		}
	else {
		webmin_log("create", "systemd", $in{'name'});
		}

	if ($config{'create_return_index'} eq '1') {
		$redirect = index_url($in{'name'}, $user_scope, $unituser);
		}
	elsif ($user_scope) {
		$redirect = "edit_unit.cgi?scope=user&unituser=".
			urlize($unituser)."&name=".urlize($in{'name'});
		}
	else {
		$redirect = "edit_unit.cgi?name=".urlize($in{'name'});
		}
	}
else {
	# Save the raw unit file contents from the edit form.
	my $can_save_unit = $edit_dropin ?
		systemd_can_dropin($user_scope, $unituser) :
		systemd_can_edit($user_scope, $unituser);
	$can_save_unit ||
		systemd_acl_error($edit_dropin ?
			($user_scope ? 'pdropin_user' : 'pdropin') :
			($user_scope ? 'pedit_user' : 'pedit'));
	if (!unit_file_editable($u)) {
		error($text{'systemd_ereadonly'});
		}
	$in{'data'} =~ /\S/ || error($text{'systemd_econf'});
	$in{'data'} =~ s/\r//g;
	my $save_data = $edit_dropin ?
		dropin_effective_data($in{'data'}) : $in{'data'};
	my $base_data;
	my ($vok, $vout);
	if ($edit_dropin) {
		# Drop-ins are verified together with the base unit they override.
		$base_data = $user_scope ?
			read_user_unit_file($unituser, $u->{'file'}) :
			read_file_contents($u->{'file'});
		defined($base_data) ||
			error($user_scope ? $text{'systemd_euserunitfile'} :
					    $text{'manual_eread'});
		($vok, $vout) =
			verify_dropin_data($u->{'file'}, $base_data,
					   $save_data, $user_scope,
					   $u->{'unitstate'}, $unituser);
		}
	else {
		# Full unit edits are verified directly under their unit basename.
		($vok, $vout) =
			verify_unit_data($u->{'file'}, $save_data,
					 $user_scope, $unituser);
		}
	$vok || error($vout);
	if ($user_scope) {
		# User unit writes go through a privilege-dropped helper.  Linger is
		# disabled only after daemon-reload succeeds, so the reload is not cut
		# off from the user manager.
		my $disable_linger;
		my ($wok, $wout) = $edit_dropin && $dropin_file ?
			write_user_dropin_config_file($unituser, $dropin_file,
						      $save_data) :
			$edit_dropin ?
			write_user_dropin_file($unituser, $in{'name'},
					       $save_data) :
			write_user_unit_file($unituser, $u->{'file'},
					     $save_data);
		$wok || error($wout);

		# Enabling linger happens before reload; disabling waits until after.
		if (defined($in{'linger'})) {
			systemd_can_linger($unituser) ||
				systemd_acl_error('plinger');
			if ($in{'linger'}) {
				my ($lok, $lout) =
					set_user_linger($unituser, 1);
				$lok || error_user_command($unituser, $lout);
				my ($mok, $mout) =
					start_user_manager($unituser);
				$mok || error_user_command($unituser, $mout);
				}
			else {
				$disable_linger = 1;
				}
			}
		my ($ok, $out) = reload_user_manager($unituser);
		$ok || error_user_command($unituser, $out);

		# Disable linger only after the user manager has accepted daemon-reload.
		if ($disable_linger) {
			my ($lok, $lout) = set_user_linger($unituser, 0);
			$lok || error_user_command($unituser, $lout);
			}
		}
	else {
		# System units are root-owned and can be updated directly.
		if ($edit_dropin && $dropin_file) {
			my ($wok, $wout) =
				write_system_dropin_config_file($dropin_file,
								$save_data);
			$wok || error($wout);
			}
		elsif ($edit_dropin) {
			my ($wok, $wout) =
				write_system_dropin_file($in{'name'},
							  $save_data);
			$wok || error($wout);
			}
		else {
			my $conf_fh = gensym();
			open_lock_tempfile($conf_fh, ">$u->{'file'}");
			print_tempfile($conf_fh, $save_data);
			close_tempfile($conf_fh);
			}
		reload_manager();
		}

	# Apply startup state changes after saving the config.
	if (defined($in{'boot'}) &&
	    boot_state_changeable($u->{'unitstate'}, $u->{'name'})) {
		systemd_can_boot($user_scope, $unituser) ||
			systemd_acl_error('pboot');
		if ($user_scope) {
			my ($ok, $out);

			# Startup state is managed through the same scoped manager as edit.
			if ($in{'boot'} == 0) {
				($ok, $out) =
					disable_user_unit(
						$unituser, $in{'name'});
				}
			else {
				($ok, $out) =
					enable_user_unit(
						$unituser, $in{'name'});
				}
			$ok || error_user_command($unituser, $out);
			}
		else {
			# System-unit startup state is independent of the raw file write.
			if ($in{'boot'} == 0) {
				my ($ok, $out) =
					disable_unit($in{'name'});
				$ok || error($out);
				}
			else {
				my ($ok, $out) =
					enable_unit($in{'name'});
				$ok || error($out);
				}
			}
		}

	# Log the edit and return to the same scoped edit page.
	if ($user_scope) {
		webmin_log("modify", "systemd-user", $in{'name'},
			    { 'user' => $unituser });
		$redirect = "edit_unit.cgi?scope=user&unituser=".
			urlize($unituser)."&name=".urlize($in{'name'}).
			($edit_dropin ? "&dropin=1" : "").
			($dropin_file ? "&dropfile=".urlize($dropin_file) : "");
		}
	else {
		webmin_log("modify", "systemd", $in{'name'});
		$redirect = "edit_unit.cgi?name=".urlize($in{'name'}).
			($edit_dropin ? "&dropin=1" : "").
			($dropin_file ? "&dropfile=".urlize($dropin_file) : "");
		}
	}
redirect($redirect || "");

# error_user_command(user, output)
# Shows a systemctl --user or loginctl failure with escaped command output.
sub error_user_command
{
my ($user, $out) = @_;
$out ||= $text{'systemd_euser'};

# Show command output as escaped preformatted text for easier diagnosis.
error(text('systemd_eusercmd',
	     ui_tag('tt', html_escape($user)),
	     ui_tag('pre', html_escape($out))));
}
