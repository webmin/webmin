#!/usr/local/bin/perl
# Delete all records of some type with some name
use strict;
use warnings;
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
$in{'name_def'} || $in{'name'} || &error($text{'rdmass_ename'});

# Do each one
&ui_print_unbuffered_header(undef, $text{'rdmass_title'}, "");

foreach my $zi (@zones) {
	print &text('rdmass_doing', "<tt>$zi->{'name'}</tt>"),"<br>\n";
	if ($zi->{'type'} ne 'master') {
		# Skip - not a master zone
		print $text{'umass_notmaster'},"<p>\n";
		next;
		}
	my $rcount = 0;
	my @recs = &read_zone_file($zi->{'file'}, $zi->{'name'});
	my $realfile = &make_chroot(&absolute_path($zi->{'file'}));
	foreach my $r (reverse(@recs)) {
		my $shortname = $r->{'name'};
		$shortname =~ s/\.$zi->{'name'}\.$//;
		my $v = join(" ", @{$r->{'values'}});
		if ($r->{'type'} eq $in{'type'} &&
		    ($shortname eq $in{'name'} || $in{'name_def'}) &&
		    ($v eq $in{'value'} || $in{'value_def'})) {
			# Found a record to delete
			&lock_file($realfile);
			&delete_record($zi->{'file'}, $r);
			$rcount++;
			}
		}
	if ($rcount) {
		&bump_soa_record($zi->{'file'}, \@recs);
		&sign_dnssec_zone_if_key($zi, \@recs);
		print &text('rdmass_done', $rcount, scalar(@recs)),"<p>\n";
		}
	else {
		print &text('rdmass_none', scalar(@recs)),"<p>\n";
		}
	}

&unlock_all_files();
&webmin_log("rdelete", "zones", scalar(@zones));

&ui_print_footer("", $text{'index_return'});

