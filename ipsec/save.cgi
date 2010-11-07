#!/usr/local/bin/perl
# save.cgi
# Save, create or delete an ipsec connection

require './ipsec-lib.pl';
&ReadParse();
if ($in{'export'}) {
	# Just redirect to export form
	&redirect("export_form.cgi?idx=$in{'idx'}");
	exit;
	}
@conf = &get_config();
if ($in{'new'}) {
	$conn = { 'name' => 'conn',
		  'values' => { } };
	$conn->{'value'} = '%default' if ($in{'new'} == 2);
	}
else {
	$conn = $conf[$in{'idx'}];
	}
&error_setup($text{'save_err'});

$file = $conn->{'file'} || $config{'file'};
&lock_file($file);
if ($in{'delete'}) {
	# Just remove this connection
	&delete_conn($conn);
	}
else {
	# Validate and store general inputs
	if ($conn->{'value'} ne '%default') {
		$in{'name'} =~ /^\S+$/ || &error($text{'save_ename'});
		$conn->{'value'} = $in{'name'};
		}
	if ($in{'auto'}) {
		$conn->{'values'}->{'auto'} = $in{'auto'};
		}
	else {
		delete($conn->{'values'}->{'auto'});
		}
	if ($in{'comp'}) {
		$conn->{'values'}->{'compress'} = $in{'comp'};
		}
	else {
		delete($conn->{'values'}->{'compress'});
		}
	if ($in{'pfs'}) {
		$conn->{'values'}->{'pfs'} = $in{'pfs'};
		}
	else {
		delete($conn->{'values'}->{'pfs'});
		}
	if ($in{'type'}) {
		$conn->{'values'}->{'type'} = $in{'type'};
		}
	else {
		delete($conn->{'values'}->{'type'});
		}
	if ($in{'authby'}) {
		$conn->{'values'}->{'authby'} = $in{'authby'};
		}
	else {
		delete($conn->{'values'}->{'authby'});
		}
	if ($in{'keying_def'}) {
		delete($conn->{'values'}->{'keyingtries'});
		}
	else {
		$in{'keying'} =~ /^\d+$/ || &error($text{'save_ekeying'});
		$conn->{'values'}->{'keyingtries'} = $in{'keying'};
		}
	if ($in{'auth'}) {
		$conn->{'values'}->{'auth'} = $in{'auth'};
		}
	else {
		delete($conn->{'values'}->{'auth'});
		}

	if ($in{'esp'}) {
		$conn->{'values'}->{'esp'} = $in{'esp'}.$in{'esp_only'};
		}
	else {
		delete($conn->{'values'}->{'esp'});
		}

	if ($in{'keylife_def'}) {
		delete($conn->{'values'}->{'keylife'});
		}
	else {
		$in{'keylife'} =~ /^[0-9\.]+$/ ||
			&error($text{'save_ekeylife'});
		$conn->{'values'}->{'keylife'} =
			$in{'keylife'}.$in{'keylife_units'};
		}

	if ($in{'ikelifetime_def'}) {
		delete($conn->{'values'}->{'ikelifetime'});
		}
	else {
		$in{'ikelifetime'} =~ /^[0-9\.]+$/ ||
			&error($text{'save_eikelifetime'});
		$conn->{'values'}->{'ikelifetime'} =
			$in{'ikelifetime'}.$in{'ikelifetime_units'};
		}

	# Validate and store left/right inputs
	foreach $d ('left', 'right') {
		# left/right
		if ($in{"${d}_mode"} == -1) {
			delete($conn->{'values'}->{$d});
			}
		elsif ($in{"${d}_mode"} == 0) {
			$conn->{'values'}->{$d} = '%defaultroute';
			}
		elsif ($in{"${d}_mode"} == 1) {
			$conn->{'values'}->{$d} = '%any';
			}
		elsif ($in{"${d}_mode"} == 2) {
			$conn->{'values'}->{$d} = '%opportunistic';
			}
		else {
			&to_ipaddress($in{$d}) || &error($text{"save_e${d}"});
			$conn->{'values'}->{$d} = $in{$d};
			}

		# leftid/rightid
		if ($in{"${d}_id_mode"} == 0) {
			delete($conn->{'values'}->{"${d}id"});
			}
		elsif ($in{"${d}_id_mode"} == 1) {
			&check_ipaddress($in{"${d}_id"}) ||
				&error($text{"save_e${d}id1"});
			$conn->{'values'}->{"${d}id"} = $in{"${d}_id"};
			}
		else {
			$in{"${d}_id"} =~ /^[a-z0-9\.\-]+$/i ||
				&error($text{"save_e${d}id2"});
			$conn->{'values'}->{"${d}id"} = "@".$in{"${d}_id"};
			}

		# leftsubnet/rightsubnet
		if ($in{"${d}_subnet_def"}) {
			delete($conn->{'values'}->{"${d}subnet"});
			}
		else {
			$in{"${d}_subnet"} =~ /^(\S+)\/(\d+)$/ &&
			    &check_ipaddress("$1") && $2 <= 32 ||
				&error($text{"save_e${d}subnet"});
			$conn->{'values'}->{"${d}subnet"} = $in{"${d}_subnet"};
			}

		# leftrsasigkey/rightrsasigkey
		if ($in{"${d}_key_mode"} == 0) {
			delete($conn->{'values'}->{"${d}rsasigkey"});
			}
		elsif ($in{"${d}_key_mode"} == 1) {
			$conn->{'values'}->{"${d}rsasigkey"} = '%dns';
			}
		else {
			$in{"${d}_key"} =~ s/\s//g;
			$in{"${d}_key"} || &error($text{"save_e${d}key"});
			$conn->{'values'}->{"${d}rsasigkey"} = $in{"${d}_key"};
			}

		# leftnexthop/rightnexthop
		if ($in{"${d}_hop_mode"} == 0) {
			delete($conn->{'values'}->{"${d}nexthop"});
			}
		elsif ($in{"${d}_hop_mode"} == 1) {
			$conn->{'values'}->{"${d}nexthop"} = '%direct';
			}
		elsif ($in{"${d}_hop_mode"} == 3) {
			$conn->{'values'}->{"${d}nexthop"} = '%defaultroute';
			}
		else {
			&check_ipaddress($in{"${d}_hop"}) ||
				&error($text{"save_e${d}hop"});
			$conn->{'values'}->{"${d}nexthop"} = $in{"${d}_hop"};
			}

		# leftcert/rightcert
		if ($in{"${d}_cert_def"}) {
			delete($conn->{'values'}->{"${d}cert"});
			}
		else {
			$in{"${d}_cert"} =~ /^(\S+)$/ ||
				&error($text{"save_e${d}cert"});
			$conn->{'values'}->{"${d}cert"} = $in{"${d}_cert"};
			}
		}

	# Update or add
	if ($in{'new'}) {
		&create_conn($conn);
		}
	else {
		&modify_conn($conn);
		}
	}
&unlock_file($file);
&webmin_log($in{'new'} ? "create" : $in{'delete'} ? "delete" : "modify",
	    "conn", $conn->{'value'}, $conn->{'values'});
&redirect("");

