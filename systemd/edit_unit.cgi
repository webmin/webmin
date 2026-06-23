#!/usr/local/bin/perl
# Show a form for creating, editing or viewing a systemd unit

use strict;
use warnings;

require './systemd-lib.pl'; ## no critic

our (%access, %config, %in, %text, $remote_user);

# Returns safe extra attributes for create-form placeholders.
sub placeholder_tags
{
my ($text, $tags) = @_;
my $rv = "placeholder=\"".quote_escape($text)."\"";
$rv .= " ".$tags if ($tags);
return $rv;
}

# Returns a create-form text box with a short example placeholder.
sub placeholder_textbox
{
my ($name, $value, $size, $placeholder) = @_;
return ui_textbox($name, $value, $size, undef, undef,
		  placeholder_tags($placeholder));
}

# Returns a create-form file box with a path-style placeholder.
sub placeholder_filebox
{
my ($name, $value, $size, $placeholder, $dironly) = @_;
return ui_filebox($name, $value, $size, undef, undef,
		  placeholder_tags($placeholder), $dironly);
}

# Returns a create-form text area with a command or directive example.
sub placeholder_textarea
{
my ($name, $value, $rows, $cols, $placeholder, $tags) = @_;
return ui_textarea($name, $value, $rows, $cols, undef, undef,
		   placeholder_tags($placeholder, $tags));
}

# Returns example home and runtime paths for user-scope placeholders.
sub user_scope_example_paths
{
my ($user) = @_;
my $uinfo = get_user_details($user);
my $home = $uinfo ? $uinfo->{'home'} : "/home/my-user";
my $runtime = $uinfo ? "/run/user/".$uinfo->{'uid'} : $home."/run";
return ($home, $runtime);
}

# Returns path-unit placeholders appropriate for system or user scope.
sub path_unit_placeholders
{
my ($user_scope, $user) = @_;
my %rv = (
	'exists' => "/run/my-app.ready",
	'existsglob' => "/var/spool/my-app/*.job",
	'changed' => "/etc/my-app.conf",
	'modified' => "/etc/my-app.d",
	'directorynotempty' => "/var/spool/my-app",
	);
if ($user_scope) {
	my ($home, $runtime) = user_scope_example_paths($user);
	%rv = (
		'exists' => $runtime."/my-app.ready",
		'existsglob' => $home."/spool/my-app/*.job",
		'changed' => $home."/.config/my-app.conf",
		'modified' => $home."/.config/my-app.d",
		'directorynotempty' => $home."/spool/my-app",
		);
	}
return \%rv;
}

# Returns service-file placeholders appropriate for system or user scope.
sub service_unit_placeholders
{
my ($user_scope, $user) = @_;
my %rv = (
	'pidfile' => "/run/my-app.pid",
	'envfile' => "-/etc/default/my-app",
	'workdir' => "/srv/my-app",
	'readwritepaths' => "/var/lib/my-app",
	'startpre' => "/usr/bin/install -d /run/my-app",
	'stoppost' => "/usr/bin/rm -f /run/my-app.pid",
	);
if ($user_scope) {
	my ($home, $runtime) = user_scope_example_paths($user);
	%rv = (
		'pidfile' => $runtime."/my-app.pid",
		'envfile' => "-".$home."/.config/my-app/env",
		'workdir' => $home."/my-app",
		'readwritepaths' => $home."/my-app",
		'startpre' => "/usr/bin/install -d ".$runtime."/my-app",
		'stoppost' => "/usr/bin/rm -f ".$runtime."/my-app.pid",
		);
	}
return \%rv;
}

# Returns socket placeholders appropriate for system or user scope.
sub socket_unit_placeholders
{
my ($user_scope, $user) = @_;
my %rv = ( 'listenfifo' => "/run/my-app.fifo" );
if ($user_scope) {
	my (undef, $runtime) = user_scope_example_paths($user);
	$rv{'listenfifo'} = $runtime."/my-app.fifo";
	}
return \%rv;
}

ReadParse();

# Work out whether this page is creating or editing a user-scoped unit.
# User-scope units live in the selected Unix user's systemd manager.
my $unituser = clean_unit_value($in{'unituser'} || $in{'user'});
my $edit_user_scope = !$in{'new'} && $in{'scope'} eq 'user' ? 1 : 0;
my $create_default_user_scope = $in{'new'} && !defined($in{'scope'}) &&
	$config{'default_create_scope'} eq 'user' ? 1 : 0;
my $create_user_scope = $in{'new'} &&
	(($in{'scope'} || "") eq 'user' || $create_default_user_scope) ? 1 : 0;
my $edit_dropin = !$in{'new'} && $in{'dropin'} ? 1 : 0;
my $dropin_file = $edit_dropin ? clean_unit_value($in{'dropfile'}) : "";
my $dropin_info;
if ($in{'new'} && $create_user_scope && !$unituser) {
	$unituser = systemd_acl_default_user() || "";
	if (!$unituser) {
		my $ruinfo = get_user_details($remote_user);
		$unituser = $ruinfo->{'user'}
			if ($ruinfo && $ruinfo->{'uid'} != 0);
		}
	}
if (!$in{'new'}) {
	valid_unit_name($in{'name'}) ||
		error($text{'systemd_ename'});
	}
my ($u, $conf);
my (@units, @unittypes, @types, @killmodes, @restarts, @protects);
my (%creatable_types);
my $default_unittype = 'service';
my $unit_file_editable = 0;
my $can_save_unit = 0;
my $remote_uinfo = get_user_details($remote_user);

# New units start with an empty record.  Existing units are looked up from the
# selected system or user scope so edits cannot cross scopes accidentally.
if ($in{'new'}) {
	systemd_can_create($create_user_scope,
			   $create_user_scope ? $unituser : undef) ||
		systemd_acl_error($create_user_scope ?
				  'pcreate_user' : 'pcreate');
	# The create form renders structured fields instead of raw unit contents.
	ui_print_header(undef, $text{'systemd_title1'}, "");
	$u = { };
	}
