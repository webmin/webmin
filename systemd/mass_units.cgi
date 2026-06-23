#!/usr/local/bin/perl
# Start, stop, inspect or enable a set of systemd units

use strict;
use warnings;

require './systemd-lib.pl'; ## no critic

our (%access, %in, %text);

# Mass actions are POSTed from the index table or redirected from edit_unit.cgi.
ReadParse();
my @sel = split(/\0/, $in{'d'});
@sel || error($text{'mass_enone'});

# Work out whether selections target system or user managers.
my $user_scope = $in{'scope'} eq 'user' ? 1 : 0;
my $users_scope = $in{'scope'} eq 'users' ? 1 : 0;
my $unituser = clean_unit_value($in{'unituser'});
if ($user_scope) {
	get_user_details($unituser) ||
		error($text{'systemd_euser'});
	}
if ($in{'return'}) {
	valid_unit_name($in{'return'}) ||
		error($text{'systemd_ename'});
	}

# Convert raw checkbox values into validated action records.
my @units = mass_units(\@sel, $user_scope, $users_scope, $unituser);
foreach my $u (@units) {
	systemd_can_view_scope($u->{'user_scope'}, $u->{'user'}) ||
		systemd_acl_error($u->{'user_scope'} ? 'pview_user' : 'pview');
	}

# Convert submitted buttons into action flags.
my $start = $in{'start'} ? 1 : 0;
my $stop = $in{'stop'} ? 1 : 0;
my $restart = $in{'restart'} ? 1 : 0;
my $status = $in{'status'} ? 1 : 0;
my $props = $in{'props'} ? 1 : 0;
my $deps = $in{'deps'} ? 1 : 0;
my $logs = $in{'logs'} ? 1 : 0;
my $enable = $in{'addboot'} ? 1 : 0;
my $disable = $in{'delboot'} ? 1 : 0;
my $mask = $in{'mask'} ? 1 : 0;
my $unmask = $in{'unmask'} ? 1 : 0;
my $delete = $in{'delete'} ? 1 : 0;
my $printed_action_result = 0;

# Use an unbuffered page because long-running systemctl operations should show
# progress as each unit completes.
ui_print_unbuffered_header(undef, $logs ? $text{'systemd_logs'} :
				     $deps ? $text{'systemd_deps'} :
				     $props ? $text{'systemd_props'} :
				     $status ? $text{'systemd_statustitle'} :
				     $restart ? $text{'mass_urestart'} :
				     $start ? $text{'mass_ustart'} :
				     $stop ? $text{'mass_ustop'} :
				     $enable ? $text{'mass_usenable'} :
				     $disable ? $text{'mass_usdisable'} :
				     $mask ? $text{'mass_umask'} :
				     $unmask ? $text{'mass_uunmask'} :
				     $delete ? $text{'mass_udelete'} :
				     $text{'mass_ustop'}, "");

# Get status
if ($status) {
	# Show full systemd status output for selected units.
	foreach my $u (@units) {
		systemd_can_inspect($u->{'user_scope'}, $u->{'user'}) ||
			systemd_acl_error('pstatus');
		my $s = $u->{'name'};

		# Status command failures can still return useful output.
		print_action_start(text('systemd_doingstatus',
				    mass_unit_label($u)));
		my ($ok, $out) = $u->{'user_scope'} ?
			status_user_unit($u->{'user'}, $s) :
			status_unit($s);
		print ui_tag('pre', html_escape($out)) if ($out);
		print $text{'mass_failed'}, ui_p() if (!$out);
		}
	mass_log('status', \@units);
	}

# Get properties
if ($props) {
	# Show the exact property set systemd reports for selected units.
	foreach my $u (@units) {
		systemd_can_inspect($u->{'user_scope'}, $u->{'user'}) ||
			systemd_acl_error('pstatus');
		my $s = $u->{'name'};

		# Properties are read from the selected system or user manager.
		print_action_start(text('systemd_doingprops',
				    mass_unit_label($u)));
		my ($ok, $out) = $u->{'user_scope'} ?
			properties_user_unit($u->{'user'}, $s) :
			properties_unit($s);
		print ui_tag('pre', html_escape($out)) if ($out);
		print $text{'mass_failed'}, ui_p() if (!$ok && !$out);
		}
	mass_log('props', \@units);
	}

