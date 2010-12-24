#!/usr/local/bin/perl
# save_record.cgi
# Adds or updates a record of some type

require './bind8-lib.pl';
&ReadParse();
&error_setup($text{'edit_err'});
$zone = &get_zone_name($in{'index'}, $in{'view'});
$dom = $zone->{'name'};
@zl = &list_zone_names();
$reverse = ($in{'origin'} =~ /\.in-addr\.arpa/i ||
	    $in{'origin'} =~ /\.$ipv6revzone/i);
&can_edit_zone($zone) || &error($text{'recs_ecannot'});
&can_edit_type($in{'type'}) ||
	&error($text{'recs_ecannottype'});
$access{'ro'} && &error($text{'master_ero'});
&lock_file(&make_chroot(&absolute_path($zone->{'file'})));

# Read the existing records
if ($config{'largezones'} && !defined($in{'num'})) {
	# Adding to a large zone, so only read the SOA
	@recs = &read_zone_file($in{'file'}, $in{'origin'}, undef, 1);
	}
else {
	# Read all records
	@recs = &read_zone_file($in{'file'}, $in{'origin'});
	}

# get the old record if needed
$r = $recs[$in{'num'}] if (defined($in{'num'}));

# check for deletion
if ($in{'delete'}) {
	# Check if confirmation is needed
	if (!$in{'confirm'} && $config{'confirm_rec'}) {
		&ui_print_header(undef, $text{'edit_dtitle'}, "");

		print &ui_confirmation_form("save_record.cgi",
			&text('edit_rusure', "<tt>$r->{'name'}</tt>",
                                             "<tt>$in{'origin'}</tt>"),
			[ map { [ $_, $in{$_} ] } (keys %in) ],
			[ [ 'confirm', $text{'edit_dok'} ] ],
			);

		&ui_print_footer("edit_recs.cgi?index=$in{'index'}&view=$in{'view'}&type=$in{'redirtype'}&sort=$in{'sort'}", $text{'recs_return'});
		}
	else {
		# Delete the record
		&lock_file(&make_chroot($r->{'file'}));
		&delete_record($r->{'file'}, $r);
		&bump_soa_record($in{'file'}, \@recs);
		&sign_dnssec_zone_if_key($zone, \@recs);

		# Update reverse
		$fulloldvalue0 = &convert_to_absolute(
					$in{'oldvalue0'}, $in{'origin'});
		$fulloldname = &convert_to_absolute(
					$in{'oldname'}, $in{'origin'});
		($orevconf, $orevfile, $orevrec) = &find_reverse($in{'oldvalue0'},
								 $in{'view'});
		if ($in{'rev'} && $orevrec && &can_edit_reverse($orevconf) &&
		    $fulloldname eq $orevrec->{'values'}->[0] &&
		    ($in{'type'} eq "A" &&
		     $in{'oldvalue0'} eq &arpa_to_ip($orevrec->{'name'}) ||
		     $in{'type'} eq "AAAA" &&
		     &expandall_ip6($in{'oldvalue0'}) eq &expandall_ip6(&ip6int_to_net($orevrec->{'name'})))) {
			&lock_file(&make_chroot($orevrec->{'file'}));
			&delete_record($orevrec->{'file'} , $orevrec);
			&lock_file(&make_chroot($orevfile));
			@orrecs = &read_zone_file($orevfile, $orevconf->{'name'});
			&bump_soa_record($orevfile, \@orrecs);
			&sign_dnssec_zone_if_key($orevconf, \@orrecs);
			}

		# Update forward
		local($ipv6 = ($fulloldvalue0 =~ /\.$ipv6revzone/i));
		($ofwdconf, $ofwdfile, $ofwdrec) = &find_forward($fulloldvalue0, $ipv6);
		if ($in{'fwd'} && $ofwdrec && &can_edit_zone($ofwdconf) &&
		    (!$ipv6 && &arpa_to_ip($in{'oldname'}) eq $ofwdrec->{'values'}->[0] ||
		     $ipv6 && &expandall_ip6(&ip6int_to_net($in{'oldname'})) eq &expandall_ip6($ofwdrec->{'values'}->[0])) &&
		    $fulloldvalue0 eq $ofwdrec->{'name'}) {
			&lock_file(&make_chroot($ofwdrec->{'file'}));
			&delete_record($ofwdrec->{'file'}, $ofwdrec);
			&lock_file(&make_chroot($ofwdfile));
			@ofrecs = &read_zone_file($ofwdfile, $ofwdconf->{'name'});
			&bump_soa_record($ofwdfile, \@ofrecs);
			&sign_dnssec_zone_if_key($ofwdconf, \@ofrecs);
			}

		&redirect("edit_recs.cgi?index=$in{'index'}&view=$in{'view'}&type=$in{'redirtype'}&sort=$in{'sort'}");
		&unlock_all_files();
		&webmin_log('delete', 'record', $in{'origin'}, $r);
		}
	exit;
	}

