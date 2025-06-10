#!/usr/local/bin/perl
# Create, update or delete a destination

require './syslog-ng-lib.pl';
&ReadParse();
&error_setup($text{'destination_err'});

# Get the old destination
$conf = &get_config();
if (!$in{'new'}) {
	@dests = &find("destination", $conf);
	($dest) = grep { $_->{'value'} eq $in{'old'} } @dests;
	$dest || &error($text{'destination_egone'});
	$old = $dest;
	}
else {
	$dest = { 'name' => 'destination',
		  'type' => 1,
		  'members' => [ ] };
	}

&lock_all_files($conf);
if ($in{'delete'}) {
	# Just delete it!
	&check_dependencies('destination', $in{'old'}) &&
	    &error(&text('ddelete_eused', $in{'old'}));
	&save_directive($conf, undef, $dest, undef, 0);
	}
else {
	# Validate inputs, and update object
	$in{'name'} =~ /^[a-z0-9_]+$/i || &error($text{'destination_ename'});
	if ($in{'new'} || $in{'old'} ne $in{'name'}) {
		($clash) = grep { $_->{'value'} eq $in{'name'} } @dests;
		$clash && &error($text{'destination_eclash'});
		}
	$dest->{'values'} = [ $in{'name'} ];

	# Clear out all existing values
	$dest->{'members'} = [ ];

	# Save type-specific values
	if ($in{'type'} == 0) {
		# Writing to a file
		$in{'file_name'} =~ /^\/\S/ ||
			&error($text{'destination_efile_name'});
		$file = { 'name' => 'file',
			  'type' => 0,
			  'values' => [ $in{'file_name'} ] };
		&save_directive($conf, $dest, undef, $file, 1);

		# Save owner
		if (!$in{'file_owner_def'}) {
			defined(getpwnam($in{'file_owner'})) ||
				&error($text{'destination_eowner'});
			&save_directive($conf, $file, "owner",
					$in{'file_owner'}, 1);
			}
		if (!$in{'file_group_def'}) {
			defined(getgrnam($in{'file_group'})) ||
				&error($text{'destination_egroup'});
			&save_directive($conf, $file, "group",
					$in{'file_group'}, 1);
			}

		# Save permissions
		if (!$in{'file_perm_def'}) {
			$in{'file_perm'} =~ /^[0-7]+$/ ||
				&error($text{'destination_eperm'});
			&save_directive($conf, $file, "perm",
					$in{'file_perm'}, 1);
			}

		# Save create dirs option
		if ($in{'file_create_dirs'}) {
			&save_directive($conf, $file, "create_dirs",
					$in{'file_create_dirs'}, 1);
			}
		if (!$in{'file_dir_perm_def'}) {
			$in{'file_dir_perm'} =~ /^[0-7]+$/ ||
				&error($text{'destination_edir_perm'});
			&save_directive($conf, $file, "dir_perm",
					$in{'file_dir_perm'}, 1);
			}

		# Save sync options
		if ($in{'file_fsync'}) {
			&save_directive($conf, $file, "fsync",
					$in{'file_fsync'}, 1);
			}
		if (!$in{'file_sync_freq_def'}) {
			$in{'file_sync_freq'} =~ /^\d+$/ ||
				&error($text{'destination_esync_freq'});
			&save_directive($conf, $file, "sync_freq",
					$in{'file_sync_freq'}, 1);
			}
		}

	elsif ($in{'type'} == 1) {
		# Sending to users
		$in{'usertty_user_def'} || $in{'usertty_user'} ||
			&error($text{'destination_euser'});
		$usertty = { 'name' => 'usertty',
			  'type' => 0,
			  'values' => [ $in{'usertty_user_def'} ? '*' :
					  $in{'usertty_user'} ] };
		&save_directive($conf, $dest, undef, $usertty, 1);
		}

	elsif ($in{'type'} == 2) {
		# Feeding to a program
		$in{'program_prog'} =~ /^\S/ ||
			&error($text{'destination_eprog'});
		$program = { 'name' => 'program',
			     'type' => 0,
			     'values' => [ $in{'program_prog'} ] };
		&save_directive($conf, $dest, undef, $program, 1);
		}

	elsif ($in{'type'} == 3) {
		# Writing to a pipe file
		$in{'pipe_name'} =~ /^\S/ ||
			&error($text{'destination_epipe'});
		$pipe = { 'name' => 'pipe',
			     'type' => 0,
			     'values' => [ $in{'pipe_name'} ] };
		&save_directive($conf, $dest, undef, $pipe, 1);
		}

	elsif ($in{'type'} == 4) {
		# Writing to a TCP or UDP socket
		$net = { 'name' => $in{'net_proto'},
			 'type' => 0,
			 'values' => [ $in{'net_host'} ] };
		&to_ipaddress($in{'net_host'}) ||
		    &to_ip6address($in{'net_host'}) ||
			&error($text{'destination_enet_host'});
		&save_directive($conf, $dest, undef, $net, 1);

		# Save other network dest options
		if (!$in{'net_port_def'}) {
			$in{'net_port'} =~ /^\d+$/ ||
				&error($text{'destination_enet_port'});
			&save_directive($conf, $net, "port",
					$in{'net_port'}, 1);
			}
		if (!$in{'net_localip_def'}) {
			&check_ipaddress($in{'net_localip'}) ||
				&error($text{'destination_enet_localip'});
			&save_directive($conf, $net, "localip",
					$in{'net_localip'}, 1);
			}
		if (!$in{'net_localport_def'}) {
			$in{'net_localport'} =~ /^\d+$/ ||
				&error($text{'destination_enet_localport'});
			&save_directive($conf, $net, "localport",
					$in{'net_localport'}, 1);
			}
		}

	elsif ($in{'type'} == 6) {
		$unix = { 'name' => $in{'unix_type'},
			 'type' => 0,
			 'values' => [ $in{'unix_name'} ] };
		$in{'unix_name'} || &error($text{'destination_eunix'});
		&save_directive($conf, $dest, undef, $unix, 1);
		}

	# Actually update the object
	&save_directive($conf, undef, $old, $dest, 0);

        # Update dependent log targets
	if (!$in{'new'}) {
		  &rename_dependencies('destination', $in{'old'}, $in{'name'});
	          }
	}

&unlock_all_files();
&webmin_log($in{'delete'} ? 'delete' : $in{'new'} ? 'create' : 'modify',
	    'destination', $in{'old'} || $in{'name'});
&redirect("list_destinations.cgi");