# Get dependencies
if ($deps) {
	# Show the dependency tree for selected units.
	foreach my $u (@units) {
		systemd_can_inspect($u->{'user_scope'}, $u->{'user'}) ||
			systemd_acl_error('pstatus');
		my $s = $u->{'name'};

		# Dependencies come from systemctl in the selected manager scope.
		print_action_start(text('systemd_doingdeps',
				    mass_unit_label($u)));
		my ($ok, $out) = $u->{'user_scope'} ?
			dependencies_user_unit($u->{'user'}, $s) :
			dependencies_unit($s);
		print ui_tag('pre', html_escape($out)) if ($out);
		print $text{'mass_failed'}, ui_p() if (!$ok && !$out);
		}
	mass_log('deps', \@units);
	}

# Get logs
if ($logs) {
	# Show recent journal output for selected units.
	foreach my $u (@units) {
		systemd_can_logs($u->{'user_scope'}, $u->{'user'}) ||
			systemd_acl_error('plogs');
		my $s = $u->{'name'};

		# Logs are read through journalctl for both system and user units.
		print_action_start(text('systemd_doinglogs',
				    mass_unit_label($u)));
		my ($ok, $out) = $u->{'user_scope'} ?
			logs_user_unit($u->{'user'}, $s) :
			logs_unit($s);
		print ui_tag('pre', html_escape($out)) if ($out);
		print $text{'mass_failed'}, ui_p() if (!$ok && !$out);
		}
	mass_log('logs', \@units);
	}

# Stop or restart before any later enable/start work.
if ($stop || $restart) {
	# Webmin itself cannot be stopped here, but it can be restarted specially.
	$SIG{'TERM'} = 'ignore';	# Restarting webmin may kill this script
	foreach my $u (@units) {
		systemd_can_runtime($stop ? 'stop' : 'restart',
				     $u->{'user_scope'}, $u->{'user'}) ||
			systemd_acl_error($stop ? 'pstop' : 'prestart');
		my $s = $u->{'name'};
		my ($ok, $out);
		my $skipped = 0;
		my $is_webmin = !$u->{'user_scope'} && $s eq 'webmin.service';

		# Stop and restart are mutually exclusive submit actions.
		if ($stop) {
			print_action_start(text('mass_ustopping',
					    mass_unit_label($u)));
			if (!$is_webmin) {
				($ok, $out) = $u->{'user_scope'} ?
					stop_user_unit($u->{'user'}, $s) :
					stop_unit($s);
				}
			}
		elsif ($restart) {
			print_action_start(text('mass_urestarting',
					    mass_unit_label($u)));
			if (!unit_restartable($s)) {
				($ok, $out) = (1, $text{'mass_enorestart'});
				$skipped = 1;
				}
			elsif (!$is_webmin) {
				($ok, $out) = $u->{'user_scope'} ?
					restart_user_unit($u->{'user'}, $s) :
					restart_unit($s);
				}
			else {
				restart_miniserv();
				}
			}

		# Keep command output under the final per-unit result.
		if ($is_webmin) {
			print_action_result(1, text('mass_enoallow', $s), 1)
				if ($stop);
			print_action_result(1, undef, 0)
				if ($restart);
			}
		else {
			print_action_result($ok, $out, $skipped);
			}
		}
	mass_log($stop ? 'massstop' : 'massrestart', \@units);
	}

