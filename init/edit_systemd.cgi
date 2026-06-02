#!/usr/local/bin/perl
# Show a form for creating or editing a systemd unit

require './init-lib.pl';
$access{'bootup'} || &error($text{'edit_ecannot'});
&ReadParse();

# Work out whether this page is creating/editing a user-scoped unit.  The
# function names below still say "service" for API compatibility, but the
# returned lists can contain services, timers, sockets and paths.
$unituser = &clean_systemd_unit_value($in{'unituser'} || $in{'user'});
$edit_user_scope = !$in{'new'} && $in{'scope'} eq 'user' ? 1 : 0;
$create_user_scope = $in{'new'} && $in{'scope'} eq 'user' ? 1 : 0;

# New units start with an empty record.  Existing units are looked up from the
# selected system or user scope so edits cannot cross scopes accidentally.
if ($in{'new'}) {
	&ui_print_header(undef, $text{'systemd_title1'}, "");
	$u = { };
	}
else {
	&ui_print_header(undef, $edit_user_scope ? $text{'systemd_title2_user'} :
			  $text{'systemd_title2'}, "");
	if ($edit_user_scope) {
		&get_systemd_user_details($unituser) ||
			&error($text{'systemd_euser'});
		@systemds = &list_systemd_user_services($unituser);
		}
	else {
		@systemds = &list_systemd_services();
		}
	($u) = grep { $_->{'name'} eq $in{'name'} } @systemds;
	$u || &error($text{'systemd_egone'});
	$u->{'legacy'} && &error($text{'systemd_elegacy'});
	}

