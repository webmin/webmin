#!/usr/local/bin/perl
# delete_zone.cgi
# Delete an existing master, slave or secondary zone, and it's records file

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
# Globals from bind8-lib.pl
our (%access, %text, %in, %config);
# Globals from records-lib.pl
our $ipv6revzone;

require './bind8-lib.pl';
&ReadParse();

my $zone = &get_zone_name_or_error($in{'zone'}, $in{'view'});
my ($zconf, $conf, $parent) = &zone_to_config($zone);
&can_edit_zone($zone) ||
	&error($text{'master_edelete'});

$access{'ro'} && &error($text{'master_ero'});
$access{'delete'} || &error($text{'master_edeletecannot'});

my $rev = ($zconf->{'value'} =~ /in-addr\.arpa/i ||
	$zconf->{'value'} =~ /\.$ipv6revzone/i);
my $type = &find("type", $zconf->{'members'})->{'value'};
$type = 'master' if ($type eq 'primary');
$type = 'slave' if ($type eq 'secondary');
if (!$in{'confirm'} && $config{'confirm_zone'}) {
	# Ask the user if he is sure ..
	&ui_print_header(undef, $text{'delete_title'}, "",
			 undef, undef, undef, undef, &restart_links());

	# Check if deleted on slaves too
	my @servers = &list_slave_servers();
	if ($type eq 'slave' || $type eq 'stub') {
		@servers = grep { $_->{'sec'} } @servers;
		}
	elsif ($type ne 'master') {
		@servers = ( );
		}

	# Check if controlled by Virtualmin
	my @doms = &get_virtualmin_domains($zconf->{'value'});
	my $vwarn;
	if (@doms) {
		my $f = "<tt>$doms[0]->{'dom'}</tt>";
		$vwarn = @doms == 1 ? &text('delete_vwarn', $f)
				    : &text('delete_vwarn2', $f, @doms-1);
		}

	my $zdesc = "<tt>".&ip6int_to_net(&arpa_to_ip($zconf->{'value'}))."</tt>";
	print &ui_confirmation_form("delete_zone.cgi",
		$type eq 'hint' ? $text{'delete_mesg2'} :
		$type eq 'master' ? &text('delete_mesg', $zdesc) :
				    &text('delete_mesg3', $zdesc),
		[ [ 'zone', $in{'zone'} ],
		  [ 'view', $in{'view'} ] ],
		[ [ 'confirm', $text{'master_del'} ] ],
		($type eq 'master' ?
			$text{$rev ? 'delete_fwd' : 'delete_rev'}." ".
			&ui_yesno_radio("rev", 1)."<br>" : "").
		(@servers && $access{'remote'} ?
			$text{'delete_onslave'}." ".
			&ui_yesno_radio("onslave", 1)."<br>" : ""),
		$vwarn,
		);

	&ui_print_footer("", $text{'index_return'});
	exit;
	}

my @recs;
if (!$rev && $in{'rev'} && $type eq 'master') {
	# find and delete reverse records
	my $file = &find("file", $zconf->{'members'})->{'value'};
	&lock_file(&make_chroot($file));
	@recs = &read_zone_file($file, $zconf->{'value'});
	foreach my $r (@recs) {
		next if ($r->{'type'} ne "A" && $r->{'type'} ne "AAAA");
		my ($orevconf, $orevfile, $orevrec) =
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
			my @orrecs = &read_zone_file($orevfile,
						  $orevconf->{'name'});
			&bump_soa_record($orevfile, \@orrecs);
			&sign_dnssec_zone_if_key($orevconf, \@orrecs);
			}
		}
	}
elsif ($rev && $in{'rev'} && $type eq 'master') {
	# find and delete forward records
	my $file = &find("file", $zconf->{'members'})->{'value'};
	&lock_file(&make_chroot($file));
	@recs = &read_zone_file($file, $zconf->{'value'});
	foreach my $r (@recs) {
		next if ($r->{'type'} ne "PTR");
		my ($ofwdconf, $ofwdfile, $ofwdrec) =
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
			my @ofrecs = &read_zone_file($ofwdfile,
						  $ofwdconf->{'name'});
			&bump_soa_record($ofwdfile, \@ofrecs);
			&sign_dnssec_zone_if_key($ofwdconf, \@ofrecs);
			}
		}
	}

# delete the records file
my $f = &find("file", $zconf->{'members'});
if ($f && $type ne 'hint') {
	&delete_records_file($f->{'value'});
	}

# delete any keys
&delete_dnssec_key($zconf, 0);

# delete all dnssec-tools related state
&dt_delete_dnssec_state($zconf);

# remove the zone directive
&lock_file(&make_chroot($zconf->{'file'}));
&save_directive($parent, [ $zconf ], [ ]);
&flush_file_lines();
&unlock_all_files();
&webmin_log("delete", &find("type", $zconf->{'members'})->{'value'},
	    $zconf->{'value'}, \%in);

# remove from acl files
my %wusers;
&read_acl(undef, \%wusers);
foreach my $u (keys %wusers) {
	my %uaccess = &get_module_acl($u);
	if ($uaccess{'zones'} ne '*') {
		$uaccess{'zones'} = join(' ', grep { $_ ne $zconf->{'value'} }
					      split(/\s+/, $uaccess{'zones'}));
		&save_module_acl(\%uaccess, $u);
		}
	}

# Also delete from slave servers
delete($ENV{'HTTP_REFERER'});
if ($in{'onslave'} && $access{'remote'}) {
	my @slaveerrs = &delete_on_slaves($zone->{'name'}, undef, $zone->{'view'});
	if (@slaveerrs) {
		&error(&text('delete_errslave',
		     "<p>".join("<br>", map { "$_->[0]->{'host'} : $_->[1]" }
				      @slaveerrs)));
		}
	}

&redirect("");