# Enable or disable
if ($enable || $disable) {
	# Enable or disable startup for each selected unit.
	foreach my $u (@units) {
		systemd_can_boot($u->{'user_scope'}, $u->{'user'}) ||
			systemd_acl_error('pboot');
		my $b = $u->{'name'};
		my ($ok, $out) = (1, undef);

		# User units use systemctl --user; system units use the system manager.
		if ($enable) {
			print_action_start(text('mass_uenable',
					    mass_unit_label($u)));
			if ($u->{'user_scope'}) {
				($ok, $out) =
					enable_user_unit($u->{'user'}, $b);
				}
			else {
				($ok, $out) = enable_unit($b);
				}
			}
		else {
			print_action_start(text('mass_udisable',
					    mass_unit_label($u)));
			if ($u->{'user_scope'}) {
				($ok, $out) =
					disable_user_unit($u->{'user'}, $b);
				}
			else {
				($ok, $out) = disable_unit($b);
				}
			}

		# Keep command output under the final per-unit result.
		print_action_result($ok, $out, startup_change_skipped($out));

		}
	mass_log($enable ? 'massenable' : 'massdisable', \@units);
	}

# Mask or unmask
if ($mask || $unmask) {
	# Masking prevents activation; unmasking restores normal start behavior.
	foreach my $u (@units) {
		systemd_can_mask($u->{'user_scope'}, $u->{'user'}) ||
			systemd_acl_error('pmask');
		my $b = $u->{'name'};
		my ($ok, $out);

		# User units use systemctl --user; system units use the system manager.
		if ($mask) {
			print_action_start(text('mass_umasking',
					    mass_unit_label($u)));
			($ok, $out) = $u->{'user_scope'} ?
				mask_user_unit($u->{'user'}, $b) :
				mask_unit($b);
			}
		else {
			print_action_start(text('mass_uunmasking',
					    mass_unit_label($u)));
			($ok, $out) = $u->{'user_scope'} ?
				unmask_user_unit($u->{'user'}, $b) :
				unmask_unit($b);
			}

		# Keep command output under the final per-unit result.
		print_action_result($ok, $out, 0);
		}
	mass_log($mask ? 'massmask' : 'massunmask', \@units);
	}

# Delete user units
if ($delete) {
	# Bulk delete is intentionally limited to user units.  System unit
	# deletion stays on the per-unit edit page where the risk is clearer.
	foreach my $u (@units) {
		$u->{'user_scope'} || error($text{'mass_edelete_user'});
		systemd_can_delete(1, $u->{'user'}) ||
			systemd_acl_error('pdelete_user');
		my $s = $u->{'name'};
		print_action_start(text('mass_udeleting',
				    mass_unit_label($u)));
		disable_user_unit($u->{'user'}, $s);
		stop_user_unit($u->{'user'}, $s);
		my ($ok, $out) = delete_user_unit($u->{'user'}, $s);
		print_action_result($ok, $out, 0);
		}
	mass_log('massdelete', \@units);
	}

# Try to start at last
if ($start) {
	# Start last, so "enable and start" first creates the wanted symlink.
	foreach my $u (@units) {
		systemd_can_runtime('start',
				     $u->{'user_scope'}, $u->{'user'}) ||
			systemd_acl_error('pstart');
		my $s = $u->{'name'};
		my ($ok, $out);

		# Each selected unit is started independently and reported inline.
		print_action_start(text('mass_ustarting',
				    mass_unit_label($u)));
		my $skipped = 0;
		if (!unit_startable($s)) {
			($ok, $out) = (1, $text{'mass_enostart'});
			$skipped = 1;
			}
		else {
			($ok, $out) = $u->{'user_scope'} ?
				start_user_unit($u->{'user'}, $s) :
				start_unit($s);
			}
		print_action_result($ok, $out, $skipped);
		}
	mass_log('massstart', \@units);
	}

# Return to the unit page when it should still exist; otherwise return to its
# tab.  Transient units can disappear after stop/restart actions.
if ($in{'return'} && !$in{'returnindex'}) {
	my $dropin = $in{'returndropin'} ? "&dropin=1" : "";
	my $dropfile = $dropin && $in{'returndropfile'} ?
		"&dropfile=".urlize(clean_unit_value($in{'returndropfile'})) :
		"";
	my $return = $user_scope ?
		"edit_unit.cgi?scope=user&unituser=".urlize($unituser).
		"&name=".urlize($in{'return'}).$dropin.$dropfile :
		"edit_unit.cgi?name=".urlize($in{'return'}).$dropin.$dropfile;
	ui_print_footer($return,
			 $text{'systemd_return'});
	}
