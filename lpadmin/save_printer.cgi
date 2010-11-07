#!/usr/local/bin/perl
# save_printer.cgi
# Create or modify a printer

require './lpadmin-lib.pl';
&ReadParse();
&error_setup($text{'save_err'});

# Check ACL
if ($in{'new'}) {
	$access{'add'} || &error($text{'save_eadd'});
	}
else {
	&can_edit_printer($in{'name'}) ||
		&error($text{'save_eedit'});
	}

# validate and store printer details
$in{'name'} =~ /^[A-z0-9\-\_\.]+$/ ||
	&error(&text('save_ename', $in{'name'}));
if ($in{'new'} && &get_printer($in{'name'})) {
	&error(&text('save_edup', $in{'name'}));
	}
$prn{'name'} = $in{'name'};
$prn{'accepting'} = $in{'accepting'};
if (!$prn{'accepting'}) { $prn{'accepting_why'} = $in{'accepting_why'}; }
$prn{'enabled'} = $in{'enabled'};
if (!$prn{'enabled'}) { $prn{'enabled_why'} = $in{'enabled_why'}; }
$prn{'desc'} = $in{'desc'};
if (&printer_support('allow')) {
	@ul = split(/\s+/, $in{'users'});
	if ($in{'access'} == 0) { $prn{'allow_all'}++; }
	elsif ($in{'access'} == 1) { $prn{'deny_all'}++; }
	else {
		$w = $in{'access'} == 2 ? "allow" : "deny";
		if (!@ul) { &error($text{"save_e$w"}); }
		foreach $u (@ul) {
			if ($u !~ /^\S+\!\S+$/ && !(@dummy=getpwnam($u))) {
				&error(&text('save_euser', $u));
				}
			}
		$prn{$w} = \@ul;
		}
	}
if (&printer_support('banner')) {
	$prn{'banner'} = $in{'prbanner'};
	}
if (&printer_support('ctype')) {
	if ($in{'ctype_simple'}) { push(@ctype, "simple"); }
	if ($in{'ctype_postscript'}) { push(@ctype, "postscript"); }
	if ($in{'ctype_other'}) {
		push(@ctype, split(/\s+/, $in{'ctype_olist'}));
		}
	&error($text{'save_etype'}) if (!@ctype && $in{'dest'} != 2);
	$prn{'ctype'} = \@ctype;
	}
$prn{'default'} = $in{'default'};
if (&printer_support('msize')) {
	if ($in{'msize_def'} == 2) {
		$prn{'msize'} = 0;
		}
	elsif ($in{'msize_def'} == 0) {
		$in{'msize'} =~ /^\d+$/ ||
			&error($text{'save_emax'});
		$prn{'msize'} = $in{'msize'};
		}
	}
if (&printer_support('alias')) {
	@alias = split(/\s+/, $in{'alias'});
	$prn{'alias'} = \@alias;
	}

