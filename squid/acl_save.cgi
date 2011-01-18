#!/usr/local/bin/perl
# acl_save.cgi
# Save or delete an ACL

require './squid-lib.pl';
$access{'actrl'} || &error($text{'eacl_ecannot'});
&ReadParseMime();
&lock_file($config{'squid_conf'});
$conf = &get_config();
$whatfailed = $text{'aclsave_failsave'};

@acls = &find_config("acl", $conf);
@denys = &find_config("deny_info", $conf);
if (defined($in{'index'})) {
	$acl = $conf->[$in{'index'}];
	}
if (defined($in{'dindex'})) {
	$deny = $conf->[$in{'dindex'}];
	}
if ($in{'delete'}) {
	# Is there more than one ACL with this name?
	$name = $acl->{'values'}->[0];
	foreach $a (&find_config("acl", $conf)) {
		$count++ if ($a->{'values'}->[0] eq $name);
		}

	# Is this ACL in use?
	$whatfailed = $text{'aclsave_faildel'};
	if ($count == 1) {
		foreach $h (&find_config("http_access", $conf)) {
			@v = @{$h->{'values'}};
			for($i=1; $i<@v;  $i++) {
				if ($v[$i] eq $name || $v[$i] eq "!$name") {
					&error($text{'aclsave_epr'});
					}
				}
			}
		foreach $h (&find_config("icp_access", $conf)) {
			@v = @{$h->{'values'}};
			for($i=1; $i<@v;  $i++) {
				if ($v[$i] eq $in{'name'} ||
				    $v[$i] eq "!$in{'name'}") {
					&error($text{'aclsave_eicpr'});
					}
				}
			}
		}
	splice(@acls, &indexof($acl, @acls), 1);
	if ($deny) { splice(@denys, &indexof($deny, @denys), 1); }
	$logacl = $acl;
	}