else {
	my $u = $units[0];
	my $return = index_url($u->{'name'}, $u->{'user_scope'},
				       $user_scope ? $unituser : undef);
	ui_print_footer($return, $text{'index_return'});
	}

# print_action_start(message)
# Prints the first progress line for a unit action.
sub print_action_start
{
my ($msg) = @_;
if ($printed_action_result) {
	print ui_tag('div', '', { 'class' => 'systemd-action-break',
				  'style' => 'height: 1em;' }), "\n";
	$printed_action_result = 0;
	}
print ui_tag('span', $msg, { 'data-first-print' => undef });
print ui_br(), "\n";
return;
}

# print_action_result(ok, output, skipped, html)
# Prints the final result line with command output folded underneath it.
sub print_action_result
{
my ($ok, $out, $skipped, $html) = @_;
my $status = $skipped ? $text{'mass_skipped'} :
	     $ok ? $text{'mass_ok'} : $text{'mass_failed'};
my $title = ui_tag('span', html_escape($status),
		   { 'data-second-print' => undef });
if (!defined($out) || $out eq "") {
	print $title, "\n";
	$printed_action_result = 1;
	return;
	}

# Keep successful output quiet, but open failures for immediate diagnosis.
my $content = $out;
$content = $html ? $content :
	ui_tag('pre', html_escape($content),
	       { 'style' => 'margin-left: 10px;' });
print ui_details({
	'html' => 1,
	'title' => $title,
	'content' => $content,
	'class' => 'inline inlined',
	}, !$ok && !$skipped);
print "\n";
$printed_action_result = 1;
return;
}

# mass_units(selected, user-scope, users-scope, user)
# Converts selected checkbox values into action records with optional owners.
sub mass_units
{
my ($selected, $user_scope, $users_scope, $unituser) = @_;
my @rv;

# The user-units tab packs owner and unit name into one checkbox value.
if ($users_scope) {
	foreach my $raw (@$selected) {
		my ($encuser, $encname) = split(/\t/, $raw, 2);
		defined($encuser) && defined($encname) ||
			error($text{'systemd_euser'});
		my $user = clean_unit_value(un_urlize($encuser));
		my $name = un_urlize($encname);
		get_user_details($user) ||
			error($text{'systemd_euser'});
		valid_unit_name($name) ||
			error($text{'systemd_ename'});
		push(@rv, { 'name' => $name,
			    'user' => $user,
			    'user_scope' => 1 });
		}
	}
else {
	# System-unit rows and single-user edit actions submit plain unit names.
	foreach my $name (@$selected) {
		valid_unit_name($name) ||
			error($text{'systemd_ename'});
		push(@rv, { 'name' => $name,
			    'user' => $unituser,
			    'user_scope' => $user_scope });
		}
	}
return @rv;
}

# mass_unit_label(unit)
# Returns escaped HTML for a unit name, including owner for user units.
sub mass_unit_label
{
my ($unit) = @_;
my $name = ui_tag('tt', html_escape($unit->{'name'}));
return $name if (!$unit->{'user_scope'});
return text('systemd_unit_for_user', $name,
	     ui_tag('tt', html_escape($unit->{'user'})));
}

# mass_log(action, units)
# Logs mixed system and user unit actions under the correct log type.
sub mass_log
{
my ($action, $units) = @_;
my @system;
my %users;

# Keep system and user actions separate so the log parser gets owner context.
foreach my $u (@$units) {
	if ($u->{'user_scope'}) {
		push(@{$users{$u->{'user'}}}, $u->{'name'});
		}
	else {
		push(@system, $u->{'name'});
		}
	}

# Group user-unit records by owner to avoid one log line per unit.
webmin_log($action, 'systemd', join(" ", @system)) if (@system);
foreach my $user (sort keys %users) {
	webmin_log($action, 'systemd-user', join(" ", @{$users{$user}}),
		    { 'user' => $user });
	}
}