if ($in{'new'} || &printer_support('editdest')) {
	if ($in{'webmin'}) {
		$drv = &parse_webmin_driver();
		$dfunc = \&create_webmin_driver;
		}
	else {
		$drv = &parse_driver();
		$dfunc = \&create_driver;
		}

	# validate and store destination section
	$SIG{'ALRM'} = \&connect_time_out;
	if ($in{'dest'} == 0) {
		# printing to some device
		$prn{'dev'} = $in{'dev'};
		$prn{'iface'} = &$dfunc(\%prn, $drv);
		}
	elsif ($in{'dest'} == 1) {
		# printing to some file
		(-r $in{'file'}) || ($in{'file'} =~ /^\|(.*)/ && -r $1) ||
			&error(&text('save_efile', $in{'file'}));
		$prn{'dev'} = $in{'file'};
		$prn{'iface'} = &$dfunc(\%prn, $drv);
		}
	elsif ($in{'dest'} == 2) {
		# printing to a unix host
		local ($rhost, $rport);
		if ($in{'rhost'} =~ /^(\S+):(\d+)$/) {
			$rhost = $1;
			$rport = $2;
			}
		else {
			$rhost = $in{'rhost'};
			$rport = 515;
			}
		&to_ipaddress($rhost) || &to_ip6address($rhost) ||
			&error(&text('save_erhost', $rhost));
		$rport =~ /^\d+$/ || &error(&text('save_erport', $rport));
		$in{'rqueue'} =~ /^[A-z0-9\-\_\.\/]+$/ ||
			(!$in{'rqueue'} && &printer_support('rnoqueue')) ||
			&error(&text('save_erqueue', $in{'rqueue'}));
		$prn{'rhost'} = $in{'rhost'};
		$prn{'rqueue'} = $in{'rqueue'};
		$prn{'rtype'} = $in{'rtype'};
		if ($drv->{'mode'} && !&printer_support('riface')) {
			&error($text{'save_eremote'});
			}
		if ($in{'check'} && (!$in{'rtype'} || $in{'rtype'} eq 'bsd')) {
			# Try connecting to the LPR port
			alarm(10);
			&open_socket($rhost, 515, TEST);
			close(TEST);
			alarm(0);
			}
		$prn{'iface'} = &$dfunc(\%prn, $drv);
		}
	elsif ($in{'dest'} == 3) {
		# printing to windows
		$sdrv = { 'server' => $in{'server'},
			 'share' => $in{'share'},
			 'user' => $in{'suser'},
			 'pass' => $in{'spass'},
			 'workgroup' => $in{'wgroup'},
			 'program' => &$dfunc(\%prn, $drv) };
		$prn{'dev'} = "/dev/null";
		$prn{'iface'} = $in{'webmin'} ? 
			&create_webmin_windows_driver(\%prn, $sdrv) :
			&create_windows_driver(\%prn, $sdrv);
		if ($in{'check'}) {
			# Try connecting to the SMB port
			alarm(10);
			&open_socket($sdrv->{'server'}, 139, TEST);
			close(TEST);
			alarm(0);
			}
		}
	elsif ($in{'dest'} == 4) {
		# printing to hpnp server
		$hdrv = { 'server' => $in{'hpnp'},
			  'port' => $in{'port'},
			  'program' => &$dfunc(\%prn, $drv) };
		$prn{'iface'} = &create_hpnp_driver(\%prn, $hdrv);
		$prn{'dev'} = "/dev/null";
		}
	elsif ($in{'dest'} == 5) {
		# direct connection printing
		&to_ipaddress($in{'dhost'}) || &to_ip6address($in{'dhost'}) ||
			&error(&text('save_edhost', $in{'dhost'}));
		$in{'dport'} =~ /^\d+$/ || &error($text{'save_edport'});
		$prn{'dhost'} = $in{'dhost'};
		$prn{'dport'} = $in{'dport'};
		$prn{'iface'} = &$dfunc(\%prn, $drv);
		if ($in{'check'}) {
			# Try connecting to the port
			alarm(10);
			&open_socket($prn{'dhost'}, $prn{'dport'}, TEST);
			close(TEST);
			alarm(0);
			}
		}
	}

# Call os-specific validation function
if (defined(&validate_printer)) {
	$err = &validate_printer(\%prn);
	&error($err) if ($err);
	}

# Create the printer
if ($in{'new'}) {
	&create_printer(\%prn);
	&system_logged("$config{'apply_cmd'} >/dev/null 2>&1 </dev/null")
		if ($config{'apply_cmd'});
	&webmin_log("create", "printer", $prn{'name'}, &log_info(\%prn));
	}
else {
	&modify_printer(\%prn);
	&system_logged("$config{'apply_cmd'} >/dev/null 2>&1 </dev/null")
		if ($config{'apply_cmd'});
	&webmin_log("modify", "printer", $prn{'name'}, &log_info(\%prn));
	}

# Update ACL
if ($in{'new'} && $access{'printers'} ne '*') {
	$access{'printers'} .= " ".$in{'name'};
	&save_module_acl(\%access);
	}

# Create on cluster
@slaveerrs = &save_on_cluster($in{'new'}, \%prn, $drv, $sdrv || $hdrv,
			      $in{'webmin'}, $in{'dest'});
if (@slaveerrs) {
	&error(&text('save_errslave',
	     "<p>".join("<br>", map { "$_->[0]->{'host'} : $_->[1]" }
				    @slaveerrs)));
	}

&redirect("");

sub connect_time_out
{
$connect_timed_out++;
}