else {
	# Editing keeps the unit in its current system or user manager.
	if ($edit_user_scope) {
		# The owner must be a real Unix user before we inspect their units.
		get_user_details($unituser) ||
			error($text{'systemd_euser'});
		systemd_can_view_scope(1, $unituser) ||
			systemd_acl_error('pview_user');
		@units = list_user_units($unituser);
		}
	else {
		# System-scope edits use the system unit list.
		systemd_can_view_scope(0) ||
			systemd_acl_error('pview');
		@units = list_units();
		}

	# Reject stale edit links after units have been deleted or renamed.
	($u) = grep { $_->{'name'} eq $in{'name'} } @units;
	$u || error($text{'systemd_egone'});
	if ($edit_dropin && $dropin_file) {
		$dropin_info = $edit_user_scope ?
			user_dropin_config_file_info($unituser, $dropin_file) :
			system_dropin_config_file_info($dropin_file);
		$dropin_info && $dropin_info->{'unit'} eq $in{'name'} ||
			error($text{'systemd_edropinfile'});
		$dropin_file = $dropin_info->{'file'};
		}
	$unit_file_editable = unit_file_editable($u);
	$can_save_unit = $edit_dropin ?
		systemd_can_dropin($edit_user_scope, $unituser) :
		systemd_can_edit($edit_user_scope, $unituser);

	# Runtime-managed units are inspect-only, so title them as views.
	my $title_key = $unit_file_editable && $can_save_unit ?
		($edit_user_scope ? 'systemd_title2_user' : 'systemd_title2') :
		($edit_user_scope ? 'systemd_title2_view_user' :
				    'systemd_title2_view');
	ui_print_header(undef, $text{$title_key}, "");
	}