else {
	# Check ACL details
	$in{'name'} =~ /^\S+$/ || &error($text{'aclsave_ename'});
	$changed++ if ($acl && $in{'name'} ne $acl->{'values'}->[0]);
	for($i=0; $i<@acls; $i++) {
		if ($changed && $acls[$i]->{'values'}->[0] eq $in{'name'}) {
			&error(&text('aclsave_eexists',$in{'name'}));
			}
		}

	if ($in{'type'} eq "src" || $in{'type'} eq "dst") {
		for($i=0; defined($from = $in{"from_$i"}); $i++) {
			$to = $in{"to_$i"}; $mask = $in{"mask_$i"};
			next if (!$from && !$to && !$mask);
			&check_ipaddress($from) ||
			    &check_ip6address($from) ||
			       &error(&text('aclsave_efrom',$from));
			!$to || &check_ipaddress($to) ||
			   &check_ip6address($to) ||
			       &error(&text('aclsave_eto',$to));
			$mask =~ /^\d*$/ || &check_ipaddress($mask) ||
			       &error(&text('aclsave_enmask',$mask));
			if ($to && $mask) { push(@vals, "$from-$to/$mask"); }
			elsif ($to) { push(@vals, "$from-$to"); }
			elsif ($mask) { push(@vals, "$from/$mask"); }
			else { push(@vals, $from); }
			}
		}
	elsif ($in{'type'} eq "myip") {
		for($i=0; defined($ip = $in{"ip_$i"}); $i++) {
			$mask = $in{"mask_$i"};
			next if (!$mask || !$ip);
			&check_ipaddress($ip) || &check_ip6address($ip) ||
				&error(&text('aclsave_eip',$ip));
			$mask =~ /^\d+$/ || &check_ipaddress($mask) ||
			       &error(&text('aclsave_enmask',$mask));
			push(@vals, "$ip/$mask");
			}
		}
	elsif ($in{'type'} eq "srcdomain") {
		push(@vals, split(/[\r\n]+/, $in{'vals'}));
		if (!@vals && !$in{'keep'}) { &error($text{'aclsave_ecdom'}); }
		}
	elsif ($in{'type'} eq "dstdomain") {
		push(@vals, split(/[\r\n]+/, $in{'vals'}));
		if (!@vals && !$in{'keep'}) { &error($text{'aclsave_esdom'}); }
		}
	elsif ($in{'type'} eq "time") {
		if (!$in{'day_def'}) {
			push(@vals, join('', split(/\0/, $in{'day'})));
			}
		if (!$in{'hour_def'}) {
			$in{'h1'} =~ /^\d+$/ || &error($text{'aclsave_eshour'});
			$in{'h2'} =~ /^\d+$/ || &error($text{'aclsave_eehour'});
			$in{'m1'} =~ /^\d+$/ || &error($text{'aclsave_esmin'});
			$in{'m2'} =~ /^\d+$/ || &error($text{'aclsave_eemin'});
			push(@vals, "$in{'h1'}:$in{'m1'}-$in{'h2'}:$in{'m2'}");
			}
		}
	elsif ($in{'type'} eq "url_regex") {
		push(@vals, "-i") if ($in{'caseless'});
		push(@vals, split(/[\r\n]+/, $in{'vals'}));
		}
	elsif ($in{'type'} eq "urlpath_regex") {
		push(@vals, "-i") if ($in{'caseless'});
		push(@vals, split(/[\r\n]+/, $in{'vals'}));
		}
	elsif ($in{'type'} eq "port") {
		push(@vals, split(/\s+/, $in{'vals'}));
		}
	elsif ($in{'type'} eq "proto") {
		push(@vals, split(/\0/, $in{'vals'}));
		}
	elsif ($in{'type'} eq "method") {
		push(@vals, split(/\0/, $in{'vals'}));
		}
	elsif ($in{'type'} eq "browser" || $in{'type'} eq "snmp_community"
            || $in{'type'} eq "req_mime_type" || $in{'type'} eq "rep_mime_type") {
		push(@vals, $in{'vals'});
		}
	elsif ($in{'type'} eq "user" || $in{'type'} eq "ident") {
		push(@vals, split(/[\r\n]+/, $in{'vals'}));
		}
	elsif ($in{'type'} eq "src_as" || $in{'type'} eq "dst_as") {
		push(@vals, split(/\s+/, $in{'vals'}));
		}
	elsif ($in{'type'} eq "proxy_auth" && $squid_version < 2.3) {
		push(@vals, $in{'vals'}) if ($in{'vals'});
		}
	elsif ($in{'type'} eq "proxy_auth" && $squid_version >= 2.3) {
		push(@vals, $in{'authall'} ? "REQUIRED"
					   : split(/[\r\n]+/, $in{'vals'}));
		}
	elsif ($in{'type'} eq "proxy_auth_regex" ||
	       $in{'type'} eq "ident_regex") {
		push(@vals, "-i") if ($in{'caseless'});
		push(@vals, split(/[\r\n]+/, $in{'vals'}));
		}
	elsif ($in{'type'} eq "srcdom_regex" || $in{'type'} eq "dstdom_regex") {
		push(@vals, "-i") if ($in{'caseless'});
		push(@vals, split(/[\r\n]+/, $in{'vals'}));
		}
	elsif ($in{'type'} eq "myport") {
		$in{'vals'} =~ /^\d+$/ ||
			&error("'$in{'vals'}' is not a valid port number");
		push(@vals, $in{'vals'});
		}
	elsif ($in{'type'} eq "maxconn") {
		$in{'vals'} =~ /^\d+$/ ||
		    &error("'$in{'vals'}' is not a valid number of requests");
		push(@vals, $in{'vals'});
		}
	elsif ($in{'type'} eq "arp") {
		push(@vals, split(/[\r\n]+/, $in{'vals'}));
		}
	elsif ($in{'type'} eq "external") {
		$in{'class'} || &error($text{'eacl_eclass'});
		push(@vals, $in{'class'});
		push(@vals, split(/\s+/, $in{'args'}));
		}
	elsif ($in{'type'} eq "max_user_ip") {
		if($in{'strict'}){
			push(@vals, '-s');
		}
		push(@vals, $in{'vals'});
		}

	if (!$in{'file_def'}) {
		# Writing to an external file
		$in{'file'} || &error($text{'aclsave_enofile'});
		&can_access($in{'file'}) ||
			&error(&text('aclsave_efile', $in{'file'}));
		if ($in{'type'} eq 'external' ||
		    &indexof($in{'type'}, @caseless_acl_types) >= 0 &&
		    $vals[0] eq "-i") {
			# Special case .. first parameter does NOT go into file
			@notvals = ( shift(@vals) );
			}
		if (!$in{'keep'}) {
			if (!$acl && -e $in{'file'}) {
				&error($text{'aclsave_ealready'});
				}
			&open_lock_tempfile(FILE, ">$in{'file'}");
			foreach $v (@vals) {
				&print_tempfile(FILE, $v,"\n");
				}
			&close_tempfile(FILE);
			}
		@vals = ( $in{'name'}, $in{'type'}, @notvals, "\"$in{'file'}\"" );
		}
	else {
		# Just saving in Squid config directly
		if ($vals[0] =~ /^"(.*)"$/) {
			local $f = $1;
			&can_access($f) ||
				&error(&text('aclsave_efile', $f));
			if ($f !~ /^\// && $access{'root'} ne '/') {
				$vals[0] = "\"$access{'root'}/$f\"";
				}
			
			}
		@vals = ( $in{'name'}, $in{'type'}, @vals );
		}
	$logacl = $newacl = { 'name' => 'acl', 'values' => \@vals };
	if ($acl) { splice(@acls, &indexof($acl, @acls), 1, $newacl); }
	else { push(@acls, $newacl); }

	$newdeny = { 'name' => 'deny_info',
		     'values' => [ $in{'deny'}, $vals[0] ] };
	$didx = &indexof($deny, @denys);
	if ($deny && $in{'deny'}) { $denys[$didx] = $newdeny; }
	elsif ($deny) { splice(@denys, $didx, 1); }
	elsif ($in{'deny'}) { push(@denys, $newdeny); }

	# Update http_access and icp_access directives if the ACL was renamed
	if ($changed) {
		@https = &find_config("http_access", $conf);
		@icps = &find_config("icp_access", $conf);
		$on = $acl->{'values'}->[0];
		foreach $c (@https, @icps) {
			for($j=1; $j<@{$c->{'values'}}; $j++) {
				if ($c->{'values'}->[$j] eq $on) {
					$c->{'values'}->[$j] = $in{'name'};
					}
				elsif ($c->{'values'}->[$j] eq "!$on") {
					$c->{'values'}->[$j] = "!$in{'name'}";
					}
				}
			}
		&save_directive($conf, "http_access", \@https);
		&save_directive($conf, "icp_access", \@icps);
		}
	}
&save_directive($conf, "acl", \@acls);
&save_directive($conf, "deny_info", \@denys);
&flush_file_lines();
&unlock_file($config{'squid_conf'});
&webmin_log($in{'delete'} ? 'delete' : $acl ? 'modify' : 'create',
	    'acl', $logacl->{'values'}->[0], \%in);
&redirect("edit_acl.cgi?mode=acls");

