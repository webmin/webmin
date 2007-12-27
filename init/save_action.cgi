#!/usr/local/bin/perl
# save_action.cgi
# Save or create an action

require './init-lib.pl';
&error_setup($text{'save_err'});
&ReadParseMime();

# Redirect to other CGIs for delete / start / stop
if ($in{'delete'} && $in{'old'}) {
	&redirect("delete_action.cgi?type=".&urlize($in{'type'}).
		  "&action=".&urlize($in{'old'}).
		  "&runlevel=".&urlize($in{'runlevel'}).
		  "&startstop=".&urlize($in{'startstop'}).
		  "&number=".&urlize($in{'number'}));
	}
elsif ($in{'old'}) {
	foreach $a (@action_buttons) {
		if ($in{$a}) {
			&redirect("start_stop.cgi?file=".&urlize($in{'file'}).
				  "&name=".&urlize($in{'old'})."&$a=1".
				  "&back=".&urlize($in{'back'}));
			exit;
			}
		}
	}

$access{'bootup'} == 1 || &error($text{'save_ecannot'});

# Check inputs
$in{'extra'} || $in{name} =~ /^[A-z0-9\_\-\.]+$/ ||
	&error($text{'save_ename'});
$dig = $config{'order_digits'};
foreach $rl (&list_runlevels()) {
	# If no priority was given for start/stop, make it 99
	if ($in{"S$rl"}) {
		if (!$in{"pri_S$rl"}) {
			$in{"pri_S$rl"} = "9" x $dig;
			}
		else {
			$in{"pri_S$rl"} = sprintf "%${dig}.${dig}d",
						  $in{"pri_S$rl"};
			}
		}
	if ($in{"K$rl"}) {
		if (!$in{"pri_K$rl"}) {
			$in{"pri_K$rl"} = "9" x $dig;
			}
		else {
			$in{"pri_K$rl"} = sprintf "%${dig}.${dig}d",
						  $in{"pri_K$rl"};
			}
		}
	}

if ($in{'old'} && $in{'type'} == 0) {
	# Changing a 'sane' action
	local $dd = $config{'daemons_dir'};
	$in{data} =~ s/\r//g;
	if ($in{old} ne $in{name}) {
		# Need to rename the action..
		if (-r &action_filename($in{name})) {
			&error(&text('save_ealready', $in{name}));
			}
		&rename_action($in{old}, $in{name});
		if ($dd) {
			# Need to rename the caldera daemons file too
			&rename_logged("$dd/$in{old}", "$dd/$in{name}");
			&lock_file("$dd/$in{'name'}");
			&read_env_file("$dd/$in{name}", \%daemon);
			$daemon{'IDENT'} = $in{'name'}
				if ($daemon{'IDENT'} eq $in{'old'});
			&write_env_file("$dd/$in{name}", \%daemon);
			}
		}
	&lock_file("$dd/$in{'name'}") if ($dd);
	$file = &action_filename($in{name});
	&lock_file($file);
	foreach (&action_levels('S', $in{name})) {
		/^(\S+)\s+(\S+)\s+(\S+)$/;
		$slvl{$1} = $2;
		}
	foreach (&action_levels('K', $in{name})) {
		/^(\S+)\s+(\S+)\s+(\S+)$/;
		$klvl{$1} = $2;
		}
	if ($config{'expert'}) {
		# Update all runlevels
		foreach $rl (&list_runlevels()) {
			if ($in{"S$rl"} && !$slvl{$rl}) {
				&add_rl_action($in{name}, $rl,
					       'S', $in{"pri_S$rl"});
				}
			elsif (!$in{"S$rl"} && $slvl{$rl}) {
				&delete_rl_action($in{name}, $rl, 'S');
				}
			elsif ($in{"pri_S$rl"} != $slvl{$rl}) {
				&reorder_rl_action($in{name}, $rl,
						   'S', $in{"pri_S$rl"});
				}
			if ($in{"K$rl"} && !$klvl{$rl}) {
				&add_rl_action($in{name}, $rl,
					       'K', $in{"pri_K$rl"});
				}
			elsif (!$in{"K$rl"} && $klvl{$rl}) {
				&delete_rl_action($in{name}, $rl, 'K');
				}
			elsif ($in{"pri_K$rl"} != $klvl{$rl}) {
				&reorder_rl_action($in{name}, $rl,
						   'K',$in{"pri_K$rl"});
				}
			}

		if (defined($in{'boot'}) && $dd) {
			# Update onboot flag in daemons file
			&read_env_file("$dd/$in{'name'}", \%daemon);
			$daemon{'ONBOOT'} = $in{'boot'} ? 'yes' : 'no';
			&write_env_file("$dd/$in{'name'}", \%daemon);
			}
		}
	else {
		# Just change whether it gets started or not
		if ($in{'boot'} && !$in{'oldboot'}) {
			&enable_at_boot($in{'name'});
			}
		elsif (!$in{'boot'} && $in{'oldboot'}) {
			&disable_at_boot($in{'name'});
			}
		}
	&open_tempfile(ACTION, ">$file");
	&print_tempfile(ACTION, $in{data});
	&close_tempfile(ACTION);
	&unlock_file($file);
	&unlock_file("$dd/$in{'name'}") if ($dd);
	delete($in{'data'});
	&webmin_log("modify", "action", $in{'name'}, \%in);
	}
