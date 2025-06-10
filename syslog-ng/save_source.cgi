#!/usr/local/bin/perl
# Create, update or delete a log source

require './syslog-ng-lib.pl';
&ReadParse();
&error_setup($text{'source_err'});

# Get the old source
$conf = &get_config();
if (!$in{'new'}) {
	@sources = &find("source", $conf);
	($source) = grep { $_->{'value'} eq $in{'old'} } @sources;
	$source || &error($text{'source_egone'});
	$old = $source;
	}
else {
	$source = { 'name' => 'source',
		  'type' => 1,
		  'members' => [ ] };
	}

&lock_all_files($conf);
if ($in{'delete'}) {
	# Just delete it!
	&check_dependencies('source', $in{'old'}) &&
	    &error(&text('sdelete_eused', $in{'old'}));
	&save_directive($conf, undef, $source, undef, 0);
	}
else {
	# Validate inputs, and update object
	$in{'name'} =~ /^[a-z0-9_]+$/i || &error($text{'source_ename'});
	if ($in{'new'} || $in{'old'} ne $in{'name'}) {
		($clash) = grep { $_->{'value'} eq $in{'name'} } @sources;
		$clash && &error($text{'source_eclash'});
		}
	$source->{'values'} = [ $in{'name'} ];

	# Clear out all existing values
	$source->{'members'} = [ ];

	if ($in{'internal'}) {
		# Save internal option
		$internal = { 'name' => 'internal',
			      'type' => 0,
			      'values' => [ ] };
		&save_directive($conf, $source, undef, $internal, 1);
		}

	foreach $t ("unix-stream", "unix-dgram") {
		# Save Unix socket file option
		next if (!$in{$t});
		$in{$t.'_name'} =~ /^\/\S/ ||
			&error($text{'source_eunix_name'});
		$unix = { 'name' => $t,
			  'type' => 0,
			  'values' => [ $in{$t.'_name'} ] };
		&save_directive($conf, $source, undef, $unix, 1);

		# Save owner
		if (!$in{$t.'_owner_def'}) {
			defined(getpwnam($in{$t.'_owner'})) ||
				&error($text{'source_eowner'});
			&save_directive($conf, $unix, "owner",
					$in{$t.'_owner'}, 1);
			}
		if (!$in{$t.'_group_def'}) {
			defined(getgrnam($in{$t.'_group'})) ||
				&error($text{'source_egroup'});
			&save_directive($conf, $unix, "group",
					$in{$t.'_group'}, 1);
			}

		# Save permissions
		if (!$in{$t.'_perm_def'}) {
			$in{$t.'_perm'} =~ /^[0-7]+$/ ||
				&error($text{'source_eperm'});
			&save_directive($conf, $unix, "perm",
					$in{$t.'_perm'}, 1);
			}

		if ($t eq "unix-stream") {
			# Save keep-alive option
			if ($in{$t.'_keep'}) {
				&save_directive($conf, $unix, "keep-alive",
						$in{$t.'_keep'}, 1);
				}

			# Save max connections option
			if (!$in{$t.'_max_def'}) {
				$in{$t.'_max'} =~ /^\d+$/ ||
					&error($text{'source_emax'});
				&save_directive($conf, $unix, "max-connections",
						$in{$t.'_max'}, 1);
				}
			}
		}

	foreach $t ('tcp', 'udp') {
		# Save network socket file option
		next if (!$in{$t});
		$net = { 'name' => $t,
		         'type' => 0,
			 'values' => [ ] };
		&save_directive($conf, $source, undef, $net, 1);

		# Save local IP and port
		if (!$in{$t.'_ip_def'}) {
			&check_ipaddress($in{$t.'_ip'}) ||
				&error($text{'source_eip'});
			&save_directive($conf, $net, "ip",
					$in{$t.'_ip'}, 1);
			}
		if (!$in{$t.'_port_def'}) {
			$in{$t.'_port'} =~ /^\d+$/ ||
				&error($text{'source_eport'});
			&save_directive($conf, $net, "port",
					$in{$t.'_port'}, 1);
			}

		# Save TCP-specific options and max connections
		if ($t eq "tcp") {
			if ($in{$t.'_keep'}) {
				&save_directive($conf, $net, "keep-alive",
						$in{$t.'_keep'}, 1);
				}
			if ($in{$t.'_tkeep'}) {
				&save_directive($conf, $net, "tcp-keep-alive",
						$in{$t.'_tkeep'}, 1);
				}
			}
		if (!$in{$t.'_max_def'}) {
			$in{$t.'_max'} =~ /^\d+$/ ||
				&error($text{'source_emax'});
			&save_directive($conf, $net, "max-connections",
					$in{$t.'_max'}, 1);
			}
		}

	# Save kernel file option
	if ($in{'file'}) {
		$in{'file_name'} =~ /^\/\S/ ||
			&error($text{'source_efile_name'});
		$file = { 'name' => 'file',
		          'type' => 0,
			  'values' => [ $in{'file_name'} ] };
		&save_directive($conf, $source, undef, $file, 1);

		# Save log prefix
		if (!$in{'file_prefix_def'}) {
			$in{'file_prefix'} =~ /\S/ ||
			    &error($text{'source_eprefix'});
			&save_directive($conf, $file, "log_prefix",
					$in{'file_prefix'}, 1);
			}
		}

	# Save named pipe option
	if ($in{'pipe'}) {
		$in{'pipe_name'} =~ /^\/\S/ ||
			&error($text{'source_epipe_name'});
		$pipe = { 'name' => 'pipe',
		          'type' => 0,
			  'values' => [ $in{'pipe_name'} ] };
		&save_directive($conf, $source, undef, $pipe, 1);

		# Save log prefix and pad size
		if (!$in{'pipe_prefix_def'}) {
			$in{'pipe_prefix'} =~ /\S/ ||
			    &error($text{'source_eprefix'});
			&save_directive($conf, $pipe, "log_prefix",
					$in{'pipe_prefix'}, 1);
			}
		if (!$in{'pipe_pad_def'}) {
			$in{'pipe_pad'} =~ /^\d+$/ ||
			    &error($text{'source_epad'});
			&save_directive($conf, $pipe, "pad_size",
					$in{'pipe_pad'}, 1);
			}
		}
		
	# Save Solaris streams option
	if ($in{'sun-streams'}) {
		$in{'sun_streams_name'} =~ /^\/\S/ ||
			&error($text{'source_esun_streams_name'});
		$sun_streams = { 'name' => 'sun-streams',
				 'type' => 0,
				 'values' => [ $in{'sun_streams_name'} ] };
		&save_directive($conf, $source, undef, $sun_streams, 1);

		# Save door file
		$in{'sun_streams_door'} =~ /\S/ ||
		    &error($text{'source_edoor'});
		&save_directive($conf, $sun_streams, "door",
				$in{'sun_streams_door'}, 1);
		}

	# Save syslog protocol option
	if ($in{'network'}) {
		$net = { 'name' => 'network',
		         'type' => 0,
			 'values' => [ ] };
		&save_directive($conf, $source, undef, $net, 1);

		# Save local IP and port
		if (!$in{'network_ip_def'}) {
			&check_ipaddress($in{'network_ip'}) ||
				&error($text{'source_eip'});
			&save_directive($conf, $net, "ip",
					$in{'network_ip'}, 1);
			}
		if (!$in{'network_port_def'}) {
			$in{'network_port'} =~ /^\d+$/ ||
				&error($text{'source_eport'});
			&save_directive($conf, $net, "port",
					$in{'network_port'}, 1);
			}
		if ($in{'network_transport'}) {
			&save_directive($conf, $net, "transport",
					$in{'network_transport'}, 1);
			}
		}

	# Actually update the object
	&save_directive($conf, undef, $old, $source, 0);

	# Update dependent log targets
	if (!$in{'new'}) {
		&rename_dependencies('source', $in{'old'}, $in{'name'});
		}
	}

&unlock_all_files();
&webmin_log($in{'delete'} ? 'delete' : $in{'new'} ? 'create' : 'modify',
	    'source', $in{'old'} || $in{'name'});
&redirect("list_sources.cgi");