# Create values string based on inputs
if (!$in{'ttl_def'}) {
	$in{'ttl'} =~ /^\d+$/ ||
		&error(&text('edit_ettl', $in{'ttl'}));
	$ttl = $in{'ttl'}.$in{'ttlunit'};
	}
$vals = $in{'value0'};
for($i=1; defined($in{"value$i"}); $i++) {
	$vals .= " ".$in{"value$i"};
	}
$vals =~ s/^\s+//;
$vals =~ s/\s+$//;

if ($in{'type'} eq "PTR" && $reverse) {
	# a reverse address
	local($ipv4);
	($ipv4 = $in{'origin'} =~ /in-addr\.arpa/i) ||
	    $in{'origin'} =~ /\.$ipv6revzone/i ||
		&error(&text('edit_eip', $in{'name'}));
	if ($ipv4) {
		if ($in{'name'} =~ /^\d+$/) {
			$in{'name'} = &arpa_to_ip($in{'origin'}).".".$in{'name'};
			}
		&check_ipaddress($in{'name'}) ||
		    ($in{'name'} =~ /^(.*)\.(\d+)$/ && &check_ipaddress("$1")) ||
		    ($in{'name'} =~ /^(.*)\.(\d+)$/ && $1 eq &arpa_to_ip($in{'origin'})) ||
			&error(&text('edit_eip', $in{'name'}));
		$name = &ip_to_arpa($in{'name'});
		}
	else {
		&check_ip6address($in{'name'}) ||
			&error(&text('edit_eip6', $in{'name'}));
		$name = &net_to_ip6int($in{'name'});
		}
	&valname($in{'value0'}) ||
		&error(&text('edit_ehost', $vals[0]));
	if ($in{'value0'} !~ /\.$/) { $vals .= "."; }
	}
