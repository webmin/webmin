#!/usr/local/bin/perl
# save_pool.cgi
# Create, update or delete an address pool

require './dhcpd-lib.pl';
require './params-lib.pl';
&ReadParse();
&lock_all_files();
$conf = &get_config();
if ($in{'sidx'} ne "") {
	$sha = $conf->[$in{'sidx'}]; 
	$sub = $sha->{'members'}->[$in{'uidx'}];
	$indent = 2;
	}
else {
	$sub = $conf->[$in{'uidx'}];
	$indent = 1;
	}
if ($in{'new'}) {
	$pool = { 'name' => 'pool',
		  'type' => 1,
		  'members' => [ ] };
	}
else {
	$pool = $sub->{'members'}->[$in{'idx'}];
	}

# check acls
%access = &get_module_acl();
&error_setup($text{'eacl_aviol'});
&error("$text{'eacl_np'} $text{'eacl_pus'}") if !&can('rw', \%access, $sub);

# save
if ($in{'delete'}) {
	# Delete this pool from it's subnet
	&save_directive($sub, [ $pool ], [ ], 0);
	}
else {
	# Validate inputs
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
	&save_directive($pool, "range", \@rng, 1);
	if($in{'failover_peer'}) {
		!&check_domain($in{'failover_peer'}) ||
			&error("'$in{'failover_peer'}' $text{'ssub_invalidfopeer'}");
		$in{'failover_peer'} = "\"$in{'failover_peer'}\"";	
        	push(@failover_peer, { 'name' => 'failover peer',
                                       'values' => [ $in{'failover_peer'} ] });
        }
        &save_directive($pool, "failover", \@failover_peer, 1);

	$in{'allow'} =~ s/\r//g;
	foreach $a (split(/\n/, $in{'allow'})) {
		push(@allow, { 'name' => 'allow', 'values' => [ $a ] });
		}
	&save_directive($pool, "allow", \@allow, 1);
	$in{'deny'} =~ s/\r//g;
	foreach $a (split(/\n/, $in{'deny'})) {
		push(@deny, { 'name' => 'deny', 'values' => [ $a ] });
		}
	&save_directive($pool, "deny", \@deny, 1);
	&parse_params($pool, 0);

	# Save or create the pool
	if ($in{'new'}) {
		&save_directive($sub, [ ], [ $pool ], $indent);
		}
	else {
		&save_directive($sub, [ $pool ], [ $pool ], $indent);
		}
	}
&flush_file_lines();
&unlock_all_files();
if ($sub->{'name'} eq 'subnet') {
	&webmin_log('modify', 'subnet',
		    "$sub->{'values'}->[0]/$sub->{'values'}->[2]", \%in);
	&redirect("edit_subnet.cgi?sidx=$in{'sidx'}&idx=$in{'uidx'}");
	}
else {
	&webmin_log('modify', 'shared', $sub->{'values'}->[0], \%in);
	&redirect("edit_shared.cgi?idx=$in{'uidx'}");
	}