elsif ($in{'old'} && $in{'type'} == 1) {
	# Changing an odd action
	$in{data} =~ s/\r//g;
	$file = &runlevel_filename($in{runlevel}, $in{startstop},
				   $in{number}, $in{name});
	&lock_file($file);
	if ($in{old} ne $in{name}) {
		if (-r &action_filename($in{name})) {
			&error("An action called $in{name} already exists");
			}
		&rename_rl_action($in{runlevel}, $in{startstop}, $in{number},
				  $in{old}, $in{name});
		}
	&open_tempfile(ACTION, ">$file");
	&print_tempfile(ACTION, $in{data});
	&close_tempfile(ACTION);
	&unlock_file($file);
	delete($in{'data'});
	&webmin_log("modify", "action", $in{'name'}, \%in);
	}
else {
	# Creating a new action, and add it to multiple runlevels
	if (-r &action_filename($in{name})) {
		&error(&text('save_ealready', $in{name}));
		}
	@start = &get_start_runlevels();
	&lock_file(&action_filename($in{name}));
	$in{desc} =~ s/\r//g; $in{start} =~ s/\r//g; $in{stop} =~ s/\r//g;
	$data = "#!/bin/sh\n";
	if ($config{'chkconfig'}) {
		# Redhat-style description: and chkconfig: lines
		$desc = "description:";
		foreach (split(/\n/, $in{desc})) {
			$data .= "# $desc $_\n";
			$desc = " " x length($desc);
			}
		$startorder = "9" x $dig;
		$stoporder = "0" x $dig;
		foreach $rl (&list_runlevels()) {
			$startorder = $in{"pri_S$rl"} if ($in{"S$rl"});
			$stoporder = $in{"pri_K$rl"} if ($in{"K$rl"});
			}
		$data .= "# chkconfig: $config{'chkconfig'} ".
			 "$startorder $stoporder\n";
		}
	elsif ($config{'init_info'}) {
		# Suse-style init info section
		$data .= "### BEGIN INIT INFO\n".
			 "# Provides: $in{'name'}\n".
		         "# Required-Start: \$network\n".
		         "# Required-Stop: \$network\n".
			 "# Default-Start: ".join(" ", @start)."\n".
			 "# Description: $in{'desc'}\n".
			 "### END INIT INFO\n";
		}
	else {
		foreach (split(/\n/, $in{'desc'})) {
			$data .= "# $_\n";
			}
		}
	$data .= "\ncase \"\$1\" in\n";
	if ($config{'start_stop_msg'}) {
		$data .= "'start_msg')\n";
		$data .= "\techo \"$in{'start_msg'}\"\n";
		$data .= "\t;;\n";
		$data .= "'stop_msg')\n";
		$data .= "\techo \"$in{'stop_msg'}\"\n";
		$data .= "\t;;\n";
		}
	$subsys = $config{'subsys'};
	$data .= "'start')\n";
	foreach (split(/\n/, $in{start})) {
		$data .= "\t$_\n";
		}
	if ($subsys) {
		$data .= "\ttouch $subsys/$in{'name'}\n";
		}
	$data .= "\t;;\n";
	$data .= "'stop')\n";
	foreach (split(/\n/, $in{stop})) {
		$data .= "\t$_\n";
		}
	if ($subsys) {
		$data .= "\trm -f $subsys/$in{'name'}\n";
		}
	$data .= "\t;;\n";
	$data .= "*)\n";
	if ($config{'start_stop_msg'}) {
		$data .= "\techo \"Usage: \$0 { start | stop | start_msg | stop_msg }\"\n";
		}
	else {
		$data .= "\techo \"Usage: \$0 { start | stop }\"\n";
		}
	$data .= "\t;;\n";
	$data .= "esac\n";
	$data .= "exit 0\n";
	$file = &action_filename($in{name});
	&open_tempfile(ACTION, ">$file");
	&print_tempfile(ACTION, $data);
	&close_tempfile(ACTION);
	chmod(0755, $file);

	if ($config{'expert'}) {
		# Make links from runlevels
		foreach $rl (&list_runlevels()) {
			if ($in{"S$rl"}) {
				&add_rl_action($in{name}, $rl, 'S',
					       $in{"pri_S$rl"});
				}
			if ($in{"K$rl"}) {
				&add_rl_action($in{name}, $rl, 'K',
					       $in{"pri_K$rl"});
				}
			}
		}
	else {
		# Just make one runlevel link
		if ($in{'boot'}) {
			&enable_at_boot($in{'name'});
			}
		}
	&unlock_file(&action_filename($in{name}));
	delete($in{'data'});
	&webmin_log("create", "action", $in{'name'}, \%in);
	}
&redirect("");