else {
	# some other kind of record
	$in{'name'} eq "" || $in{'name'} eq "@" || &valnamewild($in{'name'}) ||
		&error(&text('edit_ename', $in{'name'}));
	if ($in{'type'} eq "A") {
		&check_ipaddress($vals) ||
			&error(&text('edit_eip', $vals));
		if (!$access{'multiple'}) {
			# Is this address already in use? Search all domains
			# to find out..
			foreach $z (@zl) {
				next if ($z->{'type'} ne "master");
				next if ($z->{'name'} =~ /in-addr\.arpa/i);
				$file = $z->{'file'};
				@frecs = &read_zone_file($file, $z->{'name'});
				foreach $fr (@frecs) {
					if ($fr->{'type'} eq "A" &&
					    $fr->{'values'}->[0] eq $vals &&
					    $fr->{'name'} ne $r->{'name'}) {
						&error(&text('edit_edupip',
							     $vals));
						}
					}
				}
			}
		}
	elsif ($in{'type'} eq "AAAA") {
		&check_ip6address($vals) ||
			&error(&text('edit_eip6', $vals));
		if (!$access{'multiple'}) {
			# Is this address already in use? Search all domains
			# to find out..
			foreach $z (@zl) {
				next if ($z->{'type'} ne "master");
				next if ($z->{'name'} =~ /\.$ipv6revzone/i);
				$file = $z->{'file'};
				@frecs = &read_zone_file($file, $z->{'name'});
				foreach $fr (@frecs) {
					if ($fr->{'type'} eq "AAAA" &&
					    &expandall_ip6($fr->{'values'}->[0]) eq &expandall_ip6($vals) &&
					    $fr->{'name'} ne $r->{'name'}) {
						&error(&text('edit_edupip',
							     $vals));
						}
					}
				}
			}
		}
	elsif ($in{'type'} eq "NS") {
		&valname($vals) ||
			&error(&text('edit_ens', $vals));
		if ($vals =~ /\.\Q$in{'origin'}\E$/) {
			# Make absolute
			$vals .= ".";
			}
		}
	elsif ($in{'type'} eq "CNAME") {
		&valname($vals) || $vals eq '@' ||
			&error(&text('edit_ecname', $vals));
		if ($vals =~ /\.\Q$in{'origin'}\E$/) {
			$vals .= ".";
			}
		}
	elsif ($in{'type'} eq "MX") {
		&valname($in{'value1'}) ||
			&error(&text('edit_emx', $in{'value1'}));
		$in{'value0'} =~ /^\d+$/ ||
			&error(&text('edit_epri', $in{'value0'}));
		if ($vals =~ /\.\Q$in{'origin'}\E$/) {
			$vals .= ".";
			}
		}
	elsif ($in{'type'} eq "HINFO") {
		$in{'value0'} =~ /\S/ ||
			&error($text{'edit_ehard'});
		$in{'value1'} =~ /\S/ ||
			&error($text{'edit_eos'});
		$in{'value0'} = "\"$in{'value0'}\"" if ($in{'value0'} =~ /\s/);
		$in{'value1'} = "\"$in{'value1'}\"" if ($in{'value1'} =~ /\s/);
		$vals = $in{'value0'}." ".$in{'value1'};
		}
	elsif ($in{'type'} eq "TXT") {
		$vals = $in{'value0'};
		$vals =~ s/((?:^|[^\\])(?:\\\\)*)[\"]/$1\\\"/g;
		$vals = "\"$vals\"";
		}
	elsif ($in{'type'} eq "WKS") {
		&check_ipaddress($in{'value0'}) ||
			&error(&text('edit_eip', $in{'value0'}));
		if (!$in{'value2'}) {
			&error($text{'edit_eserv'});
			}
		@ws = split(/[\r\n]+|\s+/, $in{'value2'});
		$vals = "$in{'value0'} $in{'value1'} (";
		foreach $ws (@ws) {
			$ws =~ /^[a-z]([\w\-]*\w)?$/i ||
				&error(&text('edit_ebadserv', $ws));
			$vals .= "\n\t\t\t\t\t$ws";
			}
		$vals .= " )";
		}
	elsif ($in{'type'} eq "RP") {
		if (!$in{'value0'}) {
			$in{'value0'} = ".";
			}
		elsif (!&valemail($in{'value0'})) {
			&error(&text('edit_eemail', $in{'value0'}));
			}
		&valname($in{'value1'}) ||
			&error(&text('edit_etxt', $in{'value1'}));
		$in{'value0'} = &email_to_dotted($in{'value0'});
		$vals = "$in{'value0'} $in{'value1'}";
		}
	elsif ($in{'type'} eq "LOC") {
		$in{'value0'} =~ /\S/ || &error($text{'edit_eloc'});
		}
	elsif ($in{'type'} eq 'SRV') {
		$in{'serv'} =~ /^[A-Za-z0-9\-\_]+$/ ||
			&error(&text('edit_eserv2', $in{'serv'}));
		$in{'name'} = join(".", "_".$in{'serv'}, "_".$in{'proto'},
				   $in{'name'} ? ( $in{'name'} ) : ( ));
		$in{'value0'} =~ /^\d+$/ ||
			&error(text('edit_epri', $in{'value0'}));
		$in{'value1'} =~ /^\d+$/ ||
			&error(text('edit_eweight', $in{'value1'}));
		$in{'value2'} =~ /^\d+$/ ||
			&error(text('edit_eport', $in{'value2'}));
		&valname($in{'value3'}) ||
			&error(&text('edit_etarget', $in{'value3'}));
		}
	elsif ($in{'type'} eq 'KEY') {
		$in{'value0'} =~ /^(\d+|0x[0-9a-f]+)$/i ||
			&error(text('edit_eflags', $in{'value0'}));
		$in{'value1'} =~ /^\d+$/ ||
			&error(text('edit_eproto', $in{'value1'}));
		$in{'value2'} =~ /^\d+$/ ||
			&error(text('edit_ealg', $in{'value2'}));
		$in{'value3'} =~ s/[ \r\n]//g;
		$in{'value3'} =~ /^[a-zA-Z0-9\/\+]+$/ ||
			&error(text('edit_ekey'));
		$vals = join(" ", $in{'value0'}, $in{'value1'},
				  $in{'value2'}, $in{'value3'});
		}
	elsif ($in{'type'} eq 'PTR') {
		$vals = $in{'value0'};
		&valname($vals) ||
			&error(&text('edit_eptr', $vals));
		}
	elsif ($in{'type'} eq 'SPF') {
		# For SPF records, build the SPF string from the inputs
		$spf = $r ? &parse_spf(@{$r->{'values'}}) : { };
		$spf->{'a'} = $in{'spfa'};
		$spf->{'mx'} = $in{'spfmx'};
		$spf->{'ptr'} = $in{'spfptr'};
		$spf->{'a:'} = [ split(/\s+/, $in{'spfas'}) ];
		foreach my $a (@{$spf->{'a:'}}) {
			&to_ipaddress($a) || &error(&text('edit_espfa', $a));
			}
		$spf->{'mx:'} = [ split(/\s+/, $in{'spfmxs'}) ];
		foreach my $mx (@{$spf->{'mx:'}}) {
			&valname($mx) || &error(&text('edit_espfmx', $mx));
			}
		@{$spf->{'mx:'}} <= 10 ||
			&error(&text('edit_espfmxmax', 10));
		$spf->{'ip4:'} = [ split(/\s+/, $in{'spfip4s'}) ];
		foreach my $ip (@{$spf->{'ip4:'}}) {
			&check_ipaddress($ip) ||
			  ($ip =~ /^(\S+)\/\d+$/ && &check_ipaddress($1)) ||
			    &error(&text('edit_espfip', $ip));
			}
		if (&supports_ipv6()) {
			$spf->{'ip6:'} = [ split(/\s+/, $in{'spfip6s'}) ];
			foreach my $ip (@{$spf->{'ip6:'}}) {
				&check_ip6address($ip) ||
				  ($ip =~ /^(\S+)\/\d+$/ &&
				   &check_ip6address($1)) ||
				    &error(&text('edit_espfip6', $ip));
				}
			}
		$spf->{'include:'} = [ split(/\s+/, $in{'spfincludes'}) ];
		foreach my $i (@{$spf->{'include:'}}) {
			&valname($i) || &error(&text('edit_espfinclude', $i));
			}
		$spf->{'all'} = $in{'spfall'};
		foreach my $m ('redirect', 'exp') {
			if ($in{'spf'.$m.'_def'}) {
				delete($spf->{$m});
				}
			else {
				&valname($in{'spf'.$m}) || 
					&error(&text('edit_espf'.$m, 
						     $in{'spf'.$m}));
				$spf->{$m} = $in{'spf'.$m};
				}
			}
		$vals = "\"".&join_spf($spf)."\"";
		}
	else {
		# For other record types, just save the lines
		$in{'values'} =~ s/\r//g;
		local @vlines = split(/\n/, $in{'values'});
		$vals = join(" ",map { $_ =~ /^\S+$/ ? $_ : "\"$_\"" } @vlines);
		}
	$fullname = &convert_to_absolute($in{'name'}, $in{'origin'});
	if ($config{'short_names'}) {
		$name = $in{'name'};
		}
	else {
		$name = $fullname;
		}
	}

# check for CNAME collision
if (!defined($in{'num'}) || $name ne $r->{'name'}) {
	foreach $cr (@recs) {
		if ($cr->{'name'} eq $name) {
			if ($in{'type'} eq CNAME) {
				&error($text{'edit_ecname1'});
				}
			elsif ($cr->{'type'} eq 'CNAME') {
				&error($text{'edit_ecname2'});
				}
			}
		}
	}

if ($in{'new'}) {
	# adding a new record
	($revconf, $revfile, $revrec) = &find_reverse($in{'value0'},
						      $in{'view'});
	if ($in{'rev'} && $config{'rev_must'} && !$revconf) {
		# Reverse zone must exist, but doesn't
		&error($text{'edit_erevmust'});
		}
	&create_record($in{'file'}, $name, $ttl, "IN", $in{'type'}, $vals,
		       $in{'comment'});
	$r = { 'name' => $name, 'ttl' => $ttl, 'class' => 'IN',
	       'type' => $in{'type'}, 'values' => [ split(/\s+/, $vals) ],
	       'comment' => $in{'comment'} };
	if ($in{'rev'} && $revconf && &can_edit_reverse($revconf) &&
	    $in{'value0'} !~ /\*/) {
		local $rname = $in{'type'} eq "A" ? &ip_to_arpa($in{'value0'})
						: &net_to_ip6int($in{'value0'});
		if ($revrec && $in{'rev'} == 2) {
			# Upate the existing reverse for the domain
			&lock_file(&make_chroot($revrec->{'file'}));
			&modify_record($revrec->{'file'}, $revrec,
				       $rname, $revrec->{'ttl'}, "IN", "PTR",
				       $fullname);
			@rrecs = &read_zone_file($revfile, $revconf->{'name'});
			&bump_soa_record($revfile, \@rrecs);
			&sign_dnssec_zone_if_key($revconf, \@rrecs);
			}
		elsif (!$revrec) {
			# Add a reverse record if we are the master for the
			# reverse domain, and if there is not already a
			# reverse record for the address.
			&lock_file(&make_chroot($revfile));
			&create_record($revfile, $rname,
				$ttl, "IN", "PTR", $fullname);
			@rrecs = &read_zone_file($revfile, $revconf->{'name'});
			&bump_soa_record($revfile, \@rrecs);
			&sign_dnssec_zone_if_key($revconf, \@rrecs);
			}
		}

	($fwdconf, $fwdfile, $fwdrec) = &find_forward($vals, $vals =~ /\.$ipv6revzone/i);
	if ($in{'fwd'} && $fwdconf && !$fwdrec &&
	    &can_edit_zone($fwdconf)) {
		# Add a forward record if we are the master for the forward
		# domain, and if there is not already an A record
		# for the address
		local($rtype);
		if (&check_ipaddress($in{'name'})) {
			$rtype = "A";
			}
		elsif ($config{'support_aaaa'} &&
		       &check_ip6address($in{'name'})) {
			$rtype = "AAAA";
			}
		if ($rtype) {
			&lock_file(&make_chroot($fwdfile));
			&create_record($fwdfile, $vals,
				       $ttl, "IN", $rtype, $in{'name'});
			@frecs = &read_zone_file($fwdfile, $fwdconf->{'name'});
			&bump_soa_record($fwdfile, \@frecs);
			&sign_dnssec_zone_if_key($fwdconf, \@frecs);
			}
		}
	}
else {
	# update an existing record
	$fulloldvalue0 = &convert_to_absolute($in{'oldvalue0'}, $in{'origin'});
	$fulloldname = &convert_to_absolute($in{'oldname'}, $in{'origin'});
	($orevconf, $orevfile, $orevrec) = &find_reverse($in{'oldvalue0'},
							 $in{'view'});
	($revconf, $revfile, $revrec) = &find_reverse($in{'value0'},
						      $in{'view'});
	if ($in{'rev'} && $config{'rev_must'} && !$revconf) {
		# Reverse zone must exist, but doesn't
		&error($text{'edit_erevmust'});
		}
	&lock_file(&make_chroot($r->{'file'}));
	&modify_record($r->{'file'}, $r, $name, $ttl,
		       "IN", $in{'type'}, $vals, $in{'comment'});

	if ($in{'rev'} && $orevrec && &can_edit_reverse($orevconf) &&
	    $fulloldname eq $orevrec->{'values'}->[0] &&
	    ($in{'type'} eq "A" &&
	     $in{'oldvalue0'} eq &arpa_to_ip($orevrec->{'name'}) ||
	     $in{'type'} eq "AAAA" &&
	     &expandall_ip6($in{'oldvalue0'}) eq &expandall_ip6(&ip6int_to_net($orevrec->{'name'})))) {
		# Updating the reverse record. Either the name, address
		# or both may have changed. Furthermore, the reverse record
		# may now be in a different file!
		&lock_file(&make_chroot($orevfile));
		&lock_file(&make_chroot($revfile));
		@orrecs = &read_zone_file($orevfile, $orevconf->{'name'});
		@rrecs = &read_zone_file($revfile, $revconf->{'name'});
		if ($revconf eq $orevconf && &can_edit_reverse($revconf)) {
			# old and new in the same file
			&modify_record($orevrec->{'file'} , $orevrec, 
				       &net_to_ip6int(&ip_to_arpa($in{'value0'})),
				       $orevrec->{'ttl'}, "IN", "PTR", $fullname,
				       $in{'comment'});
			&bump_soa_record($orevfile, \@orrecs);
			&sign_dnssec_zone_if_key($orevconf, \@orrecs);
			}
		elsif ($revconf && &can_edit_reverse($revconf)) {
			# old and new in different files
			&delete_record($orevrec->{'file'} , $orevrec);
			&create_record($revfile, &net_to_ip6int(&ip_to_arpa($in{'value0'})),
				       $orevrec->{'ttl'}, "IN", "PTR", $fullname,
				       $in{'comment'});
			&bump_soa_record($orevfile, \@orrecs);
			&bump_soa_record($revfile, \@rrecs);
			&sign_dnssec_zone_if_key($orevconf, \@orrecs);
			&sign_dnssec_zone_if_key($revconf, \@rrecs);
			}
		else {
			# we don't handle the new reverse domain.. lose the
			# reverse record
			&delete_record($orevrec->{'file'}, $orevrec);
			&bump_soa_record($orevfile, \@orrecs);
			&sign_dnssec_zone_if_key($orevconf, \@orrecs);
			}
		}
	elsif ($in{'rev'} && !$orevrec && $revconf && !$revrec && 
	       &can_edit_reverse($revconf)) {
		# we don't handle the old reverse domain but handle the new 
		# one.. create a new reverse record
	 	&lock_file(&make_chroot($revfile));
		@rrecs = &read_zone_file($revfile, $revconf->{'name'});
		&create_record($revfile, &net_to_ip6int(&ip_to_arpa($in{'value0'})),
			       $ttl, "IN", "PTR", $fullname, $in{'comment'});
		&bump_soa_record($revfile, \@rrecs);
		&sign_dnssec_zone_if_key($revconf, \@rrecs);
		}

	local($ipv6 = ($in{'value0'} =~ /\.$ipv6revzone/i));
	($ofwdconf, $ofwdfile, $ofwdrec) = &find_forward($fulloldvalue0, $ipv6);
	($fwdconf, $fwdfile, $fwdrec) =	&find_forward($in{'value0'}, $ipv6);
	if ($in{'fwd'} && $ofwdrec && &can_edit_zone($ofwdconf) &&
	    &expandall_ip6(&ip6int_to_net(&arpa_to_ip($in{'oldname'}))) eq
	    &expandall_ip6($ofwdrec->{'values'}->[0]) &&
	    $fulloldvalue0 eq $ofwdrec->{'name'}) {
		# Updating the forward record
		&lock_file(&make_chroot($ofwdfile));
		&lock_file(&make_chroot($fwdfile));
		@ofrecs = &read_zone_file($ofwdfile, $ofwdconf->{'name'});
		@frecs = &read_zone_file($fwdfile, $fwdconf->{'name'});
		if ($fwdconf eq $ofwdconf &&
		    &can_edit_zone($fwdconf)) {
			# old and new are in the same file
			&modify_record($ofwdrec->{'file'} , $ofwdrec, $vals,
				       $ofwdrec->{'ttl'}, "IN",
				       $ipv6 ? "AAAA" : "A",
				       $in{'name'}, $in{'comment'});
			&bump_soa_record($ofwdfile, \@ofrecs);
			&sign_dnssec_zone_if_key($ofwdconf, \@ofrecs);
			}
		elsif ($fwdconf && &can_edit_zone($fwdconf)) {
			# old and new in different files
			&delete_record($ofwdrec->{'file'} , $ofwdrec);
			if (!ipv6 || $config{'support_aaaa'}) {
				&create_record($fwdfile, $vals, $ofwdrec->{'ttl'},
					       "IN", $ipv6 ? "AAAA" : "A",
					       $in{'name'}, $in{'comment'});
				&bump_soa_record($fwdfile, \@frecs);
				&sign_dnssec_zone_if_key($fwdconf, \@frecs);
				}
			&bump_soa_record($ofwdfile, \@ofrecs);
			&sign_dnssec_zone_if_key($ofwdconf, \@ofrecs);
			}
		else {
			# lose the forward because it has been moved to
			# a zone not handled by this server
			&delete_record($ofwdrec->{'file'} , $ofwdrec);
			&bump_soa_record($ofwdfile, \@ofrecs);
			&sign_dnssec_zone_if_key($ofwdconf, \@ofrecs);
			}
		}
	}
&bump_soa_record($in{'file'}, \@recs);
&sign_dnssec_zone_if_key($zone, \@recs);
&unlock_all_files();
$r->{'newvalues'} = $vals;
&webmin_log($in{'new'} ? 'create' : 'modify', 'record', $in{'origin'}, $r);
&redirect("edit_recs.cgi?index=$in{'index'}&view=$in{'view'}&type=$in{'redirtype'}&sort=$in{'sort'}");

# valname(name)
sub valname
{
return valdnsname($_[0], 0, $in{'origin'});
}

# valnamewild(name)
sub valnamewild
{
return valdnsname($_[0], 1, $in{'origin'});
}

