#!/usr/local/bin/perl
# setup.cgi
# Setup the CVS server in inetd or xinetd

require './pserver-lib.pl';
&ReadParse();
$access{'setup'} || &error($text{'setup_ecannot'});
$inet = &check_inetd();
$restart = $inet->{'type'} if ($inet);
%xconfig = &foreign_config("xinetd");
%iconfig = &foreign_config("inetd");
if (!$inet) {
	# Need to setup for the first time .. first construct the CVS command
	$cmd = "-f";
	foreach $r (split(/\t+/, $config{'cvsroot'})) {
		$cmd .= " --allow-root $r";
		}
	$cmd .= " pserver";

	if ($has_xinetd) {
		# Just add an unlisted service
		&lock_file($xconfig{'xinetd_conf'});
		$xinet = { 'name' => 'service',
			   'values' => [ $cvs_inet_name ] };
		&xinetd::set_member_value($xinet, "port", $cvs_port);
		&xinetd::set_member_value($xinet, "socket_type", "stream");
		&xinetd::set_member_value($xinet, "protocol", "tcp");
		&xinetd::set_member_value($xinet, "user", $in{'user'});
		&xinetd::set_member_value($xinet, "wait", "no");
		&xinetd::set_member_value($xinet, "disable", "no");
		&xinetd::set_member_value($xinet, "type", "UNLISTED");
		&xinetd::set_member_value($xinet, "server", $cvs_path);
		&xinetd::set_member_value($xinet, "server_args", $cmd);
		&xinetd::create_xinet($xinet);
		&unlock_file($xconfig{'xinetd_conf'});
		$restart = "xinetd";
		}
	elsif ($has_inetd) {
		# Is there already a service on port 2401, or named cvspserver?
		&lock_file($iconfig{'services_file'});
		&lock_file($iconfig{'inetd_conf_file'});
		foreach $s (&inetd::list_services()) {
			local @al = split(/\s+/, $s->[4]);
			if ($s->[2] == $cvs_port ||
			    $s->[1] eq $cvs_inet_name ||
			    &indexof($cvs_inet_name, @al) >= 0) {
				# Yes! Use it
				$sname = $s->[1];
				last;
				}
			}
		if (!$sname) {
			$sname = $cvs_inet_name;
			&inetd::create_service($sname, $cvs_port, "tcp", undef);
			}
		&inetd::create_inet(1, $sname, "stream", "tcp", "nowait",
				    $in{'user'}, $cvs_path, "cvs $cmd");
		&unlock_file($iconfig{'services_file'});
		&unlock_file($iconfig{'inetd_conf_file'});
		$restart = "inetd";
		}
	else {
		&error($text{'setup_einet'});
		}
	$log = "setup";
	}
elsif ($inet->{'active'}) {
	# Need to de-activate
	if ($inet->{'type'} eq 'inetd') {
		local @i = @{$inet->{'inetd'}};
		&lock_file($i[10]);
		&inetd::modify_inet($i[0], 0, $i[3], $i[4], $i[5],
				    $i[6], $i[7], $i[8], $i[9], $i[10]);
		&unlock_file($i[10]);
		}
	else {
		local $x = $inet->{'xinetd'};
		&lock_file($x->{'file'});
		&xinetd::set_member_value($x, "disable", "yes");
		&xinetd::modify_xinet($x);
		&unlock_file($x->{'file'});
		}
	$log = "deactivate";
	}
else {
	# Need to activate, possibly updating CVS root and user
	if ($inet->{'type'} eq 'inetd') {
		local @i = @{$inet->{'inetd'}};
		&lock_file($i[10]);
		if ($i[9] =~ /^(.*)\s(\/\S+)\s+pserver$/) {
			# Fix root in path
			$i[9] = "$1 $config{'cvsroot'} pserver";
			}
		&inetd::modify_inet($i[0], 1, $i[3], $i[4], $i[5],
				    $i[6], $in{'user'}, $i[8], $i[9], $i[10]);
		&unlock_file($i[10]);
		}
	else {
		local $x = $inet->{'xinetd'};
		&lock_file($x->{'file'});
		&xinetd::set_member_value($x, "disable", "no");
		&xinetd::set_member_value($x, "user", $in{'user'});
		if ($x->{'quick'}->{'server_args'}->[0] =~
		    /^(.*)\s(\/\S+)\s+pserver$/) {
			# Fix root in path
			&xinetd::set_member_value($x, "server_args",
				"$1 $config{'cvsroot'} pserver");
			}
		&xinetd::modify_xinet($x);
		&unlock_file($x->{'file'});
		}
	$log = "activate";
	}

# Restart inetd or xinetd
if ($restart eq "inetd") {
	&system_logged(
		"$iconfig{'restart_command'} >/dev/null 2>&1 </dev/null");
	}
else {
	if (open(PID, $xconfig{'pid_file'})) {
		chop($pid = <PID>);
		close(PID);
		&kill_logged('USR2', $pid);
		}
	}
&webmin_log($log);
&redirect("");

