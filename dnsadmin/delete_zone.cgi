#!/usr/local/bin/perl
# delete_zone.cgi
# Delete a master or slave zone

require './dns-lib.pl';
&ReadParse();
$conf = &get_config();
$zconf = $conf->[$in{'index'}];
%access = &get_module_acl();
&can_edit_zone(\%access, $zconf->{'values'}->[0]) ||
        &error("You are not allowed to delete this zone");

$rev = $zconf->{'values'}->[0] =~ /in-addr.arpa/i;
if (!$in{'confirm'}) {
	# Ask the user if he is sure ..
	&header("Delete Zone", "");
	print &ui_hr();

	print "<center><p>Are you sure you want to delete the zone <tt>",
		&arpa_to_ip($zconf->{'values'}->[0]),"</tt> ? All records ",
		"and the zone file will  be deleted.<p>\n";
	print "<form action=delete_zone.cgi>\n";
	print "<input type=hidden name=index value=$in{'index'}>\n";
	print "<input type=submit name=confirm value='$text{'delete'}'><br>\n";
	print $rev ? "Delete forward records in other zones ?\n" :
		     "Delete reverse records in other zones ?\n";
	print "<input type=radio name=rev value=1 checked> $text{'yes'}\n";
	print "<input type=radio name=rev value=0> $text{'no'}\n";
	print "</form></center>\n";
	print &ui_hr();
	&footer("", "record types");
	exit;
	}

if (!$rev && $in{'rev'} && $zconf->{'name'} eq 'primary') {
	# find and delete reverse records
	&lock_file($zconf->{'values'}->[1]);
	@recs = &read_zone_file($zconf->{'values'}->[1],
				$zconf->{'values'}->[0]);
	foreach $r (@recs) {
		next if ($r->{'type'} ne "A");
		($orevconf, $orevfile, $orevrec) =
			&find_reverse($r->{'values'}->[0]);
		if ($orevrec && &can_edit_reverse($orevconf) &&
		    $r->{'name'} eq $orevrec->{'values'}->[0] &&
		    $r->{'values'}->[0] eq &arpa_to_ip($orevrec->{'name'})) {
			&lock_file($orevrec->{'file'});
			&delete_record($orevrec->{'file'} , $orevrec);
			&lock_file($orevfile);
			@orrecs = &read_zone_file(
				$orevfile, $orevconf->{'values'}->[0]);
			&bump_soa_record($orevfile, \@orrecs);
			}
		}
	}
elsif ($rev && $in{'rev'} && $zconf->{'name'} eq 'primary') {
	# find and delete forward records
	&lock_file($zconf->{'values'}->[1]);
	@recs = &read_zone_file($zconf->{'values'}->[1],
			        $zconf->{'values'}->[0]);
	foreach $r (@recs) {
		next if ($r->{'type'} ne "PTR");
		($ofwdconf, $ofwdfile, $ofwdrec) =
			&find_forward($r->{'values'}->[0]);
		if ($ofwdrec && &can_edit_zone($ofwdconf->{'values'}->[0]) &&
		    &arpa_to_ip($r->{'name'}) eq $ofwdrec->{'values'}->[0] &&
		    $r->{'values'}->[0] eq $ofwdrec->{'name'}) {
			&lock_file($ofwdrec->{'file'});
			&delete_record($ofwdrec->{'file'} , $ofwdrec);
			&lock_file($ofwdfile);
			@ofrecs = &read_zone_file($ofwdfile,
						  $ofwdconf->{'value'});
			&bump_soa_record($ofwdfile, \@ofrecs);
			}
		}
	}

&lock_file($zconf->{'file'});
&delete_zone($zconf);
if ($zconf->{'name'} eq "primary") {
	&lock_file(&absolute_path($zconf->{'values'}->[1]));
	unlink(&absolute_path($zconf->{'values'}->[1]));
	}
&unlock_all_files();
&webmin_log("delete", $zconf->{'name'} eq "primary" ? "master" : "slave",
	    $zconf->{'values'}->[0], \%in);

# remove from acl files
&read_acl(undef, \%wusers);
foreach $u (keys %wusers) {
        %uaccess = &get_module_acl($u);
        if ($uaccess{'zones'} ne '*') {
                $uaccess{'zones'} =
			join(' ', grep { $_ ne $zconf->{'values'}->[0] }
                                  split(/\s+/, $uaccess{'zones'}));
                &save_module_acl(\%uaccess, $u);
                }
        }
&redirect("");

# can_edit_reverse(&zone)
sub can_edit_reverse
{
return $access{'reverse'} || &can_edit_zone(\%access, $_[0]->{'values'}->[0]);
}

