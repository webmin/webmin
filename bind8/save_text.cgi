#!/usr/local/bin/perl
# save_text.cgi
# Save a manually edit zone file
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%access, %text, %in);

require './bind8-lib.pl';
&ReadParseMime();
my $zone = &get_zone_name_or_error($in{'zone'}, $in{'view'});
my $file = &absolute_path($zone->{'file'});
my $tv = $zone->{'type'};
&can_edit_zone($zone) ||
	&error($text{'master_ecannot'});
$access{'file'} || &error($text{'text_ecannot'});
$access{'ro'} && &error($text{'master_ero'});

# Write out the file
&lock_file(&make_chroot($file));
&before_editing($zone);
$in{'text'} =~ s/\r//g;
$in{'text'} .= "\n" if ($in{'text'} !~ /\n$/);
my $FILE;
&open_tempfile($FILE, ">".&make_chroot($file));
&print_tempfile($FILE, $in{'text'});
&close_tempfile($FILE);

# BUMP soa too
my @recs = &read_zone_file($file, $zone->{'name'});
if ($in{'soa'}) {
	&bump_soa_record($file, \@recs);
	}

# Sign too
&sign_dnssec_zone_if_key($zone, \@recs);

&after_editing($zone);
&unlock_file(&make_chroot($file));
&webmin_log("text", undef, $zone->{'name'},
	    { 'file' => $file });
&redirect("edit_master.cgi?zone=$in{'zone'}&view=$in{'view'}");

