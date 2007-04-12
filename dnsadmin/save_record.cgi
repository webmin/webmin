#!/usr/local/bin/perl
# save_record.cgi
# Adds or updates a record of some type

require './dns-lib.pl';
&ReadParse();
%access = &get_module_acl();
&can_edit_zone(\%access, $in{'origin'}) ||
        &error("You are not allowed to edit records in this zone");
&lock_file($in{'file'});
@recs = &read_zone_file($in{'file'}, $in{'origin'});
$whatfailed = "Failed to save record";

# get the old record if needed
$r = $recs[$in{'num'}] if (defined($in{'num'}));

# check for deletion
if ($in{'delete'}) {
	&lock_file($r->{'file'});
	&delete_record($r->{'file'}, $r);
	&bump_soa_record($in{'file'}, \@recs);
	($orevconf, $orevfile, $orevrec) = &find_reverse($in{'oldvalue0'});
	if ($in{'rev'} && $orevrec && &can_edit_reverse($orevconf) &&
	    $in{'oldname'} eq $orevrec->{'values'}->[0] &&
	    $in{'oldvalue0'} eq &arpa_to_ip($orevrec->{'name'})) {
		&lock_file($orevrec->{'file'});
		&delete_record($orevrec->{'file'} , $orevrec);
		&lock_file($orevfile);
		@orrecs = &read_zone_file(
				$orevfile, $orevconf->{'values'}->[0]);
		&bump_soa_record($orevfile, \@orrecs);
		}

	($ofwdconf, $ofwdfile, $ofwdrec) = &find_forward($in{'oldvalue0'});
	if ($in{'fwd'} && $ofwdrec &&
	    &can_edit_zone($ofwdconf->{'values'}->[0]) &&
	    &arpa_to_ip($in{'oldname'}) eq $ofwdrec->{'values'}->[0] &&
	    $in{'oldvalue0'} eq $ofwdrec->{'name'}) {
		&lock_file($ofwdrec->{'file'});
		&delete_record($ofwdrec->{'file'}, $ofwdrec);
		&lock_file($ofwdfile);
		@ofrecs = &read_zone_file($ofwdfile,$ofwdconf->{'values'}->[0]);
		&bump_soa_record($ofwdfile, \@ofrecs);
		}

	&redirect("edit_recs.cgi?index=$in{'index'}&type=$in{'type'}");
	&unlock_all_files();
	&webmin_log('delete', 'record', $in{'origin'}, $r);
	exit;
	}

# parse inputs
if (!$in{'ttl_def'}) {
	$in{'ttl'} =~ /^\d+$/ ||
		&error("'$in{'ttl'}' is not a valid time-to-live");
	$ttl = $in{'ttl'};
	}
$vals = $in{'value0'};
for($i=1; defined($in{"value$i"}); $i++) {
	$vals .= " ".$in{"value$i"};
	}
if ($in{'type'} eq "PTR") {
	# a reverse address
	&check_ipaddress($in{'name'}) ||
		&error("'$in{'name'}' is not a valid IP address");
	$name = &ip_to_arpa($in{'name'});
	&valname($in{'value0'}) ||
		&error("'$vals[0]' is not a valid hostname");
	if ($in{'value0'} !~ /\.$/) { $vals .= "."; }
	}