# The save script uses hidden scope fields to pick the correct control plane
# for later actions, including status/log redirects.
print ui_form_start("save_unit.cgi", "post");
print ui_hidden("new", $in{'new'});
print ui_hidden("scope", "user") if ($edit_user_scope);
print ui_hidden("unituser", $unituser) if ($edit_user_scope);
print ui_hidden("name", $in{'name'}) if (!$in{'new'});
print ui_hidden("dropin", 1) if ($edit_dropin);
print ui_hidden("dropfile", $dropin_file) if ($edit_dropin && $dropin_file);
if ($in{'new'}) {
	# The first table contains the fields that almost every new unit needs.
	print ui_table_start($text{'systemd_header'}, undef, 2);

	# Unit type and name.  The suffix is displayed separately, but the save
	# script appends or validates it before writing the unit file.
	my @creatable_unit_types = get_creatable_unit_types($create_user_scope);
	@unittypes = map { [ $_, $text{'systemd_type_'.$_} || $_ ] }
		      @creatable_unit_types;
	%creatable_types = map { $_, 1 } @creatable_unit_types;
	$default_unittype = $creatable_types{$in{'unittype'}} ?
		$in{'unittype'} : "service";
	my $type_help = $create_user_scope ?
		"systemd_type_user" : "systemd_type";
	print ui_table_row(hlink($text{'systemd_type'}, $type_help),
			    ui_select("unittype", $default_unittype, \@unittypes,
				       1, 0, 0, 0));
	print ui_table_hr();
	print ui_table_row(hlink($text{'systemd_name'}, "systemd_name"),
			    placeholder_textbox("name", undef, 30, "my-app").
			    ui_tag('tt', ".$default_unittype",
				    { 'id' => 'systemd_name_suffix' }));

	# Every new unit needs a Description= line.
	print ui_table_row(hlink($text{'systemd_desc'}, "systemd_desc"),
			    placeholder_textbox("desc", undef, 60,
						"My app service"));

	# Existing mount units can be paired with a new automount, so the user
	# does not need to derive the automount name by hand.
	my @mount_units;
	if ($create_user_scope && get_user_details($unituser)) {
		@mount_units = grep { $_->{'name'} =~ /\.mount$/ }
			       list_user_units($unituser);
		}
	elsif (!$create_user_scope) {
		@mount_units = grep { $_->{'name'} =~ /\.mount$/ }
			       list_units();
		}
	my @automount_mounts = ( [ '', $text{'systemd_automountmount_none'} ] );
	foreach my $mu (sort { $a->{'name'} cmp $b->{'name'} } @mount_units) {
		my $where = mount_unit_where(
			$mu, $create_user_scope ? $unituser : undef);
		my $label = $mu->{'name'}.
			($where ? " (".$where.")" : "");
		push(@automount_mounts, [ $mu->{'name'}, html_escape($label) ]);
		}

	# Service units use command fields rather than raw [Service] body text.
	print ui_table_row(hlink($text{'systemd_start'}, "systemd_start"),
			    placeholder_textarea("atstart", undef, 5, 80,
				"/usr/bin/my-app --foreground"),
			    1, undef, [ "data-systemd-service='1'" ]);

	# The stop command is optional; the save page can generate a default.
	print ui_table_row(hlink($text{'systemd_stop'}, "systemd_stop"),
			    placeholder_textarea("atstop", undef, 5, 80,
				"/bin/kill -TERM \$MAINPID"),
			    1, undef, [ "data-systemd-service='1'" ]);

	# Timer units can be created from common activation fields.  More unusual
	# timer directives remain available in the advanced body editor below.
	my @timer_row = ( "data-systemd-timer='1' style='display:none'" );
	print ui_table_row(hlink($text{'systemd_timeroncalendar'},
				 "systemd_timeroncalendar"),
			    placeholder_textbox("timer_oncalendar", undef, 40,
						"daily"),
			    1, undef, \@timer_row);
	print ui_table_row(hlink($text{'systemd_timeronbootsec'},
				 "systemd_timeronbootsec"),
			    placeholder_textbox("timer_onbootsec", undef, 10,
						"5min"),
			    1, undef, \@timer_row);
	print ui_table_row(hlink($text{'systemd_timeronunitactivesec'},
				 "systemd_timeronunitactivesec"),
			    placeholder_textbox("timer_onunitactivesec", undef,
						10, "1h"),
			    1, undef, \@timer_row);
	print ui_table_row(hlink($text{'systemd_timerpersistent'},
				 "systemd_timerpersistent"),
			    ui_yesno_radio("timer_persistent", 0),
			    1, undef, \@timer_row);
	print ui_table_row(hlink($text{'systemd_timerrandomizeddelaysec'},
				 "systemd_timerrandomizeddelaysec"),
			    placeholder_textbox("timer_randomizeddelaysec", undef,
						10, "10min"),
			    1, undef, \@timer_row);
	print ui_table_row(hlink($text{'systemd_timeraccuracysec'},
				 "systemd_timeraccuracysec"),
			    placeholder_textbox("timer_accuracysec", undef, 10,
						"1min"),
			    1, undef, \@timer_row);
	print ui_table_row(hlink($text{'systemd_timerunit'},
				 "systemd_timerunit"),
			    placeholder_textbox("timer_unit", undef, 40,
						"my-job.service"),
			    1, undef, \@timer_row);

	# Socket units expose the usual listeners and ownership controls.
	my @socket_row = ( "data-systemd-socket='1' style='display:none'" );
	my $socket_placeholders =
		socket_unit_placeholders($create_user_scope, $unituser);
	print ui_table_row(hlink($text{'systemd_socketlistenstream'},
				 "systemd_socketlistenstream"),
			    placeholder_textbox("socket_listenstream", undef, 40,
						"127.0.0.1:8080"),
			    1, undef, \@socket_row);
	print ui_table_row(hlink($text{'systemd_socketlistendatagram'},
				 "systemd_socketlistendatagram"),
			    placeholder_textbox("socket_listendatagram", undef,
						40, "10514"),
			    1, undef, \@socket_row);
	print ui_table_row(hlink($text{'systemd_socketlistenfifo'},
				 "systemd_socketlistenfifo"),
			    placeholder_filebox("socket_listenfifo", undef, 50,
						$socket_placeholders->{'listenfifo'}, 1),
			    1, undef, \@socket_row);
	print ui_table_row(hlink($text{'systemd_socketaccept'},
				 "systemd_socketaccept"),
			    ui_yesno_radio("socket_accept", 0),
			    1, undef, \@socket_row);
	print ui_table_row(hlink($text{'systemd_socketuser'},
				 "systemd_socketuser"),
			    placeholder_textbox("socket_user", undef, 20,
						"appuser")." ".
			    user_chooser_button("socket_user"),
			    1, undef, [ "id='systemd_socket_user_row' ".
				"data-systemd-socket='1' style='display:none'" ]);
	print ui_table_row(hlink($text{'systemd_socketgroup'},
				 "systemd_socketgroup"),
			    placeholder_textbox("socket_group", undef, 20,
						"appgroup")." ".
			    group_chooser_button("socket_group"),
			    1, undef, [ "id='systemd_socket_group_row' ".
				"data-systemd-socket='1' style='display:none'" ]);
	print ui_table_row(hlink($text{'systemd_socketmode'},
				 "systemd_socketmode"),
			    placeholder_textbox("socket_mode", undef, 10, "0660"),
			    1, undef, \@socket_row);
	print ui_table_row(hlink($text{'systemd_socketservice'},
				 "systemd_socketservice"),
			    placeholder_textbox("socket_service", undef, 40,
						"my-app.service"),
			    1, undef, \@socket_row);

	# Path units watch files or directories and activate another unit.
	my @path_row = ( "data-systemd-path='1' style='display:none'" );
	my $path_placeholders =
		path_unit_placeholders($create_user_scope, $unituser);
	print ui_table_row(hlink($text{'systemd_pathexists'},
				 "systemd_pathexists"),
			    placeholder_filebox("path_exists", undef, 50,
						$path_placeholders->{'exists'}, 1),
			    1, undef, \@path_row);
	print ui_table_row(hlink($text{'systemd_pathexistsglob'},
				 "systemd_pathexistsglob"),
			    placeholder_textbox("path_existsglob", undef, 50,
						$path_placeholders->{'existsglob'}),
			    1, undef, \@path_row);
	print ui_table_row(hlink($text{'systemd_pathchanged'},
				 "systemd_pathchanged"),
			    placeholder_filebox("path_changed", undef, 50,
						$path_placeholders->{'changed'}, 1),
			    1, undef, \@path_row);
	print ui_table_row(hlink($text{'systemd_pathmodified'},
				 "systemd_pathmodified"),
			    placeholder_filebox("path_modified", undef, 50,
						$path_placeholders->{'modified'}, 1),
			    1, undef, \@path_row);
	print ui_table_row(hlink($text{'systemd_pathdirectorynotempty'},
				 "systemd_pathdirectorynotempty"),
			    placeholder_filebox("path_directorynotempty", undef,
						50,
						$path_placeholders->{'directorynotempty'}, 1),
			    1, undef, \@path_row);
	print ui_table_row(hlink($text{'systemd_pathmakedirectory'},
				 "systemd_pathmakedirectory"),
			    ui_yesno_radio("path_makedirectory", 0),
			    1, undef, \@path_row);
	print ui_table_row(hlink($text{'systemd_pathunit'},
				 "systemd_pathunit"),
			    placeholder_textbox("path_unit", undef, 40,
						"my-app.service"),
			    1, undef, \@path_row);

	# Mount units have a small, stable set of required fields.  The unit name
	# can be derived from Where= on save.
	my @mount_row = ( "data-systemd-mount='1' style='display:none'" );
	print ui_table_row(hlink($text{'systemd_mountwhat'}, "systemd_mountwhat"),
			    placeholder_textbox("mount_what", undef, 60,
						"/dev/disk/by-uuid/abcd-1234"),
			    1, undef, \@mount_row);
	print ui_table_row(hlink($text{'systemd_mountwhere'}, "systemd_mountwhere"),
			    placeholder_filebox("mount_where", undef, 50,
						"/mnt/data", 1),
			    1, undef, \@mount_row);
	print ui_table_row(hlink($text{'systemd_mounttype'}, "systemd_mounttype"),
			    placeholder_textbox("mount_type", undef, 20, "ext4"),
			    1, undef, \@mount_row);
	print ui_table_row(hlink($text{'systemd_mountoptions'}, "systemd_mountoptions"),
			    placeholder_textbox("mount_options", undef, 60,
						"defaults,noatime"),
			    1, undef, \@mount_row);

	# Automount units activate a matching mount unit by path.  Selecting an
	# existing mount lets save_unit.cgi derive the automount name safely.
	my @automount_row = (
		"data-systemd-automount='1' style='display:none'" );
	print ui_table_row(hlink($text{'systemd_automountmount'},
				 "systemd_automountmount"),
			    ui_select("automount_mount", undef,
				      \@automount_mounts),
			    1, undef, \@automount_row);
	print ui_table_row(hlink($text{'systemd_automountwhere'},
				 "systemd_automountwhere"),
			    placeholder_filebox("automount_where", undef, 50,
						"/mnt/data", 1),
			    1, undef, \@automount_row);
	print ui_table_row(hlink($text{'systemd_automountidle'},
				 "systemd_automountidle"),
			    placeholder_textbox("automount_idle", undef, 10,
						"5min"),
			    1, undef, \@automount_row);
	print ui_table_row(hlink($text{'systemd_automountmode'},
				 "systemd_automountmode"),
			    placeholder_textbox("automount_mode", undef, 10,
						"0755"),
			    1, undef, \@automount_row);

	# Swap and slice units have a few common directives worth exposing.
	my @swap_row = ( "data-systemd-swap='1' style='display:none'" );
	print ui_table_row(hlink($text{'systemd_swapwhat'}, "systemd_swapwhat"),
			    placeholder_filebox("swap_what", undef, 50,
						"/swapfile", 1),
			    1, undef, \@swap_row);
	print ui_table_row(hlink($text{'systemd_swappriority'},
				 "systemd_swappriority"),
			    placeholder_textbox("swap_priority", undef, 10, "10"),
			    1, undef, \@swap_row);
	print ui_table_row(hlink($text{'systemd_swapoptions'},
				 "systemd_swapoptions"),
			    placeholder_textbox("swap_options", undef, 60,
						"discard"),
			    1, undef, \@swap_row);
	print ui_table_row(hlink($text{'systemd_swaptimeoutsec'},
				 "systemd_swaptimeoutsec"),
			    placeholder_textbox("swap_timeoutsec", undef, 10,
						"30s"),
			    1, undef, \@swap_row);
	my @slice_row = ( "data-systemd-slice='1' style='display:none'" );
	print ui_table_row(hlink($text{'systemd_slicecpuweight'},
				 "systemd_slicecpuweight"),
			    placeholder_textbox("slice_cpuweight", undef, 10,
						"200"),
			    1, undef, \@slice_row);
	print ui_table_row(hlink($text{'systemd_slicememorymax'},
				 "systemd_slicememorymax"),
			    placeholder_textbox("slice_memorymax", undef, 10,
						"512M"),
			    1, undef, \@slice_row);
	print ui_table_row(hlink($text{'systemd_slicetasksmax'},
				 "systemd_slicetasksmax"),
			    placeholder_textbox("slice_tasksmax", undef, 10,
						"500"),
			    1, undef, \@slice_row);
	print ui_table_row(hlink($text{'systemd_sliceioweight'},
				 "systemd_sliceioweight"),
			    placeholder_textbox("slice_ioweight", undef, 10,
						"200"),
			    1, undef, \@slice_row);

	# Startup state is applied after the unit is created.
	if (systemd_can_boot($create_user_scope,
			     $create_user_scope ? $unituser : undef)) {
		print ui_table_row(hlink($text{'systemd_boot'}, "systemd_boot"),
				    ui_yesno_radio("boot", 1));
		}

	# Pick a safe default owner for new user units when possible.
	my $default_unituser = $unituser;
	my $acl_default_unituser;
	if (!$default_unituser) {
		$acl_default_unituser =
			systemd_acl_default_user() || "";
		$default_unituser = $acl_default_unituser;
		if (!$default_unituser) {
			$default_unituser = $remote_uinfo->{'user'}
				if ($remote_uinfo &&
				    $remote_uinfo->{'uid'} != 0);
			}
		}
	my $force_user_scope_create = $create_user_scope &&
		!systemd_can_create(0) &&
		(($remote_uinfo && $remote_uinfo->{'uid'} != 0) ||
		 $acl_default_unituser) ? 1 : 0;
	my $force_user_scope_owner = $force_user_scope_create &&
		$default_unituser ? 1 : 0;
	# User units live in the selected user's home and run under that user's
	# systemd manager, so the service-level User=/Group= rows are hidden by JS.
	if ($force_user_scope_create) {
		print ui_hidden("userservice", 1);
		}
	else {
		print ui_table_row(hlink($text{'systemd_userservice'},
					 "systemd_userservice"),
				    ui_radio("userservice",
					     $create_user_scope ? 1 : 0,
					     [ [ 1, $text{'yes'} ],
					       [ 0, $text{'no'} ] ]),
				    1, undef,
				    [ "id='systemd_userservice_row'" ]);
		print ui_table_hr();
		}
	if ($force_user_scope_owner) {
		print ui_hidden("unituser", $default_unituser);
		}
	else {
		print ui_table_row(hlink($text{'systemd_unituser'},
					 "systemd_unituser"),
				    placeholder_textbox("unituser",
							$default_unituser, 20,
							"appuser")." ".
				    user_chooser_button("unituser"),
				    1, undef,
				    [ "id='systemd_unituser_row'".
				      ($create_user_scope ? "" :
				       " style='display:none'") ]);
		}
	if (systemd_acl_bool('linger')) {
		my $linger_text = $create_user_scope ?
			$text{'systemd_linger_user'} : $text{'systemd_linger'};
		my $linger_help = $create_user_scope ?
			"systemd_linger_user" : "systemd_linger";
		print ui_table_row(hlink($linger_text, $linger_help),
				    ui_yesno_radio("linger",
						   $config{'default_linger'} ? 1 : 0),
				    1, undef, [ "id='systemd_linger_row'".
					($create_user_scope ? "" : " style='display:none'") ]);
		}

	print ui_table_end();

	# Less common create-time settings are collapsed by default.
	print ui_hidden_table_start($text{'systemd_advanced'}, undef, 2,
				     "advanced", 0);

	# Unit relationships are shared by all creatable unit types and are written
	# into the [Unit] section.
	print ui_table_row(hlink($text{'systemd_before'}, "systemd_before"),
			    placeholder_textbox("before", undef, 60,
						"network.target"));
	print ui_table_row(hlink($text{'systemd_after'}, "systemd_after"),
			    placeholder_textbox("after", undef, 60,
						"network-online.target"));
	print ui_table_row(hlink($text{'systemd_wants'}, "systemd_wants"),
			    placeholder_textbox("wants", undef, 60,
						"network-online.target"));
	print ui_table_row(hlink($text{'systemd_requires'}, "systemd_requires"),
			    placeholder_textbox("requires", undef, 60,
						"postgresql.service"));
	print ui_table_row(hlink($text{'systemd_conflicts'}, "systemd_conflicts"),
			    placeholder_textbox("conflicts", undef, 60,
						"old-app.service"));
	print ui_table_row(hlink($text{'systemd_onfailure'}, "systemd_onfailure"),
			    placeholder_textbox("onfailure", undef, 60,
						"notify@%n.service"));
	print ui_table_row(hlink($text{'systemd_onsuccess'}, "systemd_onsuccess"),
			    placeholder_textbox("onsuccess", undef, 60,
						"report.service"));

	# Service options become irrelevant for all non-service unit types; each row
	# is marked so the JS type switch can hide it.
	my @service_row = ( "data-systemd-service='1'" );
	my $service_placeholders =
		service_unit_placeholders($create_user_scope, $unituser);
	@types = ( [ '', $text{'default'} ], "simple", "exec", "forking",
		   "oneshot", "dbus", "notify", "idle" );
	print ui_table_row(hlink($text{'systemd_servicetype'}, "systemd_servicetype"),
			    ui_select("type", undef, \@types),
			    1, undef, \@service_row);
	print ui_table_row(hlink($text{'systemd_remain'}, "systemd_remain"),
			    ui_yesno_radio("remain", 0),
			    1, undef, \@service_row);
	print ui_table_row(hlink($text{'systemd_pidfile'}, "systemd_pidfile"),
			    placeholder_filebox("pidfile", undef, 50,
						$service_placeholders->{'pidfile'}),
			    1, undef, \@service_row);
	print ui_table_row(hlink($text{'systemd_env'}, "systemd_env"),
			    placeholder_textbox("env", undef, 60,
						"NODE_ENV=production PORT=8080"),
			    1, undef, \@service_row);
	print ui_table_row(hlink($text{'systemd_envfile'}, "systemd_envfile"),
			    placeholder_filebox("envfile", undef, 50,
						$service_placeholders->{'envfile'}),
			    1, undef, \@service_row);
	print ui_table_row(hlink($text{'systemd_user'}, "systemd_user"),
			    placeholder_textbox("user", undef, 20, "appuser")." ".
			    user_chooser_button("user"),
			    1, undef, [ "id='systemd_runas_user_row' ".
				"data-systemd-service='1'".
				($create_user_scope ? " style='display:none'" : "") ]);
	print ui_table_row(hlink($text{'systemd_group'}, "systemd_group"),
			    placeholder_textbox("group", undef, 20, "appgroup")." ".
			    group_chooser_button("group"),
			    1, undef, [ "id='systemd_runas_group_row' ".
				"data-systemd-service='1'".
				($create_user_scope ? " style='display:none'" : "") ]);
	@killmodes = ( [ '', $text{'default'} ], "control-group",
		       "process", "mixed", "none" );
	print ui_table_row(hlink($text{'systemd_killmode'}, "systemd_killmode"),
			    ui_select("killmode", undef, \@killmodes),
			    1, undef, \@service_row);
	print ui_table_row(hlink($text{'systemd_workdir'}, "systemd_workdir"),
			    placeholder_filebox("workdir", undef, 50,
						$service_placeholders->{'workdir'}, 1),
			    1, undef, \@service_row);
	@restarts = ( [ '', $text{'default'} ], "no", "on-success",
		      "on-failure", "on-abnormal", "on-watchdog",
		      "on-abort", "always" );
	print ui_table_row(hlink($text{'systemd_restart'}, "systemd_restart"),
			    ui_select("restart_policy", undef, \@restarts),
			    1, undef, \@service_row);
	print ui_table_row(hlink($text{'systemd_restartsec'}, "systemd_restartsec"),
			    placeholder_textbox("restartsec", undef, 10, "5s"),
			    1, undef, \@service_row);
	print ui_table_row(hlink($text{'systemd_watchdogsec'}, "systemd_watchdogsec"),
			    placeholder_textbox("watchdogsec", undef, 10, "30s"),
			    1, undef, \@service_row);
	print ui_table_row(hlink($text{'systemd_timeout'}, "systemd_timeout"),
			    placeholder_textbox("timeoutstartsec", undef, 10,
						"30s"),
			    1, undef, \@service_row);
	print ui_table_row(hlink($text{'systemd_timeoutstop'}, "systemd_timeoutstop"),
			    placeholder_textbox("timeoutstopsec", undef, 10,
						"30s"),
			    1, undef, \@service_row);
	print ui_table_row(hlink($text{'systemd_limitnofile'}, "systemd_limitnofile"),
			    placeholder_textbox("limitnofile", undef, 10,
						"65535"),
			    1, undef, \@service_row);
	print ui_table_row(hlink($text{'systemd_logstd'}, "systemd_logstd"),
			    placeholder_textbox("logstd", undef, 50,
						"journal"),
			    1, undef, \@service_row);
	print ui_table_row(hlink($text{'systemd_logerr'}, "systemd_logerr"),
			    placeholder_textbox("logerr", undef, 50,
						"journal"),
			    1, undef, \@service_row);
	print ui_table_row(hlink($text{'systemd_syslogid'}, "systemd_syslogid"),
			    placeholder_textbox("syslogid", undef, 30, "my-app"),
			    1, undef, \@service_row);
	print ui_table_row(hlink($text{'systemd_nonewprivs'}, "systemd_nonewprivs"),
			    ui_yesno_radio("nonewprivs", 0),
			    1, undef, \@service_row);
	print ui_table_row(hlink($text{'systemd_privatetmp'}, "systemd_privatetmp"),
			    ui_yesno_radio("privatetmp", 0),
			    1, undef, \@service_row);
	@protects = ( [ '', $text{'default'} ], "true", "full", "strict" );
	print ui_table_row(hlink($text{'systemd_protectsystem'}, "systemd_protectsystem"),
			    ui_select("protectsystem", undef, \@protects),
			    1, undef, \@service_row);
	print ui_table_row(hlink($text{'systemd_readwritepaths'}, "systemd_readwritepaths"),
			    placeholder_textbox("readwritepaths", undef, 60,
						$service_placeholders->{'readwritepaths'}),
			    1, undef, \@service_row);

	# Install options stay visible for all types.  JS changes the default target
	# when switching between system/user units or between unit types.
	my $default_wantedby =
		get_default_install_target($default_unittype,
						    $create_user_scope);
	print ui_table_row(hlink($text{'systemd_wantedby'}, "systemd_wantedby"),
			    placeholder_textbox("wantedby", $default_wantedby,
						60, "multi-user.target"));

	# Extra non-service directives supplement the guided fields above.  Only
	# directive lines belong here; the renderer adds the correct section header.
	print ui_table_row(hlink($text{'systemd_unitconf'}, "systemd_unitconf"),
			    placeholder_textarea("unitconf", undef, 8, 80,
				"RuntimeMaxSec=1h", "spellcheck='false'"),
			    1, undef, [ "data-systemd-extra='1' ".
					"style='display:none'" ]);

	# Extra command hooks are service-only and are kept near the end because
	# they are less commonly needed than the scalar service settings above.
	print ui_table_row(hlink($text{'systemd_startpre'}, "systemd_startpre"),
			    placeholder_textarea("startpre", undef, 3, 80,
				$service_placeholders->{'startpre'}),
			    1, undef, \@service_row);
	print ui_table_row(hlink($text{'systemd_startpost'}, "systemd_startpost"),
			    placeholder_textarea("startpost", undef, 3, 80,
				"/usr/bin/logger my-app started"),
			    1, undef, \@service_row);
	print ui_table_row(hlink($text{'systemd_stoppost'}, "systemd_stoppost"),
			    placeholder_textarea("stoppost", undef, 3, 80,
				$service_placeholders->{'stoppost'}),
			    1, undef, \@service_row);
	print ui_table_row(hlink($text{'systemd_reload'}, "systemd_reload"),
			    placeholder_textarea("reload", undef, 3, 80,
				"/bin/kill -HUP \$MAINPID"),
			    1, undef, \@service_row);

	print ui_hidden_table_end("advanced");
	my $systemd_js = <<'EOF';
(function() {
'use strict';

// Unit suffixes shown next to the editable base name.
const systemdSuffixes = {
	service: '.service',
	timer: '.timer',
	socket: '.socket',
	path: '.path',
	target: '.target',
	mount: '.mount',
	automount: '.automount',
	swap: '.swap',
	slice: '.slice'
	};
// Type-aware examples keep the create form from sounding service-only.
const systemdNamePlaceholders = {
	service: 'my-app',
	timer: 'nightly-backup',
	socket: 'my-app',
	path: 'config-watch',
	target: 'app-stack',
	mount: 'mnt-data',
	automount: 'mnt-data',
	swap: 'swapfile',
	slice: 'app-workload'
	};
const systemdDescPlaceholders = {
	service: 'My app service',
	timer: 'Nightly backup timer',
	socket: 'My app socket',
	path: 'Watch app config',
	target: 'App stack target',
	mount: 'Mount /mnt/data',
	automount: 'Automount /mnt/data',
	swap: 'Swap file',
	slice: 'App resource slice'
	};
const systemdExtraPlaceholders = {
	timer: 'OnUnitInactiveSec=2min\nWakeSystem=no\nRemainAfterElapse=yes',
	socket: 'Backlog=32\nKeepAlive=yes\nNoDelay=yes\nFileDescriptorName=my-app',
	path: 'TriggerLimitIntervalSec=30s\nTriggerLimitBurst=10',
	mount: 'TimeoutSec=30s\nLazyUnmount=yes',
	automount: 'DirectoryMode=0755',
	swap: 'TimeoutSec=30s',
	slice: 'CPUQuota=50%\nMemoryHigh=256M'
	};
// Default install targets mirror systemd's usual system and user unit targets.
const systemdInstallTargets = {
	system: {
		service: 'multi-user.target',
		timer: 'timers.target',
		socket: 'sockets.target',
		path: 'paths.target',
		target: 'multi-user.target',
		mount: 'local-fs.target',
		automount: 'local-fs.target',
		swap: 'swap.target',
		slice: 'slices.target'
		},
	user: {
		service: 'default.target',
		timer: 'timers.target',
		socket: 'sockets.target',
		path: 'paths.target',
		target: 'default.target',
		mount: 'default.target',
		automount: 'default.target',
		swap: 'default.target',
		slice: 'slices.target'
		}
	};

// Returns the currently selected type, falling back to the service form.
function currentUnitType()
{
const field = document.querySelector('select[name="unittype"]');
return field && field.value ? field.value : 'service';
}

// Updates generic placeholders to match the currently selected unit type.
function updateTypePlaceholders()
{
const type = currentUnitType();
const nameField = document.querySelector('input[name="name"]');
const descField = document.querySelector('input[name="desc"]');
if (nameField && systemdNamePlaceholders[type]) {
	nameField.setAttribute('placeholder', systemdNamePlaceholders[type]);
	}
if (descField && systemdDescPlaceholders[type]) {
	descField.setAttribute('placeholder', systemdDescPlaceholders[type]);
	}
const extraField = document.querySelector('textarea[name="unitconf"]');
if (extraField) {
	extraField.setAttribute('placeholder',
				systemdExtraPlaceholders[type] || '');
	}
}

// Detects defaults we own, so a custom WantedBy value is not overwritten.
function knownInstallTarget(value)
{
for (const scope in systemdInstallTargets) {
	for (const type in systemdInstallTargets[scope]) {
		if (systemdInstallTargets[scope][type] == value) {
			return true;
			}
		}
	}
return false;
}

// Refreshes WantedBy only when it is blank or still one of our defaults.
function updateInstallTarget(userMode)
{
const field = document.querySelector('[name="wantedby"]');
if (!field) {
	return;
	}
const scope = userMode ? 'user' : 'system';
const target = systemdInstallTargets[scope][currentUnitType()];
if (target && (!field.value || knownInstallTarget(field.value))) {
	field.value = target;
	}
}

// Shows user-manager fields and hides service User=/Group= in user mode.
function userModeChange()
{
let checked = document.querySelector('input[name="userservice"]:checked');
const hidden = document.querySelector('input[name="userservice"][type="hidden"]');
const f = checked ? checked.form : null;
const userservice = f ? f.elements['userservice'] :
	document.querySelectorAll('input[name="userservice"]');
if (!checked && userservice) {
	for (let i = 0; i < userservice.length; i++) {
		if (userservice[i].checked) {
			checked = userservice[i];
			break;
			}
		}
	}
const enabled = checked ? checked.value == '1' :
	hidden ? hidden.value == '1' : false;
const service = currentUnitType() == 'service';
const socket = currentUnitType() == 'socket';
const showrow = function(id, show) {
	const row = document.getElementById(id);
	if (row) {
		row.style.display = show ? '' : 'none';
		}
	};
showrow('systemd_unituser_row', enabled);
showrow('systemd_linger_row', enabled);
const userserviceHr =
	document.querySelector('#systemd_userservice_row + tr');
if (userserviceHr) {
	userserviceHr.style.display = enabled ? '' : 'none';
	}
showrow('systemd_runas_user_row', !enabled && service);
showrow('systemd_runas_group_row', !enabled && service);
showrow('systemd_socket_user_row', !enabled && socket);
showrow('systemd_socket_group_row', !enabled && socket);
updateInstallTarget(enabled);
}

// Switches between service-specific rows and each unit type's guided fields.
function unitTypeChange()
{
	const type = currentUnitType();
	const service = type == 'service';
	const extra = !service && type != 'target';
	const mount = type == 'mount';
	const automount = type == 'automount';
	const typedRowSets = {
		timer: document.querySelectorAll('[data-systemd-timer]'),
		socket: document.querySelectorAll('[data-systemd-socket]'),
		path: document.querySelectorAll('[data-systemd-path]'),
		mount: document.querySelectorAll('[data-systemd-mount]'),
		automount: document.querySelectorAll('[data-systemd-automount]'),
		swap: document.querySelectorAll('[data-systemd-swap]'),
		slice: document.querySelectorAll('[data-systemd-slice]')
		};
	const suffix = document.getElementById('systemd_name_suffix');
	if (suffix) {
		suffix.textContent = systemdSuffixes[type] || '';
		}
	updateTypePlaceholders();
	const serviceRows = document.querySelectorAll('[data-systemd-service]');
	for (let i = 0; i < serviceRows.length; i++) {
		serviceRows[i].style.display = service ? '' : 'none';
		}
	for (const rowType in typedRowSets) {
		const rows = typedRowSets[rowType];
		for (let i = 0; i < rows.length; i++) {
			rows[i].style.display = type == rowType ? '' : 'none';
			}
		}
	const extraRows = document.querySelectorAll('[data-systemd-extra]');
	for (let i = 0; i < extraRows.length; i++) {
		extraRows[i].style.display = extra ? '' : 'none';
		}
	userModeChange();
	}

// Authentic and Gray themes can render rows at different times, so initialize
// after DOM readiness and also bind explicit change handlers.
function initializeSystemdUnitForm()
{
	const systemdUserServiceInputs =
		document.querySelectorAll('input[name="userservice"]');
	for (let i = 0; i < systemdUserServiceInputs.length; i++) {
		systemdUserServiceInputs[i].addEventListener('change',
							    userModeChange);
		}
	const systemdUnitTypeInput = document.querySelector('select[name="unittype"]');
	if (systemdUnitTypeInput) {
		systemdUnitTypeInput.addEventListener('change',
						     unitTypeChange);
		}
	unitTypeChange();
}

if (document.readyState == 'loading') {
	document.addEventListener('DOMContentLoaded', initializeSystemdUnitForm);
	}
else {
	initializeSystemdUnitForm();
	}
})();
EOF
	print ui_tag('script', $systemd_js,
		      { 'type' => 'text/javascript' });
	}
