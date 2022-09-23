#!/usr/local/bin/perl
# Change all instances of some IP 
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%access, %text, %in);

require './bind8-lib.pl';
&ReadParse();
&error_setup($text{'umass_err'});

# Get the zones
my @zones;
foreach my $d (split(/\0/, $in{'d'})) {
	my ($zonename, $viewidx) = split(/\s+/, $d);
	my $zone = &get_zone_name_or_error($zonename, $viewidx);
	$zone || &error($text{'umass_egone'});
	&can_edit_zone($zone) ||
		&error($text{'master_edelete'});
	push(@zones, $zone);
	}
$access{'ro'} && &error($text{'master_ero'});

# Validate inputs
$in{'old'} =~ s/\s+/ /g;
$in{'old_def'} || $in{'old'} || &error($text{'umass_eold'});
$in{'new'} || &error($text{'umass_enew'});
if ($in{'type'} eq 'A') {
	&check_ipaddress($in{'new'}) ||
		&error(&text('edit_eip', $in{'new'}));
	}
elsif ($in{'type'} eq 'AAAA') {
	&check_ip6address($in{'new'}) ||
		&error(&text('edit_eip6', $in{'new'}));
	}
elsif ($in{'type'} eq 'NS') {
	&valname($in{'new'}) ||
		&error(&text('edit_ens', $in{'new'}));
	}
elsif ($in{'type'} eq 'CNAME') {
	&valname($in{'new'}) || $in{'new'} eq '@' ||
		&error(&text('edit_ecname', $in{'new'}));
	}
elsif ($in{'type'} eq 'MX') {
	$in{'new'} =~ /^(\d+)\s+(\S+)$/ && &valname("$2") ||
		&error(&text('emass_emx', $in{'new'}));
	}
elsif ($in{'type'} eq 'TXT' || $in{'type'} eq 'SPF') {
	$in{'new'} = "\"$in{'new'}\"";
	}
elsif ($in{'type'} eq 'PTR') {
	&valname($in{'new'}) ||
		&error(&text('edit_eptr', $in{'new'}));
	}
elsif ($in{'type'} eq 'ttl') {
	$in{'new'} =~ /^\d+$/ || 
		&error(&text('master_edefttl', $in{'new'}));
	}

# Do each one
&ui_print_unbuffered_header(undef, $text{'umass_title'}, "");

foreach my $zi (@zones) {
	print &text('umass_doing', "<tt>$zi->{'name'}</tt>"),"<br>\n";
	if ($zi->{'type'} ne 'master' && $zi->{'type'} ne 'primary') {
		# Skip - not a master zone
		print $text{'umass_notmaster'},"<p>\n";
		next;
		}
	my $rcount = 0;
	&before_editing($zi);
	my @recs = &read_zone_file($zi->{'file'}, $zi->{'name'});
	my $realfile = &make_chroot(&absolute_path($zi->{'file'}));
	foreach my $r (@recs) {
		my $v = join(" ", @{$r->{'values'} || []});
		if ($r->{'type'} eq $in{'type'} &&
		    ($v eq $in{'old'} || $in{'old_def'})) {
			# Found a regular record to fix
			&lock_file($realfile);
			&modify_record($zi->{'file'}, $r, $r->{'name'},
				       $r->{'ttl'}, $r->{'class'}, $r->{'type'},
				       $in{'new'}, $r->{'cmt'});
			$rcount++;
			}
		elsif ($in{'type'} eq 'ttl' && $r->{'defttl'}) {
			# Found default TTL to fix
			&lock_file($realfile);
			&modify_defttl($zi->{'file'}, $r, $in{'new'});
			$rcount++;
			}
		}
	if ($rcount) {
		&bump_soa_record($zi->{'file'}, \@recs);
		&sign_dnssec_zone_if_key($zi, \@recs);
		print &text('umass_done', $rcount, scalar(@recs)),"<p>\n";
		}
	else {
		print &text('umass_none', scalar(@recs)),"<p>\n";
		}
	&after_editing($zi);
	}

&unlock_all_files();
&webmin_log("update", "zones", scalar(@zones));

&ui_print_footer("", $text{'index_return'});

# valname(name)
sub valname
{
return valdnsname($_[0], 0, $in{'origin'});
}

