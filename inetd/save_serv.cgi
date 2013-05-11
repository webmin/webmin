#!/usr/local/bin/perl
# save_serv.cgi
# Save or create an internet service. This can be called N ways
#  - create a new services file entry
#  - create a new inetd.conf entry (and maybe update or add to services file)
#  - update inetd.conf (and maybe services)
#  - remove an entry from inetd.conf (and maybe change services)

require './inetd-lib.pl';
&error_setup($text{'error_saveservice'});
&ReadParse();

# Delete button clicked, redirect to correct CGI
if ($in{'delete'}) {
	&redirect("delete_serv.cgi?spos=$in{'spos'}&ipos=$in{'ipos'}");
	return;
	}

# Check inputs
$in{'name'} =~ /^[A-z][A-z0-9\_\-]+$/ ||
	&error(&text('error_invalidservice' ,$in{'name'}));
$in{'port'} =~ /^[0-9]*$/ || &error(&text('error_invalidport', $in{'port'}));
if ($in{'port'} <= 0 || $in{'port'} > 65535) {
	&error(&text('error_portnum', $in{'port'}));
	}
if ($in{'act'} && $in{'serv'} == 2) {
	$in{'program'} =~ /^\/\S+$/ ||
		&error(&text('error_invalidprg', $in{program}));
	if ($in{'act'} == 2) {
		if (!$in{'qm'}) {
			-r $in{'program'} ||
				&error(&text('error_notexist', $in{'program'}));
			-x $in{'program'} ||
				&error(&text('error_notexecutable', $in{'program'}));
			}
		}
	$in{'args'} =~ /^\S+/ ||&error(&text('error_invalidarg', $in{'args'}));
	}
elsif ($in{'act'} && $in{serv} == 3) {
	$in{tcpd} =~ /^\S+$/ ||
		&error(&text('error_invalidwrapper', $in{tcpd}));
	}
if ($in{'act'}) {
	$in{'user'} || &error($text{'error_nouser'});
	defined(getpwnam($in{'user'})) || &error($text{'error_user'});
	if ($config{'extended_inetd'} == 1) {
		$in{'group_def'} || defined(getgrnam($in{'group'})) ||
			&error($text{'error_group'});
		}
	}
if ($config{'extended_inetd'} && !$in{'permin_def'} && $in{'permin'}!~/^\d+$/) {
	&error(&text('error_invalidpermin', $in{'permin'}));
	}
if ($config{'extended_inetd'} == 2 &&
    !$in{'child_def'} && $in{'child'} !~ /^\d+$/) {
	&error(&text('error_invalidchildnum', $in{'child'}));
	}

# Build argument list
@sargs = ($in{'name'}, $in{'port'}, $in{'protocol'},
	  join(' ', split(/\s+/, $in{'aliases'})) );
@iargs = ($in{'act'} == 2, $in{'name'},
	  $in{'protocol'} =~ /^tcp/ ? "stream" : "dgram", $in{'protocol'});
$wait = $in{'wait'};
$user = $in{'user'};
if ($config{'extended_inetd'} == 1) {
	if (!$in{'permin_def'}) { $wait .= ".$in{'permin'}"; }
	if (!$in{'group_def'}) { $user .= ".$in{'group'}"; }
	}
elsif ($config{'extended_inetd'} == 2) {
	if (!$in{'child_def'}) { $wait .= "/$in{'child'}"; }
	if (!$in{'permin_def'} && $in{'child_def'}) {
		&error($text{'error_childnum'});
		}
	if (!$in{'permin_def'}) { $wait .= "/$in{'permin'}"; }
	if ($in{'group'}) { $user .= ":$in{'group'}"; }
	if ($in{'class'}) { $user .= "/$in{'class'}"; }
	}
push(@iargs, $wait);
push(@iargs, $user);
if (($in{'serv'} == 1) & (!$config{'no_internal'})) {
	push(@iargs, "internal", undef);
	}
elsif (($in{'serv'} == 1) & ($config{'no_internal'})) {
	&error(&text('error_invalidcmd', $in{args}));
	}
elsif ($in{serv} == 2) {
	push(@iargs, ($in{'qm'} ? "?" : "").$in{'program'});
	push(@iargs, $in{'args'});
	}
elsif ($in{serv} == 3) {
	push(@iargs, $config{'tcpd_path'});
	push(@iargs, $in{'tcpd'});
	$iargs[$#iargs] .= " $in{'args2'}" if ($in{'args2'});
	}

&lock_inetd_files();
@servs = &list_services();
@inets = &list_inets();
foreach $s (@servs) {
	if ($s->[1] eq $sargs[0] && $s->[3] eq $sargs[2]) { $same_name = $s; }
	if ($s->[2] == $sargs[1] && $s->[3] eq $sargs[2]) { $same_port = $s; }
	}

if ($in{'spos'} =~ /\d/) {
	# Changing a service..
	@old_serv = @{$servs[$in{'spos'}]};
	if ($in{'ipos'} =~ /\d/) {
		@old_inet = @{$inets[$in{'ipos'}]};
		}
	if ($old_serv[1] ne $sargs[0] || $old_serv[2] != $sargs[1] ||
	    $old_serv[3] ne $sargs[2]) {
		if ($same_name && $same_name->[2] != $old_serv[2]) {
			&error(&text('error_nameexist', $sargs[0], $sargs[2]));
			}
		if ($same_port && $same_port->[1] ne $old_serv[1]) {
			&error(&text('error_serviceexist', $sargs[1], $sargs[2]));
			}
		}
	&modify_service($old_serv[0], @sargs);
	if ($in{'act'} && @old_inet) {
		# modify inetd
		&modify_inet($old_inet[0], @iargs, $old_inet[10]);
		}
	elsif ($in{'act'} && !@old_inet) {
		# add to inetd
		&create_inet(@iargs);
		}
	elsif (!$in{'act'} && @old_inet) {
		# remove from inetd
		&delete_inet($old_inet[0], $old_inet[10]);
		@iargs = ();
		}
	&unlock_inetd_files();
	&webmin_log("modify", "serv", $sargs[0],
		    { 'name' => $sargs[0], 'port' => $sargs[1],
		      'proto' => $sargs[2], 'active' => $iargs[0],
		      'user' => $iargs[5], 'wait' => $iargs[4],
		      'prog' => $in{'act'} ? join(" ", @iargs[6..@iargs-1])
					   : undef } );
	}
else {
	# Creating a new service...
	# Check for a service with the same name or port and protocol
	if ($same_name) {
		&error(&text('error_nameexist', $sargs[0], $sargs[2]));
		}
	if ($same_port) {
		&error(&text('error_serviceexist', $sargs[1], $sargs[2]));
		}
	# Check for an existing internet service
	if ($in{'act'}) {
		foreach $i (@inets) {
			if ($i->[3] eq $iargs[1] && $i->[5] eq $iargs[3]) {
				&error(&text('error_inetservice', $i->[3], $i->[5]));
				}
			}
		}
	&create_service(@sargs);
	if ($in{'act'}) { &create_inet(@iargs); }
	&unlock_inetd_files();
	&webmin_log("create", "serv", $sargs[0],
		    { 'name' => $sargs[0], 'port' => $sargs[1],
		      'proto' => $sargs[2], 'active' => $iargs[0],
		      'user' => $iargs[5], 'wait' => $iargs[4],
		      'prog' => $in{'act'} ? join(" ", @iargs[6..@iargs-1])
					   : undef } );
	}
&redirect("");

