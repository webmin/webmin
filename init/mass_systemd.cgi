#!/usr/local/bin/perl
# Start, stop, inspect or enable a set of systemd units

require './init-lib.pl';
&ReadParse();
@sel = split(/\0/, $in{'d'});
@sel || &error($text{'mass_enone'});

# Work out whether selections target system or user managers.
$user_scope = $in{'scope'} eq 'user' ? 1 : 0;
$users_scope = $in{'scope'} eq 'users' ? 1 : 0;
$unituser = &clean_systemd_unit_value($in{'unituser'});
if ($user_scope) {
	&get_systemd_user_details($unituser) ||
		&error($text{'systemd_euser'});
	}
@units = &systemd_mass_units(\@sel, $user_scope, $users_scope, $unituser);

# Convert submitted buttons into action flags.
$start = 1 if ($in{'start'} || $in{'addboot_start'});
$stop = 1 if ($in{'stop'} || $in{'delboot_stop'});
$restart = 1 if ($in{'restart'});
$status = 1 if ($in{'status'});
$logs = 1 if ($in{'logs'});
$enable = 1 if ($in{'addboot'} || $in{'addboot_start'});
$disable = 1 if ($in{'delboot'} || $in{'delboot_stop'});

&ui_print_unbuffered_header(undef, $logs ? $text{'systemd_logs'} :
				     $status ? $text{'systemd_statustitle'} :
				     $restart ? $text{'mass_urestart'} :
				     $start ? $text{'mass_ustart'} :
				     $stop ? $text{'mass_ustop'} :
				     $enable ? $text{'mass_usenable'} :
				     $disable ? $text{'mass_usdisable'} :
				     $text{'mass_ustop'}, "");

# Get status
if ($status) {
	# Show full systemd status output for selected units.
	$access{'bootup'} || &error($text{'ss_ecannot'});
	foreach my $u (@units) {
		my $s = $u->{'name'};
		print &text('systemd_doingstatus',
			    &systemd_mass_unit_label($u)),
		      &ui_br(), "\n";
		my ($ok, $out) = $u->{'user_scope'} ?
			&status_systemd_user_service($u->{'user'}, $s) :
			&status_systemd_service($s);
		print &ui_tag('pre', &html_escape($out)) if ($out);
		print $text{'mass_failed'}, &ui_p() if (!$out);
		}
	&systemd_mass_log('status', \@units);
	}

# Get logs
if ($logs) {
	# Show recent journal output for selected units.
	$access{'bootup'} || &error($text{'ss_ecannot'});
	foreach my $u (@units) {
		my $s = $u->{'name'};
		print &text('systemd_doinglogs', &systemd_mass_unit_label($u)),
		      &ui_br(), "\n";
		my ($ok, $out) = $u->{'user_scope'} ?
			&logs_systemd_user_service($u->{'user'}, $s) :
			&logs_systemd_service($s);
		print &ui_tag('pre', &html_escape($out)) if ($out);
		print $text{'mass_failed'}, &ui_p() if (!$ok && !$out);
		}
	&systemd_mass_log('logs', \@units);
	}

# Stop or restart before any later enable/start work.
if ($stop || $restart) {
	# Webmin itself cannot be stopped here, but it can be restarted specially.
	$access{'bootup'} || &error($text{'ss_ecannot'});
	$SIG{'TERM'} = 'ignore';	# Restarting webmin may kill this script
	foreach my $u (@units) {
		my $s = $u->{'name'};
		my ($ok, $out);
		my $is_webmin = !$u->{'user_scope'} && $s eq 'webmin.service';
		if ($stop) {
			print &text('mass_ustopping',
				    &systemd_mass_unit_label($u)),
			      &ui_br(), "\n";
			if (!$is_webmin) {
				($ok, $out) = $u->{'user_scope'} ?
					&stop_systemd_user_service($u->{'user'}, $s) :
					&stop_action($s);
				}
			}
		elsif ($restart) {
			print &text('mass_urestarting',
				    &systemd_mass_unit_label($u)),
			      &ui_br(), "\n";
			if (!$is_webmin) {
				($ok, $out) = $u->{'user_scope'} ?
					&restart_systemd_user_service($u->{'user'}, $s) :
					&restart_action($s);
				}
			else {
				&restart_miniserv();
				}
			}
		print &ui_tag('pre', &html_escape($out)) if ($out);
		if ($is_webmin) {
			print "$text{'mass_skipped'} : ".
				&text('mass_enoallow', &html_escape($s)),
				&ui_p()
				if ($stop);
			print $text{'mass_ok'}, &ui_p()
				if ($restart);
			}
		elsif (!$ok) {
			print $text{'mass_failed'}, &ui_p();
			}
		else {
			print $text{'mass_ok'}, &ui_p();
			}
		}
	&systemd_mass_log($stop ? 'massstop' : 'massrestart', \@units);
	}

