#!/usr/local/bin/perl
# save_subnet.cgi
# Update, create or delete a subnet

require './dhcpd-lib.pl';
require './params-lib.pl';
&ReadParse();
&lock_all_files();
($par, $sub, $indent, $npar, $nindent) = get_branch('sub', $in{'new'});
$parconf = $par->{'members'};

# check acls
%access = &get_module_acl();
&error_setup($text{'eacl_aviol'});
if ($in{'delete'}) {
	&error("$text{'eacl_np'} $text{'eacl_pds'}")
		if !&can('rw', \%access, $sub, 1);
	}
elsif ($in{'options'}) {
	&error("$text{'eacl_np'} $text{'eacl_pss'}") 
		if !&can('r', \%access, $sub);
	}
elsif ($in{'new'}) {
	&error("$text{'eacl_np'} $text{'eacl_pis'}")
		unless &can('c', \%access, $sub) && 
				&can('rw', \%access, $par) &&
				(!$npar || &can('rw', \%access, $npar));
	# restrict duplicates
	if ($access{'uniq_sub'}) {
		foreach $s (&get_subnets()) {
			&error("$text{'eacl_np'} $text{'eacl_uniq'}")
				if lc $s->{'values'}->[0] eq lc $in{'network'};
			}
		}
	}
elsif (!$in{'leases'}) {
	&error("$text{'eacl_np'} $text{'eacl_pus'}")
		unless &can('rw', \%access, $sub) &&
			(!$npar || &can('rw', \%access, $npar));
	}

# save
if ($in{'options'}) {
	# Redirect to client options
	&redirect("edit_options.cgi?sidx=$in{'sidx'}&idx=$in{'idx'}");
	exit;
	}
elsif ($in{'leases'}) {
	# Redirect to lease list for subnet
	&redirect("list_leases.cgi?network=$sub->{'values'}->[0]&netmask=$sub->{'values'}->[2]");
	exit;
	}