else {
	# Existing units are edited as raw files to preserve unknown directives.
	print ui_table_start($text{'systemd_header'}, undef, 2);

	# Unit names are identifiers and cannot be renamed from the edit page.
	print ui_table_row(hlink($text{'systemd_name'}, "systemd_name"),
			    ui_tag('tt', html_escape($in{'name'})));

	# Show the resolved file path before the editable unit contents.
	my $edit_file = $u->{'file'};
	if ($edit_dropin) {
		$edit_file = $dropin_file ||
			($edit_user_scope ?
			user_dropin_file($unituser, $in{'name'}) :
			system_dropin_file($in{'name'}));
		$edit_file || error($text{'systemd_edropinfile'});
		}
	print ui_table_row(hlink($text{'systemd_file'}, "systemd_file"),
			    ui_tag('tt', html_escape($edit_file)));

	# User files are read through privilege-dropping helpers so a path in the
	# home tree cannot make root follow user-controlled symlinks.
	if ($edit_dropin) {
		$conf = $dropin_file && $edit_user_scope ?
			read_user_dropin_config_file($unituser, $dropin_file) :
			$dropin_file ?
			read_system_dropin_config_file($dropin_file) :
			$edit_user_scope ?
			read_user_dropin_file($unituser, $in{'name'}) :
			read_system_dropin_file($in{'name'});
		defined($conf) || error($text{'systemd_edropinfile'});
		}
	else {
		$conf = $edit_user_scope ?
			read_user_unit_file($unituser, $u->{'file'}) :
			read_file_contents($u->{'file'});
		defined($conf) || error($text{'systemd_euserunitfile'});
		}
	print ui_table_row(hlink($text{'systemd_conf'}, "systemd_conf"),
			    ui_textarea("data", $conf, 20, 80, undef,
					undef, $unit_file_editable &&
					$can_save_unit ? undef :
					"readonly='readonly'"));

	if ($edit_user_scope) {
		# The owner is fixed for an existing user unit.
		print ui_table_row(hlink($text{'systemd_unituser'}, "systemd_unituser"),
				    ui_tag('tt', html_escape($unituser)));
		}

	# Show systemd's own state model before editable policy toggles.
	print ui_table_row(hlink($text{'systemd_runtime_state'},
				 "systemd_runtime_state"),
			    edit_runtime_state($u->{'runtime'}, $u->{'substate'}));
	if (defined($u->{'pid'}) && $u->{'pid'} =~ /^\d+$/ && $u->{'pid'} > 0) {
		print ui_table_row(hlink($text{'systemd_main_pid'},
					 "systemd_main_pid"),
				    ui_tag('tt', html_escape($u->{'pid'})));
		}
	print ui_table_row(hlink($text{'systemd_unit_state'},
				 "systemd_unit_state"),
			    edit_state_value($u->{'unitstate'}));

	# Only file-backed installable units can have their startup state changed.
	if (boot_state_changeable($u->{'unitstate'}, $u->{'name'}) &&
	    systemd_can_boot($edit_user_scope, $unituser)) {
		print ui_table_row(hlink($text{'systemd_boot'}, "systemd_boot"),
			    ui_yesno_radio("boot", $u->{'boot'}));
		}

	# User-scope edits allow linger to be managed alongside the raw unit file.
	if ($edit_user_scope) {
		my $linger_enabled = user_linger_enabled($unituser);
		my $linger_field = systemd_can_linger($unituser) ?
			ui_yesno_radio("linger", $linger_enabled) :
			html_escape($linger_enabled ? $text{'yes'} : $text{'no'});
		print ui_table_row(hlink($text{'systemd_linger_user'},
					 "systemd_linger_user"),
				    $linger_field);
		}

	print ui_table_end();
	}