# The save script uses hidden scope fields to pick the correct control plane
# for later actions, including status/log redirects.
print &ui_form_start("save_systemd.cgi", "post");
print &ui_hidden("new", $in{'new'});
print &ui_hidden("scope", "user") if ($edit_user_scope);
print &ui_hidden("unituser", $unituser) if ($edit_user_scope);
print &ui_hidden("name", $in{'name'}) if (!$in{'new'});
if ($in{'new'}) {
	print &ui_table_start($text{'systemd_header'}, undef, 2);

	# Unit type and name.  The suffix is displayed separately, but the save
	# script appends or validates it before writing the unit file.
	@unittypes = map { [ $_, $text{'systemd_type_'.$_} || $_ ] }
		     &get_systemd_creatable_unit_types();
	%creatable_types = map { $_, 1 } &get_systemd_creatable_unit_types();
	$default_unittype = $creatable_types{$in{'unittype'}} ?
		$in{'unittype'} : "service";
	print &ui_table_row(&hlink($text{'systemd_type'}, "systemd_type"),
			    &ui_select("unittype", $default_unittype, \@unittypes,
				       1, 0, 0, 0));
	print &ui_table_hr();
	print &ui_table_row(&hlink($text{'systemd_name'}, "systemd_name"),
			    &ui_textbox("name", undef, 30).
			    &ui_tag('tt', ".$default_unittype",
				    { 'id' => 'systemd_name_suffix' }));

	# Description
	print &ui_table_row(&hlink($text{'systemd_desc'}, "systemd_desc"),
			    &ui_textbox("desc", undef, 60));

	# Start script
	print &ui_table_row(&hlink($text{'systemd_start'}, "systemd_start"),
			    &ui_textarea("atstart", undef, 5, 80),
			    1, undef, [ "data-systemd-service='1'" ]);

	# Stop script
	print &ui_table_row(&hlink($text{'systemd_stop'}, "systemd_stop"),
			    &ui_textarea("atstop", undef, 5, 80),
			    1, undef, [ "data-systemd-service='1'" ]);

	# Non-service type-specific settings
	print &ui_table_row(&hlink($text{'systemd_unitconf'}, "systemd_unitconf"),
			    &ui_textarea("unitconf", undef, 8, 80, undef,
					 undef, "spellcheck='false'"),
			    1, undef, [ "data-systemd-nonservice='1' ".
					"style='display:none'" ]);

	# Start at boot?
	print &ui_table_row(&hlink($text{'systemd_boot'}, "systemd_boot"),
			    &ui_yesno_radio("boot", 1));

	# User service controls
	my $default_unituser = $unituser ||
		($remote_user && $remote_user ne "root" ? $remote_user : undef);
	# User units live in the selected user's home and run under that user's
	# systemd manager, so the service-level User=/Group= rows are hidden by JS.
	print &ui_table_row(&hlink($text{'systemd_userservice'}, "systemd_userservice"),
			    &ui_radio("userservice", $create_user_scope ? 1 : 0,
				      [ [ 1, $text{'yes'} ],
					[ 0, $text{'no'} ] ]),
			    1, undef, [ "id='systemd_userservice_row'" ]);
	print &ui_table_hr();
	print &ui_table_row(&hlink($text{'systemd_unituser'}, "systemd_unituser"),
			    &ui_textbox("unituser", $default_unituser, 20)." ".
			    &user_chooser_button("unituser"),
			    1, undef, [ "id='systemd_unituser_row'".
				($create_user_scope ? "" : " style='display:none'") ]);
	print &ui_table_row(&hlink($text{'systemd_linger'}, "systemd_linger"),
			    &ui_yesno_radio("linger", 1),
			    1, undef, [ "id='systemd_linger_row'".
				($create_user_scope ? "" : " style='display:none'") ]);

	print &ui_table_end();

	print &ui_hidden_table_start($text{'systemd_advanced'}, undef, 2,
				     "advanced", 0);

	# Unit relationships are shared by all creatable unit types and are written
	# into the [Unit] section.
	print &ui_table_row(&hlink($text{'systemd_before'}, "systemd_before"),
			    &ui_textbox("before", undef, 60));
	print &ui_table_row(&hlink($text{'systemd_after'}, "systemd_after"),
			    &ui_textbox("after", undef, 60));
	print &ui_table_row(&hlink($text{'systemd_wants'}, "systemd_wants"),
			    &ui_textbox("wants", undef, 60));
	print &ui_table_row(&hlink($text{'systemd_requires'}, "systemd_requires"),
			    &ui_textbox("requires", undef, 60));
	print &ui_table_row(&hlink($text{'systemd_conflicts'}, "systemd_conflicts"),
			    &ui_textbox("conflicts", undef, 60));
	print &ui_table_row(&hlink($text{'systemd_onfailure'}, "systemd_onfailure"),
			    &ui_textbox("onfailure", undef, 60));
	print &ui_table_row(&hlink($text{'systemd_onsuccess'}, "systemd_onsuccess"),
			    &ui_textbox("onsuccess", undef, 60));

	# Service options become irrelevant for timers, sockets, paths and targets;
	# each row is marked so the JS type switch can hide it.
	my @service_row = ( "data-systemd-service='1'" );
	@types = ( [ '', $text{'default'} ], "simple", "exec", "forking",
		   "oneshot", "dbus", "notify", "idle" );
	print &ui_table_row(&hlink($text{'systemd_servicetype'}, "systemd_servicetype"),
			    &ui_select("type", undef, \@types),
			    1, undef, \@service_row);
	print &ui_table_row(&hlink($text{'systemd_remain'}, "systemd_remain"),
			    &ui_yesno_radio("remain", 0),
			    1, undef, \@service_row);
	print &ui_table_row(&hlink($text{'systemd_pidfile'}, "systemd_pidfile"),
			    &ui_filebox("pidfile", undef, 50),
			    1, undef, \@service_row);
	print &ui_table_row(&hlink($text{'systemd_env'}, "systemd_env"),
			    &ui_textbox("env", undef, 60),
			    1, undef, \@service_row);
	print &ui_table_row(&hlink($text{'systemd_envfile'}, "systemd_envfile"),
			    &ui_filebox("envfile", undef, 50),
			    1, undef, \@service_row);
	print &ui_table_row(&hlink($text{'systemd_user'}, "systemd_user"),
			    &ui_textbox("user", undef, 20)." ".
			    &user_chooser_button("user"),
			    1, undef, [ "id='systemd_runas_user_row' ".
				"data-systemd-service='1'".
				($create_user_scope ? " style='display:none'" : "") ]);
	print &ui_table_row(&hlink($text{'systemd_group'}, "systemd_group"),
			    &ui_textbox("group", undef, 20)." ".
			    &group_chooser_button("group"),
			    1, undef, [ "id='systemd_runas_group_row' ".
				"data-systemd-service='1'".
				($create_user_scope ? " style='display:none'" : "") ]);
	@killmodes = ( [ '', $text{'default'} ], "control-group",
		       "process", "mixed", "none" );
	print &ui_table_row(&hlink($text{'systemd_killmode'}, "systemd_killmode"),
			    &ui_select("killmode", undef, \@killmodes),
			    1, undef, \@service_row);
	print &ui_table_row(&hlink($text{'systemd_workdir'}, "systemd_workdir"),
			    &ui_filebox("workdir", undef, 50, undef,
					undef, undef, 1),
			    1, undef, \@service_row);
	@restarts = ( [ '', $text{'default'} ], "no", "on-success",
		      "on-failure", "on-abnormal", "on-watchdog",
		      "on-abort", "always" );
	print &ui_table_row(&hlink($text{'systemd_restart'}, "systemd_restart"),
			    &ui_select("restart", undef, \@restarts),
			    1, undef, \@service_row);
	print &ui_table_row(&hlink($text{'systemd_restartsec'}, "systemd_restartsec"),
			    &ui_textbox("restartsec", undef, 10),
			    1, undef, \@service_row);
	print &ui_table_row(&hlink($text{'systemd_watchdogsec'}, "systemd_watchdogsec"),
			    &ui_textbox("watchdogsec", undef, 10),
			    1, undef, \@service_row);
	print &ui_table_row(&hlink($text{'systemd_timeout'}, "systemd_timeout"),
			    &ui_textbox("timeout", undef, 10),
			    1, undef, \@service_row);
	print &ui_table_row(&hlink($text{'systemd_timeoutstop'}, "systemd_timeoutstop"),
			    &ui_textbox("timeoutstopsec", undef, 10),
			    1, undef, \@service_row);
	print &ui_table_row(&hlink($text{'systemd_limitnofile'}, "systemd_limitnofile"),
			    &ui_textbox("limitnofile", undef, 10),
			    1, undef, \@service_row);
	print &ui_table_row(&hlink($text{'systemd_logstd'}, "systemd_logstd"),
			    &ui_textbox("logstd", undef, 50),
			    1, undef, \@service_row);
	print &ui_table_row(&hlink($text{'systemd_logerr'}, "systemd_logerr"),
			    &ui_textbox("logerr", undef, 50),
			    1, undef, \@service_row);
	print &ui_table_row(&hlink($text{'systemd_syslogid'}, "systemd_syslogid"),
			    &ui_textbox("syslogid", undef, 30),
			    1, undef, \@service_row);
	print &ui_table_row(&hlink($text{'systemd_nonewprivs'}, "systemd_nonewprivs"),
			    &ui_yesno_radio("nonewprivs", 0),
			    1, undef, \@service_row);
	print &ui_table_row(&hlink($text{'systemd_privatetmp'}, "systemd_privatetmp"),
			    &ui_yesno_radio("privatetmp", 0),
			    1, undef, \@service_row);
	@protects = ( [ '', $text{'default'} ], "true", "full", "strict" );
	print &ui_table_row(&hlink($text{'systemd_protectsystem'}, "systemd_protectsystem"),
			    &ui_select("protectsystem", undef, \@protects),
			    1, undef, \@service_row);
	print &ui_table_row(&hlink($text{'systemd_readwritepaths'}, "systemd_readwritepaths"),
			    &ui_textbox("readwritepaths", undef, 60),
			    1, undef, \@service_row);

	# Install options stay visible for all types.  JS changes the default target
	# when switching between system/user units or between unit types.
	my $default_wantedby =
		&get_systemd_default_install_target($default_unittype,
						    $create_user_scope);
	print &ui_table_row(&hlink($text{'systemd_wantedby'}, "systemd_wantedby"),
			    &ui_textbox("wantedby", $default_wantedby, 60));

	# Extra command hooks are service-only and are kept near the end because
	# they are less commonly needed than the scalar service settings above.
	print &ui_table_row(&hlink($text{'systemd_startpre'}, "systemd_startpre"),
			    &ui_textarea("startpre", undef, 3, 80),
			    1, undef, \@service_row);
	print &ui_table_row(&hlink($text{'systemd_startpost'}, "systemd_startpost"),
			    &ui_textarea("startpost", undef, 3, 80),
			    1, undef, \@service_row);
	print &ui_table_row(&hlink($text{'systemd_stoppost'}, "systemd_stoppost"),
			    &ui_textarea("stoppost", undef, 3, 80),
			    1, undef, \@service_row);
	print &ui_table_row(&hlink($text{'systemd_reload'}, "systemd_reload"),
			    &ui_textarea("reload", undef, 3, 80),
			    1, undef, \@service_row);

	print &ui_hidden_table_end("advanced");
	my $systemd_js = <<'EOF';
(function() {
'use strict';

// Unit suffixes shown next to the editable base name.
const systemdSuffixes = {
	service: '.service',
	timer: '.timer',
	socket: '.socket',
	path: '.path',
	target: '.target'
	};
// Default install targets mirror systemd's usual system and user unit targets.
const systemdInstallTargets = {
	system: {
		service: 'multi-user.target',
		timer: 'timers.target',
		socket: 'sockets.target',
		path: 'paths.target',
		target: 'multi-user.target'
		},
	user: {
		service: 'default.target',
		timer: 'timers.target',
		socket: 'sockets.target',
		path: 'paths.target',
		target: 'default.target'
		}
	};

// Returns the currently selected type, falling back to the service form.
function currentUnitType()
{
const field = document.querySelector('select[name="unittype"]');
return field && field.value ? field.value : 'service';
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
const enabled = checked && checked.value == '1';
const service = currentUnitType() == 'service';
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
updateInstallTarget(enabled);
}

// Switches between service-specific rows and raw type-specific configuration.
function unitTypeChange()
{
const type = currentUnitType();
const service = type == 'service';
const suffix = document.getElementById('systemd_name_suffix');
if (suffix) {
	suffix.textContent = systemdSuffixes[type] || '';
	}
const serviceRows = document.querySelectorAll('[data-systemd-service]');
for (let i = 0; i < serviceRows.length; i++) {
	serviceRows[i].style.display = service ? '' : 'none';
	}
const nonServiceRows = document.querySelectorAll('[data-systemd-nonservice]');
for (let i = 0; i < nonServiceRows.length; i++) {
	nonServiceRows[i].style.display = service ? 'none' : '';
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
	print &ui_tag('script', $systemd_js,
		      { 'type' => 'text/javascript' });
	}
else {
	print &ui_table_start($text{'systemd_header'}, undef, 2);

	# Unit name (non-editable)
	print &ui_table_row(&hlink($text{'systemd_name'}, "systemd_name"),
			    &ui_tag('tt', &html_escape($in{'name'})));

	# Config file and contents
	print &ui_table_row(&hlink($text{'systemd_file'}, "systemd_file"),
			    &ui_tag('tt', &html_escape($u->{'file'})));

	# User unit files are read through the privilege-dropping helper so a
	# user-controlled path cannot make root follow symlinks in the home tree.
	$conf = $edit_user_scope ?
		&read_systemd_user_unit_file($unituser, $u->{'file'}) :
		&read_file_contents($u->{'file'});
	defined($conf) || &error($text{'systemd_euserunitfile'});
	print &ui_table_row(&hlink($text{'systemd_conf'}, "systemd_conf"),
			    &ui_textarea("data", $conf, 20, 80));

	# User-scope edits allow linger to be managed alongside the raw unit file.
	if ($edit_user_scope) {
		print &ui_table_row(&hlink($text{'systemd_unituser'}, "systemd_unituser"),
				    &ui_tag('tt', &html_escape($unituser)));
		print &ui_table_row(&hlink($text{'systemd_linger'}, "systemd_linger"),
				    &ui_yesno_radio("linger",
					&systemd_user_linger_enabled($unituser)));
		}

	# Current status
	if ($u->{'boot'} != 2) {
		print &ui_table_row(&hlink($text{'systemd_boot'}, "systemd_boot"),
			    &ui_yesno_radio("boot", $u->{'boot'}));
		}
	print &ui_table_row(&hlink($text{'systemd_status'}, "systemd_status"),
		$u->{'status'} == 1 && $u->{'pid'} ?
			&text('systemd_status1', $u->{'pid'}) :
		$u->{'status'} == 1 ?
			$text{'systemd_status2'} :
		$u->{'status'} == 0 ?
			$text{'systemd_status0'} :
			$text{'systemd_status3'});

	print &ui_table_end();
	}

if ($in{'new'}) {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}
else {
	# Group save, runtime actions and delete separately in the button row.
	my @save_buttons = ( [ undef, $text{'save'} ] );
	my @control_buttons;
	if (defined($u->{'status'}) && $u->{'status'} == 1) {
		push(@control_buttons, [ 'restart', $text{'edit_restartnow'} ]);
		push(@control_buttons, [ 'stop', $text{'edit_stopnow'} ])
			if ($in{'name'} ne 'webmin.service');
		}
	elsif (defined($u->{'status'}) && $u->{'status'} == 0) {
		push(@control_buttons, [ 'start', $text{'edit_startnow'} ]);
		}
	else {
		push(@control_buttons, [ 'start', $text{'edit_startnow'} ],
				       [ 'restart', $text{'edit_restartnow'} ]);
		push(@control_buttons, [ 'stop', $text{'edit_stopnow'} ])
			if ($in{'name'} ne 'webmin.service');
		}
	push(@control_buttons, [ 'status', $text{'edit_statusnow'} ],
			       [ 'logs', $text{'edit_logsnow'} ]);
	my @delete_buttons = (
		$in{'name'} eq 'webmin.service' ? ( ) :
			( [ 'delete', $text{'delete'} ] ),
		);
	print &ui_form_grouped_buttons([ [ \@save_buttons, \@control_buttons ],
					 \@delete_buttons ]);
	print &ui_form_end();
	}

# Return to the index tab that owns this unit when the type or scope is known.
$footer_url = $in{'new'} ?
	&systemd_index_url(".".$default_unittype, $create_user_scope, $unituser) :
	&systemd_index_url($in{'name'}, $edit_user_scope, $unituser);
&ui_print_footer($footer_url, $text{'index_return'});
