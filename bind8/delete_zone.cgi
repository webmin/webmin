#!/usr/local/bin/perl
# delete_zone.cgi
# Delete an existing master, slave or secondary zone, and it's records file

require './bind8-lib.pl';
&ReadParse();
$conf = &get_config();
if ($in{'view'} ne '') {
	$view = $conf->[$in{'view'}];
	$conf = $view->{'members'};
	}
$zconf = $conf->[$in{'index'}];
&can_edit_zone($zconf, $view) ||
	&error($text{'master_edelete'});
$access{'ro'} && &error($text{'master_ero'});
$access{'delete'} || &error($text{'master_edeletecannot'});

$rev = ($zconf->{'value'} =~ /in-addr\.arpa/i || $zconf->{'value'} =~ /\.$ipv6revzone/i);
$type = &find("type", $zconf->{'members'})->{'value'};
if (!$in{'confirm'} && $config{'confirm_zone'}) {
	# Ask the user if he is sure ..
	&ui_print_header(undef, $text{'delete_title'}, "");

	print "<center><p>\n";
	if ($type eq 'hint') {
		print $text{'delete_mesg2'},"<p>\n";
		}
	else {
		print &text('delete_mesg', "<tt>".&ip6int_to_net(&arpa_to_ip(
			$zconf->{'value'}))."</tt>"),"<p>\n";
		}
	print "<form action=delete_zone.cgi>\n";
	print "<input type=hidden name=index value=$in{'index'}>\n";
	print "<input type=hidden name=view value=$in{'view'}>\n";
	print "<input type=submit name=confirm value='$text{'delete'}'><br>\n";
	if ($type eq 'master') {
		print $text{$rev ? 'delete_fwd' : 'delete_rev'},"\n";
		print &ui_yesno_radio("rev", 1),"<br>\n";
		}

	# Ask if zone should be deleted on slaves too
	@servers = &list_slave_servers();
	if ($type eq 'slave' || $type eq 'stub') {
		@servers = grep { $_->{'sec'} } @servers;
		}
	elsif ($type ne 'master') {
		@servers = ( );
		}
	if (@servers && $access{'remote'}) {
		print $text{'delete_onslave'},"\n";
		print &ui_yesno_radio("onslave", 1),"<br>\n";
		}
	print "</form></center>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}

if (!$rev && $in{'rev'} && $type eq 'master') {
	# find and delete reverse records
	local $file = &find("file", $zconf->{'members'})->{'value'};
	&lock_file(&make_chroot($file));
	@recs = &read_zone_file($file, $zconf->{'value'});
	foreach $r (@recs) {
		next if ($r->{'type'} ne "A" && $r->{'type'} ne "AAAA");
		($orevconf, $orevfile, $orevrec) =
			&find_reverse($r->{'values'}->[0], $in{'view'});
		if ($orevrec && &can_edit_reverse($orevconf) &&
		    $r->{'name'} eq $orevrec->{'values'}->[0] &&
		    ($r->{'type'} eq "A" &&
		     $r->{'values'}->[0] eq &arpa_to_ip($orevrec->{'name'})
		     || $r->{'type'} eq "AAAA" &&
		     &expandall_ip6($r->{'values'}->[0]) eq &expandall_ip6(&ip6int_to_net($orevrec->{'name'})))) {
			&lock_file(&make_chroot($orevrec->{'file'}));
			&delete_record($orevrec->{'file'} , $orevrec);
			&lock_file(&make_chroot($orevfile));
			@orrecs = &read_zone_file($orevfile,
						  $orevconf->{'name'});
			&bump_soa_record($orevfile, \@orrecs);
			}
		}
	}
elsif ($rev && $in{'rev'} && $type eq 'master') {
	# find and delete forward records
	local $file = &find("file", $zconf->{'members'})->{'value'};
	&lock_file(&make_chroot($file));
	@recs = &read_zone_file($file, $zconf->{'value'});
	foreach $r (@recs) {
		next if ($r->{'type'} ne "PTR");
		($ofwdconf, $ofwdfile, $ofwdrec) =
			&find_forward($r->{'values'}->[0]);
		if ($ofwdrec && &can_edit_zone($ofwdconf) &&
		    ($ofwdrec->{'type'} eq "A" &&
		     &arpa_to_ip($r->{'name'}) eq $ofwdrec->{'values'}->[0] 
		     || $ofwdrec->{'type'} eq "AAAA" &&
		     &expandall_ip6(&ip6int_to_net($r->{'name'})) eq &expandall_ip6($ofwdrec->{'values'}->[0])) &&
		    $r->{'values'}->[0] eq $ofwdrec->{'name'}) {
			&lock_file(&make_chroot($ofwdrec->{'file'}));
			&delete_record($ofwdrec->{'file'} , $ofwdrec);
			&lock_file(&make_chroot($ofwdfile));
			@ofrecs = &read_zone_file($ofwdfile,
						  $ofwdconf->{'name'});
			&bump_soa_record($ofwdfile, \@ofrecs);
			}
		}
	}

# delete the records file
$f = &find("file", $zconf->{'members'});
if ($f && $type ne 'hint') {
	local $zonefile = &make_chroot(&absolute_path($f->{'value'}));
	&lock_file($zonefile);
	unlink($zonefile);
	local $logfile = $zonefile.".log";
	if (!-r $logfile) { $logfile = $zonefile.".jnl"; }
	if (-r $logfile) {
		&lock_file($logfile);
		unlink($logfile);
		}
	}

# remove the zone directive
&lock_file(&make_chroot($zconf->{'file'}));
$lref = &read_file_lines(&make_chroot($zconf->{'file'}));
splice(@$lref, $zconf->{'line'}, $zconf->{'eline'} - $zconf->{'line'} + 1);
&flush_file_lines();
&unlock_all_files();
&webmin_log("delete", &find("type", $zconf->{'members'})->{'value'},
	    $zconf->{'value'}, \%in);

# remove from acl files
&read_acl(undef, \%wusers);
foreach $u (keys %wusers) {
	%uaccess = &get_module_acl($u);
	if ($uaccess{'zones'} ne '*') {
		$uaccess{'zones'} = join(' ', grep { $_ ne $zconf->{'value'} }
					      split(/\s+/, $uaccess{'zones'}));
		&save_module_acl(\%uaccess, $u);
		}
	}

# Also delete from slave servers
if ($in{'onslave'} && $access{'remote'}) {
	@slaveerrs = &delete_on_slaves($zconf->{'value'});
	if (@slaveerrs) {
		&error(&text('delete_errslave',
		     "<p>".join("<br>", map { "$_->[0]->{'host'} : $_->[1]" }
				      @slaveerrs)));
		}
	}

&redirect("");

sub slave_error_handler
{
$slave_error = $_[0];
}