if ($in{'new'}) {
	# New units only need a create button; runtime actions appear after save.
	print ui_form_end([ [ undef, $text{'create'} ] ]);
	}
else {
	# Keep save, override, runtime and inspection actions in nearby clusters;
	# destructive actions stay isolated on the far side of the button row.
	my @save_buttons = $unit_file_editable && $can_save_unit ?
		( [ undef, $text{'save'} ] ) : ( );
	my @control_buttons;
	my @inspect_buttons = systemd_can_inspect($edit_user_scope, $unituser) ?
		( [ 'status', $text{'edit_statusnow'} ],
		  [ 'props', $text{'edit_propsnow'} ],
		  [ 'deps', $text{'edit_depsnow'} ] ) : ( );
	my @log_buttons = systemd_can_logs($edit_user_scope, $unituser) ?
		( [ 'logs', $text{'edit_logsnow'} ] ) : ( );

	# Running units can be stopped, but only restart units where systemd
	# supports a restart job type.  Some runtime units, such as scopes and
	# devices, are externally managed and can only be inspected or stopped.
	if (defined($u->{'status'}) && $u->{'status'} == 1) {
		push(@control_buttons, [ 'restart', $text{'edit_restartnow'} ])
			if (unit_restartable($in{'name'}) &&
			    systemd_can_runtime('restart', $edit_user_scope,
				$unituser));
		push(@control_buttons, [ 'stop', $text{'edit_stopnow'} ])
			if (systemd_can_runtime('stop', $edit_user_scope,
				$unituser));
		}
	elsif (unit_startable($in{'name'}) &&
	       systemd_can_runtime('start',
				   $edit_user_scope, $unituser)) {
		push(@control_buttons, [ 'start', $text{'edit_startnow'} ]);
		}

	my @override_buttons;
	if ($edit_dropin) {
		push(@override_buttons,
		     [ 'stock_unit',
		       $text{'edit_stockunitnow'} || "Stock Unit" ]);
		}
	elsif ($unit_file_editable &&
	       systemd_can_dropin($edit_user_scope, $unituser)) {
		my $override_text = dropin_exists($edit_user_scope,
			$unituser, $in{'name'}) ?
				($text{'edit_editoverridenow'} ||
				 "Edit Override") :
				($text{'edit_overridenow'} ||
				 "Create Override");
		push(@override_buttons, [ 'override', $override_text ]);
		}
	my @delete_buttons;
	if ($edit_dropin && !$dropin_file && $unit_file_editable &&
	    systemd_can_dropin($edit_user_scope, $unituser)) {
		push(@delete_buttons,
		     [ 'delete_override',
		       $text{'edit_deleteoverridenow'} || "Delete Override" ]);
		}
	elsif ($unit_file_editable && $in{'name'} ne 'webmin.service' &&
	       systemd_can_delete($edit_user_scope, $unituser)) {
		push(@delete_buttons, [ 'delete', $text{'delete'} ]);
		}

	print ui_form_grouped_buttons([ [ \@save_buttons,
					  \@override_buttons,
					  \@control_buttons,
					  \@inspect_buttons,
					  \@log_buttons ],
					 [ \@delete_buttons ] ]);
	print ui_form_end();
	}

# Return to the index tab that owns this unit when the type or scope is known.
my $footer_url = $in{'new'} ?
	index_url(".".$default_unittype, $create_user_scope, $unituser) :
	index_url($in{'name'}, $edit_user_scope, $unituser);
ui_print_footer($footer_url, $text{'index_return'});

# edit_runtime_state(active-state, sub-state)
# Returns a systemd-style runtime state value such as "Active (running)".
sub edit_runtime_state
{
my ($state, $substate) = @_;
my $value = edit_state_value($state);
if (defined($state) && $state ne "" &&
    defined($substate) && $substate ne "" && $substate ne $state) {
	$value .= " ".ui_tag('span',
			     "(".html_escape(lcfirst($substate)).")");
	}
return $value;
}

# edit_state_value(state)
# Returns a formatted systemd state value for the edit form.
sub edit_state_value
{
my ($state) = @_;
return ui_tag('i', $text{'index_unknown'})
	if (!defined($state) || $state eq "");
return html_escape(ucfirst($state));
}