# Enable or disable
if ($enable || $disable) {
	# Enable or disable startup for each selected unit.
	$access{'bootup'} == 1 || &error($text{'edit_ecannot'});
	foreach my $u (@units) {
		my $b = $u->{'name'};
		my ($ok, $out) = (1, undef);
		if ($enable) {
			print &text('mass_uenable',
				    &systemd_mass_unit_label($u)),
			      &ui_br(), "\n";
			if ($u->{'user_scope'}) {
				($ok, $out) =
					&enable_systemd_user_service($u->{'user'}, $b);
				}
			else {
				&enable_at_boot($b);
				}
			}
		else {
			print &text('mass_udisable',
				    &systemd_mass_unit_label($u)),
			      &ui_br(), "\n";
			if ($u->{'user_scope'}) {
				($ok, $out) =
					&disable_systemd_user_service($u->{'user'}, $b);
				}
			else {
				&disable_at_boot($b);
				}
			}
		print &ui_tag('pre', &html_escape($out)) if ($out);
		print (($ok ? $text{'mass_ok'} : $text{'mass_failed'}),
		       &ui_p());

		}
	&systemd_mass_log($enable ? 'massenable' : 'massdisable', \@units);
	}

# Try to start at last
if ($start) {
	# Start last, so "enable and start" first creates the wanted symlink.
	$access{'bootup'} || &error($text{'ss_ecannot'});
	foreach my $u (@units) {
		my $s = $u->{'name'};
		my ($ok, $out);
		print &text('mass_ustarting',
			    &systemd_mass_unit_label($u)),
		      &ui_br(), "\n";
		($ok, $out) = $u->{'user_scope'} ?
			&start_systemd_user_service($u->{'user'}, $s) :
			&start_action($s);
		print &ui_tag('pre', &html_escape($out)) if ($out);
		if (!$ok) {
			print $text{'mass_failed'}, &ui_p();
			}
		else {
			print $text{'mass_ok'}, &ui_p();
			}
		}
	&systemd_mass_log('massstart', \@units);
	}

# Return to the unit page when one sent us here.
if ($in{'return'}) {
	my $return = $user_scope ?
		"edit_systemd.cgi?scope=user&unituser=".&urlize($unituser).
		"&name=".&urlize($in{'return'}) :
		"edit_systemd.cgi?name=".&urlize($in{'return'});
	&ui_print_footer($return,
			 $text{'systemd_return'});
	}
else {
	my $u = $units[0];
	my $return = &systemd_index_url($u->{'name'}, $u->{'user_scope'},
				       $user_scope ? $unituser : undef);
	&ui_print_footer($return, $text{'index_return'});
	}

# systemd_mass_units(&selected, user-scope, users-scope, user)
# Converts selected checkbox values into action records with optional owners.
sub systemd_mass_units
{
my ($selected, $user_scope, $users_scope, $unituser) = @_;
my @rv;
if ($users_scope) {
	foreach my $raw (@$selected) {
		my ($encuser, $encname) = split(/\t/, $raw, 2);
		defined($encuser) && defined($encname) ||
			&error($text{'systemd_euser'});
		my $user = &clean_systemd_unit_value(&un_urlize($encuser));
		my $name = &un_urlize($encname);
		&get_systemd_user_details($user) ||
			&error($text{'systemd_euser'});
		&valid_systemd_unit_name($name) ||
			&error($text{'systemd_ename'});
		push(@rv, { 'name' => $name,
			    'user' => $user,
			    'user_scope' => 1 });
		}
	}
else {
	foreach my $name (@$selected) {
		if ($user_scope) {
			&valid_systemd_unit_name($name) ||
				&error($text{'systemd_ename'});
			}
		push(@rv, { 'name' => $name,
			    'user' => $unituser,
			    'user_scope' => $user_scope });
		}
	}
return @rv;
}

# systemd_mass_unit_label(&unit)
# Returns escaped HTML for a unit name, including owner for user units.
sub systemd_mass_unit_label
{
my ($unit) = @_;
my $name = &ui_tag('tt', &html_escape($unit->{'name'}));
return $name if (!$unit->{'user_scope'});
return &text('systemd_unit_for_user', $name,
	     &ui_tag('tt', &html_escape($unit->{'user'})));
}

# systemd_mass_log(action, &units)
# Logs mixed system and user unit actions under the correct log type.
sub systemd_mass_log
{
my ($action, $units) = @_;
my @system;
my %users;
foreach my $u (@$units) {
	if ($u->{'user_scope'}) {
		push(@{$users{$u->{'user'}}}, $u->{'name'});
		}
	else {
		push(@system, $u->{'name'});
		}
	}
&webmin_log($action, 'systemd', join(" ", @system)) if (@system);
foreach my $user (sort keys %users) {
	&webmin_log($action, 'systemd-user', join(" ", @{$users{$user}}),
		    { 'user' => $user });
	}
}