else {
	if ($in{'delete'}) {
		&error_setup($text{'ssub_faildel'});
		if ($par->{'name'} eq "shared-network") {
			@subnets = &find("subnet", $par->{'members'});
			if (@subnets < 2) {
				&error(&text('ssub_nosubnet', $par->{'values'}->[0]));
				}
			}
		}
	else {
		&error_setup($text{'ssub_failsave'});
		# Validate and save inputs
		&to_ipaddress($in{'network'}) ||
			&error("'$in{'network'}' $text{'ssub_invalidsubaddr'}");
		&check_ipaddress($in{'netmask'}) ||
			&error("'$in{'netmask'}' $text{'ssub_invalidnmask'}");
		$oldnetwork = $sub->{'values'}->[0];
		$sub->{'values'} = [ $in{'network'}, "netmask", $in{'netmask'} ];
		}

	@wasin = &find("host", $sub->{'members'});
	foreach $hn (split(/\0/, $in{'hosts'})) {
		if ($hn =~ /(\d+),(\d+)/) {
			push(@nowin, $parconf->[$2]->{'members'}->[$1]);
			$nowpr{$parconf->[$2]->{'members'}->[$1]} =
				$parconf->[$2];
			}
		elsif ($hn =~ /(\d+),/) {
			push(@nowin, $parconf->[$1]);
			$nowpr{$parconf->[$1]} = $par;
			}
		if ($nowin[$#nowin]->{'name'} ne "host") {
			&error($text{'sgroup_echanged'});
			}
		}
	@wasgin = &find("group", $sub->{'members'});
	foreach $gn (split(/\0/, $in{'groups'})) {
		if ($gn =~ /(\d+),(\d+)/) {
			push(@nowgin, $parconf->[$2]->{'members'}->[$1]);
			$nowgpr{$parconf->[$2]->{'members'}->[$1]} =
				$parconf->[$2];
			}
		elsif ($gn =~ /(\d+),/) {
			push(@nowgin, $parconf->[$1]);
			$nowgpr{$parconf->[$1]} = $par;
			}
		if ($nowgin[$#nowgin]->{'name'} ne "group") {
			&error($text{'sgroup_echanged'});
			}
		}

	&error_setup($text{'eacl_aviol'});
	foreach $h (&unique(@wasin, @nowin)) {
		$was = &indexof($h, @wasin) != -1;
		$now = &indexof($h, @nowin) != -1;

		# per-host ACLs for new or updated hosts
		if ($was != $now && !&can('rw', \%access, $h)) {
			&error("$text{'eacl_np'} $text{'eacl_pus'}");
			}
		if ($was && !$now) {
			# Move out of the subnet
			&save_directive($sub, [ $h ], [ ], $indent);
			&save_directive($par, [ ], [ $h ], $indent);
			}
		elsif ($now && !$was) {
			# Move into the subnet (maybe from another subnet)
			&save_directive($nowpr{$h}, [ $h ], [ ], $indent);
			&save_directive($sub, [ ], [ $h ], $indent + 1);
			}
		}
	foreach $g (&unique(@wasgin, @nowgin)) {
		$was = &indexof($g, @wasgin) != -1;
		$now = &indexof($g, @nowgin) != -1;

		# per-group ACLs for new or updated groups
		if ($was != $now && !&can('rw', \%access, $g)) {
			&error("$text{'eacl_np'} $text{'eacl_pus'}");
			}
		if ($was && !$now) {
			# Move out of the subnet
			&save_directive($sub, [ $g ], [ ], $indent);
			&save_directive($par, [ ], [ $g ], $indent);
			}
		elsif ($now && !$was) {
			# Move into the subnet (maybe from another subnet)
			&save_directive($nowgpr{$g}, [ $g ], [ ], $indent);
			&save_directive($sub, [ ], [ $g ], $indent + 1);
			}
		}

	if (!$in{'delete'}) {
		&error_setup($text{'ssub_failsave'});
		for($i=0; defined($low = $in{"range_low_$i"}); $i++) {
			next if (!$low);
			$hi = $in{"range_hi_$i"}; $dyn = $in{"range_dyn_$i"};
			&check_ipaddress($low) ||
				&error("'$low' $text{'ssub_invalidipr'}");
			!$hi || &check_ipaddress($hi) ||
				&error("'$hi' $text{'ssub_invalidipr'}");
			$rng = { 'name' => 'range',
				 'values' => [ ($dyn ? "dynamic-bootp" : ()),
					       $low, ($hi ? $hi : ()) ] };
			push(@rng, $rng);
			}
		&save_directive($sub, "range", \@rng, 1);
		$sub->{'comment'} = $in{'desc'};
		&parse_params($sub, 0);

		if (!npar || $in{'assign'} > 0 && $npar->{'name'} ne "shared-network") {
			&error($text{'sgroup_echanged'});
			}
		if ($in{'new'}) {
			# save acl for new network
			&save_dhcpd_acl('rw','sub',\%access,$in{'network'});
			# Add to the end of the parent structure
			&save_directive($npar, [ ], [ $sub ], $nindent);
			}
		elsif ($par eq $npar) {
			# Update the subnet in the current parent
			&save_directive($par, [ $sub ], [ $sub ], $nindent);
			if ($in{'network'} ne $oldnetwork) {
				# Fix the ACL
				&drop_dhcpd_acl('sub', \%access, $oldnetwork);
				&save_dhcpd_acl('rw','sub',\%access,
						$in{'network'});
				}
			}
		else {
			# Move the subnet
			if ($par->{'name'} eq "shared-network") {
				@subnets = &find("subnet", $par->{'members'});
				if (@subnets < 2) {
					&error(&text('ssub_nosubnet', $par->{'values'}->[0]));
					}
				}
			&save_directive($par, [ $sub ], [ ], 0);
			&save_directive($npar, [ ], [ $sub ], $nindent);
			}
		}
	}
&flush_file_lines();
if ($in{'delete'}) {
	# Delete this subnet
	if ($in{'hosts'} eq "" && $in{'groups'} eq "") {
		&drop_dhcpd_acl('sub', \%access, $sub->{'values'}->[0]);
		&save_directive($par, [ $sub ], [ ], 0);
		&flush_file_lines();
		}
	else {
		&unlock_all_files();
		&redirect("confirm_delete.cgi?sidx=$in{'sidx'}&idx=$in{'idx'}"
			."\&type=1");
		exit;
		}
	}
&unlock_all_files();
&webmin_log($in{'delete'} ? 'delete' : $in{'new'} ? 'create' : 'modify',
	    'subnet', "$sub->{'values'}->[0]/$sub->{'values'}->[2]", \%in);

&redirect($in{'ret'} eq "shared" ? "edit_shared.cgi?idx=$in{'sidx'}" : "");