else {
	# some other kind of record
	$in{'name'} eq "" || &valname($in{'name'}) ||
		&error("'$in{'name'}' is not a valid ",
		       lc($code_map{$in{'type'}})," record name");
	if ($in{'type'} eq "A") {
		&check_ipaddress($vals) ||
			&error("'$vals' is not a valid IP address");
		if (!$access{'multiple'}) {
			$conf = &get_config();
			@zl = &find_config("primary", $conf);
			foreach $z (@zl) {
				$file = $z->{'values'}->[1];
				@frecs = &read_zone_file($z->{'values'}->[1],
							 $z->{'values'}->[0]);
				foreach $fr (@frecs) {
					if ($fr->{'type'} eq "A" &&
					    $fr->{'values'}->[0] eq $vals &&
					    $fr->{'name'} ne $r->{'name'}) {
						&error("An address record for ",
						       "$vals already exists");
						}
					}
				}
			}
		}
	elsif ($in{'type'} eq "NS") {
		&valname($vals) ||
			&error("'$vals' is not a valid nameserver");
		}
	elsif ($in{'type'} eq "CNAME") {
		&valname($vals) ||
			&error("'$vals' is not a valid alias target");
		}
	elsif ($in{'type'} eq "MX") {
		$in{'value1'} =~ /^[A-z0-9\-\.\*]+$/ ||
			&error("'$in{'value1'}' is not a valid mail server");
		$in{'value0'} =~ /^\d+$/ ||
			&error("'$in{'value0'}' is not a valid priority");
		}
	elsif ($in{'type'} eq "HINFO") {
		$in{'value0'} =~ /^\S+$/ ||
			&error("'$in{'value0'}' is not a valid hardware type");
		$in{'value1'} =~ /^\S+$/ ||
			&error("'$in{'value1'}' is not a valid OS type");
		}
	elsif ($in{'type'} eq "TXT") {
		$vals = "\"$in{'value0'}\"";
		}
	elsif ($in{'type'} eq "WKS") {
		&check_ipaddress($in{'value0'}) ||
			&error("'$in{'value0'}' is not a valid IP address");
		if (!$in{'value2'}) {
			&error("You did not enter any well known services");
			}
		@ws = split(/[\r\n]+/, $in{'value2'});
		$vals = "$in{'value0'} $in{'value1'} (";
		foreach $ws (@ws) { $vals .= "\n\t\t\t\t\t$ws"; }
		$vals .= " )";
		}
	elsif ($in{'type'} eq "RP") {
		$in{'value0'} =~ /^(\S+)\@(\S+)$/ ||
			&error("'$in{'value0'}' is not a valid email address");
		&valname($in{'value1'}) ||
			&error("'$in{'value1'}' is not a valid text record");
		$in{'value0'} =~ s/\@/\./g;
		$vals = "$in{'value0'} $in{'value1'}";
		}
	$name = $in{'name'} eq "" ?    "$in{'origin'}." :
		$in{'name'} !~ /\.$/ ? "$in{'name'}.$in{'origin'}." :
				       $in{'name'};
	}

if ($in{'new'}) {
	# just adding a new record
	&create_record($in{'file'}, $name, $ttl, "IN", $in{'type'}, $vals);
	$r = { 'name' => $name, 'ttl' => $ttl, 'class' => 'IN',
	       'type' => $in{'type'}, 'values' => [ split(/\s+/, $vals) ] };
	($revconf, $revfile, $revrec) = &find_reverse($in{'value0'});
	if ($in{'rev'} && $revconf && !$revrec && &can_edit_reverse($revconf)) {
		# Add a reverse record if we are the master for the reverse
		# domain, and if there is not already a reverse record
		# for the address.
		&lock_file($revfile);
		&create_record($revfile,
			      &ip_to_arpa($in{'value0'}), $ttl,
			      "IN", "PTR", $name);
		@rrecs = &read_zone_file($revfile, $revconf->{'values'}->[0]);
		&bump_soa_record($revfile, \@rrecs);
		}

	($fwdconf, $fwdfile, $fwdrec) = &find_forward($vals);
	if ($in{'fwd'} && $fwdconf && !$fwdrec &&
	    &can_edit_zone($fwdconf->{'values'}->[0])) {
		# Add a forward record if we are the master for the forward
		# domain, and if there is not already an A record
		# for the address
		&lock_file($fwdfile);
		&create_record($fwdfile, $vals,
			       $ttl, "IN", "A", $in{'name'});
		@frecs = &read_zone_file($fwdfile, $fwdconf->{'values'}->[0]);
		&bump_soa_record($fwdfile, \@frecs);
		}
	}
