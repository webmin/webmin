#!/usr/local/bin/perl
# save_stunnel.cgi
# Save, create or delete an SSL tunnel

require './stunnel-lib.pl';
&ReadParse();
&error_setup($text{'save_err'});

if ($in{'idx'} ne '') {
	@stunnels = &list_stunnels();
	$st = $stunnels[$in{'idx'}];
	%old = %$st;
	}

if ($in{'delete'}) {
	# Just delete from inetd.conf and xinetd.conf
	&lock_file($st->{'file'});
	if (&get_stunnel_version(\$dummy) >= 4) {
		if ($st->{'args'} =~ /^(\S+)\s+(\S+)/) {
			$cfile = $2;
			if ($cfile =~ /^\Q$module_config_directory\E\//) {
				&lock_file($cfile);
				unlink($cfile);
				}
			}
		}
	&delete_stunnel($st);
	}
else {
	# Validate inputs
	$in{'name'} =~ /^[A-z][A-z0-9\_\-]+$/ || &error($text{'save_ename'});
	$in{'port'} =~ /^\d+$/ || &error($text{'save_eport'});
	if ($in{'pmode'} == 2) {
		-r $in{'pem'} || &error(&text('save_epem', $in{'pem'}));
		}
	if (!$in{'tcpw_def'}) {
		$in{'tcpw'} =~ /^\S+$/ || &error($text{'save_etcpw'});
		}
	if (!$in{'iface_def'}) {
		&to_ipaddress($in{'iface'}) || &to_ip6address($in{'iface'}) ||
			&error($text{'save_eiface'});
		}
	if ($in{'mode'} == 0 || $in{'mode'} == 1) {
		# Running a command
		$cmd = $in{'mode'} == 0 ? $in{'cmd0'} : $in{'cmd1'};
		$args = $in{'mode'} == 0 ? $in{'args0'} : $in{'args1'};
		&has_command($cmd) || &error($text{'save_ecmd'});
		}
	else {
		# Connecting to remote host and port
		&to_ipaddress($in{'rhost'}) || &to_ip6address($in{'rhost'}) ||
			&error($text{'save_erhost'});
		$in{'rport'} =~ /^\d+$/ || &error($text{'save_erport'});
		}

	# Create inetd/xinetd config
	if (&get_stunnel_version(\$dummy) >= 4) {
		# New-style args format
		if ($in{'new'}) {
			$cfile = "$module_config_directory/$in{'name'}.conf";
			unlink($cfile);
			$conf = { };
			$st = { 'args' => "$stunnel_shortname $cfile",
				'command' => $config{'stunnel_path'},
				'type' => $in{'type'} };
			}
		else {
			if ($st->{'args'} =~ /^(\S+)\s+(\S+)/) {
				$cfile = $2;
				@conf = &get_stunnel_config($cfile);
				($conf) = grep { !$_->{'name'} } @conf;
				}
			}
		$st->{'name'} = $in{'name'};
		$st->{'port'} = $in{'port'};
		$st->{'active'} = $in{'active'};
		if ($in{'pmode'} == 1) {
			$conf->{'values'}->{'cert'} = $webmin_pem;
			}
		elsif ($in{'pmode'} == 2) {
			$conf->{'values'}->{'cert'} = $in{'pem'};
			}
		else {
			delete($conf->{'values'}->{'cert'});
			}
		$conf->{'values'}->{'client'} = $in{'cmode'} ? 'yes' : 'no';
		if (!$in{'tcpw_def'}) {
			$conf->{'values'}->{'service'} = $in{'tcpw'};
			}
		else {
			delete($conf->{'values'}->{'service'});
			}
		if (!$in{'iface_def'}) {
			$conf->{'values'}->{'local'} = $in{'iface'};
			}
		else {
			delete($conf->{'values'}->{'local'});
			}
		if ($in{'mode'} == 0 || $in{'mode'} == 1) {
			# Running a command
			$conf->{'values'}->{'exec'} = $cmd;
			$conf->{'values'}->{'execargs'} = $args if ($args);
			$conf->{'values'}->{'pty'} = $in{'mode'} ? 'yes' : 'no';
			delete($conf->{'values'}->{'connect'});
			}
		else {
			# Connecting to remote host and port
			if ($in{'rhost'} eq 'localhost') {
				$conf->{'values'}->{'connect'} = $in{'rport'};
				}
			else {
				$conf->{'values'}->{'connect'} =
					"$in{'rhost'}:$in{'rport'}";
				}
			delete($conf->{'values'}->{'exec'});
			delete($conf->{'values'}->{'execargs'});
			delete($conf->{'values'}->{'pty'});
			}

		# Save this stunnel config file
		if ($in{'new'}) {
			&create_stunnel_service($conf, $cfile);
			}
		else {
			&modify_stunnel_service($conf, $cfile);
			}
		}
	else {
		# Old-style args format
		if ($in{'new'}) {
			$st = { 'args' => $stunnel_shortname,
				'command' => $config{'stunnel_path'},
				'type' => $in{'type'} };
			}
		else {
			$st->{'args'} = $in{'args'};
			}
		$st->{'name'} = $in{'name'};
		$st->{'port'} = $in{'port'};
		$st->{'active'} = $in{'active'};
		if ($in{'pmode'} == 1) {
			$st->{'args'} .= " -p $webmin_pem";
			}
		elsif ($in{'pmode'} == 2) {
			$st->{'args'} .= " -p $in{'pem'}";
			}
		if ($in{'cmode'}) {
			$st->{'args'} .= " -c";
			}
		if (!$in{'tcpw_def'}) {
			$st->{'args'} .= " -N $in{'tcpw'}";
			}
		if (!$in{'iface_def'}) {
			$st->{'args'} .= " -I $in{'iface'}";
			}
		if ($in{'mode'} == 0 || $in{'mode'} == 1) {
			# Running a command
			if ($in{'mode'} == 0) {
				$st->{'args'} .= " -l $cmd";
				}
			else {
				$st->{'args'} .= " -L $cmd";
				}
			if ($args) {
				$st->{'args'} .= " -- $args";
				}
			}
		else {
			# Connecting to remote host and port
			if ($in{'rhost'} eq 'localhost') {
				$st->{'args'} .= " -r $in{'rport'}";
				}
			else {
				$st->{'args'} .=" -r $in{'rhost'}:$in{'rport'}";
				}
			}
		}

	if ($in{'new'}) {
		&lock_create_file();
		&create_stunnel($st);
		}
	else {
		&lock_file($old{'file'});
		&modify_stunnel(\%old, $st);
		}
	}
&unlock_all_files();
&webmin_log($in{'delete'} ? "delete" : $in{'new'} ? "create" : "modify",
	    "stunnel", $st->{'name'}, $st);
&redirect("");