else {
	# updating an existing record
	($orevconf, $orevfile, $orevrec) = &find_reverse($in{'oldvalue0'});
	($revconf, $revfile, $revrec) = &find_reverse($in{'value0'});
	&lock_file($r->{'file'});
	&modify_record($r->{'file'}, $r, $name, $ttl,
		       "IN", $in{'type'},$vals);

	if ($in{'rev'} && $orevrec && &can_edit_reverse($orevconf) &&
	    $in{'oldname'} eq $orevrec->{'values'}->[0] &&
	    $in{'oldvalue0'} eq &arpa_to_ip($orevrec->{'name'})) {
		# Updating the reverse record. Either the name, address
		# or both may have changed. Furthermore, the reverse record
		# may now be in a different file!
		&lock_file($orevfile);
		&lock_file($revfile);
		@orrecs = &read_zone_file($orevfile,$orevconf->{'values'}->[0]);
		@rrecs = &read_zone_file($revfile, $revconf->{'values'}->[0]);
		if ($revconf eq $orevconf && &can_edit_reverse($revconf)) {
			# old and new in the same file
			&modify_record($orevrec->{'file'} , $orevrec, 
				      &ip_to_arpa($in{'value0'}),
				      $orevrec->{'ttl'}, "IN", "PTR", $name);
			&bump_soa_record($orevfile, \@orrecs);
			}
		elsif ($revconf && &can_edit_reverse($revconf)) {
			# old and new in different files
			&delete_record($orevrec->{'file'} , $orevrec);
			&create_record($revfile, &ip_to_arpa($in{'value0'}),
				      $orevrec->{'ttl'}, "IN", "PTR", $name);
			&bump_soa_record($orevfile, \@orrecs);
			&bump_soa_record($revfile, \@rrecs);
			}
		else {
			# we don't handle the new reverse domain.. lose the
			# reverse record
			&delete_record($orevrec->{'file'}, $orevrec);
			&bump_soa_record($orevfile, \@orrecs);
			}
		}

	($ofwdconf, $ofwdfile, $ofwdrec) = &find_forward($in{'oldvalue0'});
	($fwdconf, $fwdfile, $fwdrec) = &find_forward($in{'value0'});
	if ($in{'fwd'} && $ofwdrec &&
	    &can_edit_zone($ofwdconf->{'values'}->[0]) &&
	    &arpa_to_ip($in{'oldname'}) eq $ofwdrec->{'values'}->[0] &&
	    $in{'oldvalue0'} eq $ofwdrec->{'name'}) {
		# Updating the forward record
		&lock_file($ofwdfile);
		&lock_file($fwdfile);
		@ofrecs = &read_zone_file($ofwdfile,$ofwdconf->{'values'}->[0]);
		@frecs = &read_zone_file($fwdfile, $fwdconf->{'values'}->[0]);
		if ($fwdconf eq $ofwdconf &&
		    &can_edit_zone($fwdconf->{'values'}->[0])) {
			# old and new are in the same file
			&modify_record($ofwdrec->{'file'} , $ofwdrec, $vals,
				       $ofwdrec->{'ttl'}, "IN", "A",
				       $in{'name'});
			&bump_soa_record($ofwdfile, \@ofrecs);
			}
		elsif ($fwdconf && &can_edit_zone($fwdconf->{'values'}->[0])) {
			# old and new in different files
			&delete_record($ofwdrec->{'file'} , $ofwdrec);
			&create_record($fwdfile, $vals, $ofwdrec->{'ttl'},
				       "IN", "A", $in{'name'});
			&bump_soa_record($ofwdfile, \@ofrecs);
			&bump_soa_record($fwdfile, \@frecs);
			}
		else {
			# lose the forward because it has been moved to
			# a zone not handled by this server
			&delete_record($ofwdrec->{'file'} , $ofwdrec);
			&bump_soa_record($ofwdfile, \@ofrecs);
			}
		}
	}
&bump_soa_record($in{'file'}, \@recs);
&unlock_all_files();
&webmin_log($in{'new'} ? 'create' : 'modify', 'record', $in{'origin'}, $r);
&redirect("edit_recs.cgi?index=$in{'index'}&type=$in{'type'}");

sub valname
{
return $_[0] =~ /[A-z0-9\-\.]+$/;
}

# can_edit_reverse(&zone)
sub can_edit_reverse
{
return $access{'reverse'} || &can_edit_zone(\%access, $_[0]->{'values'}->[0]);
}

